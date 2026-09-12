from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import architecture_migration, service_task_links, staff_authority
from omc_app.setup import roles


class TestArchitectureMigration(FrappeTestCase):
    def test_preflight_requires_new_relation_schema(self):
        with patch.object(
            architecture_migration.frappe.db,
            "exists",
            return_value=False,
        ):
            result = architecture_migration.preflight()

        self.assertTrue(result["read_only"])
        self.assertFalse(result["ready"])
        self.assertIn("bench migrate", result["reason"])

    def test_apply_requires_explicit_confirmation(self):
        with self.assertRaises(frappe.ValidationError):
            architecture_migration.apply(confirm="wrong", commit=False)

    def test_service_task_preflight_detects_safe_backfill(self):
        request = SimpleNamespace(
            name="OMC-SR-0001",
            erp_task="TASK-0001",
            erp_service="ERP-SVC-0001",
        )

        def exists(doctype, name):
            return (doctype, name) == ("Task", "TASK-0001")

        with patch.object(
            architecture_migration.frappe,
            "get_all",
            return_value=[request],
        ), patch.object(
            architecture_migration.frappe.db,
            "exists",
            side_effect=exists,
        ), patch.object(
            service_task_links,
            "_link_doctype_available",
            return_value=True,
        ), patch.object(
            architecture_migration.frappe.db,
            "get_value",
            return_value=None,
        ):
            result = architecture_migration._service_task_plan()

        self.assertEqual(result["backfill_ready"], 1)
        self.assertEqual(result["conflicts"], 0)
        self.assertEqual(result["missing_task"], 0)

    def test_staff_preflight_detects_missing_canonical_links(self):
        access = SimpleNamespace(
            name="staff@example.com",
            user="staff@example.com",
            employee="",
            legacy_staff_profile="",
            persona_snapshot="Consultant",
            access_status="Approved",
            reconciliation_status="Current",
        )
        with patch.object(
            architecture_migration.frappe,
            "get_all",
            return_value=[access],
        ), patch.object(
            architecture_migration.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            staff_authority,
            "canonical_links",
            return_value={
                "employee": "EMP-0001",
                "legacy_staff_profile": "staff@example.com",
            },
        ):
            result = architecture_migration._staff_access_plan()

        self.assertEqual(result["link_backfill_ready"], 1)
        self.assertEqual(result["conflicts"], 0)

    def test_service_task_link_is_explicit_read_only_evidence(self):
        self.assertIn(
            service_task_links.LINK_DOCTYPE,
            roles.ADMIN_READ_ONLY_DOCTYPES,
        )
        self.assertIn(
            service_task_links.LINK_DOCTYPE,
            roles.MANAGER_READ_ONLY_DOCTYPES,
        )
        self.assertNotIn(
            service_task_links.LINK_DOCTYPE,
            roles.ADMIN_MUTABLE_DOCTYPES,
        )
