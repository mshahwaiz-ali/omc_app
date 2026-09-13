from types import SimpleNamespace
import unittest
from unittest.mock import patch

import frappe

from omc_app.setup.service_catalogue import accounting_mapping


class TestServiceAccountingMapping(unittest.TestCase):
    def test_every_published_service_has_a_preferred_invoice_item(self):
        active_ids = {
            spec.service_id
            for spec in accounting_mapping.SERVICES
            if spec.is_active
        }

        self.assertEqual(
            set(accounting_mapping.ERP_INVOICE_ITEM_BY_SERVICE_ID),
            active_ids,
        )

    def test_non_stock_sales_item_is_valid(self):
        with (
            patch.object(frappe.db, "exists", return_value="Business Tax Filing"),
            patch.object(
                frappe.db,
                "get_value",
                return_value=SimpleNamespace(
                    disabled=0,
                    is_sales_item=1,
                    is_stock_item=0,
                ),
            ),
        ):
            result = accounting_mapping.assess_invoice_item("Business Tax Filing")

        self.assertTrue(result["valid"])
        self.assertEqual(result["reason"], "valid_non_stock_sales_item")

    def test_stock_sales_item_is_rejected(self):
        with (
            patch.object(frappe.db, "exists", return_value="House Wife Filing"),
            patch.object(
                frappe.db,
                "get_value",
                return_value=SimpleNamespace(
                    disabled=0,
                    is_sales_item=1,
                    is_stock_item=1,
                ),
            ),
        ):
            result = accounting_mapping.assess_invoice_item("House Wife Filing")

        self.assertFalse(result["valid"])
        self.assertEqual(result["reason"], "stock_item_not_allowed")

    def test_missing_item_is_reported_not_created(self):
        with (
            patch.object(frappe.db, "exists", return_value=None),
            patch.object(frappe.db, "get_value") as get_value,
            patch.object(frappe, "new_doc") as new_doc,
        ):
            result = accounting_mapping.assess_invoice_item("Other Sources")

        self.assertFalse(result["valid"])
        self.assertEqual(result["reason"], "item_not_found")
        get_value.assert_not_called()
        new_doc.assert_not_called()

    def test_safe_pending_auto_map_is_ready_but_not_yet_valid(self):
        service = SimpleNamespace(service_id="business-tax-filing", is_active=True)
        rows = {
            "business-tax-filing": {
                "name": "business-tax-filing",
                "service_id": "business-tax-filing",
                "erp_invoice_item": None,
            }
        }

        with (
            patch.object(accounting_mapping, "SERVICES", (service,)),
            patch.dict(
                accounting_mapping.ERP_INVOICE_ITEM_BY_SERVICE_ID,
                {"business-tax-filing": "Business Tax Filing"},
                clear=True,
            ),
            patch.object(accounting_mapping, "_managed_service_rows", return_value=rows),
            patch.object(
                accounting_mapping,
                "assess_invoice_item",
                return_value={
                    "item": "Business Tax Filing",
                    "valid": True,
                    "reason": "valid_non_stock_sales_item",
                },
            ),
        ):
            result = accounting_mapping.preview_service_accounting_mappings()

        self.assertTrue(result["ready_to_sync"])
        self.assertFalse(result["valid"])
        self.assertEqual(result["summary"]["auto_map_ready"], 1)

    def test_sync_refuses_unsafe_preflight_before_writes(self):
        with (
            patch.object(
                accounting_mapping,
                "preview_service_accounting_mappings",
                return_value={
                    "ready_to_sync": False,
                    "unresolved": [{"service_id": "other-sources"}],
                    "invalid": [],
                },
            ),
            patch.object(frappe.db, "set_value") as set_value,
            patch.object(frappe.db, "savepoint") as savepoint,
        ):
            with self.assertRaises(frappe.ValidationError):
                accounting_mapping.sync_service_accounting_mappings()

        set_value.assert_not_called()
        savepoint.assert_not_called()

    def test_sync_fills_blank_safe_mapping(self):
        service = SimpleNamespace(service_id="business-tax-filing", is_active=True)
        rows = {
            "business-tax-filing": {
                "name": "business-tax-filing",
                "service_id": "business-tax-filing",
                "erp_invoice_item": None,
            }
        }
        validation = {"valid": True}

        with (
            patch.object(accounting_mapping, "SERVICES", (service,)),
            patch.dict(
                accounting_mapping.ERP_INVOICE_ITEM_BY_SERVICE_ID,
                {"business-tax-filing": "Business Tax Filing"},
                clear=True,
            ),
            patch.object(
                accounting_mapping,
                "preview_service_accounting_mappings",
                return_value={"ready_to_sync": True},
            ),
            patch.object(accounting_mapping, "_managed_service_rows", return_value=rows),
            patch.object(
                accounting_mapping,
                "assess_invoice_item",
                return_value={
                    "item": "Business Tax Filing",
                    "valid": True,
                    "reason": "valid_non_stock_sales_item",
                },
            ),
            patch.object(
                accounting_mapping,
                "validate_service_accounting_mappings",
                return_value=validation,
            ),
            patch.object(frappe.db, "set_value") as set_value,
            patch.object(frappe.db, "savepoint") as savepoint,
            patch.object(frappe.db, "commit") as commit,
        ):
            result = accounting_mapping.sync_service_accounting_mappings()

        savepoint.assert_called_once_with("omc_service_accounting_mapping_sync")
        set_value.assert_called_once_with(
            "OMC Service",
            "business-tax-filing",
            "erp_invoice_item",
            "Business Tax Filing",
            update_modified=False,
        )
        commit.assert_called_once_with()
        self.assertEqual(result["updated"][0]["item"], "Business Tax Filing")

    def test_sync_rolls_back_when_post_validation_fails(self):
        service = SimpleNamespace(service_id="business-tax-filing", is_active=True)
        rows = {
            "business-tax-filing": {
                "name": "business-tax-filing",
                "service_id": "business-tax-filing",
                "erp_invoice_item": None,
            }
        }

        with (
            patch.object(accounting_mapping, "SERVICES", (service,)),
            patch.dict(
                accounting_mapping.ERP_INVOICE_ITEM_BY_SERVICE_ID,
                {"business-tax-filing": "Business Tax Filing"},
                clear=True,
            ),
            patch.object(
                accounting_mapping,
                "preview_service_accounting_mappings",
                return_value={"ready_to_sync": True},
            ),
            patch.object(accounting_mapping, "_managed_service_rows", return_value=rows),
            patch.object(
                accounting_mapping,
                "assess_invoice_item",
                return_value={
                    "item": "Business Tax Filing",
                    "valid": True,
                    "reason": "valid_non_stock_sales_item",
                },
            ),
            patch.object(
                accounting_mapping,
                "validate_service_accounting_mappings",
                return_value={"valid": False},
            ),
            patch.object(frappe.db, "set_value"),
            patch.object(frappe.db, "savepoint"),
            patch.object(frappe.db, "rollback") as rollback,
            patch.object(frappe.db, "commit") as commit,
        ):
            with self.assertRaises(frappe.ValidationError):
                accounting_mapping.sync_service_accounting_mappings()

        rollback.assert_called_once_with(save_point="omc_service_accounting_mapping_sync")
        commit.assert_not_called()

    def test_sync_preserves_existing_client_mapping(self):
        service = SimpleNamespace(service_id="business-tax-filing", is_active=True)
        rows = {
            "business-tax-filing": {
                "name": "business-tax-filing",
                "service_id": "business-tax-filing",
                "erp_invoice_item": "Client Tax Service Item",
            }
        }

        with (
            patch.object(accounting_mapping, "SERVICES", (service,)),
            patch.dict(
                accounting_mapping.ERP_INVOICE_ITEM_BY_SERVICE_ID,
                {"business-tax-filing": "Business Tax Filing"},
                clear=True,
            ),
            patch.object(
                accounting_mapping,
                "preview_service_accounting_mappings",
                return_value={"ready_to_sync": True},
            ),
            patch.object(accounting_mapping, "_managed_service_rows", return_value=rows),
            patch.object(
                accounting_mapping,
                "validate_service_accounting_mappings",
                return_value={"valid": True},
            ),
            patch.object(frappe.db, "set_value") as set_value,
            patch.object(frappe.db, "savepoint"),
            patch.object(frappe.db, "commit"),
        ):
            result = accounting_mapping.sync_service_accounting_mappings()

        set_value.assert_not_called()
        self.assertEqual(
            result["preserved"],
            [
                {
                    "service_id": "business-tax-filing",
                    "item": "Client Tax Service Item",
                }
            ],
        )
