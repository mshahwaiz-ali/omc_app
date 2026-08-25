from __future__ import annotations

import frappe
from frappe.utils import now_datetime

from omc_app.api import access, identity, staff_profile
from omc_app.referral_automation import ensure_referral_code_for_user
from omc_app.setup.roles import ERP_STAFF_PERSONAS

ERP_USER_TYPE_TO_PERSONA = {
    "Consultant": "Consultant",
    "Business Partner": "Business Partner",
    "Tax Associates": "Tax Associates",
    "Tax Associate": "Tax Associates",
    "Employee": "Employee",
}

REFERRAL_OWNER_PERSONAS = frozenset({
    "Consultant",
    "Business Partner",
    "Tax Associates",
})
COMMISSION_BENEFICIARY_PERSONAS = frozenset({
    "Consultant",
    "Business Partner",
    "Tax Associates",
    "Employee",
})
LEGACY_OVERLOADED_CAPABILITY = "can_view_referral_commissions"


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


def _persona_source(user: str, mapped_persona: str) -> str:
    if frappe.db.has_column("User", "omc_user_type"):
        value = _text(
            frappe.db.get_value(
                "User",
                user,
                "omc_user_type",
            )
        )
        if value:
            return "User.omc_user_type"

    if mapped_persona == "Employee" and _employee_for_user(user):
        return "Employee Fallback"

    return "Reviewed"


def _persona_capabilities(mapped_persona: str) -> set[str]:
    capabilities = set(access.ROLE_CAPABILITIES.get(mapped_persona, set()))

    # Retire the old overloaded capability from canonical staff provisioning.
    # Existing rows are deterministically replaced by _ensure_staff_access().
    capabilities.discard(LEGACY_OVERLOADED_CAPABILITY)

    if mapped_persona in REFERRAL_OWNER_PERSONAS:
        capabilities.add("can_own_referrals")
    if mapped_persona in COMMISSION_BENEFICIARY_PERSONAS:
        capabilities.add("can_view_own_commissions")

    return capabilities


def _ensure_staff_access(user: str, profile, mapped_persona: str):
    """Create or reconcile canonical OMC Staff Access for a trusted ERP user."""

    employee = _employee_for_user(user)
    persona_source = _persona_source(user, mapped_persona)
    capability_codes = sorted(
        _persona_capabilities(mapped_persona)
        | {
            "can_access_internal_workspace",
            "can_view_tasks",
            "can_view_internal_notifications",
        }
    )

    name = frappe.db.get_value(
        "OMC Staff Access",
        {"user": user},
        "name",
    )

    doc = (
        frappe.get_doc("OMC Staff Access", name)
        if name
        else frappe.new_doc("OMC Staff Access")
    )

    # A deliberately reviewed persona must never be silently overwritten by
    # automated ERP reconciliation. Fail closed until an administrator reviews
    # the conflict.
    if (
        name
        and _text(doc.get("persona_source")) == "Reviewed"
        and _text(doc.get("persona_snapshot"))
        and _text(doc.get("persona_snapshot")) != mapped_persona
    ):
        doc.reconciliation_status = "Conflict"
        doc.last_reconciled_at = now_datetime()
        doc.save(ignore_permissions=True)
        return doc

    if employee:
        employee_owner = frappe.db.get_value(
            "OMC Staff Access",
            {"employee": employee},
            "name",
        )
        if employee_owner and employee_owner != name:
            frappe.throw(
                f"Employee {employee} is already linked to another OMC Staff Access record.",
                frappe.ValidationError,
            )

    existing_status = _text(doc.get("access_status"))

    # Explicit suspension/rejection is security authority and must survive
    # migration reruns. New/Pending records from trusted ERP staff become
    # Approved.
    protected_status = existing_status in {
        "Suspended",
        "Rejected",
    }

    doc.user = user
    doc.employee = employee or None
    doc.legacy_staff_profile = profile.name
    doc.persona_snapshot = mapped_persona
    doc.persona_source = persona_source
    doc.source_version = identity.source_version(
        profile.modified,
        mapped_persona,
        employee,
    )
    doc.reconciliation_status = "Current"
    doc.last_reconciled_at = now_datetime()

    doc.set(
        "capabilities",
        [
            {"capability": code}
            for code in capability_codes
        ],
    )

    if protected_status:
        doc.access_status = existing_status
    else:
        doc.access_status = "Approved"
        doc.approved_by = doc.get("approved_by") or "Administrator"
        doc.approved_at = doc.get("approved_at") or now_datetime()
        doc.suspended_by = None
        doc.suspended_at = None
        doc.suspension_reason = ""

    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)

    return doc


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
    commit: bool = True,
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

    profile = staff_profile.ensure_staff_profile(
        user,
        commit=commit,
    )
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

    # Canonical authority must exist before referral automation evaluates
    # whether this user may own an OMC referral code.
    staff_access = _ensure_staff_access(
        user,
        profile,
        mapped_persona,
    )

    referral = ensure_referral_code_for_user(user)

    # Standalone staff sync keeps its existing commit behavior.
    # Parent migrations may defer the transaction boundary and
    # commit the complete multi-phase operation themselves.
    if commit:
        frappe.db.commit()

    return {
        **preview_staff_user(user),
        "applied": True,
        "erp_roles_untouched": True,
        "staff_profile": profile.name,
        "staff_status": profile.staff_status,
        "approval_status": profile.approval_status,
        "is_active": int(profile.is_active or 0),
        "staff_access": staff_access.name,
        "staff_access_status": staff_access.access_status,
        "staff_access_reconciliation_status": (
            staff_access.reconciliation_status
        ),
        "referral_record": referral.name if referral else "",
        "referral_code": referral.referral_code if referral else "",
    }
