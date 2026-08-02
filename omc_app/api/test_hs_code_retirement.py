from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

import frappe

from omc_app.patches import remove_omc_hs_code_substitute as retirement


class TestHsCodeRetirement(TestCase):
    def test_refuses_to_remove_non_omc_doctype(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=True),
            patch.object(
                retirement.frappe.db,
                "get_value",
                return_value=SimpleNamespace(module="Stock", custom=0),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            retirement.execute()

    def test_refuses_to_remove_when_records_exist(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=True),
            patch.object(
                retirement.frappe.db,
                "get_value",
                return_value=SimpleNamespace(module="OMC App", custom=0),
            ),
            patch.object(retirement.frappe.db, "table_exists", return_value=True),
            patch.object(
                retirement.frappe,
                "get_all",
                return_value=[
                    frappe._dict(
                        name="CLIENT-123",
                        description="Client business value",
                        owner="Administrator",
                    )
                ],
            ),
            patch.object(retirement.frappe.db, "delete") as db_delete,
            patch.object(retirement.frappe.db, "count", return_value=1),
            patch.object(retirement, "_nonempty_references", return_value=[]),
            patch.object(retirement.frappe, "delete_doc") as delete_doc,
            self.assertRaises(frappe.ValidationError),
        ):
            retirement.execute()
        delete_doc.assert_not_called()
        db_delete.assert_not_called()

    def test_empty_omc_substitute_is_removed(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=True),
            patch.object(
                retirement.frappe.db,
                "get_value",
                return_value=SimpleNamespace(module="OMC App", custom=0),
            ),
            patch.object(retirement.frappe.db, "table_exists", return_value=True),
            patch.object(retirement.frappe, "get_all", return_value=[]),
            patch.object(retirement.frappe.db, "count", return_value=0),
            patch.object(retirement, "_nonempty_references", return_value=[]),
            patch.object(retirement.frappe, "delete_doc") as delete_doc,
            patch.object(retirement.frappe, "clear_cache"),
        ):
            retirement.execute()
        delete_doc.assert_called_once_with(
            "DocType",
            "HS Code",
            force=True,
            ignore_permissions=True,
            delete_permanently=True,
        )

    def test_exact_reserved_fixture_is_removed_before_doctype_retirement(self):
        row = frappe._dict(retirement.RESERVED_TEST_RECORD)
        with (
            patch.object(retirement.frappe.db, "exists", return_value=True),
            patch.object(
                retirement.frappe.db,
                "get_value",
                return_value=SimpleNamespace(module="OMC App", custom=0),
            ),
            patch.object(retirement.frappe.db, "table_exists", return_value=True),
            patch.object(retirement.frappe, "get_all", return_value=[row]),
            patch.object(retirement.frappe.db, "delete") as db_delete,
            patch.object(retirement.frappe.db, "count", return_value=0),
            patch.object(retirement, "_nonempty_references", return_value=[]),
            patch.object(retirement.frappe, "delete_doc"),
            patch.object(retirement.frappe, "clear_cache"),
        ):
            retirement.execute()
        db_delete.assert_called_once_with("HS Code", {"name": "9999.99"})
