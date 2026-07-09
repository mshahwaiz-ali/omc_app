import frappe


STAFF_ROLES = {
    "OMC Admin",
    "OMC Manager",
    "OMC Support Agent",
}

PORTAL_ROLES = {
    "OMC Customer",
    "OMC Customer Applicant",
}

OBSOLETE_ROLES = {
    "OMC Document Reviewer",
    "OMC Finance Reviewer",
    "OMC Consultant",
    "OMC Business Partner",
    "OMC Tax Associate",
}


def _set_role_access(role_name, desk_access):
    if not frappe.db.exists("Role", role_name):
        role = frappe.new_doc("Role")
        role.role_name = role_name
        role.is_custom = 1
        role.insert(ignore_permissions=True)

    frappe.db.set_value("Role", role_name, "desk_access", 1 if desk_access else 0)


def execute():
    for role_name in sorted(STAFF_ROLES):
        _set_role_access(role_name, desk_access=True)

    for role_name in sorted(PORTAL_ROLES):
        _set_role_access(role_name, desk_access=False)

    # Keep old roles from showing in Desk if they already exist on older sites.
    for role_name in sorted(OBSOLETE_ROLES):
        if frappe.db.exists("Role", role_name):
            frappe.db.set_value("Role", role_name, "desk_access", 0)

    frappe.db.commit()
