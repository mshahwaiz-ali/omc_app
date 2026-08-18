from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import lead_read_guard, referral_analytics


class TestLeadReferralIntegrity(FrappeTestCase):
    def test_hooks_route_lead_reads(self):
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.mobile.get_leads"],
            "omc_app.api.lead_read_guard.get_leads",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.mobile.get_lead"],
            "omc_app.api.lead_read_guard.get_lead",
        )

    @patch("omc_app.api.lead_read_guard.frappe.db.exists")
    @patch("omc_app.api.lead_read_guard.frappe.get_doc")
    @patch("omc_app.api.lead_read_guard.frappe.get_all")
    @patch("omc_app.api.lead_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.lead_read_guard.mobile._assert_internal_workspace_access")
    def test_list_skips_lead_deleted_after_name_lookup(
        self,
        internal_access,
        require_capability,
        get_all,
        get_doc,
        exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_leads": True}
        get_all.return_value = ["LEAD-STALE", "LEAD-VALID"]
        exists.side_effect = lambda doctype, name: name != "LEAD-STALE"
        get_doc.return_value = SimpleNamespace(name="LEAD-VALID")

        with patch(
            "omc_app.api.lead_read_guard.mobile._lead_to_dict",
            return_value={
                "name": "LEAD-VALID",
                "assigned_to": "",
                "customer_profile": "",
                "converted_customer_profile": "",
            },
        ):
            result = lead_read_guard.get_leads()

        self.assertEqual([row["name"] for row in result["leads"]], ["LEAD-VALID"])
        get_doc.assert_called_once_with("Lead", "LEAD-VALID")

    @patch("omc_app.api.lead_read_guard.frappe.db.exists")
    def test_sanitize_clears_only_stale_lead_references(self, exists):
        exists.side_effect = lambda doctype, name: name not in {
            "deleted@example.com",
            "CUST-DELETED",
        }
        result = lead_read_guard._sanitize_lead_payload(
            {
                "assigned_to": "deleted@example.com",
                "customer_profile": "CUST-VALID",
                "converted_customer_profile": "CUST-DELETED",
            }
        )

        self.assertEqual(result["assigned_to"], "")
        self.assertEqual(result["customer_profile"], "CUST-VALID")
        self.assertEqual(result["converted_customer_profile"], "")

    @patch("omc_app.api.lead_read_guard.frappe.db.exists", return_value=False)
    @patch("omc_app.api.lead_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.lead_read_guard.mobile._assert_internal_workspace_access")
    def test_missing_lead_detail_is_rejected(
        self,
        internal_access,
        require_capability,
        _exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_leads": True}

        with self.assertRaises(frappe.DoesNotExistError):
            lead_read_guard.get_lead(lead_id="LEAD-MISSING")

    @patch("omc_app.api.lead_read_guard.frappe.db.exists", return_value=True)
    @patch("omc_app.api.lead_read_guard.frappe.get_doc")
    @patch("omc_app.api.lead_read_guard.mobile._lead_to_dict")
    @patch("omc_app.api.lead_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.lead_read_guard.mobile._assert_internal_workspace_access")
    def test_valid_lead_detail_preserves_payload_contract(
        self,
        internal_access,
        require_capability,
        lead_to_dict,
        get_doc,
        _exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_leads": True}
        lead = SimpleNamespace(name="LEAD-1")
        get_doc.return_value = lead
        lead_to_dict.return_value = {
            "name": "LEAD-1",
            "assigned_to": "",
            "customer_profile": "",
            "converted_customer_profile": "",
        }

        result = lead_read_guard.get_lead(lead_id="LEAD-1")

        self.assertEqual(result["lead"]["name"], "LEAD-1")
        lead_to_dict.assert_called_once_with(lead)

    @patch("omc_app.api.referral_analytics.frappe.db.get_value", return_value=None)
    def test_referral_customer_lookup_rejects_unowned_profile(self, get_value):
        with self.assertRaises(frappe.PermissionError):
            referral_analytics._owned_customer_profile(
                "owner@example.com",
                "CUST-OTHER",
            )

        get_value.assert_called_once()

    @patch("omc_app.api.referral_analytics.frappe.get_all", return_value=[])
    @patch("omc_app.api.referral_analytics._owned_customer_profile")
    @patch("omc_app.api.referral_analytics._owner_record")
    @patch("omc_app.api.referral_analytics._current_user")
    def test_referral_detail_rejects_mismatched_referral_record(
        self,
        current_user,
        owner_record,
        owned_profile,
        _get_all,
    ):
        current_user.return_value = "owner@example.com"
        owner_record.return_value = SimpleNamespace(name="REF-OWNER")
        owned_profile.return_value = SimpleNamespace(referral_record="REF-OTHER")

        with self.assertRaises(frappe.PermissionError):
            referral_analytics.get_my_referral_detail(customer_profile="CUST-1")

    @patch("omc_app.api.referral_analytics.referral_automation.ensure_referral_code_for_user")
    def test_referral_owner_requires_eligible_record(self, ensure_record):
        ensure_record.return_value = None

        with self.assertRaises(frappe.PermissionError):
            referral_analytics._owner_record("ineligible@example.com")
