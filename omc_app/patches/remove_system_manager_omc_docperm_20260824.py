import frappe


PERMISSION_DOCTYPES = (
    "DocPerm",
    "Custom DocPerm",
)


def execute():
    """Remove stale implicit System Manager authority over OMC DocTypes."""

    for permission_doctype in PERMISSION_DOCTYPES:
        names = frappe.get_all(
            permission_doctype,
            filters={
                "role": "System Manager",
                "parent": ["like", "OMC %"],
            },
            pluck="name",
            limit_page_length=0,
        )

        for name in names:
            frappe.delete_doc(
                permission_doctype,
                name,
                ignore_permissions=True,
                force=True,
            )

    frappe.clear_cache()
