import uuid
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase
from frappe.utils import add_to_date, now_datetime
from frappe.utils.password import check_password

from omc_app.api import access, customer_activation


class TestCustomerActivation(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_emails = []

    def tearDown(self):
        frappe.set_user("Administrator")

        for email in reversed(self.created_emails):
            for name in frappe.get_all(
                customer_activation.DOCTYPE,
                filters={"email": email},
                pluck="name",
            ):
                if frappe.db.exists(customer_activation.DOCTYPE, name):
                    frappe.delete_doc(
                        customer_activation.DOCTYPE,
                        name,
                        force=True,
                        ignore_permissions=True,
                    )

            for name in frappe.get_all(
                "OMC Customer Profile",
                filters={"email": email},
                pluck="name",
            ):
                if frappe.db.exists("OMC Customer Profile", name):
                    frappe.delete_doc(
                        "OMC Customer Profile",
                        name,
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
        email = f"{prefix}-{uuid.uuid4().hex[:10]}@qa.omc.test"
        self.created_emails.append(email)
        return email

    def _profile(self, email=None):
        email = email or self._email("activation")

        profile = frappe.get_doc(
            {
                "doctype": "OMC Customer Profile",
                "full_name": "Imported Customer",
                "email": email,
                "customer_status": "Active",
                "approval_status": "Approved",
                "is_active": 1,
                "customer_origin": "Imported",
                "manual_customer_status": "Unregistered",
                "register_as": "Customer",
                "customer_type": "Customer",
            }
        ).insert(ignore_permissions=True)

        return profile

    def _request_token(self, profile):
        with patch.object(
            customer_activation,
            "_send_activation_email",
        ) as sendmail:
            result = customer_activation.request_activation(
                profile.email
            )

        self.assertEqual(sendmail.call_count, 1)
        token = sendmail.call_args.args[2]
        return token, result

    def test_public_response_does_not_enumerate_customer_accounts(self):
        unknown_email = self._email("unknown")
        profile = self._profile()

        with patch.object(
            customer_activation,
            "_send_activation_email",
        ):
            unknown = customer_activation.request_activation(
                unknown_email
            )
            eligible = customer_activation.request_activation(
                profile.email
            )

        self.assertEqual(unknown, eligible)
        self.assertEqual(
            unknown["message"],
            customer_activation.GENERIC_MESSAGE,
        )
        self.assertEqual(
            unknown["cooldown_seconds"],
            customer_activation.REQUEST_COOLDOWN_SECONDS,
        )
        self.assertNotIn("customer_profile", unknown)
        self.assertNotIn("eligible", unknown)

    def test_token_is_stored_as_digest_only(self):
        profile = self._profile()
        token, _ = self._request_token(profile)

        name = frappe.db.get_value(
            customer_activation.DOCTYPE,
            {"customer_profile": profile.name},
            "name",
        )
        doc = frappe.get_doc(
            customer_activation.DOCTYPE,
            name,
        )

        self.assertNotEqual(doc.token_digest, token)
        self.assertEqual(
            doc.token_digest,
            customer_activation._digest(token),
        )
        self.assertEqual(doc.status, "Pending")

    def test_immediate_repeat_is_cooled_down_without_new_token(self):
        profile = self._profile()

        with patch.object(
            customer_activation,
            "_send_activation_email",
        ) as sendmail:
            first = customer_activation.request_activation(
                profile.email
            )
            second = customer_activation.request_activation(
                profile.email
            )

        self.assertEqual(first, second)
        self.assertEqual(sendmail.call_count, 1)
        self.assertEqual(
            frappe.db.count(
                customer_activation.DOCTYPE,
                {"customer_profile": profile.name},
            ),
            1,
        )

    def test_new_request_supersedes_old_token_after_cooldown(self):
        profile = self._profile()
        first_token, _ = self._request_token(profile)

        first_name = frappe.db.get_value(
            customer_activation.DOCTYPE,
            {"customer_profile": profile.name},
            "name",
        )

        frappe.db.set_value(
            customer_activation.DOCTYPE,
            first_name,
            "requested_at",
            add_to_date(
                now_datetime(),
                seconds=-(customer_activation.REQUEST_COOLDOWN_SECONDS + 1),
            ),
        )
        frappe.db.commit()

        second_token, _ = self._request_token(profile)

        first_doc = frappe.get_doc(
            customer_activation.DOCTYPE,
            first_name,
        )

        self.assertNotEqual(first_token, second_token)
        self.assertEqual(first_doc.status, "Superseded")
        self.assertNotEqual(
            first_doc.token_digest,
            customer_activation._digest(first_token),
        )

        result = customer_activation.complete_activation(
            token=first_token,
            password="SecurePass123!",
            confirm_password="SecurePass123!",
        )
        self.assertFalse(result["ok"])
        self.assertEqual(
            result["status"],
            "invalid_or_expired",
        )

    def test_expired_token_cannot_activate(self):
        profile = self._profile()
        token, _ = self._request_token(profile)

        name = frappe.db.get_value(
            customer_activation.DOCTYPE,
            {"customer_profile": profile.name},
            "name",
        )

        frappe.db.set_value(
            customer_activation.DOCTYPE,
            name,
            "expires_at",
            add_to_date(now_datetime(), minutes=-1),
        )
        frappe.db.commit()

        result = customer_activation.complete_activation(
            token=token,
            password="SecurePass123!",
            confirm_password="SecurePass123!",
        )

        self.assertFalse(result["ok"])
        self.assertEqual(
            result["status"],
            "invalid_or_expired",
        )

        doc = frappe.get_doc(
            customer_activation.DOCTYPE,
            name,
        )
        self.assertEqual(doc.status, "Expired")

        self.assertFalse(
            frappe.db.exists("User", profile.email)
        )

    def test_existing_user_at_request_is_not_auto_merged(self):
        profile = self._profile()

        user = frappe.get_doc(
            {
                "doctype": "User",
                "email": profile.email,
                "first_name": "Existing Internal User",
                "enabled": 1,
                "user_type": "System User",
                "send_welcome_email": 0,
            }
        )
        user.insert(ignore_permissions=True)

        with patch.object(
            customer_activation,
            "_send_activation_email",
        ) as sendmail:
            result = customer_activation.request_activation(
                profile.email
            )

        self.assertEqual(
            result["message"],
            customer_activation.GENERIC_MESSAGE,
        )
        self.assertEqual(sendmail.call_count, 0)
        self.assertEqual(
            frappe.db.count(
                customer_activation.DOCTYPE,
                {"customer_profile": profile.name},
            ),
            0,
        )

        profile.reload()
        self.assertFalse(profile.user)
        self.assertFalse(profile.linked_app_user)
        self.assertEqual(
            profile.manual_customer_status,
            "Unregistered",
        )

    def test_identity_collision_during_activation_requires_review(self):
        profile = self._profile()
        token, _ = self._request_token(profile)

        user = frappe.get_doc(
            {
                "doctype": "User",
                "email": profile.email,
                "first_name": "Late Existing User",
                "enabled": 1,
                "user_type": "Website User",
                "send_welcome_email": 0,
            }
        )
        user.insert(ignore_permissions=True)

        result = customer_activation.complete_activation(
            token=token,
            password="SecurePass123!",
            confirm_password="SecurePass123!",
        )

        self.assertFalse(result["ok"])
        self.assertEqual(
            result["status"],
            "review_required",
        )

        activation = frappe.get_doc(
            customer_activation.DOCTYPE,
            frappe.db.get_value(
                customer_activation.DOCTYPE,
                {"customer_profile": profile.name},
                "name",
            ),
        )
        self.assertEqual(
            activation.status,
            "Review Required",
        )
        self.assertEqual(
            activation.review_reason,
            "existing_user_identity",
        )

        profile.reload()
        self.assertFalse(profile.user)
        self.assertFalse(profile.linked_app_user)
        self.assertEqual(
            profile.manual_customer_status,
            "Duplicate Review",
        )

    def test_success_creates_lazy_user_and_links_existing_profile_once(self):
        profile = self._profile()
        original_name = profile.name
        token, _ = self._request_token(profile)

        result = customer_activation.complete_activation(
            token=token,
            password="SecurePass123!",
            confirm_password="SecurePass123!",
        )

        self.assertTrue(result["ok"])
        self.assertEqual(result["status"], "activated")
        self.assertEqual(
            result["customer_profile"],
            original_name,
        )
        self.assertEqual(result["user"], profile.email)

        user = frappe.get_doc("User", profile.email)
        roles = {row.role for row in user.roles}

        self.assertEqual(user.user_type, "Website User")
        self.assertEqual(user.enabled, 1)
        self.assertIn(access.CUSTOMER_ROLE, roles)
        self.assertTrue(
            check_password(
                profile.email,
                "SecurePass123!",
            )
        )

        profile.reload()

        self.assertEqual(profile.name, original_name)
        self.assertEqual(profile.user, profile.email)
        self.assertEqual(
            profile.linked_app_user,
            profile.email,
        )
        self.assertEqual(
            profile.manual_customer_status,
            "Linked",
        )

        # Business lifecycle must remain untouched by app activation.
        self.assertEqual(profile.customer_origin, "Imported")
        self.assertEqual(profile.customer_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(profile.is_active, 1)

        self.assertEqual(
            frappe.db.count(
                "OMC Customer Profile",
                {"email": profile.email},
            ),
            1,
        )

        activation = frappe.get_doc(
            customer_activation.DOCTYPE,
            frappe.db.get_value(
                customer_activation.DOCTYPE,
                {"customer_profile": profile.name},
                "name",
            ),
        )
        self.assertEqual(activation.status, "Used")
        self.assertEqual(
            activation.activated_user,
            profile.email,
        )
        self.assertTrue(activation.used_at)
        self.assertNotEqual(
            activation.token_digest,
            customer_activation._digest(token),
        )

        second = customer_activation.complete_activation(
            token=token,
            password="AnotherPass123!",
            confirm_password="AnotherPass123!",
        )

        self.assertFalse(second["ok"])
        self.assertEqual(
            second["status"],
            "invalid_or_expired",
        )
        self.assertTrue(
            check_password(
                profile.email,
                "SecurePass123!",
            )
        )
