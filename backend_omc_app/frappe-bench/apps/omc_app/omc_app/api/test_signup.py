import uuid

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, mobile
from omc_app.setup.roles import ADMIN_ROLE, CUSTOMER_ROLE


class TestSignupRoleNormalization(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_users = []

    def tearDown(self):
        for email in reversed(self.created_users):
            for profile_name in frappe.get_all(
                "OMC Customer Profile",
                filters={"email": email},
                pluck="name",
            ):
                frappe.delete_doc(
                    "OMC Customer Profile",
                    profile_name,
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

    def _email(self, prefix):
        email = f"{prefix}-{uuid.uuid4().hex[:10]}@example.com"
        self.created_users.append(email)
        return email

    def _signup_payload(self, email, **overrides):
        payload = {
            "email": email,
            "full_name": "Ayesha Khan",
            "password": "StrongPass123!",
            "phone": "+923063191907",
            "whatsapp_no": "+923063191908",
            "company": "Example & Co",
            "cnic": "4210112345678",
            "ntn": "1234567-8",
            "register_as": "Tax Associate",
            "customer_type": "Tax Associate",
            "address": "Karachi, Pakistan",
            "education": "B.Com",
            "experience": "Three years",
            "remarks": "Available for review",
        }
        payload.update(overrides)
        return payload

    def test_canonical_signup_creates_pending_website_customer(self):
        email = self._email("canonical-signup")

        result = access.sign_up(**self._signup_payload(email))

        user = frappe.get_doc("User", email)
        roles = {row.role for row in user.roles}
        profile = frappe.get_doc("OMC Customer Profile", result["profile"]["customer_id"])

        self.assertEqual(user.user_type, "Website User")
        self.assertIn(CUSTOMER_ROLE, roles)
        self.assertNotIn("OMC Customer Applicant", roles)
        self.assertEqual(profile.customer_status, "Pending")
        self.assertEqual(profile.approval_status, "Pending Review")
        self.assertEqual(profile.get("register_as"), "Tax Associate")
        self.assertEqual(profile.get("customer_type"), "Tax Associate")
        self.assertEqual(profile.company_name, "Example & Co")
        self.assertEqual(profile.cnic, "4210112345678")
        self.assertEqual(profile.ntn, "1234567-8")
        self.assertEqual(profile.get("education"), "B.Com")
        self.assertEqual(profile.get("experience"), "Three years")
        self.assertEqual(profile.get("remarks"), "Available for review")
        self.assertEqual(result["access_state"], "pending")

    def test_direct_mobile_signup_uses_same_canonical_customer_role(self):
        email = self._email("direct-signup")

        result = mobile.sign_up(**self._signup_payload(email, register_as="Customer", customer_type="Customer"))

        user = frappe.get_doc("User", email)
        roles = {row.role for row in user.roles}
        self.assertEqual(user.user_type, "Website User")
        self.assertIn(CUSTOMER_ROLE, roles)
        self.assertNotIn("OMC Customer Applicant", roles)
        self.assertEqual(result["access_state"], "pending")

    def test_existing_internal_user_is_not_downgraded(self):
        email = self._email("internal-signup")
        user = frappe.new_doc("User")
        user.email = email
        user.first_name = "Internal"
        user.enabled = 1
        user.user_type = "System User"
        user.send_welcome_email = 0
        user.append("roles", {"role": ADMIN_ROLE})
        user.insert(ignore_permissions=True)

        mobile.sign_up(**self._signup_payload(email))

        user.reload()
        roles = {row.role for row in user.roles}
        self.assertEqual(user.user_type, "System User")
        self.assertIn(ADMIN_ROLE, roles)
        self.assertNotIn(CUSTOMER_ROLE, roles)
        self.assertNotIn("OMC Customer Applicant", roles)

    def test_duplicate_signup_is_idempotent_and_preserves_approved_profile(self):
        email = self._email("duplicate-signup")
        first = access.sign_up(**self._signup_payload(email, register_as="Customer", customer_type="Customer"))
        profile = frappe.get_doc("OMC Customer Profile", first["profile"]["customer_id"])
        profile.customer_status = "Active"
        profile.approval_status = "Approved"
        profile.save(ignore_permissions=True)

        second = access.sign_up(**self._signup_payload(email, company="Updated Company"))

        user = frappe.get_doc("User", email)
        profile.reload()
        roles = [row.role for row in user.roles]
        self.assertFalse(second["created"])
        self.assertEqual(roles.count(CUSTOMER_ROLE), 1)
        self.assertEqual(profile.customer_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(profile.company_name, "Updated Company")
        self.assertEqual(second["access_state"], "approved")
