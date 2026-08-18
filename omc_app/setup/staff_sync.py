from __future__ import annotations

import frappe

from omc_app.api import staff_profile
from omc_app.referral_automation import ensure_referral_code_for_user
from omc_app.setup.roles import ERP_STAFF_PERSONAS

ERP_USER_TYPE_TO_PERSONA = {
    "Consultant": "Consultant",
    "Business Partner": "Business Partner",
    "Tax Associates": "Tax Associates",
    "Tax Associate": "Tax Associates",
    "Employee": "Employee",
}


def _text(value) -> str:
    return str(value or "").strip()


def _employee_for_user(user: str) -> str:
    if not frappe.db.exists("DocType", "Employee"):
        return ""
    return _text(
        frappe.db.get_value(
            "Employee",
            {"user_id": user},
            "name",
        )
    )


def _erp_omc_user_type(user_doc) -> str:
    # The client ERP stores omc_user_type as a legacy User table column. On
    # restored/live sites the column can exist without corresponding Frappe
    # Custom Field metadata, so read the ERP column directly and never mutate
    # ERP metadata from the OMC bridge.
    if frappe.db.has_column("User", "omc_user_type"):
        value = _text(
            frappe.db.get_value(
                "User",
                user_doc.name,
                "omc_user_type",
            )
        )
        if value:
            return value

    # Some legacy users may have no OMC User Type but are explicitly linked
    # to an ERP Employee. Treat only that strong ERP relationship as Employee.
    if _employee_for_user(user_doc.name):
        return "Employee"

    return ""


def preview_staff_user(user: str | None = None) -> dict:
    user = _text(user)
    if not user or not frappe.db.exists("User", user):
        return {
            "eligible": False,
            "user": user,
            "reason": "user_not_found",
        }

    user_doc = frappe.get_doc("User", user)
    omc_user_type = _erp_omc_user_type(user_doc)
    mapped_persona = ERP_USER_TYPE_TO_PERSONA.get(omc_user_type, "")
    existing_profile = staff_profile.get_staff_profile(user)

    reason = ""
    eligible = True
    if user in {"Guest", "Administrator"}:
        eligible = False
        reason = "reserved_user"
    elif not int(user_doc.enabled or 0):
        eligible = False
        reason = "user_disabled"
    elif _text(user_doc.user_type) != "System User":
        eligible = False
        reason = "not_system_user"
    elif mapped_persona not in ERP_STAFF_PERSONAS:
        eligible = False
        reason = "unsupported_or_missing_omc_user_type"

    return {
        "eligible": eligible,
        "user": user,
        "enabled": int(user_doc.enabled or 0),
        "user_type": _text(user_doc.user_type),
        "erp_omc_user_type": omc_user_type,
        "mapped_staff_persona": mapped_persona,
        "linked_employee": _employee_for_user(user),
        "staff_profile_exists": bool(existing_profile),
        "staff_profile": existing_profile.name if existing_profile else "",
        "reason": reason,
    }


def sync_staff_user(
    user: str | None = None,
    *,
    apply: bool = False,
) -> dict:
    """Preview or synchronize exactly one ERP user into OMC staff.

    ERP roles and Role Profiles remain untouched. OMC stores the ERP persona on
    OMC Staff Profile and uses that profile for mobile/referral authorization.
    """

    preview = preview_staff_user(user)
    if not preview.get("eligible") or not apply:
        return {
            **preview,
            "applied": False,
        }

    user = preview["user"]
    mapped_persona = preview["mapped_staff_persona"]

    profile = staff_profile.ensure_staff_profile(user)
    if not profile:
        frappe.throw(
            f"Unable to create OMC Staff Profile for {user}.",
            frappe.ValidationError,
        )

    profile.staff_role = mapped_persona
    profile.staff_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1
    profile.save(ignore_permissions=True)

    referral = ensure_referral_code_for_user(user)
    frappe.db.commit()

    return {
        **preview_staff_user(user),
        "applied": True,
        "erp_roles_untouched": True,
        "staff_profile": profile.name,
        "staff_status": profile.staff_status,
        "approval_status": profile.approval_status,
        "is_active": int(profile.is_active or 0),
        "referral_record": referral.name if referral else "",
        "referral_code": referral.referral_code if referral else "",
    }
