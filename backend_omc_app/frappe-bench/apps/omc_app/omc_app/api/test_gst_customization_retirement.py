from __future__ import annotations

import json
from pathlib import Path

import frappe
from frappe.tests.utils import FrappeTestCase


FIELDNAME = "custom_gst_category"


class TestGSTCustomizationRetirement(FrappeTestCase):
    def test_abandoned_fields_are_absent_from_live_metadata(self):
        self.assertFalse(frappe.get_meta("Supplier").has_field(FIELDNAME))
        self.assertFalse(frappe.get_meta("Customer").has_field(FIELDNAME))
        self.assertFalse(
            frappe.db.exists(
                "Custom Field",
                {"dt": "Customer", "fieldname": FIELDNAME},
            )
        )
        self.assertFalse(
            frappe.db.exists(
                "Custom Field",
                {"dt": "Supplier", "fieldname": FIELDNAME},
            )
        )

    def test_supplier_source_has_no_broken_gst_link(self):
        path = Path(
            frappe.get_app_path(
                "erpnext",
                "buying",
                "doctype",
                "supplier",
                "supplier.json",
            )
        )
        data = json.loads(path.read_text())

        self.assertNotIn(FIELDNAME, data.get("field_order", []))
        self.assertFalse(
            any(
                field.get("fieldname") == FIELDNAME
                for field in data.get("fields", [])
            )
        )

    def test_customer_customization_has_no_abandoned_field(self):
        path = Path(
            frappe.get_app_path(
                "erpnext",
                "selling",
                "custom",
                "customer.json",
            )
        )
        data = json.loads(path.read_text())

        self.assertFalse(
            any(
                field.get("fieldname") == FIELDNAME
                for field in data.get("custom_fields", [])
            )
        )
        for setter in data.get("property_setters", []):
            if setter.get("property") != "field_order":
                continue
            field_order = json.loads(setter.get("value") or "[]")
            self.assertNotIn(FIELDNAME, field_order)
