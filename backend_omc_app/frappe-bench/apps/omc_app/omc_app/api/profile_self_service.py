from __future__ import annotations

import json
import re

import frappe
from frappe import _
from frappe.exceptions import PermissionError, ValidationError
from frappe.utils import now_datetime

from omc_app.api import mobile, profile_location


ALLOWED_FIELDS = {
    "full_name": 140,
    "phone": 40,
    "whatsapp_no": 40,
    "address": 500,
}
PROTECTED_ONCE_FIELDS = {
    "cnic": 40,
    "ntn": 40,
    "company_name": 140,
}
SELF_SERVICE_ONCE_FIELDS = {
    *PROTECTED_ONCE_FIELDS,
}
PROTECTED_FIELD_LABELS = {
    "email": "Email",
    "cnic": "CNIC",
    "ntn": "NTN",
    "company_name": "Company name",
}
LOCKED_FIELDS = {
    "email",
    "user",
    "username",
    "tax_id",
    "customer_type",
    "register_as",
    "approval_status",
    "customer_status",
}
AUDIT_DOCTYPE = "OMC Profile Change Log"
PROTECTED_CORRECTION_SOURCE = "Mobile App Protected Correction"

INTERNAL_ALLOWED_FIELDS = {
    "full_name",
    "phone",
    "whatsapp_no",
    "address",
    "education",
    "experience",
    "remarks",
}


def _current_user() -> str:
    user = str(frappe.session.user or "").strip()
    if not user or user == "Guest":
        frappe.throw(_("Login is required."), PermissionError)
    return user


def _normalise_phone(value: str) -> str:
    clean = str(value or "").strip()
    if not clean:
        return ""

    digits = re.sub(r"\D", "", clean)
    if digits.startswith("92"):
        local = digits[2:]
    elif digits.startswith("0"):
        local = digits[1:]
    else:
        local = digits

    if len(local) != 10 or not local.startswith("3"):
        frappe.throw(
            _("Enter a valid Pakistani mobile number."),
            ValidationError,
        )
    return f"+92{local}"


def _clean_payload(kwargs) -> dict[str, str]:
    data = dict(kwargs or {})
    blocked = sorted(field for field in LOCKED_FIELDS if field in data)
    if blocked:
        frappe.throw(
            _("These account fields cannot be changed: {0}").format(
                ", ".join(blocked)
            ),
            ValidationError,
        )

    cleaned: dict[str, str] = {}
    editable_limits = {**ALLOWED_FIELDS, **PROTECTED_ONCE_FIELDS}
    for fieldname, max_length in editable_limits.items():
        if fieldname not in data:
            continue

        value = data.get(fieldname)
        if value is not None and not isinstance(value, (str, int, float)):
            frappe.throw(
                _("{0} must be text.").format(fieldname),
                ValidationError,
            )

        text = str(value or "").strip()
        if len(text) > max_length:
            frappe.throw(
                _("{0} must be {1} characters or fewer.").format(
                    fieldname,
                    max_length,
                ),
                ValidationError,
            )

        if fieldname in {"phone", "whatsapp_no"}:
            text = _normalise_phone(text)

        if fieldname in PROTECTED_ONCE_FIELDS and not text:
            frappe.throw(
                _("{0} cannot be cleared once it is being corrected.").format(
                    PROTECTED_FIELD_LABELS[fieldname],
                ),
                ValidationError,
            )

        if fieldname == "cnic":
            digits = re.sub(r"\D", "", text)
            if len(digits) != 13:
                frappe.throw(_("CNIC must contain exactly 13 digits."), ValidationError)
            text = digits

        cleaned[fieldname] = text

    if "full_name" in cleaned and len(cleaned["full_name"]) < 2:
        frappe.throw(_("Full name is required."), ValidationError)

    return cleaned


def _self_service_changed_fields(profile_name: str) -> set[str]:
    rows = frappe.get_all(
        AUDIT_DOCTYPE,
        filters={
            "customer_profile": profile_name,
            "source": PROTECTED_CORRECTION_SOURCE,
        },
        pluck="changed_fields",
    )

    used: set[str] = set()
    for row in rows:
        used.update(
            field.strip()
            for field in str(row or "").split(",")
            if field.strip()
        )
    return used


