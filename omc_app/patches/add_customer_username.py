import frappe


def execute():
    if frappe.get_meta("OMC Customer Profile").has_field("username"):
        return

    from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

    create_custom_fields(
        {
            "OMC Customer Profile": [
                {
                    "fieldname": "username",
                    "label": "Username",
                    "fieldtype": "Data",
                    "insert_after": "email",
                    "unique": 1,
                    "search_index": 1,
                    "description": (
                        "Normalized public login identifier. "
                        "Frappe User remains email-based."
                    ),
                }
            ]
        },
        update=True,
    )
