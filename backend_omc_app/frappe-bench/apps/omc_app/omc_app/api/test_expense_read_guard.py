from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import expense_read_guard


class TestExpenseReadGuard(FrappeTestCase):
    def test_hooks_route_expense_reads(self):
        expected = {
            "omc_app.api.expense.get_expense_entries": "omc_app.api.expense_read_guard.get_expense_entries",
            "omc_app.api.expense.get_expense_summary": "omc_app.api.expense_read_guard.get_expense_summary",
            "omc_app.api.expense.get_expense_budgets": "omc_app.api.expense_read_guard.get_expense_budgets",
        }
        for source, target in expected.items():
            self.assertEqual(hooks.override_whitelisted_methods[source], target)

    @patch("omc_app.api.expense_read_guard.expense._has_doctype", return_value=True)
    @patch("omc_app.api.expense_read_guard.frappe.db.exists")
    def test_stale_category_becomes_uncategorized(self, exists, _has_doctype):
        exists.return_value = False

        result = expense_read_guard._sanitize_entry(
            {"category": "Deleted Category", "receipt_file": ""}
        )

        self.assertEqual(result["category"], "Uncategorized")
        exists.assert_called_once_with("OMC Expense Category", "Deleted Category")

    @patch("omc_app.api.expense_read_guard.expense._has_doctype", return_value=True)
    @patch("omc_app.api.expense_read_guard.frappe.db.exists")
    def test_valid_category_is_preserved(self, exists, _has_doctype):
        exists.return_value = True

        result = expense_read_guard._sanitize_entry(
            {"category": "Fuel", "receipt_file": ""}
        )

        self.assertEqual(result["category"], "Fuel")

    @patch("omc_app.api.expense_read_guard.frappe.db.exists", return_value=False)
    def test_deleted_local_receipt_is_cleared(self, exists):
        result = expense_read_guard._sanitize_entry(
            {"category": "Uncategorized", "receipt_file": "/private/files/missing.pdf"}
        )

        self.assertEqual(result["receipt_file"], "")
        exists.assert_called_once_with(
            "File", {"file_url": "/private/files/missing.pdf"}
        )

    @patch("omc_app.api.expense_read_guard.frappe.db.exists")
    def test_external_receipt_url_is_preserved(self, exists):
        result = expense_read_guard._sanitize_entry(
            {
                "category": "Uncategorized",
                "receipt_file": "https://files.example.com/receipt.pdf",
            }
        )

        self.assertEqual(
            result["receipt_file"], "https://files.example.com/receipt.pdf"
        )
        exists.assert_not_called()

    def test_entry_summary_is_recomputed_after_sanitizing(self):
        # The historical method name is retained. The approved paged contract now
        # obtains sanitized receipt counts globally, never by totaling this page.
        complete = {"transaction_count": 250, "income": 5000, "expenses": 2500,
                    "balance": 2500, "receipts_attached": 0}
        with patch.object(expense_read_guard.expense, "_summary") as page_summary, \
                patch.object(expense_read_guard.expense, "get_expense_entries", return_value={
                    "entries": [{"category": "Old", "receipt_file": "/files/old.pdf"}],
                    "summary": complete, "fallback": False, "has_more": True, "next_start": 100,
                }) as get_entries, \
                patch.object(expense_read_guard, "_sanitize_entry", return_value={
                    "category": "Uncategorized", "receipt_file": "",
                }) as sanitize_entry:
            result = expense_read_guard.get_expense_entries(month="2026-07", limit=100)
        self.assertEqual(result["summary"], complete)
        self.assertEqual(result["entries"], [{"category": "Uncategorized", "receipt_file": ""}])
        self.assertTrue(result["has_more"])
        self.assertEqual(result["next_start"], 100)
        sanitize_entry.assert_called_once_with({"category": "Old", "receipt_file": "/files/old.pdf"})
        page_summary.assert_not_called()
        get_entries.assert_called_once_with(month="2026-07", limit=100, start=0)

    @patch("omc_app.api.expense_read_guard.expense._has_doctype", return_value=True)
    @patch("omc_app.api.expense_read_guard.frappe.db.exists", return_value=False)
    def test_stale_budget_category_is_cleared(self, _exists, _has_doctype):
        result = expense_read_guard._sanitize_budget(
            {"name": "BUDGET-1", "category": "Deleted Category"}
        )

        self.assertEqual(result["name"], "BUDGET-1")
        self.assertEqual(result["category"], "")

    @patch("omc_app.api.expense_read_guard._sanitize_budget")
    @patch("omc_app.api.expense_read_guard.expense.get_expense_budgets")
    def test_budget_read_preserves_canonical_response(
        self, get_budgets, sanitize_budget
    ):
        get_budgets.return_value = {
            "budgets": [{"name": "BUDGET-1", "category": "Fuel"}],
            "fallback": False,
            "enabled": True,
        }
        sanitize_budget.return_value = {
            "name": "BUDGET-1",
            "category": "Fuel",
        }

        result = expense_read_guard.get_expense_budgets(month="2026-07")

        self.assertTrue(result["enabled"])
        self.assertFalse(result["fallback"])
        self.assertEqual(result["budgets"][0]["name"], "BUDGET-1")
        get_budgets.assert_called_once_with(month="2026-07")
