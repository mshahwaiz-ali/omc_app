from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import referral_commissions
from omc_app.omc_app.doctype.omc_commission_settlement.omc_commission_settlement import (
    OMCCommissionSettlement,
)


class TestReferralCommissionEarnings(FrappeTestCase):
    def _documents(self):
        service = SimpleNamespace(
            name="tax-filing",
            referral_commission_enabled=1,
            referral_commission_percent=10,
        )
        profile = SimpleNamespace(
            name="OMC-CUST-1",
            referral_assistance_consent=1,
            referral_record="OMC-REF-1",
            referred_by="referrer@example.com",
        )
        referral = SimpleNamespace(
            name="OMC-REF-1",
            is_active=1,
            status="Approved",
            referrer_user="referrer@example.com",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            service="tax-filing",
            customer_profile=profile.name,
            referral_record=referral.name,
            referral_owner=referral.referrer_user,
        )
        payment = SimpleNamespace(name="OMC-PAY-1")
        invoice = SimpleNamespace(
            name="SINV-1",
            docstatus=1,
            outstanding_amount=0,
            grand_total=10000,
            currency="PKR",
        )
        return service, profile, referral, request, payment, invoice

    def test_posted_payment_snapshots_percentage_and_final_invoice_amount(self):
        service, profile, referral, request, payment, invoice = self._documents()
        earning = MagicMock()
        earning.name = "OMC-COM-1"

        with (
            patch.object(referral_commissions.frappe.db, "get_value", return_value=None),
            patch.object(referral_commissions.frappe.db, "exists", return_value=True),
            patch.object(
                referral_commissions.frappe,
                "get_doc",
                side_effect=[service, profile, referral],
            ),
            patch.object(referral_commissions.frappe, "new_doc", return_value=earning),
            patch.object(
                referral_commissions.frappe.utils,
                "now_datetime",
                return_value=__import__("datetime").datetime(2026, 8, 16, 12, 0),
            ),
            patch("omc_app.api.mobile._create_customer_notification") as notify,
        ):
            result = referral_commissions.create_earning_for_posted_payment(
                payment,
                request=request,
                invoice=invoice,
            )

        self.assertTrue(result["created"])
        self.assertEqual(earning.basis_amount, 10000.0)
        self.assertEqual(earning.commission_percent_snapshot, 10.0)
        self.assertEqual(earning.commission_amount, 1000.0)
        self.assertEqual(earning.unique_event_key, "payment:OMC-PAY-1:finance-posted")
        earning.insert.assert_called_once_with(ignore_permissions=True)
        notify.assert_called_once()
        self.assertEqual(
            notify.call_args.kwargs["mobile_route"],
            "/my-commissions/OMC-COM-1",
        )

    def test_retry_reuses_existing_earning_without_recalculation(self):
        _service, _profile, _referral, request, payment, invoice = self._documents()
        with patch.object(
            referral_commissions.frappe.db,
            "get_value",
            return_value="OMC-COM-EXISTING",
        ):
            result = referral_commissions.create_earning_for_posted_payment(
                payment,
                request=request,
                invoice=invoice,
            )
        self.assertFalse(result["created"])
        self.assertEqual(result["earning"], "OMC-COM-EXISTING")
        self.assertEqual(result["reason"], "already_exists")

    def test_disabled_commission_creates_no_ledger_record(self):
        service, _profile, _referral, request, payment, invoice = self._documents()
        service.referral_commission_enabled = 0
        with (
            patch.object(referral_commissions.frappe.db, "get_value", return_value=None),
            patch.object(referral_commissions.frappe.db, "exists", return_value=True),
            patch.object(referral_commissions.frappe, "get_doc", return_value=service),
            patch.object(referral_commissions.frappe, "new_doc") as new_doc,
        ):
            result = referral_commissions.create_earning_for_posted_payment(
                payment,
                request=request,
                invoice=invoice,
            )
        self.assertEqual(result["reason"], "commission_disabled")
        new_doc.assert_not_called()

    def test_revoked_consent_creates_no_earning(self):
        service, profile, _referral, request, payment, invoice = self._documents()
        profile.referral_assistance_consent = 0
        with (
            patch.object(referral_commissions.frappe.db, "get_value", return_value=None),
            patch.object(referral_commissions.frappe.db, "exists", return_value=True),
            patch.object(
                referral_commissions.frappe,
                "get_doc",
                side_effect=[service, profile],
            ),
        ):
            result = referral_commissions.create_earning_for_posted_payment(
                payment,
                request=request,
                invoice=invoice,
            )
        self.assertEqual(result["reason"], "no_eligible_referral")


class TestReferralCommissionAccess(FrappeTestCase):
    def test_list_is_always_scoped_to_current_referrer(self):
        with (
            patch.object(referral_commissions, "_current_user", return_value="owner@example.com"),
            patch.object(
                referral_commissions,
                "_capabilities",
                return_value={"can_view_referral_commissions": True},
            ),
            patch.object(referral_commissions.frappe, "get_all", return_value=[]) as get_all,
        ):
            result = referral_commissions.get_my_commissions(start=0, limit=20)
        self.assertEqual(result["items"], [])
        self.assertEqual(get_all.call_args.kwargs["filters"]["referrer_user"], "owner@example.com")

    def test_unrelated_role_cannot_view_commissions(self):
        with (
            patch.object(referral_commissions, "_current_user", return_value="support@example.com"),
            patch.object(referral_commissions, "_capabilities", return_value={}),
            self.assertRaises(frappe.PermissionError),
        ):
            referral_commissions.get_my_commissions()

    def test_referrer_cannot_reverse_earning(self):
        with (
            patch.object(referral_commissions, "_current_user", return_value="owner@example.com"),
            patch.object(
                referral_commissions,
                "_capabilities",
                return_value={"can_view_referral_commissions": True},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            referral_commissions.reverse_commission("OMC-COM-1", "Correction")


class TestCommissionSettlementContract(FrappeTestCase):
    def test_validate_snapshots_rows_and_total(self):
        row = SimpleNamespace(
            earning="OMC-COM-1",
            customer_profile="",
            service_request="",
            amount=0,
        )
        settlement = SimpleNamespace(
            period_start=date(2026, 8, 1),
            period_end=date(2026, 8, 31),
            earnings=[row],
            referrer_user="owner@example.com",
            currency="PKR",
            total_amount=0,
        )
        earning = SimpleNamespace(
            name="OMC-COM-1",
            referrer_user="owner@example.com",
            currency="PKR",
            earning_status="Earned",
            customer_profile="OMC-CUST-1",
            service_request="OMC-SR-1",
            commission_amount=1000,
        )
        with patch(
            "omc_app.omc_app.doctype.omc_commission_settlement.omc_commission_settlement.frappe.get_doc",
            return_value=earning,
        ):
            OMCCommissionSettlement.validate(settlement)
        self.assertEqual(settlement.total_amount, 1000)
        self.assertEqual(row.customer_profile, "OMC-CUST-1")
        self.assertEqual(row.service_request, "OMC-SR-1")

    def test_submitted_settlement_cannot_be_cancelled(self):
        with self.assertRaises(frappe.ValidationError):
            OMCCommissionSettlement.before_cancel(SimpleNamespace())
