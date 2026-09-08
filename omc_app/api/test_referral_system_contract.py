from __future__ import annotations

import json
from pathlib import Path

from frappe.tests.utils import FrappeTestCase


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = (
    PACKAGE_ROOT
    / "omc_app"
    / "report"
    / "my_referrals"
    / "my_referrals.json"
)
REFERRAL_AUTOMATION_PATH = PACKAGE_ROOT / "referral_automation.py"
REFERRALS_API_PATH = PACKAGE_ROOT / "api" / "referrals.py"
REFERRAL_CAPABILITIES_PATH = PACKAGE_ROOT / "referral_capabilities.py"
STAFF_PROFILE_PATH = (
    PACKAGE_ROOT
    / "omc_app"
    / "doctype"
    / "omc_staff_profile"
    / "omc_staff_profile.json"
)


class TestReferralSystemContract(FrappeTestCase):
    def test_my_referrals_report_remains_enabled_with_compatible_roles(self):
        report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertEqual(report["report_name"], "My Referrals")
        self.assertEqual(report["report_type"], "Script Report")
        self.assertEqual(int(report.get("disabled") or 0), 0)

        roles = {row["role"] for row in report.get("roles") or []}
        self.assertTrue(
            {
                "Consultant",
                "Tax Associates",
                "Business Partner",
                "OMC Consultant",
                "OMC Tax Associate",
                "OMC Business Partner",
                "OMC Admin",
                "OMC Manager",
            }
            <= roles
        )

    def test_referral_code_generation_and_validation_remain_available(self):
        automation = REFERRAL_AUTOMATION_PATH.read_text(encoding="utf-8")
        referrals_api = REFERRALS_API_PATH.read_text(encoding="utf-8")

        self.assertIn("def ensure_referral_code_for_user", automation)
        self.assertIn("def validate_referral_code", automation)
        self.assertIn("def generate_unique_referral_code", referrals_api)
        self.assertIn("def resolve_active_referral", referrals_api)
        self.assertIn('CODE_PREFIX = "OMC-"', referrals_api)

    def test_referral_owner_personas_remain_supported(self):
        capabilities = REFERRAL_CAPABILITIES_PATH.read_text(encoding="utf-8")
        self.assertIn("CONSULTANT_ROLE", capabilities)
        self.assertIn("TAX_ASSOCIATE_ROLE", capabilities)
        self.assertIn("BUSINESS_PARTNER_ROLE", capabilities)
        self.assertIn("REFERRAL_OWNER_ROLES", capabilities)

    def test_staff_profile_keeps_referral_identity_fields(self):
        profile = json.loads(STAFF_PROFILE_PATH.read_text(encoding="utf-8"))
        fields = {field["fieldname"] for field in profile.get("fields") or []}
        self.assertIn("referral_record", fields)
        self.assertIn("own_referral_code", fields)
