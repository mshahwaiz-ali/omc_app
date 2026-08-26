import json

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile, profile as profile_api, profile_self_service


class TestProfileSelfService(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.user = "profile-edit-test@example.com"

        # A previously interrupted test can leave this unique fixture behind
        # because tearDown is not reached when setUp itself fails. Always start
        # from a clean fixture state.
        frappe.set_user("Administrator")

        for name in frappe.get_all(
            "OMC Profile Change Log",
            filters={"user": self.user},
            pluck="name",
        ):
            frappe.delete_doc(
                "OMC Profile Change Log",
                name,
                force=True,
                ignore_permissions=True,
            )

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"email": self.user},
            pluck="name",
        ):
            frappe.delete_doc(
                "OMC Customer Profile",
                name,
                force=True,
                ignore_permissions=True,
            )

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"user": self.user},
            pluck="name",
        ):
            if frappe.db.exists("OMC Customer Profile", name):
                frappe.delete_doc(
                    "OMC Customer Profile",
                    name,
                    force=True,
                    ignore_permissions=True,
                )

        if frappe.db.exists("User", self.user):
            frappe.delete_doc(
                "User",
                self.user,
                force=True,
                ignore_permissions=True,
            )

        frappe.db.commit()

        if not frappe.db.exists("User", self.user):
            frappe.get_doc(
                {
                    "doctype": "User",
                    "email": self.user,
                    "first_name": "Profile Edit Test",
                    "enabled": 1,
                    "send_welcome_email": 0,
                    "user_type": "Website User",
                }
            ).insert(ignore_permissions=True)

        self.profile = frappe.get_doc(
            {
                "doctype": "OMC Customer Profile",
                "user": self.user,
                "email": self.user,
                "full_name": "Profile Edit Test",
                "phone": "+923001111111",
                "cnic": "3520212345671",
                "customer_status": "Active",
                "approval_status": "Approved",
                "is_active": 1,
            }
        ).insert(ignore_permissions=True)

        self.previous_user = frappe.session.user
        frappe.set_user(self.user)

    def tearDown(self):
        frappe.set_user("Administrator")

        for name in frappe.get_all(
            "OMC Profile Change Log",
            filters={"user": self.user},
            pluck="name",
        ):
            frappe.delete_doc(
                "OMC Profile Change Log",
                name,
                force=True,
                ignore_permissions=True,
            )

        if frappe.db.exists("OMC Customer Profile", self.profile.name):
            frappe.delete_doc(
                "OMC Customer Profile",
                self.profile.name,
                force=True,
                ignore_permissions=True,
            )

        if frappe.db.exists("User", self.user):
            frappe.delete_doc(
                "User",
                self.user,
                force=True,
                ignore_permissions=True,
            )

        frappe.db.rollback()
        frappe.set_user(self.previous_user)
        super().tearDown()

    def test_updates_allowed_fields_and_creates_audit(self):
        result = profile_self_service.update_profile(
            full_name="Updated Profile Name",
            phone="03001234567",
            company_name="Updated Company",
        )

        self.assertTrue(result["updated"])
        self.assertEqual(
            set(result["updated_fields"]),
            {"full_name", "phone", "company_name"},
        )

        profile = frappe.get_doc("OMC Customer Profile", self.profile.name)
        self.assertEqual(profile.full_name, "Updated Profile Name")
        self.assertEqual(profile.phone, "+923001234567")
        self.assertEqual(profile.company_name, "Updated Company")

        logs = frappe.get_all(
            "OMC Profile Change Log",
            filters={"customer_profile": self.profile.name},
            fields=["changed_fields", "before_json", "after_json"],
        )
        self.assertEqual(len(logs), 1)
        after = json.loads(logs[0].after_json)
        self.assertEqual(after["full_name"], "Updated Profile Name")

    def test_allows_ntn_to_be_set_once_then_locks_it(self):
        first = profile_self_service.update_profile(ntn="1234567-8")

        self.assertTrue(first["updated"])
        self.assertIn("ntn", first["updated_fields"])

        profile = frappe.get_doc("OMC Customer Profile", self.profile.name)
        self.assertEqual(profile.ntn, "1234567-8")

        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(ntn="7654321-0")

    def test_rejects_cnic_change(self):
        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(cnic="1111111111111")

    def test_allows_cnic_to_be_added_once_when_blank_then_locks_it(self):
        frappe.db.set_value("OMC Customer Profile", self.profile.name, "cnic", "")

        first = profile_self_service.update_profile(cnic="3520212345671")
        self.assertTrue(first["updated"])
        self.assertIn("cnic", first["updated_fields"])

        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(cnic="1111111111111")

    def test_allows_company_name_to_be_added_once_then_locks_it(self):
        first = profile_self_service.update_profile(company_name="First Company")
        self.assertTrue(first["updated"])
        self.assertIn("company_name", first["updated_fields"])

        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(company_name="Second Company")

    def test_profile_edit_policy_exposes_add_only_for_blank_set_once_fields(self):
        payload = profile_api.get_profile()
        policy = payload["profile_edit_policy"]

        self.assertEqual(policy["email"], {"can_edit": False, "mode": "locked"})
        self.assertEqual(policy["cnic"], {"can_edit": False, "mode": "locked"})
        self.assertEqual(policy["ntn"], {"can_edit": True, "mode": "add"})
        self.assertEqual(
            policy["company_name"],
            {"can_edit": True, "mode": "add"},
        )

    def test_ignores_frappe_cmd_transport_metadata(self):
        result = profile_self_service.update_profile(
            cmd="omc_app.api.profile_self_service.update_profile",
            address="Test Address Lahore",
        )
        self.assertTrue(result["updated"])
        self.assertIn("address", result["updated_fields"])

    def test_rejects_email_change(self):
        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(email="new@example.com")

    def test_rejects_unknown_mass_assignment_field(self):
        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(is_active=0)

    def test_legacy_mobile_update_profile_cannot_change_cnic(self):
        with self.assertRaises(frappe.ValidationError):
            mobile.update_profile(cnic="1111111111111")

    def test_legacy_mobile_update_contact_cannot_change_email(self):
        with self.assertRaises(frappe.ValidationError):
            mobile.update_contact_info(email="new@example.com")

    def test_no_change_does_not_create_audit(self):
        result = profile_self_service.update_profile(
            full_name="Profile Edit Test",
        )

        self.assertFalse(result["updated"])
        self.assertEqual(
            frappe.db.count(
                "OMC Profile Change Log",
                {"customer_profile": self.profile.name},
            ),
            0,
        )

