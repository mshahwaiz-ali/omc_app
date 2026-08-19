from __future__ import annotations

from types import SimpleNamespace

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api.accounting_policy import assert_invoice_matches_request


class TestAccountingCompanyAuthority(FrappeTestCase):
    def _request(self, **overrides):
        values = {
            "erp_customer": "CUST-001",
            "company_snapshot": "OMC Legal Co",
            "pricing_currency": "PKR",
        }
        values.update(overrides)
        return frappe._dict(values)

    def _invoice(self, **overrides):
        values = {
            "docstatus": 1,
            "is_return": 0,
            "customer": "CUST-001",
            "company": "OMC Legal Co",
            "currency": "PKR",
            "grand_total": 1000,
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_matching_invoice_is_accepted(self):
        assert_invoice_matches_request(self._request(), self._invoice())

    def test_company_mismatch_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            assert_invoice_matches_request(
                self._request(),
                self._invoice(company="Wrong Legal Co"),
            )

    def test_customer_mismatch_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            assert_invoice_matches_request(
                self._request(),
                self._invoice(customer="CUST-OTHER"),
            )

    def test_currency_mismatch_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            assert_invoice_matches_request(
                self._request(),
                self._invoice(currency="USD"),
            )

    def test_legacy_request_without_company_snapshot_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            assert_invoice_matches_request(
                self._request(company_snapshot=""),
                self._invoice(),
            )

    def test_return_invoice_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            assert_invoice_matches_request(
                self._request(),
                self._invoice(is_return=1),
            )
