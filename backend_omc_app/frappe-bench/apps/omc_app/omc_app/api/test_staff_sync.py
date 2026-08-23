from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.setup import staff_sync


TEST_USER = "omc.staff.sync.regression@example.com"


class TestStaffSyncCanonicalAccess(FrappeTestCase):
    def setUp(self):
        frappe.set_user("Administrator")
        self._cleanup()

        user = frappe.get_doc(
            {
                "doctype": "User",
                "email": TEST_USER,
                "first_name": "OMC",
                "last_name": "Staff Sync Regression",
                "enabled": 1,
                "user_type": "System User",
                "send_welcome_email": 0,
            }
        )
        user.insert(ignore_permissions=True)

        # Frappe may recalculate a newly-created test User as Website User.
        # This fixture specifically represents an existing internal ERP user.
        frappe.db.set_value(
            "User",
            TEST_USER,
            "user_type",
            "System User",
            update_modified=False,
        )
        frappe.db.commit()

    def tearDown(self):
        frappe.set_user("Administrator")
        self._cleanup()
        frappe.db.commit()

    def _cleanup(self):
        for doctype, filters in (
            ("OMC Referral", {"referrer_user": TEST_USER}),
            ("OMC Staff Access", {"user": TEST_USER}),
            ("OMC Staff Profile", {"user": TEST_USER}),
        ):
            if not frappe.db.exists("DocType", doctype):
                continue

            for name in frappe.get_all(
                doctype,
                filters=filters,
                pluck="name",
                limit_page_length=0,
            ):
                frappe.delete_doc(
                    doctype,
                    name,
                    force=True,
                    ignore_permissions=True,
                )

        if frappe.db.exists("User", TEST_USER):
            frappe.delete_doc(
                "User",
                TEST_USER,
                force=True,
                ignore_permissions=True,
            )

    def test_sync_creates_canonical_staff_access_before_referral(self):
        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Consultant",
        ):
            result = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertTrue(result["applied"], result)

        profile_name = frappe.db.get_value(
            "OMC Staff Profile",
            {"user": TEST_USER},
            "name",
        )
        self.assertTrue(profile_name)

        profile = frappe.get_doc(
            "OMC Staff Profile",
            profile_name,
        )
        self.assertEqual(profile.staff_role, "Consultant")
        self.assertEqual(profile.staff_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(int(profile.is_active or 0), 1)

        access_name = frappe.db.get_value(
            "OMC Staff Access",
            {"user": TEST_USER},
            "name",
        )
        self.assertTrue(
            access_name,
            "staff sync must create canonical OMC Staff Access",
        )

        access = frappe.get_doc(
            "OMC Staff Access",
            access_name,
        )
        self.assertEqual(access.access_status, "Approved")
        self.assertEqual(
            access.reconciliation_status,
            "Current",
        )
        self.assertEqual(
            access.persona_snapshot,
            "Consultant",
        )

        referral_name = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": TEST_USER},
            "name",
        )
        self.assertTrue(
            referral_name,
            "referral code must exist after Staff Access is canonical",
        )

        referral = frappe.get_doc(
            "OMC Referral",
            referral_name,
        )
        self.assertEqual(referral.referrer_user, TEST_USER)
        self.assertEqual(referral.status, "Approved")
        self.assertEqual(int(referral.is_active or 0), 1)
        self.assertTrue(referral.referral_code)

        # Rerun must be idempotent.
        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Consultant",
        ):
            second = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertTrue(second["applied"])

        self.assertEqual(
            frappe.db.count(
                "OMC Staff Access",
                {"user": TEST_USER},
            ),
            1,
        )
        self.assertEqual(
            frappe.db.count(
                "OMC Referral",
                {"referrer_user": TEST_USER},
            ),
            1,
        )



    def test_business_partner_gets_staff_access_and_referral(self):
        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Business Partner",
        ):
            result = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertTrue(result["applied"], result)

        access_name = frappe.db.get_value(
            "OMC Staff Access",
            {"user": TEST_USER},
            "name",
        )
        self.assertTrue(access_name)

        access = frappe.get_doc(
            "OMC Staff Access",
            access_name,
        )
        self.assertEqual(
            access.persona_snapshot,
            "Business Partner",
        )
        self.assertEqual(
            access.access_status,
            "Approved",
        )
        self.assertEqual(
            access.reconciliation_status,
            "Current",
        )

        referral_name = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": TEST_USER},
            "name",
        )
        self.assertTrue(referral_name)

    def test_website_user_is_not_promoted_to_staff(self):
        frappe.db.set_value(
            "User",
            TEST_USER,
            "user_type",
            "Website User",
            update_modified=False,
        )

        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Business Partner",
        ):
            result = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertFalse(result["applied"])
        self.assertEqual(
            result["reason"],
            "not_system_user",
        )

        self.assertFalse(
            frappe.db.exists(
                "OMC Staff Access",
                {"user": TEST_USER},
            )
        )
        self.assertFalse(
            frappe.db.exists(
                "OMC Referral",
                {"referrer_user": TEST_USER},
            )
        )

    def test_disabled_system_user_is_not_promoted_to_staff(self):
        frappe.db.set_value(
            "User",
            TEST_USER,
            "enabled",
            0,
            update_modified=False,
        )

        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Consultant",
        ):
            result = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertFalse(result["applied"])
        self.assertEqual(
            result["reason"],
            "user_disabled",
        )

        self.assertFalse(
            frappe.db.exists(
                "OMC Staff Access",
                {"user": TEST_USER},
            )
        )
        self.assertFalse(
            frappe.db.exists(
                "OMC Referral",
                {"referrer_user": TEST_USER},
            )
        )

    def test_suspended_staff_access_is_not_reactivated_on_rerun(self):
        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Consultant",
        ):
            first = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertTrue(first["applied"], first)

        access_name = frappe.db.get_value(
            "OMC Staff Access",
            {"user": TEST_USER},
            "name",
        )
        referral_name = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": TEST_USER},
            "name",
        )

        self.assertTrue(access_name)
        self.assertTrue(referral_name)

        frappe.db.set_value(
            "OMC Staff Access",
            access_name,
            {
                "access_status": "Suspended",
                "suspended_by": "Administrator",
                "suspension_reason": "Regression test suspension",
            },
            update_modified=False,
        )

        with patch.object(
            staff_sync,
            "_erp_omc_user_type",
            return_value="Consultant",
        ):
            second = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
            )

        self.assertTrue(second["applied"], second)

        access = frappe.get_doc(
            "OMC Staff Access",
            access_name,
        )
        self.assertEqual(
            access.access_status,
            "Suspended",
        )
        self.assertEqual(
            access.suspension_reason,
            "Regression test suspension",
        )

        referral = frappe.get_doc(
            "OMC Referral",
            referral_name,
        )
        self.assertEqual(
            int(referral.is_active or 0),
            0,
        )
        self.assertEqual(
            referral.status,
            "Inactive",
        )

    def test_sync_can_defer_commit_to_parent_migration(self):
        with (
            patch.object(
                staff_sync,
                "_erp_omc_user_type",
                return_value="Consultant",
            ),
            patch.object(
                staff_sync.frappe.db,
                "commit",
            ) as commit,
        ):
            result = staff_sync.sync_staff_user(
                TEST_USER,
                apply=True,
                commit=False,
            )

        self.assertTrue(result["applied"], result)

        # Staff Profile / Access / Referral may be created inside the
        # current transaction, but the parent migration owns the commit.
        commit.assert_not_called()

        self.assertTrue(
            frappe.db.exists(
                "OMC Staff Access",
                {"user": TEST_USER},
            )
        )
        self.assertTrue(
            frappe.db.exists(
                "OMC Referral",
                {"referrer_user": TEST_USER},
            )
        )