class TestInternalProfileSelfService(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.user = "profile-internal-test@example.com"
        self.previous_user = frappe.session.user
        frappe.set_user("Administrator")

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"user": self.user},
            pluck="name",
        ):
            frappe.delete_doc(
                "OMC Customer Profile",
                name,
                force=True,
                ignore_permissions=True,
            )

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"email": self.user},
            pluck="name",
        ):
            if frappe.db.exists("OMC Customer Profile", name):
                frappe.delete_doc(
                    "OMC Customer Profile",
                    name,
                    force=True,
                    ignore_permissions=True,
                )

        if frappe.db.exists("User", self.user):
            frappe.delete_doc("User", self.user, force=True, ignore_permissions=True)

        frappe.get_doc(
            {
                "doctype": "User",
                "email": self.user,
                "first_name": "Internal Profile Test",
                "mobile_no": "+923001111111",
                "enabled": 1,
                "send_welcome_email": 0,
                "user_type": "System User",
                "roles": [{"role": "System Manager"}],
            }
        ).insert(ignore_permissions=True)
        frappe.db.commit()
        frappe.set_user(self.user)

    def tearDown(self):
        frappe.set_user("Administrator")

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"user": self.user},
            pluck="name",
        ):
            frappe.delete_doc(
                "OMC Customer Profile",
                name,
                force=True,
                ignore_permissions=True,
            )

        for name in frappe.get_all(
            "OMC Customer Profile",
            filters={"email": self.user},
            pluck="name",
        ):
            if frappe.db.exists("OMC Customer Profile", name):
                frappe.delete_doc(
                    "OMC Customer Profile",
                    name,
                    force=True,
                    ignore_permissions=True,
                )

        if frappe.db.exists("User", self.user):
            frappe.delete_doc("User", self.user, force=True, ignore_permissions=True)
        frappe.db.rollback()
        frappe.set_user(self.previous_user)
        super().tearDown()

    def test_internal_user_updates_safe_user_fields_without_customer_profile(self):
        self.assertFalse(frappe.db.exists("OMC Customer Profile", {"user": self.user}))

        result = profile_self_service.update_profile(
            full_name="Updated Internal Name",
            phone="03001234567",
        )

        self.assertTrue(result["updated"])
        self.assertEqual(set(result["updated_fields"]), {"full_name", "phone"})

        user_doc = frappe.get_doc("User", self.user)
        self.assertEqual(user_doc.full_name, "Updated Internal Name")
        self.assertEqual(user_doc.mobile_no, "+923001234567")
        self.assertFalse(frappe.db.exists("OMC Customer Profile", {"user": self.user}))

    def test_internal_user_rejects_customer_only_fields(self):
        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(company_name="Not Allowed")

        with self.assertRaises(frappe.ValidationError):
            profile_self_service.update_profile(ntn="1234567-8")
