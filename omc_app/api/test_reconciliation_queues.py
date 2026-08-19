import uuid

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import accounting_reconciliation, reconciliation_queues


class TestReconciliationQueues(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.source_name = f"TEST-REQ-{uuid.uuid4().hex[:12]}"

    def tearDown(self):
        frappe.db.delete(
            "OMC Reconciliation Review",
            {"source_name": self.source_name},
        )
        frappe.db.delete(
            "OMC Technical Quarantine",
            {"source_name": self.source_name},
        )
        frappe.db.commit()
        super().tearDown()

    def test_settlement_state_distinguishes_quarantine_review_and_reversal(self):
        quarantined, _ = accounting_reconciliation.settlement_state(
            required=100,
            invoice_basis=100,
            allocated=100,
            technical_reason="database source missing",
            invalid_reason="finance mismatch",
        )
        review, _ = accounting_reconciliation.settlement_state(
            required=100,
            invoice_basis=100,
            allocated=100,
            invalid_reason="finance mismatch",
        )
        reversed_state, _ = accounting_reconciliation.settlement_state(
            required=100,
            invoice_basis=100,
            allocated=0,
            reversed_exists=True,
        )

        self.assertEqual(quarantined, "Quarantined")
        self.assertEqual(review, "Review Required")
        self.assertEqual(reversed_state, "Reversed")

    def test_human_review_is_idempotent_for_same_source_version(self):
        first = reconciliation_queues.open_human_review(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v1",
            reason_code="invoice_currency_mismatch",
            safe_evidence={"sales_invoice": "SINV-TEST"},
        )
        second = reconciliation_queues.open_human_review(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v1",
            reason_code="invoice_currency_mismatch",
            safe_evidence={"sales_invoice": "SINV-TEST"},
        )

        self.assertEqual(first.name, second.name)
        self.assertEqual(first.status, "Open")
        self.assertFalse(
            frappe.db.exists(
                "OMC Technical Quarantine",
                {"source_name": self.source_name},
            )
        )

    def test_technical_quarantine_counts_recurrence_and_reopens(self):
        first = reconciliation_queues.open_technical_quarantine(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v1",
            failure_code="linked_invoice_missing",
            safe_evidence={"sales_invoice": "SINV-MISSING"},
        )
        reconciliation_queues.resolve_source_queues(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
        )
        second = reconciliation_queues.open_technical_quarantine(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v2",
            failure_code="linked_invoice_missing",
            safe_evidence={"sales_invoice": "SINV-MISSING"},
        )
        second.reload()

        self.assertEqual(first.name, second.name)
        self.assertEqual(second.status, "Open")
        self.assertEqual(second.attempt_count, 2)
        self.assertEqual(second.source_version, "v2")
        self.assertFalse(
            frappe.db.exists(
                "OMC Reconciliation Review",
                {"source_name": self.source_name},
            )
        )

    def test_recovered_source_resolves_both_open_queue_types(self):
        review = reconciliation_queues.open_human_review(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v1",
            reason_code="payment_party_mismatch",
        )
        quarantine = reconciliation_queues.open_technical_quarantine(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
            source_version="v1",
            failure_code="linked_invoice_missing",
        )

        result = reconciliation_queues.resolve_source_queues(
            domain="Accounting",
            source_doctype="OMC Service Request",
            source_name=self.source_name,
        )
        review.reload()
        quarantine.reload()

        self.assertEqual(result, {"reviews": 1, "quarantines": 1})
        self.assertEqual(review.status, "Resolved")
        self.assertEqual(quarantine.status, "Resolved")
