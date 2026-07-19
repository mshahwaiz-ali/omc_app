import uuid

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import guest_session


class TestGuestSessionBoundaries(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created_sessions = []
        frappe.set_user("Guest")

    def tearDown(self):
        frappe.set_user("Administrator")
        for name in reversed(self.created_sessions):
            if frappe.db.exists("OMC Guest Session", name):
                frappe.delete_doc(
                    "OMC Guest Session",
                    name,
                    force=True,
                    ignore_permissions=True,
                )
        frappe.db.commit()
        super().tearDown()

    def _device_id(self, prefix="device"):
        return f"{prefix}-{uuid.uuid4().hex}"

    def _create(self, device_id=None):
        result = guest_session.create_guest_session(
            device_id=device_id or self._device_id(),
            platform="android",
            app_version="test",
        )
        name = result["guest_session"]["session_id"]
        self.created_sessions.append(name)
        return result

    def test_public_response_does_not_expose_converted_identity(self):
        result = self._create()
        payload = result["guest_session"]

        self.assertNotIn("converted_user", payload)
        self.assertNotIn("converted_customer_profile", payload)

    def test_session_id_requires_matching_device_id(self):
        created = self._create()
        session_id = created["guest_session"]["session_id"]

        with self.assertRaises(frappe.PermissionError):
            guest_session.update_guest_activity(
                session_id=session_id,
                device_id=self._device_id("attacker"),
                interested_services=["tax"],
            )

    def test_guest_cannot_mark_session_as_converted(self):
        created = self._create()
        session_id = created["guest_session"]["session_id"]
        device_id = created["guest_session"]["device_id"]

        guest_session.update_guest_activity(
            session_id=session_id,
            device_id=device_id,
            converted_user="victim@example.com",
            converted_customer_profile="OMC-CUST-VICTIM",
        )

        doc = frappe.get_doc("OMC Guest Session", session_id)
        self.assertFalse(int(doc.is_converted or 0))
        self.assertFalse(doc.converted_user)
        self.assertFalse(doc.converted_customer_profile)

    def test_authenticated_conversion_uses_server_session_identity(self):
        created = self._create()
        session_id = created["guest_session"]["session_id"]
        device_id = created["guest_session"]["device_id"]

        frappe.set_user("Administrator")
        result = guest_session.update_guest_activity(
            session_id=session_id,
            device_id=device_id,
            converted_user="spoofed@example.com",
        )

        doc = frappe.get_doc("OMC Guest Session", session_id)
        self.assertEqual(doc.converted_user, "Administrator")
        self.assertTrue(int(doc.is_converted or 0))
        self.assertNotIn("converted_user", result["guest_session"])
