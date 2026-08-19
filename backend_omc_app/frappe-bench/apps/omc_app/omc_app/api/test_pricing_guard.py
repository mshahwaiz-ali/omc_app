from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import pricing_guard


class TestPricingGuard(FrappeTestCase):
    def test_tax_exclusive_finalization_recomputes_payable(self):
        totals = pricing_guard.finalized_totals(
            final_price=1700,
            tax_policy="Tax Exclusive",
            tax_rate=15,
        )
        self.assertEqual(totals["final_price"], 1700)
        self.assertEqual(totals["tax_amount"], 255)
        self.assertEqual(totals["payable_amount"], 1955)

    def test_tax_included_finalization_keeps_payable_at_final_price(self):
        totals = pricing_guard.finalized_totals(
            final_price=1150,
            tax_policy="Tax Included",
            tax_rate=15,
        )
        self.assertEqual(totals["final_price"], 1150)
        self.assertEqual(totals["tax_amount"], 150)
        self.assertEqual(totals["payable_amount"], 1150)

    def test_no_tax_finalization_has_zero_tax(self):
        totals = pricing_guard.finalized_totals(
            final_price=1250,
            tax_policy="No Tax",
            tax_rate=0,
        )
        self.assertEqual(totals["tax_amount"], 0)
        self.assertEqual(totals["payable_amount"], 1250)

    def test_negative_final_price_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            pricing_guard.finalized_totals(
                final_price=-1,
                tax_policy="No Tax",
                tax_rate=0,
            )

    def test_review_rejects_after_financial_processing_started(self):
        request = SimpleNamespace(
            name="OMC-SR-PRICE-LOCK",
            discount_status="Pending Approval",
            request_state="Pending Payment",
        )
        with (
            patch.object(
                pricing_guard.frappe.db,
                "get_value",
                return_value=request.name,
            ),
            patch.object(
                pricing_guard.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                pricing_guard.payment_opening,
                "financial_processing_started",
                return_value=True,
            ),
        ):
            with self.assertRaises(frappe.ValidationError):
                pricing_guard.finalize_discount_review(
                    request.name,
                    decision="approve",
                    reviewer="finance@example.com",
                )

    def test_review_requires_pending_discount(self):
        request = SimpleNamespace(
            name="OMC-SR-NO-DISCOUNT",
            discount_status="Approved",
            request_state="Pending Payment",
        )
        with (
            patch.object(
                pricing_guard.frappe.db,
                "get_value",
                return_value=request.name,
            ),
            patch.object(
                pricing_guard.frappe,
                "get_doc",
                return_value=request,
            ),
        ):
            with self.assertRaises(frappe.ValidationError):
                pricing_guard.finalize_discount_review(
                    request.name,
                    decision="approve",
                    reviewer="finance@example.com",
                )
