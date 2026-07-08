import frappe


def execute():
    staff_roles = {
        "OMC Admin",
        "OMC Manager",
        "OMC Support Agent",
        "OMC Document Reviewer",
        "OMC Finance Reviewer",
        "OMC Consultant",
        "OMC Business Partner",
        "OMC Tax Associate",
    }
    portal_roles = {
        "OMC Customer",
        "OMC Customer Applicant",
    }

    for role_name in staff_roles | portal_roles:
        if frappe.db.exists("Role", role_name):
            frappe.db.set_value(
                "Role",
                role_name,
                "desk_access",
                1 if role_name in staff_roles else 0,
            )

    frappe.db.commit()
