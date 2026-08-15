import uuid

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, mobile, referrals
from omc_app.setup.roles import ADMIN_ROLE, CUSTOMER_ROLE


class TestSignupRoleNormalization(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_users = []
        self.created_referrals = []

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
        for referral_name in reversed(self.created_referrals):
            if frappe.db.exists("OMC Referral", referral_name):
                frappe.delete_doc(
                    "OMC Referral",
                    referral_name,
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

    def _referral_record(self):
        staff_email = self._email("referral-owner")
        user = frappe.new_doc("User")
        user.email = staff_email
        user.first_name = "Referral Owner"
        user.enabled = 1
        user.user_type = "System User"
        user.send_welcome_email = 0
        user.append("roles", {"role": "OMC Consultant"})
        user.insert(ignore_permissions=True)

        doc = referrals.get_or_create_owner_record(staff_email)
        self.created_referrals.append(doc.name)
        return doc

    def test_canonical_signup_creates_pending_website_customer(self):
        email = self._email("canonical-signup")

        result = mobile._activate_verified_registration(**self._signup_payload(email))

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

        result = mobile._activate_verified_registration(**self._signup_payload(email, register_as="Customer", customer_type="Customer"))

        user = frappe.get_doc("User", email)
        roles = {row.role for row in user.roles}
        profile = frappe.get_doc(
            "OMC Customer Profile",
            result["profile"]["customer_id"],
        )

        self.assertEqual(user.user_type, "Website User")
        self.assertIn(CUSTOMER_ROLE, roles)
        self.assertNotIn("OMC Customer Applicant", roles)
        self.assertEqual(profile.customer_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(result["access_state"], "approved")

    def test_existing_internal_user_cannot_be_targeted_by_guest_signup(self):
        email = self._email("internal-signup")
        user = frappe.new_doc("User")
        user.email = email
        user.first_name = "Internal"
        user.enabled = 1
        user.user_type = "System User"
        user.send_welcome_email = 0
        user.append("roles", {"role": ADMIN_ROLE})
        user.insert(ignore_permissions=True)

        with self.assertRaises(frappe.DuplicateEntryError):
            mobile._activate_verified_registration(**self._signup_payload(email))

        user.reload()
        roles = {row.role for row in user.roles}
        self.assertEqual(user.user_type, "System User")
        self.assertIn(ADMIN_ROLE, roles)
        self.assertNotIn(CUSTOMER_ROLE, roles)
        self.assertFalse(
            frappe.db.exists("OMC Customer Profile", {"email": email})
        )

    def test_duplicate_guest_signup_cannot_modify_existing_profile(self):
        email = self._email("duplicate-signup")
        first = mobile._activate_verified_registration(
            **self._signup_payload(
                email,
                register_as="Customer",
                customer_type="Customer",
            )
        )
        profile = frappe.get_doc(
            "OMC Customer Profile",
            first["profile"]["customer_id"],
        )
        profile.customer_status = "Active"
        profile.approval_status = "Approved"
        original_company = profile.company_name
        profile.save(ignore_permissions=True)

        with self.assertRaises(frappe.DuplicateEntryError):
            mobile._activate_verified_registration(
                **self._signup_payload(email, company="Attacker Company")
            )

        profile.reload()
        self.assertEqual(profile.customer_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(profile.company_name, original_company)

    def test_password_is_required_for_guest_signup(self):
        email = self._email("passwordless-signup")

        with self.assertRaises(frappe.ValidationError):
            mobile._activate_verified_registration(**self._signup_payload(email, password=""))

        self.assertFalse(frappe.db.exists("User", email))
        self.assertFalse(
            frappe.db.exists("OMC Customer Profile", {"email": email})
        )

    def test_short_password_is_rejected_for_guest_signup(self):
        email = self._email("short-password-signup")

        with self.assertRaises(frappe.ValidationError):
            mobile._activate_verified_registration(**self._signup_payload(email, password="short"))

        self.assertFalse(frappe.db.exists("User", email))

    def test_referral_signup_links_customer_before_insert(self):
        referral = self._referral_record()
        email = self._email("referral-signup")

        result = mobile._activate_verified_registration(
            **self._signup_payload(
                email,
                acquisition_source="Referral",
                referral_code=referral.referral_code.lower(),
                referral_assistance_consent=True,
            )
        )

        profile = frappe.get_doc(
            "OMC Customer Profile",
            result["profile"]["customer_id"],
        )
        self.assertEqual(profile.acquisition_source, "Referral")
        self.assertEqual(profile.referral_record, referral.name)
        self.assertEqual(profile.referred_by, referral.referrer_user)
        self.assertEqual(profile.referral_code_used, referral.referral_code)
        self.assertEqual(profile.referral_assistance_consent, 1)
        self.assertEqual(profile.customer_origin, "App Signup")
        self.assertEqual(profile.linked_app_user, email)
        self.assertEqual(
            result["profile"]["referral_code_used"],
            referral.referral_code,
        )

    def test_invalid_referral_does_not_create_partial_account(self):
        email = self._email("invalid-referral")

        with self.assertRaises(frappe.ValidationError):
            mobile._activate_verified_registration(
                **self._signup_payload(
                    email,
                    acquisition_source="Referral",
                    referral_code="OMC-ABC234",
                    referral_assistance_consent=True,
                )
            )

        self.assertFalse(frappe.db.exists("User", email))
        self.assertFalse(
            frappe.db.exists("OMC Customer Profile", {"email": email})
        )

    def test_referral_signup_requires_consent(self):
        referral = self._referral_record()
        email = self._email("referral-no-consent")

        with self.assertRaises(frappe.ValidationError):
            mobile._activate_verified_registration(
                **self._signup_payload(
                    email,
                    acquisition_source="Referral",
                    referral_code=referral.referral_code,
                    referral_assistance_consent=False,
                )
            )

        self.assertFalse(frappe.db.exists("User", email))

    def test_non_referral_signup_preserves_source_detail(self):
        email = self._email("other-source")

        result = mobile._activate_verified_registration(
            **self._signup_payload(
                email,
                acquisition_source="Other",
                acquisition_source_detail="Professional seminar",
            )
        )

        profile = frappe.get_doc(
            "OMC Customer Profile",
            result["profile"]["customer_id"],
        )
        self.assertEqual(profile.acquisition_source, "Other")
        self.assertEqual(
            profile.acquisition_source_detail,
            "Professional seminar",
        )
        self.assertFalse(profile.referral_record)
