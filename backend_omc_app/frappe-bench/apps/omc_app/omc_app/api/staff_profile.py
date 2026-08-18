from __future__ import annotations

import frappe

from omc_app.setup.roles import ACTIVE_STAFF_ROLES, MANAGED_OMC_STAFF_ROLES


DOCTYPE = "OMC Staff Profile"


def _text(value) -> str:
    return str(value or "").strip()


def _has_doctype(doctype: str) -> bool:
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def get_staff_role(user: str, profile=None) -> str:
    user = _text(user)

    if not user or user == "Guest":
        return ""

    profile = profile or get_staff_profile(user)
    if not profile or not profile.meta.has_field("staff_role"):
        return ""

    role = _text(profile.get("staff_role"))
    return role if role in ACTIVE_STAFF_ROLES else ""


def get_effective_staff_roles(user: str, profile=None) -> set[str]:
    """Return OMC-owned roles plus the Staff Profile's authoritative persona."""
    user = _text(user)

    if not user or user == "Guest":
        return set()

    # ERP Has Role / Role Profile values are not reliable persona classifiers.
    # Only OMC-owned operational roles may come from Frappe role assignments.
    roles = set(frappe.get_roles(user) or []).intersection(MANAGED_OMC_STAFF_ROLES)

    profile_role = get_staff_role(user, profile=profile)
    if profile_role:
        roles.add(profile_role)

    return roles


def get_staff_profile(user: str):
    user = _text(user)

    if not user or user == "Guest":
        return None

    if not _has_doctype(DOCTYPE):
        return None

    name = frappe.db.get_value(
        DOCTYPE,
        {"user": user},
        "name",
    )

    return frappe.get_doc(DOCTYPE, name) if name else None


def _employee_for_user(user: str) -> str:
    if not _has_doctype("Employee"):
        return ""

    return _text(
        frappe.db.get_value(
            "Employee",
            {"user_id": user},
            "name",
        )
    )


def is_staff_identity(user: str) -> bool:
    """Classify internal identity without granting OMC access."""
    user = _text(user)

    if not user or user == "Guest":
        return False

    # Desk/System users must never accidentally receive Customer Profiles.
    user_type = _text(
        frappe.db.get_value("User", user, "user_type")
        if frappe.db.exists("User", user)
        else ""
    )
    if user_type == "System User":
        return True

    if get_staff_profile(user):
        return True

    return bool(_employee_for_user(user))


def is_staff_profile_approved(user: str, profile=None) -> bool:
    """Return whether the staff profile is eligible for internal access."""
    user = _text(user)

    if not user or user == "Guest":
        return False

    if not frappe.db.exists("User", user):
        return False

    if not int(frappe.db.get_value("User", user, "enabled") or 0):
        return False

    profile = profile or get_staff_profile(user)
    if not profile:
        return False

    if _text(profile.get("staff_status")).lower() != "active":
        return False

    if _text(profile.get("approval_status")).lower() != "approved":
        return False

    if not int(profile.get("is_active") or 0):
        return False

    employee = _text(profile.get("linked_employee"))
    if employee:
        if not frappe.db.exists("Employee", employee):
            return False

        employee_status = _text(
            frappe.db.get_value("Employee", employee, "status")
        )
        if employee_status.lower() != "active":
            return False

    return True


def ensure_staff_profile(user: str):
    user = _text(user)

    if not user or user == "Guest":
        return None

    if not frappe.db.exists("User", user):
        return None

    profile = get_staff_profile(user)
    user_doc = frappe.get_doc("User", user)
    employee = _employee_for_user(user)

    employee_doc = (
        frappe.get_doc("Employee", employee)
        if employee and frappe.db.exists("Employee", employee)
        else None
    )

    full_name = _text(
        user_doc.get("full_name")
        or user_doc.get("first_name")
        or user
    )

    email = _text(user_doc.get("email") or user).lower()
    username = _text(user_doc.get("username"))
    phone = _text(user_doc.get("mobile_no"))

    if not phone and employee_doc:
        phone = _text(employee_doc.get("cell_number"))

    if not profile:
        profile = frappe.new_doc(DOCTYPE)
        profile.user = user
        profile.full_name = full_name
        profile.email = email
        profile.phone = phone
        profile.linked_employee = employee or None

        if profile.meta.has_field("username"):
            profile.username = username

        if profile.meta.has_field("company_name") and employee_doc:
            profile.company_name = _text(employee_doc.get("company"))

        if profile.meta.has_field("cnic") and employee_doc:
            profile.cnic = _text(employee_doc.get("cnic"))

        profile.staff_status = "Pending"
        profile.approval_status = "Pending Review"

        existing_omc_roles = set(
            frappe.get_roles(user) or []
        ).intersection(MANAGED_OMC_STAFF_ROLES)

        if (
            profile.meta.has_field("staff_role")
            and len(existing_omc_roles) == 1
        ):
            profile.staff_role = next(iter(existing_omc_roles))

        profile.is_active = 0

        profile.insert(ignore_permissions=True)
        frappe.db.commit()
        return profile

    changed = False

    sync_values = {
        "full_name": full_name,
        "email": email,
        "linked_employee": employee or None,
    }

    if profile.meta.has_field("username"):
        sync_values["username"] = username

    if employee_doc:
        if profile.meta.has_field("company_name"):
            sync_values["company_name"] = _text(employee_doc.get("company"))

        if profile.meta.has_field("cnic"):
            employee_cnic = _text(employee_doc.get("cnic"))
            if employee_cnic:
                sync_values["cnic"] = employee_cnic

    for fieldname, value in sync_values.items():
        current = profile.get(fieldname)

        if (current or "") == (value or ""):
            continue

        profile.set(fieldname, value)
        changed = True

    if not profile.phone and phone:
        profile.phone = phone
        changed = True

    if not _text(profile.get("staff_status")):
        profile.staff_status = "Pending"
        changed = True

    if not _text(profile.get("approval_status")):
        profile.approval_status = "Pending Review"
        changed = True

    # Repair legacy minimal-profile state: pending/rejected/suspended staff
    # must never remain accidentally active.
    approved = (
        _text(profile.get("staff_status")).lower() == "active"
        and _text(profile.get("approval_status")).lower() == "approved"
    )

    if not approved and int(profile.get("is_active") or 0):
        profile.is_active = 0
        changed = True

    if changed:
        profile.save(ignore_permissions=True)
        frappe.db.commit()

    return profile
