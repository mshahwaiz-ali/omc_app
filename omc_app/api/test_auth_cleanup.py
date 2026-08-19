import json
import uuid

import frappe
from frappe.tests.utils import FrappeTestCase
from frappe.utils import add_to_date, now_datetime

from omc_app.api import auth_cleanup, pending_registration


class TestAuthCleanup(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created = []

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
        super().tearDown()

    def _create(self):
        suffix = uuid.uuid4().hex[:10]
        secret = pending_registration.create_pending_registration(
            {
                "email": f"cleanup-{suffix}@example.com",
                "full_name": "Cleanup User",
                "username": f"cleanup_{suffix}",
                "password": "StrongPass123!",
                "phone": "+923001234567",
                "cnic": "4210112345678",
                "register_as": "Customer",
                "customer_type": "Customer",
            }
        )
        self.created.append(secret.registration_name)
        return frappe.get_doc("OMC Pending Registration", secret.registration_name)

    def test_cleanup_expires_overdue_pending_and_clears_secret(self):
        doc = self._create()
        doc.expires_at = add_to_date(now_datetime(), seconds=-1)
        doc.save(ignore_permissions=True)

        result = auth_cleanup.cleanup_pending_registrations()
        doc.reload()

        self.assertEqual(result["expired"], 1)
        self.assertEqual(doc.status, "Expired")
        self.assertFalse(doc.get_password("password_secret", raise_exception=False))
        self.assertEqual(
            json.loads(doc.payload_json),
            {"email": doc.email, "username": doc.username},
        )

    def test_recent_verified_registration_keeps_no_recovery_secret(self):
        doc = self._create()
        doc.status = "Verified"
        doc.verified_at = now_datetime()
        doc.save(ignore_permissions=True)

        auth_cleanup.cleanup_pending_registrations()
        doc.reload()

        self.assertEqual(doc.status, "Verified")
        self.assertFalse(doc.get_password("password_secret", raise_exception=False))
        with self.assertRaises(frappe.ValidationError):
            pending_registration.read_pending_password(doc)

    def test_cleanup_is_idempotent_for_terminal_record(self):
        doc = self._create()
        pending_registration.sanitize_registration(doc, status="Expired")
        doc.save(ignore_permissions=True)

        first = auth_cleanup.cleanup_pending_registrations()
        second = auth_cleanup.cleanup_pending_registrations()
        doc.reload()

        self.assertEqual(first["sanitized"], 0)
        self.assertEqual(second["sanitized"], 0)
        self.assertFalse(doc.get_password("password_secret", raise_exception=False))
