from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

import frappe
from omc_app.api import expense_guard


class TestExpenseReceiptContract(TestCase):
    def test_canonical_and_legacy_identifiers(self):
        with patch.object(frappe, "request", SimpleNamespace(files={"file": object()})), patch.object(
            expense_guard.expense, "upload_expense_receipt", return_value={"entry": "owned"}
        ) as upload:
            for arguments in ({"entry_id": "owned"}, {"docname": "owned"},
                              {"entry_id": "owned", "docname": "owned"}):
                self.assertEqual(expense_guard.upload_expense_receipt(**arguments), {"entry": "owned"})
                upload.assert_called_with(entry_id="owned")

    def test_rejects_conflicting_missing_and_url_identifiers(self):
        with patch.object(frappe, "throw", side_effect=ValueError), patch.object(
            expense_guard.expense, "upload_expense_receipt"
        ) as upload:
            for arguments in ({}, {"entry_id": "a", "docname": "b"},
                              {"entry_id": "a", "file_url": "/private/files/x.pdf"}):
                with self.assertRaises(ValueError):
                    expense_guard.upload_expense_receipt(**arguments)
            upload.assert_not_called()
