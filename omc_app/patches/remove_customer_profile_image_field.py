import frappe


def execute():
    if not frappe.db.exists("DocType", "OMC Customer Profile"):
        return

    meta = frappe.get_meta("OMC Customer Profile")
    if not meta.has_field("profile_image"):
        return

    frappe.delete_doc(
        "DocField",
        {
            "parent": "OMC Customer Profile",
            "fieldname": "profile_image",
        },
        ignore_permissions=True,
        force=True,
    )
    frappe.clear_cache(doctype="OMC Customer Profile")
