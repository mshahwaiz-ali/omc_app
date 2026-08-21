import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import admin_control, mobile


class TestCustomerOnboardingPersistence(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_users = []
        self.rate_limit = patch(
            "omc_app.api.security.enforce_rate_limit",
            return_value=None,
        )
        self.rate_limit.start()

    def tearDown(self):
        self.rate_limit.stop()

        for email in reversed(self.created_users):
            for account in frappe.get_all(
                "OMC Customer Account",
                filters={"user": email},
                pluck="name",
            ):
                frappe.delete_doc(
                    "OMC Customer Account",
                    account,
                    force=True,
                    ignore_permissions=True,
                )

            for profile in frappe.get_all(
                "OMC Customer Profile",
                filters={"email": email},
                pluck="name",
            ):
                frappe.delete_doc(
                    "OMC Customer Profile",
                    profile,
                    force=True,
                    ignore_permissions=True,
                )

            if frappe.db.exists("User", email):
                frappe.delete_doc(
                    "User",
                    email,
                    force=True,
                    ignore_permissions=True,
                )

        frappe.db.commit()
        super().tearDown()

    def _payload(self, **overrides):
        suffix = uuid.uuid4().hex[:10]
        email = f"mode-{suffix}@example.com"
        self.created_users.append(email)

        payload = {
            "email": email,
            "username": f"mode_{suffix}",
            "full_name": "Mode Customer",
            "password": "StrongPass123!",
            "phone": "+923001234567",
            "cnic": "4210112345678",
            "register_as": "Customer",
            "customer_type": "Customer",
        }
        payload.update(overrides)
        return payload

    def test_direct_mobile_signup_defaults_and_persists_new_customer(self):
        payload = self._payload()

        result = mobile.sign_up(**payload)

        profile = frappe.get_doc(
            "OMC Customer Profile",
            result["profile"]["customer_id"],
        )

        self.assertEqual(
            profile.get("onboarding_mode"),
            "New Customer",
        )

    def test_direct_mobile_signup_persists_existing_customer_claim(self):
        payload = self._payload(
            onboarding_mode="Existing Customer Claim",
        )

        result = mobile.sign_up(**payload)

        profile = frappe.get_doc(
            "OMC Customer Profile",
            result["profile"]["customer_id"],
        )

        self.assertEqual(
            profile.get("onboarding_mode"),
            "Existing Customer Claim",
        )

    def test_direct_mobile_signup_rejects_imported_existing(self):
        payload = self._payload(
            onboarding_mode="Imported Existing",
        )

        with self.assertRaises(frappe.ValidationError):
            mobile.sign_up(**payload)

    def _review_profile(self, onboarding_mode):
        email = "review-mode@example.com"

        profile = SimpleNamespace(
            name="OMC-CUST-REVIEW-1",
            user=email,
            email=email,
            linked_app_user=email,
            full_name="Review Customer",
            register_as="Customer",
            customer_type="Customer",
            onboarding_mode=onboarding_mode,
            approval_status="Pending Review",
            customer_status="Pending",
            is_active=1,
            modified="2026-08-21 10:00:00",
        )
        profile.get = lambda key: getattr(profile, key, None)
        profile.save = MagicMock()

        account = SimpleNamespace(
            name="OMC-ACCOUNT-1",
            erp_customer="",
            identity_proof_status="Pending",
            account_link_status="Unlinked",
            service_access_status="Pending Review",
            mapping_provenance="",
            mapping_confidence="",
            source_version="",
            approved_by=None,
            approved_at=None,
        )
        account.save = MagicMock()

        return profile, account, email

    def _review_with_mode(self, onboarding_mode, expected_resolution_mode):
        profile, account, email = self._review_profile(
            onboarding_mode
        )

        with (
            patch.object(
                admin_control,
                "_require",
            ),
            patch.object(
                admin_control.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                admin_control.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                admin_control.identity,
                "user_type",
                return_value="Website User",
            ),
            patch.object(
                admin_control.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Resolved",
                    "customer": "ERP-CUST-1",
                    "created": False,
                    "reason": "",
                },
            ) as resolver,
            patch.object(
                admin_control.identity,
                "ensure_customer_account_from_legacy",
                return_value=account,
            ),
            patch.object(
                admin_control.security,
                "audit_event",
            ),
            patch.object(
                admin_control.frappe,
                "clear_cache",
            ),
            patch.object(
                admin_control.frappe.utils,
                "now_datetime",
                return_value="2026-08-21 10:00:00",
            ),
            patch.object(
                admin_control.frappe.db,
                "commit",
            ),
        ):
            result = admin_control.review_registration(
                profile_id=profile.name,
                decision="approve",
            )

        self.assertEqual(result["decision"], "approved")
        resolver.assert_called_once_with(
            profile,
            resolution_mode=expected_resolution_mode,
        )
        account.save.assert_called_once()

    def test_admin_forwards_existing_claim_mode_to_resolver(self):
        self._review_with_mode(
            "Existing Customer Claim",
            "claim_existing",
        )

    def test_admin_forwards_new_customer_mode_to_resolver(self):
        self._review_with_mode(
            "New Customer",
            "new_customer",
        )
