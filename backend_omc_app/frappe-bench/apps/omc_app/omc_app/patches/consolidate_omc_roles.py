import frappe


ACTIVE_STAFF_ROLES = {
    "OMC Admin",
    "OMC Manager",
}

ACTIVE_PORTAL_ROLES = {
    "OMC Customer",
    "OMC Business Partner",
    "OMC Tax Associate",
}

OBSOLETE_ROLES = {
    "OMC Customer Applicant",
    "OMC Support Agent",
    "OMC Customer Support",
    "OMC Document Reviewer",
    "OMC Finance Reviewer",
    "OMC Consultant",
}


def _role_has_field(fieldname):
    try:
        return frappe.get_meta("Role").has_field(fieldname)
    except Exception:
        return False


def _set_role(role_name, desk_access):
    if not frappe.db.exists("Role", role_name):
        role = frappe.new_doc("Role")
        role.role_name = role_name
        role.is_custom = 1
        role.insert(ignore_permissions=True)

    values = {"desk_access": 1 if desk_access else 0}
    if _role_has_field("disabled"):
        values["disabled"] = 0
    frappe.db.set_value("Role", role_name, values)


def _hide_obsolete_role(role_name):
    if not frappe.db.exists("Role", role_name):
        return

    values = {"desk_access": 0}
    if _role_has_field("disabled"):
        values["disabled"] = 1
    frappe.db.set_value("Role", role_name, values)


def _remove_obsolete_assignments():
    for role_name in OBSOLETE_ROLES:
        frappe.db.delete("Has Role", {"role": role_name})


def _protect_manager_from_delete():
    # Manager is staff-level, but below Admin: no delete permission.
    for perm_name in frappe.get_all("DocPerm", filters={"role": "OMC Manager"}, pluck="name"):
        frappe.db.set_value("DocPerm", perm_name, "delete", 0)


def execute():
    for role_name in sorted(ACTIVE_STAFF_ROLES):
        _set_role(role_name, desk_access=True)

    for role_name in sorted(ACTIVE_PORTAL_ROLES):
        _set_role(role_name, desk_access=False)

    for role_name in sorted(OBSOLETE_ROLES):
        _hide_obsolete_role(role_name)

    _remove_obsolete_assignments()
    _protect_manager_from_delete()

    frappe.db.commit()
