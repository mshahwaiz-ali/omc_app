from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import finance_reconciliation


class TestFinanceReconciliation(FrappeTestCase):
    def _row(self, **overrides):
        values = {
            "name": "REV-1",
            "source_doctype": "OMC Service Request",
            "source_name": "OMC-SR-1",
            "reason_code": "payment_party_mismatch",
            "safe_evidence_json": '{"payment_entry":"ACC-PAY-1"}',
            "status": "Open",
            "creation": "2026-08-19 10:00:00",
            "resolved_by": None,
            "resolved_at": None,
            "resolution_note": "",
        }
        values.update(overrides)
        return frappe._dict(values)

    def test_list_is_capability_guarded_and_accounting_scoped(self):
        rows = [self._row(), self._row(name="REV-2")]
        with (
            patch.object(finance_reconciliation.capabilities, "require") as require,
            patch.object(finance_reconciliation.security, "enforce_rate_limit"),
            patch.object(finance_reconciliation.frappe, "get_all", return_value=rows) as get_all,
            patch.object(finance_reconciliation, "_request_context", return_value={}),
        ):
            result = finance_reconciliation.get_settlement_reviews(limit_page_length=1)

        require.assert_called_once_with("can_reconcile_settlement")
        self.assertEqual(get_all.call_args.kwargs["filters"]["domain"], "Accounting")
        self.assertEqual(result["scope"], "Accounting")
        self.assertTrue(result["has_more"])
        self.assertEqual(result["next_start"], 1)
        self.assertEqual(result["items"][0]["allowed_actions"], ["resolve", "ignore"])

    def test_closed_review_has_no_mobile_actions(self):
        item = finance_reconciliation._review_item(
            self._row(status="Resolved", resolution_note="Verified in Desk.")
        )
        self.assertEqual(item["allowed_actions"], [])
        self.assertEqual(item["resolution_note"], "Verified in Desk.")

    def test_decision_requires_note(self):
        with patch.object(finance_reconciliation.capabilities, "require"):
            with self.assertRaises(frappe.ValidationError):
                finance_reconciliation.decide_settlement_review(
                    review="REV-1",
                    decision="resolve",
                    note="",
                )

    def test_decision_rejects_non_accounting_review(self):
        doc = SimpleNamespace(domain="Commission")
        with (
            patch.object(finance_reconciliation.capabilities, "require"),
            patch.object(finance_reconciliation.frappe.db, "exists", return_value=True),
            patch.object(finance_reconciliation.frappe, "get_doc", return_value=doc),
        ):
            with self.assertRaises(frappe.PermissionError):
                finance_reconciliation.decide_settlement_review(
                    review="REV-1",
                    decision="ignore",
                    note="Not an accounting review.",
                )

    def test_decision_delegates_to_audited_review_resolver(self):
        doc = SimpleNamespace(domain="Accounting")
        with (
            patch.object(finance_reconciliation.capabilities, "require"),
            patch.object(finance_reconciliation.frappe.db, "exists", return_value=True),
            patch.object(finance_reconciliation.frappe, "get_doc", return_value=doc),
            patch.object(
                finance_reconciliation.reconciliation_queues,
                "resolve_review",
                return_value={"review": "REV-1", "status": "Resolved"},
            ) as resolve_review,
        ):
            result = finance_reconciliation.decide_settlement_review(
                review="REV-1",
                decision="resolve",
                note="Evidence verified outside the mobile workflow.",
            )

        resolve_review.assert_called_once_with(
            review="REV-1",
            resolution="resolved",
            note="Evidence verified outside the mobile workflow.",
        )
        self.assertEqual(result["status"], "Resolved")
        self.assertTrue(result["note_recorded"])
