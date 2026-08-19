from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import admin_read


class Row(dict):
    def __getattr__(self, key):
        return self.get(key)


class TestAdminRead(TestCase):
    def test_business_settings_only_does_not_receive_staff_or_registrations(self):
        values = {
            "can_manage_staff": False,
            "can_review_registrations": False,
            "can_manage_business_settings": True,
        }
        with (
            patch.object(admin_read.capabilities, "effective", return_value=values),
            patch.object(admin_read.security, "enforce_rate_limit"),
            patch.object(admin_read.admin_control, "_pagination", return_value=(0, 20)),
            patch.object(admin_read.frappe, "get_all") as get_all,
        ):
            result = admin_read.get_admin_overview()

        self.assertEqual(result["applications"], [])
        self.assertEqual(result["staff"], [])
        self.assertEqual(result["available_roles"], [])
        self.assertEqual(
            result["allowed_sections"],
            {
                "registrations": False,
                "staff": False,
                "business_settings": True,
            },
        )
        get_all.assert_not_called()

    def test_registration_reviewer_reads_registrations_only(self):
        values = {
            "can_manage_staff": False,
            "can_review_registrations": True,
            "can_manage_business_settings": False,
        }
        pending = Row(
            name="OMC-CUST-0001",
            full_name="Customer One",
            email="customer@example.com",
            phone="",
            register_as="Customer",
            customer_type="Customer",
            customer_status="Pending",
            approval_status="Pending Review",
            creation="2026-08-20 00:00:00",
        )

        with (
            patch.object(admin_read.capabilities, "effective", return_value=values),
            patch.object(admin_read.security, "enforce_rate_limit"),
            patch.object(admin_read.admin_control, "_pagination", return_value=(0, 20)),
            patch.object(admin_read.admin_control, "_requested_staff_role", return_value=None),
            patch.object(admin_read.frappe, "get_all", return_value=[pending]) as get_all,
            patch.object(admin_read.frappe, "get_doc") as get_doc,
        ):
            result = admin_read.get_admin_overview()

        self.assertEqual(len(result["applications"]), 1)
        self.assertEqual(result["staff"], [])
        self.assertTrue(result["allowed_sections"]["registrations"])
        self.assertFalse(result["allowed_sections"]["staff"])
        self.assertEqual(get_all.call_args.args[0], "OMC Customer Profile")
        get_doc.assert_not_called()

    def test_staff_manager_reads_staff_only(self):
        values = {
            "can_manage_staff": True,
            "can_review_registrations": False,
            "can_manage_business_settings": False,
        }
        staff_row = SimpleNamespace(name="OMC-STAFF-0001")
        with (
            patch.object(admin_read.capabilities, "effective", return_value=values),
            patch.object(admin_read.security, "enforce_rate_limit"),
            patch.object(admin_read.admin_control, "_pagination", return_value=(0, 20)),
            patch.object(admin_read.frappe, "get_all", return_value=[staff_row]) as get_all,
            patch.object(admin_read.frappe, "get_doc", return_value=object()),
            patch.object(
                admin_read.admin_control,
                "_staff_item",
                return_value={"user_id": "staff@example.com"},
            ),
        ):
            result = admin_read.get_admin_overview()

        self.assertEqual(result["applications"], [])
        self.assertEqual(result["staff"], [{"user_id": "staff@example.com"}])
        self.assertTrue(result["allowed_sections"]["staff"])
        self.assertFalse(result["allowed_sections"]["registrations"])
        self.assertEqual(get_all.call_args.args[0], "OMC Staff Access")
