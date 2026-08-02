"""Retire the temporary OMC-owned global HS Code substitute safely."""

from __future__ import annotations

import frappe


DOCTYPE = "HS Code"
OMC_MODULE = "OMC App"
RESERVED_TEST_RECORD = {
    "name": "9999.99",
    "description": "Reserved QA HS code",
    "owner": "Administrator",
}


def _link_fields():
    rows = []
    for metadata_doctype, parent_field in (
        ("DocField", "parent"),
        ("Custom Field", "dt"),
    ):
        for row in frappe.get_all(
            metadata_doctype,
            filters={"fieldtype": "Link", "options": DOCTYPE},
            fields=[parent_field, "fieldname"],
            limit_page_length=0,
        ):
            parent = row.get(parent_field)
            fieldname = row.get("fieldname")
            if parent and fieldname:
                rows.append((parent, fieldname))
    return sorted(set(rows))


def _nonempty_references():
    references = []
    for parent, fieldname in _link_fields():
        if not frappe.db.table_exists(parent) or not frappe.db.has_column(parent, fieldname):
            continue
        count = frappe.db.count(parent, filters={fieldname: ["is", "set"]})
        if count:
            references.append(
                {"doctype": parent, "fieldname": fieldname, "count": count}
            )
    return references


def execute():
    if not frappe.db.exists("DocType", DOCTYPE):
        return

    owner = frappe.db.get_value("DocType", DOCTYPE, ["module", "custom"], as_dict=True)
    if not owner or owner.module != OMC_MODULE or int(owner.custom or 0):
        frappe.throw(
            "Refusing to remove HS Code because it is not the standard OMC App substitute.",
            frappe.ValidationError,
        )

    if frappe.db.table_exists(DOCTYPE):
        rows = frappe.get_all(
            DOCTYPE,
            fields=["name", "description", "owner"],
            limit_page_length=0,
        )
        for row in rows:
            if all(row.get(key) == value for key, value in RESERVED_TEST_RECORD.items()):
                frappe.db.delete(DOCTYPE, {"name": row.name})
        record_count = frappe.db.count(DOCTYPE)
    else:
        record_count = 0
    references = _nonempty_references()
    if record_count or references:
        frappe.throw(
            "Refusing to retire the OMC HS Code substitute because data exists. "
            f"HS Code records: {record_count}; non-empty references: {references}.",
            frappe.ValidationError,
        )

    frappe.delete_doc(
        "DocType",
        DOCTYPE,
        force=True,
        ignore_permissions=True,
        delete_permanently=True,
    )
    frappe.clear_cache(doctype=DOCTYPE)
