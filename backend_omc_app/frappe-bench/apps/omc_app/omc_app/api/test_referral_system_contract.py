from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup import referral_workspace


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

REFERRAL_REPORT_ROLE_CANDIDATES = {
    "Consultant",
    "OMC Consultant",
    "Tax Associates",
    "Tax Associate",
    "OMC Tax Associate",
    "Business Partner",
    "OMC Business Partner",
    "OMC Admin",
    "OMC Manager",
}


class TestReferralSystemContract(FrappeTestCase):
    def test_my_referrals_report_remains_enabled_with_install_safe_roles(self):
        report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertEqual(report["report_name"], "My Referrals")
        self.assertEqual(report["report_type"], "Script Report")
        self.assertEqual(int(report.get("disabled") or 0), 0)

        roles = {row["role"] for row in report.get("roles") or []}
        self.assertEqual(roles, {"OMC Admin", "OMC Manager"})

    def test_desk_sync_supports_canonical_and_compatibility_role_names(self):
        self.assertTrue(
            REFERRAL_REPORT_ROLE_CANDIDATES
            <= set(referral_workspace._MY_REFERRALS_REPORT_ROLE_CANDIDATES)
        )

    def test_desk_sync_writes_only_roles_installed_on_the_site(self):
        installed = {
            "Consultant",
            "Tax Associate",
            "Business Partner",
            "OMC Admin",
            "OMC Manager",
        }
        report = MagicMock()
        report.get.return_value = [
            {"role": "OMC Consultant"},
            {"role": "OMC Admin"},
            {"role": "OMC Admin"},
        ]

        def exists(doctype, name):
            if doctype == "Report":
                return name == "My Referrals"
            if doctype == "Role":
                return name in installed
            return False

        with (
            patch.object(referral_workspace.frappe.db, "exists", side_effect=exists),
            patch.object(referral_workspace.frappe, "get_doc", return_value=report),
        ):
            referral_workspace._ensure_my_referrals_report_roles()

        desired = [
            "Consultant",
            "Tax Associate",
            "Business Partner",
            "OMC Admin",
            "OMC Manager",
        ]
        report.set.assert_called_once_with(
            "roles",
            [{"role": role} for role in desired],
        )
        report.save.assert_called_once_with(ignore_permissions=True)

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