def _profile_edit_policy(profile) -> dict[str, dict[str, object]]:
    used = _self_service_changed_fields(profile.name)
    policy: dict[str, dict[str, object]] = {
        "email": {
            "can_edit": False,
            "mode": "locked",
        },
    }

    for fieldname in SELF_SERVICE_ONCE_FIELDS:
        current = str(profile.get(fieldname) or "").strip()
        already_used = fieldname in used

        policy[fieldname] = {
            "can_edit": not already_used,
            "mode": (
                "locked"
                if already_used
                else ("correct" if current else "add")
            ),
        }

    return policy


def _assert_once_field_available(profile, fieldname: str, value: str) -> None:
    if fieldname not in {"cnic", "ntn"}:
        return

    duplicate = frappe.db.get_value(
        "OMC Customer Profile",
        {
            fieldname: value,
            "name": ["!=", profile.name],
        },
        "name",
    )
    if duplicate:
        frappe.throw(
            _("{0} is already linked to another customer profile.").format(
                PROTECTED_FIELD_LABELS[fieldname],
            ),
            ValidationError,
        )


def _snapshot(profile) -> dict[str, str]:
    tracked_fields = {
        **ALLOWED_FIELDS,
        **PROTECTED_ONCE_FIELDS,
        "email": 140,
    }
    return {
        fieldname: str(profile.get(fieldname) or "")
        for fieldname in tracked_fields
    }


def _create_audit(
    *,
    user: str,
    profile,
    changed_fields: list[str],
    before: dict[str, str],
    after: dict[str, str],
    source: str = "Mobile App",
) -> None:
    frappe.get_doc(
        {
            "doctype": AUDIT_DOCTYPE,
            "user": user,
            "customer_profile": profile.name,
            "changed_fields": ", ".join(changed_fields),
            "before_json": json.dumps(before, ensure_ascii=False, sort_keys=True),
            "after_json": json.dumps(after, ensure_ascii=False, sort_keys=True),
            "source": source,
            "changed_at": now_datetime(),
        }
    ).insert(ignore_permissions=True)




def _existing_profile_for_user(user: str):
    profile_name = frappe.db.get_value(
        "OMC Customer Profile",
        {"linked_app_user": user},
        "name",
    )
    if not profile_name:
        profile_name = frappe.db.get_value(
            "OMC Customer Profile",
            {"email": user},
            "name",
        )
    return frappe.get_doc("OMC Customer Profile", profile_name) if profile_name else None


def _internal_profile_payload(*, user: str, user_doc=None, profile=None) -> dict:
    user_doc = user_doc or frappe.get_doc("User", user)
    profile = profile or _existing_profile_for_user(user)
    capabilities = mobile._get_mobile_capabilities(user=user, profile=profile)

    def profile_value(fieldname: str) -> str:
        if not profile or not profile.meta.has_field(fieldname):
            return ""
        return str(profile.get(fieldname) or "")

    roles = [
        role
        for role in frappe.get_roles(user)
        if role not in {"All", "Desk User", "Guest"}
    ]

    return {
        "full_name": str(
            user_doc.get("full_name")
            or profile_value("full_name")
            or user_doc.get("first_name")
            or ""
        ),
        "email": str(user_doc.get("email") or user),
        "username": str(user_doc.get("username") or profile_value("username")),
        "phone": str(user_doc.get("mobile_no") or profile_value("phone")),
        "whatsapp_no": profile_value("whatsapp_no"),
        "address": profile_value("address"),
        "education": profile_value("education"),
        "experience": profile_value("experience"),
        "remarks": profile_value("remarks"),
        "register_as": profile_value("register_as") or (roles[0] if roles else "Internal"),
        "customer_type": profile_value("customer_type"),
        "company_name": profile_value("company_name"),
        "cnic": profile_value("cnic"),
        "ntn": profile_value("ntn"),
        "avatar_url": str(user_doc.get("user_image") or ""),
        "profile_image": str(user_doc.get("user_image") or ""),
        "user_image": str(user_doc.get("user_image") or ""),
        "customer_id": str(profile.name if profile else ""),
        "customer_status": "Internal",
        "approval_status": profile_value("approval_status"),
        "access_state": capabilities["access_state"],
        "capabilities": capabilities,
        **capabilities,
    }


