import frappe


def execute():
    portal_roles = {"OMC Customer", "OMC Customer Applicant"}
    staff_roles = {
        "System Manager",
        "OMC Admin",
        "OMC Manager",
        "OMC Support Agent",
        "OMC Document Reviewer",
        "OMC Finance Reviewer",
        "OMC Consultant",
        "OMC Business Partner",
        "OMC Tax Associate",
    }

    parents = frappe.get_all(
        "Has Role",
        filters={"role": ["in", list(portal_roles)]},
        pluck="parent",
    )

    for user_id in set(parents):
        if user_id in {"Administrator", "Guest"}:
            continue

        roles = {
            row.role
            for row in frappe.get_all(
                "Has Role",
                filters={"parent": user_id},
                fields=["role"],
            )
        }
        if roles & staff_roles:
            continue

        if frappe.db.exists("User", user_id):
            frappe.db.set_value("User", user_id, "user_type", "Website User")

    frappe.db.commit()
