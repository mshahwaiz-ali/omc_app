import frappe


_AUTOMATIC_NAMING_SERIES_DOCTYPES = (
    "OMC Customer Profile",
    "OMC Expense Budget",
    "OMC Expense Entry",
    "OMC Lead",
    "OMC Service Document",
    "OMC Service Payment",
    "OMC Service Request",
    "OMC Support Ticket",
    "OMC Support Ticket Message",
    "OMC Task",
)


def sync_desk_metadata():
    """Keep internal identifiers out of Desk forms and remove child-table links."""
    _hide_automatic_naming_series_fields()
    _remove_standalone_tax_slab_links()
    frappe.clear_cache()


def _hide_automatic_naming_series_fields():
    for doctype in _AUTOMATIC_NAMING_SERIES_DOCTYPES:
        field = frappe.db.get_value(
            "DocField",
            {"parent": doctype, "fieldname": "naming_series"},
            ["name", "default", "options"],
            as_dict=True,
        )
        if not field:
            continue

        values = {
            "hidden": 1,
            "read_only": 1,
            "no_copy": 1,
        }

        # A hidden mandatory naming-series field must retain a usable default.
        if not field.default:
            options = [
                option.strip()
                for option in (field.options or "").splitlines()
                if option.strip()
            ]
            if len(options) == 1:
                values["default"] = options[0]

        frappe.db.set_value("DocField", field.name, values, update_modified=False)


def _remove_standalone_tax_slab_links():
    # OMC Tax Slab is a child table of OMC Tax Year and must not be opened
    # independently from the workspace.
    links = frappe.get_all(
        "Workspace Link",
        filters={
            "parent": "OMC App",
            "parenttype": "Workspace",
            "link_to": "OMC Tax Slab",
        },
        pluck="name",
    )
    for link_name in links:
        frappe.db.delete("Workspace Link", {"name": link_name})