def _update_internal_profile(*, user: str, payload: dict[str, str]):
    unsupported = sorted(set(payload) - INTERNAL_ALLOWED_FIELDS)
    if unsupported:
        frappe.throw(
            _("Internal accounts can only update full name and mobile number."),
            ValidationError,
        )

    if not frappe.db.exists("User", user):
        frappe.throw(_("User account was not found."), ValidationError)

    user_doc = frappe.get_doc("User", user)
    profile = _existing_profile_for_user(user)
    changed_fields: list[str] = []

    if "full_name" in payload:
        full_name = payload["full_name"]
        if str(user_doc.get("full_name") or "").strip() != full_name:
            user_doc.first_name = full_name
            user_doc.full_name = full_name
            changed_fields.append("full_name")

    if "phone" in payload:
        phone = payload["phone"]
        if str(user_doc.get("mobile_no") or "").strip() != phone:
            user_doc.mobile_no = phone
            changed_fields.append("phone")

    profile_fields = {
        "full_name",
        "phone",
        "whatsapp_no",
        "address",
        "education",
        "experience",
        "remarks",
    }
    profile_required_fields = {
        "whatsapp_no",
        "address",
        "education",
        "experience",
        "remarks",
    }
    requested_profile_fields = profile_fields.intersection(payload)
    requested_profile_only_fields = profile_required_fields.intersection(payload)

    if requested_profile_only_fields and not profile:
        frappe.throw(
            _("Your professional profile record was not found. Contact OMC support."),
            ValidationError,
        )

    if profile:
        for fieldname in requested_profile_fields:
            if not profile.meta.has_field(fieldname):
                continue
            value = payload[fieldname]
            if str(profile.get(fieldname) or "").strip() == value:
                continue
            profile.set(fieldname, value)
            if fieldname not in changed_fields:
                changed_fields.append(fieldname)

    if not changed_fields:
        return {
            "updated": False,
            "updated_fields": [],
            "message": "No profile details changed.",
            "profile": _internal_profile_payload(
                user=user,
                user_doc=user_doc,
                profile=profile,
            ),
        }

    user_doc.save(ignore_permissions=True)
    if profile:
        profile.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "updated": True,
        "updated_fields": changed_fields,
        "message": "Profile updated successfully.",
        "profile": _internal_profile_payload(
            user=user,
            user_doc=user_doc,
            profile=profile,
        ),
    }



def _location_audit_snapshot(profile) -> dict[str, object]:
    payload = profile_location.api_payload(profile)
    return {
        fieldname: payload.get(fieldname)
        for fieldname in profile_location.INPUT_FIELDS
    }


@frappe.whitelist()
def update_work_address(**kwargs):
    """Replace or partially update the customer's Work / Business Address."""

    user = _current_user()

    if mobile._can_access_internal_workspace(user):
        frappe.throw(
            _("Work / Business Address self-service is for customer profiles."),
            ValidationError,
        )

    profile = mobile._get_customer_profile_for_user(user)

    frappe.db.get_value(
        "OMC Customer Profile",
        profile.name,
        "name",
        for_update=True,
    )
    profile.reload()

    clear_requested = str(
        kwargs.pop("clear", "") or ""
    ).strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    before = _location_audit_snapshot(profile)

    if clear_requested:
        candidate = {
            fieldname: (
                None
                if fieldname in {"work_latitude", "work_longitude"}
                else ""
            )
            for fieldname in profile_location.INPUT_FIELDS
        }
    else:
        changes = profile_location.clean_input(kwargs)

        if not changes:
            return {
                "updated": False,
                "updated_fields": [],
                "message": "No Work / Business Address details changed.",
                "profile": mobile.get_profile(),
            }

        candidate = profile_location.merged_candidate(
            profile,
            changes,
        )

    changed_fields = []

    for fieldname in profile_location.INPUT_FIELDS:
        if not profile.meta.has_field(fieldname):
            continue

        new_value = candidate.get(fieldname)
        current_value = profile.get(fieldname)

        if fieldname in {"work_latitude", "work_longitude"}:
            current_normalized = (
                None
                if current_value is None
                or str(current_value).strip() == ""
                else float(current_value)
            )
            changed = current_normalized != new_value
        else:
            changed = (
                str(current_value or "").strip()
                != str(new_value or "").strip()
            )

        if not changed:
            continue

        profile.set(fieldname, new_value)
        changed_fields.append(fieldname)

    if not changed_fields:
        return {
            "updated": False,
            "updated_fields": [],
            "message": "No Work / Business Address details changed.",
            "profile": mobile.get_profile(),
        }

    if profile.meta.has_field("work_address_prompt_dismissed"):
        profile.work_address_prompt_dismissed = 1

    profile.save(ignore_permissions=True)

    after = _location_audit_snapshot(profile)

    _create_audit(
        user=user,
        profile=profile,
        changed_fields=changed_fields,
        before=before,
        after=after,
        source="Mobile App Work Address",
    )

    frappe.db.commit()

    return {
        "updated": True,
        "updated_fields": changed_fields,
        "message": (
            "Work / Business Address updated successfully."
            if not clear_requested
            else "Work / Business Address removed."
        ),
        "profile": mobile.get_profile(),
    }


