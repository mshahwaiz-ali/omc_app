from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import expense


class TestExpensePublicReads(FrappeTestCase):
    @patch("omc_app.api.expense.frappe.db.commit")
    @patch("omc_app.api.expense._seed_default_categories")
    @patch("omc_app.api.expense.frappe.get_all", return_value=[])
    @patch("omc_app.api.expense._has_doctype", return_value=True)
    @patch("omc_app.api.expense._expense_enabled", return_value=True)
    def test_public_categories_read_does_not_seed_or_commit(
        self,
        _expense_enabled,
        _has_doctype,
        _get_all,
        seed_default_categories,
        commit,
    ):
        result = expense.get_expense_categories()

        seed_default_categories.assert_not_called()
        commit.assert_not_called()
        self.assertTrue(result["fallback"])
        self.assertTrue(result["enabled"])
        self.assertEqual(result["categories"], expense.DEFAULT_EXPENSE_CATEGORIES)

    @patch("omc_app.api.expense.frappe.get_all")
    @patch("omc_app.api.expense._has_doctype", return_value=False)
    @patch("omc_app.api.expense._expense_enabled", return_value=True)
    def test_missing_category_doctype_uses_static_fallback(
        self,
        _expense_enabled,
        _has_doctype,
        get_all,
    ):
        result = expense.get_expense_categories()

        get_all.assert_not_called()
        self.assertTrue(result["fallback"])
        self.assertTrue(result["enabled"])
        self.assertEqual(result["categories"], expense.DEFAULT_EXPENSE_CATEGORIES)
