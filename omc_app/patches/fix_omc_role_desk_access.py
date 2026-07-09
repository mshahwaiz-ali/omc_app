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


def execute():
    for role_name in STAFF_ROLES | PORTAL_ROLES | OBSOLETE_ROLES:
        if not frappe.db.exists("Role", role_name):
            continue

        frappe.db.set_value(
            "Role",
            role_name,
            "desk_access",
            1 if role_name in STAFF_ROLES else 0,
        )

    frappe.db.commit()
