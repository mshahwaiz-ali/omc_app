import frappe


def execute():
    field_roles = {
        "OMC Consultant",
        "OMC Business Partner",
        "OMC Tax Associate",
    }

    for role_name in field_roles:
        if frappe.db.exists("Role", role_name):
            frappe.db.set_value("Role", role_name, "desk_access", 1)

    frappe.db.commit()
