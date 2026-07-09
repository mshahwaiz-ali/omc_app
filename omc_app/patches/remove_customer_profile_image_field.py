import frappe


def execute():
    if not frappe.db.exists("DocType", "OMC Customer Profile"):
        return

    for field_name in frappe.get_all(
        "DocField",
        filters={
            "parent": "OMC Customer Profile",
            "fieldname": "profile_image",
        },
        pluck="name",
    ):
        frappe.delete_doc(
            "DocField",
            field_name,
            ignore_permissions=True,
            force=True,
        )

    frappe.db.commit()
    frappe.clear_cache(doctype="OMC Customer Profile")
