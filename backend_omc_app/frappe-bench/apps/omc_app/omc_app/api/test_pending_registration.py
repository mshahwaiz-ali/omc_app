import json
import uuid
from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import pending_registration, signup_policy


class TestPendingRegistration(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.rate_limit = patch("omc_app.api.security.enforce_rate_limit", return_value=None)
        self.rate_limit.start()
        self.created = []
        self.previous_mute_emails = frappe.conf.get("mute_emails")
        frappe.conf.mute_emails = 0

    def tearDown(self):
        self.rate_limit.stop()
        for name in reversed(self.created):
            if frappe.db.exists("OMC Pending Registration", name):
                frappe.delete_doc("OMC Pending Registration", name, force=True, ignore_permissions=True)
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

    def _mock_account(self):
        return SimpleNamespace(
            name="OMC-ACCOUNT-TEST",
            mapping_provenance="",
            save=lambda **_kwargs: None,
        )

    def test_create_pending_registration_stores_no_password_or_account(self):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)
        doc = frappe.get_doc("OMC Pending Registration", secret.registration_name)
        stored_payload = json.loads(doc.payload_json)

        self.assertEqual(doc.status, "Pending")
        self.assertEqual(doc.email, payload["email"])
        self.assertEqual(doc.username, payload["username"])
        self.assertNotIn("password", stored_payload)
        self.assertFalse(doc.meta.has_field("password_secret"))
        self.assertNotEqual(doc.token_digest, secret.verification_token)
        self.assertFalse(frappe.db.exists("User", payload["email"]))
        self.assertFalse(frappe.db.exists("OMC Customer Profile", {"email": payload["email"]}))

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_start_registration_sends_token_but_never_returns_it(self, sendmail):
        payload = self._payload()
        result = pending_registration.start_registration(**payload)
        name = frappe.db.get_value("OMC Pending Registration", {"email": payload["email"]}, "name")
        self.assertTrue(name)
        self.created.append(name)
        self.assertEqual(result["message"], pending_registration.GENERIC_PUBLIC_MESSAGE)
        self.assertTrue(result["password_required_after_verification"])
        self.assertNotIn("verification_token", result)
        self.assertNotIn("registration_id", result)
        sendmail.assert_called_once()

    @patch("omc_app.api.pending_registration.frappe.are_emails_muted", return_value=True)
    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_muted_environment_persists_pending_without_email(self, sendmail, _muted):
        payload = self._payload()
        result = pending_registration.start_registration(**payload)
        name = frappe.db.get_value("OMC Pending Registration", {"email": payload["email"]}, "name")
        self.assertTrue(name)
        self.created.append(name)
        self.assertTrue(result["verification_required"])
        sendmail.assert_not_called()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_legacy_signup_route_requires_email_verification(self, sendmail):
        payload = self._payload()
        result = signup_policy.sign_up(**payload)
        name = frappe.db.get_value("OMC Pending Registration", {"email": payload["email"]}, "name")
        self.assertTrue(name)
        self.created.append(name)
        self.assertTrue(result["verification_required"])
        self.assertFalse(frappe.db.exists("User", payload["email"]))
        sendmail.assert_called_once()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_resend_rotates_token_after_cooldown(self, sendmail):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)
        doc = frappe.get_doc("OMC Pending Registration", secret.registration_name)
        original_digest = doc.token_digest
        doc.resend_after = frappe.utils.add_to_date(frappe.utils.now_datetime(), seconds=-1)
        doc.save(ignore_permissions=True)

        result = pending_registration.resend_verification(doc.email)
        doc.reload()
        self.assertNotEqual(doc.token_digest, original_digest)
        self.assertEqual(doc.attempt_count, 1)
        self.assertGreater(result["cooldown_seconds"], 0)
        sendmail.assert_called_once()

    @patch("omc_app.api.pending_registration.frappe.sendmail")
    def test_unknown_resend_is_generic(self, sendmail):
        result = pending_registration.resend_verification("unknown-registration@example.com")
        self.assertEqual(result["message"], pending_registration.GENERIC_PUBLIC_MESSAGE)
        sendmail.assert_not_called()

    def test_get_token_inspection_is_read_only(self):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)
        before = frappe.db.get_value(
            "OMC Pending Registration",
            secret.registration_name,
            ["status", "verified_at", "token_digest"],
            as_dict=True,
        )
        result = pending_registration.inspect_verification_token(secret.verification_token)
        after = frappe.db.get_value(
            "OMC Pending Registration",
            secret.registration_name,
            ["status", "verified_at", "token_digest"],
            as_dict=True,
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["status"], "awaiting_password")
        self.assertEqual(before, after)
        self.assertFalse(frappe.db.exists("User", result["email"]))

    @patch("omc_app.api.pending_registration.frappe.respond_as_web_page")
    @patch("omc_app.api.pending_registration.inspect_verification_token")
    def test_verify_registration_web_only_renders_completion_page(self, inspect_token, respond):
        inspect_token.return_value = {"ok": True, "status": "awaiting_password"}
        pending_registration.verify_registration_web(token="valid-token")
        inspect_token.assert_called_once_with("valid-token")
        call = respond.call_args.kwargs
        self.assertEqual(call["http_status_code"], 200)
        self.assertEqual(call["indicator_color"], "green")
        self.assertIn("Email verified", call["html"])
        self.assertIn("omchouse://auth/verify-email?token=valid-token", call["html"])

    @patch("omc_app.api.mobile.sign_up")
    def test_post_completion_requires_password_and_activates_once(self, sign_up):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)

        with patch.object(
            pending_registration.identity,
            "ensure_customer_account_from_legacy",
            return_value=self._mock_account(),
        ):
            result = pending_registration.complete_registration(
                secret.verification_token,
                password=payload["password"],
            )

        doc = frappe.get_doc("OMC Pending Registration", secret.registration_name)
        self.assertTrue(result["ok"])
        self.assertEqual(doc.status, "Activated")
        self.assertEqual(
            json.loads(doc.payload_json),
            {"email": payload["email"], "username": payload["username"]},
        )
        call = sign_up.call_args.kwargs
        self.assertEqual(call["password"], payload["password"])
        self.assertNotEqual(doc.token_digest, pending_registration._token_digest(secret.verification_token))

    @patch("omc_app.api.mobile.sign_up")
    def test_consumed_token_cannot_activate_again(self, sign_up):
        payload = self._payload()
        secret = pending_registration.create_pending_registration(payload)
        self.created.append(secret.registration_name)
        with patch.object(
            pending_registration.identity,
            "ensure_customer_account_from_legacy",
            return_value=self._mock_account(),
        ):
            first = pending_registration.verify_registration(
                secret.verification_token,
                password=payload["password"],
            )
            second = pending_registration.verify_registration(
                secret.verification_token,
                password=payload["password"],
            )
        self.assertTrue(first["ok"])
        self.assertFalse(second["ok"])
        self.assertEqual(second["status"], "invalid_or_expired")
        sign_up.assert_called_once()

    def test_completion_rejects_missing_password_without_consuming_token(self):
        secret = pending_registration.create_pending_registration(self._payload())
        self.created.append(secret.registration_name)
        with self.assertRaises(frappe.ValidationError):
            pending_registration.complete_registration(secret.verification_token, password="")
        self.assertIsNotNone(
            pending_registration.load_pending_registration_by_token(secret.verification_token)
        )

    def test_invalid_verification_token_is_rejected(self):
        result = pending_registration.complete_registration("not-a-valid-token", password="StrongPass123!")
        self.assertFalse(result["ok"])
        self.assertEqual(result["status"], "invalid_or_expired")

    def test_new_pending_registration_supersedes_previous(self):
        payload = self._payload()
        first = pending_registration.create_pending_registration(payload)
        self.created.append(first.registration_name)
        second = pending_registration.create_pending_registration(payload)
        self.created.append(second.registration_name)
        first_doc = frappe.get_doc("OMC Pending Registration", first.registration_name)
        second_doc = frappe.get_doc("OMC Pending Registration", second.registration_name)
        self.assertEqual(first_doc.status, "Superseded")
        self.assertEqual(
            json.loads(first_doc.payload_json),
            {"email": payload["email"], "username": payload["username"]},
        )
        self.assertEqual(second_doc.status, "Pending")
