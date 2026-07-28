from __future__ import annotations

import json
import re

import frappe
from frappe import _
from frappe.exceptions import PermissionError, ValidationError
from frappe.utils import now_datetime

from omc_app.api import mobile


ALLOWED_FIELDS = {
    "full_name": 140,
    "phone": 40,
    "whatsapp_no": 40,
    "address": 500,
    "company_name": 140,
}
SET_ONCE_FIELDS = {
    "ntn": 40,
}
LOCKED_FIELDS = {
    "email",
    "user",
    "username",
    "cnic",
    "tax_id",
    "customer_type",
    "register_as",
    "approval_status",
    "customer_status",
}
AUDIT_DOCTYPE = "OMC Profile Change Log"


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
    editable_limits = {**ALLOWED_FIELDS, **SET_ONCE_FIELDS}
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

        cleaned[fieldname] = text

    if "full_name" in cleaned and len(cleaned["full_name"]) < 2:
        frappe.throw(_("Full name is required."), ValidationError)

    return cleaned


def _snapshot(profile) -> dict[str, str]:
    tracked_fields = {**ALLOWED_FIELDS, **SET_ONCE_FIELDS}
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
) -> None:
    frappe.get_doc(
        {
            "doctype": AUDIT_DOCTYPE,
            "user": user,
            "customer_profile": profile.name,
            "changed_fields": ", ".join(changed_fields),
            "before_json": json.dumps(before, ensure_ascii=False, sort_keys=True),
            "after_json": json.dumps(after, ensure_ascii=False, sort_keys=True),
            "source": "Mobile App",
            "changed_at": now_datetime(),
        }
    ).insert(ignore_permissions=True)


@frappe.whitelist()
def update_profile(**kwargs):
    user = _current_user()
    payload = _clean_payload(kwargs)
    profile = mobile._get_customer_profile_for_user(user)

    before = _snapshot(profile)
    changed_fields: list[str] = []

    for fieldname, value in payload.items():
        current_value = str(profile.get(fieldname) or "").strip()

        if fieldname in SET_ONCE_FIELDS and current_value:
            if current_value != value:
                frappe.throw(
                    _("NTN can only be added once from the app. Contact OMC support for a verified correction."),
                    ValidationError,
                )
            continue

        if current_value == value:
            continue

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
    _create_audit(
        user=user,
        profile=profile,
        changed_fields=changed_fields,
        before=before,
        after=after,
    )
    frappe.db.commit()

    return {
        "updated": True,
        "updated_fields": changed_fields,
        "message": "Profile updated successfully.",
        "profile": mobile.get_profile(),
    }
