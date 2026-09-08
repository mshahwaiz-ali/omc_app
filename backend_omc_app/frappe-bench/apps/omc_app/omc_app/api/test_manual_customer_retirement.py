import json
from pathlib import Path

import frappe
from frappe.tests.utils import FrappeTestCase


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
DOCTYPE_ROOT = PACKAGE_ROOT / "omc_app" / "doctype"
WORKSPACE_PATH = PACKAGE_ROOT / "omc_app" / "workspace" / "omc_app" / "omc_app.json"
ROLES_PATH = PACKAGE_ROOT / "setup" / "roles.py"


class TestManualCustomerRetirement(FrappeTestCase):
    def test_new_manual_customer_insert_is_blocked(self):
        doc = frappe.new_doc("OMC Manual Customer")
        doc.naming_series = "OMC-MC-.YY..MM..DD.-.#####"
        doc.full_name = "Retired Manual Flow"
        doc.mobile = "03000000000"

        with self.assertRaisesRegex(
            frappe.ValidationError,
            "OMC Manual Customer is retired",
        ):
            doc.insert(ignore_permissions=True)

    def test_manual_customer_is_not_exposed_in_workspace(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))
        targets = {
            str(row.get("link_to") or "").strip()
            for row in workspace.get("links") or []
            if row.get("type") == "Link"
        }
        self.assertNotIn("OMC Manual Customer", targets)

    def test_manual_customer_source_permission_is_read_only(self):
        schema_path = (
            DOCTYPE_ROOT
            / "omc_manual_customer"
            / "omc_manual_customer.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        permissions = schema.get("permissions") or []

        self.assertTrue(permissions)
        for permission in permissions:
            self.assertEqual(int(permission.get("read") or 0), 1)
            self.assertEqual(int(permission.get("create") or 0), 0)
            self.assertEqual(int(permission.get("write") or 0), 0)
            self.assertEqual(int(permission.get("delete") or 0), 0)

    def test_role_repair_keeps_manual_customer_out_of_mutable_allowlist(self):
        roles_source = ROLES_PATH.read_text(encoding="utf-8")
        mutable_block = roles_source.split(
            "ADMIN_MUTABLE_DOCTYPES = {", 1
        )[1].split("}", 1)[0]
        read_only_block = roles_source.split(
            "ADMIN_READ_ONLY_DOCTYPES = {", 1
        )[1].split("}", 1)[0]

        self.assertNotIn('"OMC Manual Customer"', mutable_block)
        self.assertIn('"OMC Manual Customer"', read_only_block)

    def test_service_request_keeps_manual_reference_hidden_for_history(self):
        schema_path = (
            DOCTYPE_ROOT
            / "omc_service_request"
            / "omc_service_request.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        field = next(
            row
            for row in schema.get("fields") or []
            if row.get("fieldname") == "manual_customer"
        )

        self.assertEqual(field.get("options"), "OMC Manual Customer")
        self.assertEqual(int(field.get("hidden") or 0), 1)
        self.assertEqual(int(field.get("read_only") or 0), 1)
