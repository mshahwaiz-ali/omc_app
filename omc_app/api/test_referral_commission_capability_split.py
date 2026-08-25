from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, capabilities
from omc_app.referral_capabilities import REFERRAL_OWNER_ROLES
from omc_app.setup import staff_sync


class TestReferralCommissionCapabilitySplit(FrappeTestCase):
    def test_canonical_referral_owner_personas_are_exact(self):
        self.assertEqual(
            REFERRAL_OWNER_ROLES,
            {"Consultant", "Business Partner", "Tax Associates"},
        )

    def test_referral_owner_personas_receive_both_personal_capabilities(self):
        for persona in ("Consultant", "Business Partner", "Tax Associates"):
            values = staff_sync._persona_capabilities(persona)
            self.assertIn("can_own_referrals", values)
            self.assertIn("can_view_own_commissions", values)
            self.assertNotIn("can_view_referral_commissions", values)

    def test_employee_can_view_own_commissions_but_cannot_own_referrals(self):
        values = staff_sync._persona_capabilities("Employee")
        self.assertNotIn("can_own_referrals", values)
        self.assertIn("can_view_own_commissions", values)
        self.assertNotIn("can_view_referral_commissions", values)

    def test_finance_reviewer_does_not_gain_personal_entitlements(self):
        values = access.ROLE_CAPABILITIES["OMC Finance Reviewer"]
        self.assertNotIn("can_own_referrals", values)
        self.assertNotIn("can_view_own_commissions", values)
        self.assertNotIn("can_view_referral_commissions", values)
        self.assertIn("can_approve_commissions", values)
        self.assertIn("can_mark_commissions_paid", values)

    def test_administrator_does_not_gain_self_scoped_capabilities(self):
        with patch.object(capabilities.identity, "user_is_enabled", return_value=True):
            values = capabilities.effective("Administrator")
        self.assertFalse(values["can_own_referrals"])
        self.assertFalse(values["can_view_own_commissions"])
        self.assertFalse(values["can_view_referral_commissions"])
        self.assertTrue(values["can_approve_commissions"])
        self.assertTrue(values["can_mark_commissions_paid"])

    def test_legacy_capability_is_not_canonical_staff_provisioning_authority(self):
        for persona in ("Consultant", "Business Partner", "Tax Associates", "Employee"):
            self.assertNotIn(
                "can_view_referral_commissions",
                staff_sync._persona_capabilities(persona),
            )

    def test_role_templates_never_store_legacy_overloaded_capability(self):
        for role, values in access.ROLE_CAPABILITIES.items():
            self.assertNotIn(
                "can_view_referral_commissions",
                values,
                role,
            )

    def test_non_owner_internal_templates_have_no_self_scoped_entitlements(self):
        for role in ("OMC Admin", "OMC Manager", "OMC Finance Reviewer"):
            values = access.ROLE_CAPABILITIES[role]
            self.assertNotIn("can_own_referrals", values, role)
            self.assertNotIn("can_view_own_commissions", values, role)
