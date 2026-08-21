import json
import uuid

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, admin_control, pending_registration


class TestCustomerOnboardingMode(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_pending = []

    def tearDown(self):
        for name in reversed(self.created_pending):
            if frappe.db.exists("OMC Pending Registration", name):
                frappe.delete_doc(
                    "OMC Pending Registration",
                    name,
                    force=True,
                    ignore_permissions=True,
                )
        frappe.db.commit()
        super().tearDown()

    def _payload(self, **overrides):
        suffix = uuid.uuid4().hex[:10]
        payload = {
            "email": f"onboarding-{suffix}@example.com",
            "full_name": "Onboarding Customer",
            "username": f"onboard_{suffix}",
            "phone": "+923001234567",
            "cnic": "4210112345678",
            "register_as": "Customer",
            "customer_type": "Customer",
        }
        payload.update(overrides)
        return payload

    def test_public_signup_defaults_to_new_customer(self):
        validated = access._validated_signup_kwargs(
            self._payload()
        )

        self.assertEqual(
            validated["onboarding_mode"],
            "New Customer",
        )

    def test_public_signup_accepts_existing_customer_claim(self):
        validated = access._validated_signup_kwargs(
            self._payload(
                onboarding_mode="Existing Customer Claim",
            )
        )

        self.assertEqual(
            validated["onboarding_mode"],
            "Existing Customer Claim",
        )

    def test_public_signup_cannot_select_imported_existing(self):
        with self.assertRaises(frappe.ValidationError):
            access._validated_signup_kwargs(
                self._payload(
                    onboarding_mode="Imported Existing",
                )
            )

    def test_public_signup_rejects_unknown_onboarding_mode(self):
        with self.assertRaises(frappe.ValidationError):
            access._validated_signup_kwargs(
                self._payload(
                    onboarding_mode="Something Else",
                )
            )

    def test_pending_registration_preserves_onboarding_mode(self):
        payload = self._payload(
            onboarding_mode="Existing Customer Claim",
        )

        secret = pending_registration.create_pending_registration(
            payload
        )
        self.created_pending.append(secret.registration_name)

        doc = frappe.get_doc(
            "OMC Pending Registration",
            secret.registration_name,
        )
        stored = json.loads(doc.payload_json)

        self.assertEqual(
            stored["onboarding_mode"],
            "Existing Customer Claim",
        )

    def test_admin_resolution_mode_mapping_is_fail_closed(self):
        self.assertEqual(
            admin_control._resolution_mode_for_profile(
                {"onboarding_mode": "Existing Customer Claim"}
            ),
            "claim_existing",
        )
        self.assertEqual(
            admin_control._resolution_mode_for_profile(
                {"onboarding_mode": "New Customer"}
            ),
            "new_customer",
        )
        self.assertEqual(
            admin_control._resolution_mode_for_profile(
                {"onboarding_mode": "Imported Existing"}
            ),
            "claim_existing",
        )

        # Pre-field / older pending signups fail closed as new-customer
        # processing: an existing ERP identity collision is detected and
        # cannot be silently claimed or duplicated.
        self.assertEqual(
            admin_control._resolution_mode_for_profile(
                {"onboarding_mode": ""}
            ),
            "new_customer",
        )
