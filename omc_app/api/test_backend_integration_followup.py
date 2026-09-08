"""Account-wide summary and internal delivery-ledger regression coverage."""
import json
import uuid
from pathlib import Path
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase
from omc_app.api import expense
from omc_app.setup import roles


class TestBackendIntegrationFollowup(FrappeTestCase):
    def test_delivery_ledger_has_only_internal_classification(self):
        self.assertIn("OMC Push Delivery", roles.INTERNAL_ONLY_DOCTYPES)
        self.assertNotIn("OMC Push Delivery", roles.ADMIN_MUTABLE_DOCTYPES)
        self.assertNotIn("OMC Push Delivery", roles.ADMIN_READ_ONLY_DOCTYPES)
        root = Path(__file__).resolve().parents[1]
        definition = json.loads((root / "omc_app/doctype/omc_push_delivery/omc_push_delivery.json").read_text())
        self.assertEqual(definition.get("permissions"), [])

    def test_database_receipt_expression_discards_missing_local_files(self):
        marker = uuid.uuid4().hex
        values = [None, "", "   ", "/files/omc-test-" + marker + ".pdf",
                  "/private/files/omc-test-" + marker + ".pdf",
                  "https://files.example.invalid/receipt.pdf", "legacy-reference"]
        for value in values[3:5]:
            self.assertFalse(frappe.db.exists("File", {"file_url": value}))
        derived = " UNION ALL ".join(["SELECT %s AS receipt_file"] * len(values))
        rows = frappe.db.sql(
            "SELECT SUM(" + expense._VALID_RECEIPT_SQL + ") FROM (" + derived + ") AS expense_entry",
            tuple(values),
        )
        self.assertEqual(int(rows[0][0]), 2)

    def test_complete_summary_retains_full_count_money_and_month_scope(self):
        first, last = "2026-09-01", "2026-09-30"
        rows = [frappe._dict(transaction_type="Expense", category="Fuel", payment_method="Cash",
                             amount=2500, row_count=250, tax_total=500, business_total=1000,
                             receipts=7, recurring_count=4),
                frappe._dict(transaction_type="Income", category="Salary", payment_method="Bank",
                             amount=5000, row_count=2, tax_total=0, business_total=0,
                             receipts=0, recurring_count=0)]
        with patch.object(frappe.db, "sql", return_value=rows) as query, \
                patch.object(frappe.utils, "get_first_day", return_value=first), \
                patch.object(frappe.utils, "get_last_day", return_value=last):
            result = expense._complete_summary("OWNED-PROFILE", "2026-09")
        query.assert_called_once()
        sql, parameters = query.call_args.args
        self.assertEqual(parameters, ("OWNED-PROFILE", first, last))
        self.assertIn("customer_profile=%s", sql)
        self.assertIn("transaction_date BETWEEN %s AND %s", sql)
        self.assertIn("NOT EXISTS", sql)
        self.assertNotIn("LIMIT", sql.upper())
        self.assertEqual(result["transaction_count"], 252)
        self.assertEqual(result["income"], 5000)
        self.assertEqual(result["expenses"], 2500)
        self.assertEqual(result["balance"], 2500)
        self.assertEqual(result["receipts_attached"], 7)
        self.assertEqual(result["category_totals"], {"Fuel": 2500})
