from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import referrals


class TestReferralBackend(FrappeTestCase):
    def test_normalize_referral_code(self):
        self.assertEqual(referrals.normalize_referral_code(" ab12cd "), "OMC-AB12CD")
        self.assertEqual(referrals.normalize_referral_code("omc-ab12cd"), "OMC-AB12CD")
        self.assertEqual(referrals.normalize_referral_code(""), "")

    def test_generate_unique_code_retries_collision(self):
        with (
            patch.object(referrals, "_generate_candidate", side_effect=["OMC-AAAAAA", "OMC-BBBBBB"]),
            patch.object(frappe.db, "exists", side_effect=[True, False]),
        ):
            self.assertEqual(referrals.generate_unique_referral_code(), "OMC-BBBBBB")

    def test_apply_referral_requires_consent(self):
        record = MagicMock()
        record.name = "OMC-REF-1"
        record.referrer_user = "staff@example.com"
        record.referral_code = "OMC-ABC234"
        with patch.object(referrals, "resolve_active_referral", return_value=record):
            with self.assertRaises(frappe.ValidationError):
                referrals.apply_referral_to_customer(
                    MagicMock(),
                    "OMC-ABC234",
                    consent_granted=False,
                )

    def test_apply_referral_sets_customer_fields(self):
        record = MagicMock()
        record.name = "OMC-REF-1"
        record.referrer_user = "staff@example.com"
        record.referral_code = "OMC-ABC234"
        profile = MagicMock()
        with (
            patch.object(referrals, "resolve_active_referral", return_value=record),
            patch.object(referrals, "now_datetime", return_value="2026-07-27 17:00:00"),
        ):
            referrals.apply_referral_to_customer(
                profile,
                "OMC-ABC234",
                consent_granted=True,
            )

        self.assertEqual(profile.acquisition_source, "Referral")
        self.assertEqual(profile.referral_record, "OMC-REF-1")
        self.assertEqual(profile.referred_by, "staff@example.com")
        self.assertEqual(profile.referral_code_used, "OMC-ABC234")
        self.assertEqual(profile.referral_assistance_consent, 1)
