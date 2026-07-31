from pathlib import Path

import frappe
from frappe.tests.utils import FrappeTestCase


class TestLegacyTaskDoctypeRetirement(FrappeTestCase):
    def test_legacy_doctype_source_removed(self):
        app_root = Path(__file__).resolve().parents[1]
        legacy_dir = (
            app_root
            / "omc_app"
            / "doctype"
            / "omc_task"
        )
        self.assertFalse(legacy_dir.exists())

    def test_legacy_doctype_removed_from_database(self):
        self.assertFalse(
            frappe.db.exists("DocType", "OMC Task")
        )

    def test_legacy_permissions_removed_with_doctype(self):
        self.assertEqual(
            frappe.db.count(
                "DocPerm",
                {"parent": "OMC Task"},
            ),
            0,
        )
        self.assertEqual(
            frappe.db.count(
                "Custom DocPerm",
                {"parent": "OMC Task"},
            ),
            0,
        )