@frappe.whitelist()
def dismiss_work_address_prompt():
    """Allow signup-skippers to continue without repeated login prompts."""

    user = _current_user()

    if mobile._can_access_internal_workspace(user):
        return {
            "dismissed": True,
            "needs_work_address_prompt": False,
        }

    profile = mobile._get_customer_profile_for_user(user)

    if not profile.meta.has_field("work_address_prompt_dismissed"):
        return {
            "dismissed": True,
            "needs_work_address_prompt": False,
        }

    if int(profile.work_address_prompt_dismissed or 0):
        return {
            "dismissed": True,
            "needs_work_address_prompt": False,
        }

    profile.work_address_prompt_dismissed = 1
    profile.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "dismissed": True,
        "needs_work_address_prompt": False,
    }


@frappe.whitelist()
def update_profile(**kwargs):
    user = _current_user()
    payload = _clean_payload(kwargs)

    if mobile._can_access_internal_workspace(user):
        return _update_internal_profile(user=user, payload=payload)

    profile = mobile._get_customer_profile_for_user(user)

    # Serialize competing profile corrections so two simultaneous requests
    # cannot consume the same one-time correction allowance.
    frappe.db.get_value(
        "OMC Customer Profile",
        profile.name,
        "name",
        for_update=True,
    )
    profile.reload()

    used_once_fields = _self_service_changed_fields(profile.name)
    before = _snapshot(profile)
    changed_fields: list[str] = []

    for fieldname, value in payload.items():
        current_value = str(profile.get(fieldname) or "").strip()

        if current_value == value:
            continue

        if fieldname in PROTECTED_ONCE_FIELDS:
            if fieldname in used_once_fields:
                frappe.throw(
                    _("{0} has already used its one-time profile correction. Contact OMC support if another legal correction is required.").format(
                        PROTECTED_FIELD_LABELS[fieldname],
                    ),
                    ValidationError,
                )

            _assert_once_field_available(profile, fieldname, value)

        profile.set(fieldname, value)
        changed_fields.append(fieldname)

    if not changed_fields:
        return {
            "updated": False,
            "updated_fields": [],
            "message": "No profile details changed.",
            "profile": mobile.get_profile(),
        }

    profile.save(ignore_permissions=True)

    if "full_name" in changed_fields and frappe.db.exists("User", user):
        user_doc = frappe.get_doc("User", user)
        user_doc.first_name = payload["full_name"]
        user_doc.full_name = payload["full_name"]
        user_doc.save(ignore_permissions=True)

    after = _snapshot(profile)
    protected_changed = bool(
        set(changed_fields).intersection(PROTECTED_ONCE_FIELDS)
    )
    _create_audit(
        user=user,
        profile=profile,
        changed_fields=changed_fields,
        before=before,
        after=after,
        source=(
            PROTECTED_CORRECTION_SOURCE
            if protected_changed
            else "Mobile App"
        ),
    )
    frappe.db.commit()

    return {
        "updated": True,
        "updated_fields": changed_fields,
        "message": "Profile updated successfully.",
        "profile": mobile.get_profile(),
    }
