import frappe


def execute():
    roles = [
        "OMC Admin",
        "OMC Manager",
        "OMC Support Agent",
        "OMC Document Reviewer",
        "OMC Finance Reviewer",
        "OMC Consultant",
        "OMC Business Partner",
        "OMC Tax Associate",
        "OMC Customer",
        "OMC Customer Applicant",
    ]

    for role_name in roles:
        if frappe.db.exists("Role", role_name):
            continue

        role = frappe.new_doc("Role")
        role.role_name = role_name
        role.desk_access = 1 if role_name != "OMC Customer Applicant" else 0
        role.is_custom = 1
        role.insert(ignore_permissions=True)

    frappe.db.commit()
