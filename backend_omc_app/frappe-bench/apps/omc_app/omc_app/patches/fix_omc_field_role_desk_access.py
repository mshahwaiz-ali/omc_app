import frappe


OBSOLETE_FIELD_ROLES = {
    "OMC Consultant",
    "OMC Business Partner",
    "OMC Tax Associate",
}


def execute():
    # These roles were split too finely for the current OMC workflow.
    # Keep them hidden if they already exist on an older site.
    for role_name in OBSOLETE_FIELD_ROLES:
        if frappe.db.exists("Role", role_name):
            frappe.db.set_value("Role", role_name, "desk_access", 0)

    frappe.db.commit()
