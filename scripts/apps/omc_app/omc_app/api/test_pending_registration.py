import json
import uuid
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import pending_registration, signup_policy


class TestPendingRegistration(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created = []
        self.previous_mute_emails = frappe.conf.get("mute_emails")
        frappe.conf.mute_emails = 0

    def tearDown(self):
        for name in reversed(self.created):
            if frappe.db.exists("OMC Pending Registration", name):
                frappe.delete_doc(
                    "OMC Pending Registration",
                    name,
                    force=True,
                    ignore_permissions=True,
                )
        frappe.db.commit()
        frappe.conf.mute_emails = self.previous_mute_emails
        super().tearDown()

    def _payload(self, **overrides):
        suffix = uuid.uuid4().hex[:10]
        payload = {
            "email": f"pending-{suffix}@example.com",
            "full_name": "Pending User",
            "username": f"pending_{suffix}",
            "password": "StrongPass123!",
            "phone": "+923001234567",
            "cnic": "4210112345678",
            "register_as": "Customer",
            "customer_type": "Customer",
        }
        payload.update(overrides)
        return payload

    def test_create_pending_registration_does_not_create_user_or_profile(self):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)

        doc = frappe.get_doc(
            "OMC Pending Registration",
            secret.registration_name,
        )
        stored_payload = json.loads(doc.payload_json)

        self.assertEqual(doc.status, "Pending")
        self.assertEqual(doc.email, payload["email"])
        self.assertEqual(doc.username, payload["username"])
        self.assertNotIn("password", stored_payload)
        self.assertNotEqual(doc.token_digest, secret.verification_token)
        self.assertFalse(frappe.db.exists("User", payload["email"]))
        self.assertFalse(
            frappe.db.exists(
                "OMC Customer Profile",
                {"email": payload["email"]},
            )
        )
        self.assertEqual(
            pending_registration.read_pending_password(doc),
            payload["password"],
        )

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_start_registration_queues_email_without_returning_token(self, sendmail):
        payload = self._payload()
        result = pending_registration.start_registration(**payload)

        names = frappe.get_all(
            "OMC Pending Registration",
            filters={"email": payload["email"]},
            pluck="name",
            order_by="creation desc",
            limit=1,
        )
        self.assertTrue(names)
        self.created.append(names[0])
        self.assertEqual(
            result["message"],
            pending_registration.GENERIC_PUBLIC_MESSAGE,
        )
        self.assertNotIn("verification_token", result)
        self.assertNotIn("registration_id", result)
        self.assertGreater(result["cooldown_seconds"], 0)
        self.assertLessEqual(
            result["cooldown_seconds"],
            pending_registration.RESEND_COOLDOWN_SECONDS,
        )
        sendmail.assert_called_once()
        call = sendmail.call_args.kwargs
        self.assertEqual(call["recipients"], [payload["email"]])
        self.assertIn("Verify your OMC account", call["subject"])
        self.assertNotIn("password", call["message"].lower())

    @patch("omc_app.api.pending_registration.frappe.are_emails_muted", return_value=True)
    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_muted_environment_persists_pending_registration_without_email_queue(
        self,
        sendmail,
        _are_emails_muted,
    ):
        payload = self._payload()
        result = pending_registration.start_registration(**payload)

        name = frappe.db.get_value(
            "OMC Pending Registration",
            {"email": payload["email"]},
            "name",
        )
        self.assertTrue(name)
        self.created.append(name)
        self.assertTrue(result["verification_required"])
        sendmail.assert_not_called()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_legacy_signup_route_requires_email_verification(self, sendmail):
        payload = self._payload()

        result = signup_policy.sign_up(**payload)

        names = frappe.get_all(
            "OMC Pending Registration",
            filters={"email": payload["email"]},
            pluck="name",
            order_by="creation desc",
            limit=1,
        )
        self.assertTrue(names)
        self.created.append(names[0])
        self.assertTrue(result["verification_required"])
        self.assertNotIn("verification_token", result)
        self.assertNotIn("registration_id", result)
        self.assertFalse(frappe.db.exists("User", payload["email"]))
        self.assertFalse(
            frappe.db.exists(
                "OMC Customer Profile",
                {"email": payload["email"]},
            )
        )
        sendmail.assert_called_once()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_resend_rotates_token_after_cooldown(self, sendmail):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)
        doc = frappe.get_doc(
            "OMC Pending Registration",
            secret.registration_name,
        )
        original_digest = doc.token_digest
        doc.resend_after = frappe.utils.add_to_date(
            frappe.utils.now_datetime(),
            seconds=-1,
        )
        doc.save(ignore_permissions=True)

        result = pending_registration.resend_verification(doc.email)
        doc.reload()

        self.assertEqual(
            result["message"],
            pending_registration.GENERIC_PUBLIC_MESSAGE,
        )
        self.assertNotEqual(doc.token_digest, original_digest)
        self.assertEqual(doc.attempt_count, 1)
        self.assertGreater(result["cooldown_seconds"], 0)
        self.assertLessEqual(
            result["cooldown_seconds"],
            pending_registration.RESEND_COOLDOWN_SECONDS,
        )
        sendmail.assert_called_once()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_resend_during_cooldown_does_not_send(self, sendmail):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)
        doc = frappe.get_doc(
            "OMC Pending Registration",
            secret.registration_name,
        )
        original_digest = doc.token_digest

        result = pending_registration.resend_verification(doc.email)
        doc.reload()

        self.assertEqual(
            result["message"],
            pending_registration.GENERIC_PUBLIC_MESSAGE,
        )
        self.assertEqual(doc.token_digest, original_digest)
        self.assertGreater(result["cooldown_seconds"], 0)
        self.assertLessEqual(
            result["cooldown_seconds"],
            pending_registration.RESEND_COOLDOWN_SECONDS,
        )
        sendmail.assert_not_called()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_unknown_resend_is_generic(self, sendmail):
        result = pending_registration.resend_verification(
            "unknown-registration@example.com"
        )
        self.assertEqual(
            result["message"],
            pending_registration.GENERIC_PUBLIC_MESSAGE,
        )
        self.assertEqual(
            result["cooldown_seconds"],
            pending_registration.RESEND_COOLDOWN_SECONDS,
        )
        sendmail.assert_not_called()


    @patch("omc_app.api.pending_registration.frappe.respond_as_web_page")
    @patch("omc_app.api.pending_registration.verify_registration")
    def test_verify_registration_web_renders_success_page(
        self,
        verify_registration,
        respond_as_web_page,
    ):
        verify_registration.return_value = {
            "ok": True,
            "status": "activated",
            "message": "Your email is verified. You can sign in now.",
        }

        pending_registration.verify_registration_web(token="valid-token")

        verify_registration.assert_called_once_with(token="valid-token")
        respond_as_web_page.assert_called_once()
        call = respond_as_web_page.call_args.kwargs
        self.assertEqual(call["http_status_code"], 200)
        self.assertEqual(call["indicator_color"], "green")
        self.assertIn("Your OMC account is activated", call["html"])
        self.assertIn("omchouse://auth/login?verified=1", call["html"])
        self.assertNotEqual(
            frappe.local.response.get("type"),
            "redirect",
        )

    @patch("omc_app.api.pending_registration.frappe.respond_as_web_page")
    @patch("omc_app.api.pending_registration.verify_registration")
    def test_verify_registration_web_renders_invalid_page(
        self,
        verify_registration,
        respond_as_web_page,
    ):
        verify_registration.return_value = {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This verification link is invalid or has expired.",
        }

        pending_registration.verify_registration_web(token="bad-token")

        respond_as_web_page.assert_called_once()
        call = respond_as_web_page.call_args.kwargs
        self.assertEqual(call["http_status_code"], 200)
        self.assertEqual(call["indicator_color"], "orange")
        self.assertIn("Verification link unavailable", call["html"])
        self.assertIn("invalid or has expired", call["html"])

    @patch("omc_app.api.mobile.sign_up")
    def test_verify_registration_activates_once(self, sign_up):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)

        result = pending_registration.verify_registration(
            secret.verification_token
        )

        doc = frappe.get_doc(
            "OMC Pending Registration",
            secret.registration_name,
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["status"], "activated")
        self.assertEqual(doc.status, "Activated")
        self.assertFalse(doc.activated_user)
        self.assertFalse(doc.get_password("password_secret", raise_exception=False))
        self.assertEqual(
            json.loads(doc.payload_json),
            {"email": payload["email"], "username": payload["username"]},
        )
        sign_up.assert_called_once()
        call = sign_up.call_args.kwargs
        self.assertEqual(call["email"], payload["email"])
        self.assertEqual(call["username"], payload["username"])
        self.assertEqual(call["password"], payload["password"])
        self.assertNotEqual(
            doc.token_digest,
            pending_registration._token_digest(secret.verification_token),
        )

    @patch("omc_app.api.mobile.sign_up")
    def test_consumed_token_cannot_activate_again(self, sign_up):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)

        first = pending_registration.verify_registration(
            secret.verification_token
        )
        second = pending_registration.verify_registration(
            secret.verification_token
        )

        self.assertTrue(first["ok"])
        self.assertFalse(second["ok"])
        self.assertEqual(second["status"], "invalid_or_expired")
        sign_up.assert_called_once()

    def test_invalid_verification_token_is_rejected(self):
        result = pending_registration.verify_registration("not-a-valid-token")
        self.assertFalse(result["ok"])
        self.assertEqual(result["status"], "invalid_or_expired")


    def test_token_lookup_accepts_valid_token(self):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)

        doc = pending_registration.load_pending_registration_by_token(
            secret.verification_token
        )

        self.assertIsNotNone(doc)
        self.assertEqual(doc.name, secret.registration_name)

    def test_new_pending_registration_supersedes_previous(self):
        payload = self._payload()
        first = pending_registration.create_pending_registration(payload)
        self.created.append(first.registration_name)

        second = pending_registration.create_pending_registration(payload)
        self.created.append(second.registration_name)

        first_doc = frappe.get_doc(
            "OMC Pending Registration",
            first.registration_name,
        )
        second_doc = frappe.get_doc(
            "OMC Pending Registration",
            second.registration_name,
        )

        self.assertEqual(first_doc.status, "Superseded")
        self.assertFalse(
            first_doc.get_password("password_secret", raise_exception=False)
        )
        self.assertEqual(
            json.loads(first_doc.payload_json),
            {"email": payload["email"], "username": payload["username"]},
        )
        self.assertEqual(second_doc.status, "Pending")
