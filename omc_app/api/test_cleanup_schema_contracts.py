import json
from pathlib import Path

from frappe.tests.utils import FrappeTestCase


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
DOCTYPE_ROOT = PACKAGE_ROOT / "omc_app" / "doctype"


def _schema(doctype_folder: str) -> dict:
    path = DOCTYPE_ROOT / doctype_folder / f"{doctype_folder}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _field(schema: dict, fieldname: str) -> dict:
    return next(
        row
        for row in schema.get("fields") or []
        if row.get("fieldname") == fieldname
    )


class TestCleanupSchemaContracts(FrappeTestCase):
    def test_mobile_settings_expose_only_real_runtime_controls(self):
        schema = _schema("omc_mobile_settings")
        fieldnames = {
            row.get("fieldname")
            for row in schema.get("fields") or []
        }

        retired = {
            "integration_mode",
            "erpnext_integration_enabled",
            "customer_doctype",
            "customer_name_field",
            "customer_email_field",
            "customer_mobile_field",
            "invoice_doctype",
            "invoice_customer_field",
            "invoice_amount_field",
            "invoice_date_field",
            "invoice_status_field",
            "payment_doctype",
            "payment_customer_field",
            "payment_amount_field",
            "payment_date_field",
            "payment_mode_field",
            "is_mobile_backend_active",
            "signup_enabled",
            "require_customer_approval",
            "subscriptions_enabled",
        }

        self.assertFalse(retired & fieldnames)
        for active in (
            "guest_mode_enabled",
            "payments_enabled",
            "payment_gateway_enabled",
            "support_enabled",
            "knowledge_enabled",
            "tax_calculator_enabled",
            "expense_tracker_enabled",
            "internal_workspace_enabled",
            "minimum_app_version",
            "force_update",
            "maintenance_mode",
        ):
            self.assertIn(active, fieldnames)

    def test_service_role_selector_is_legacy_hidden_state(self):
        schema = _schema("omc_service")
        role = _field(schema, "default_assignment_role")
        duration = _field(schema, "estimated_duration")

        self.assertEqual(role.get("default"), "Employee")
        self.assertEqual(int(role.get("hidden") or 0), 1)
        self.assertEqual(int(role.get("read_only") or 0), 1)
        self.assertEqual(int(duration.get("hidden") or 0), 1)
        self.assertEqual(int(duration.get("read_only") or 0), 1)
        self.assertIn("completion_time", schema.get("field_order") or [])

    def test_customer_profile_is_customer_only_in_normal_forms(self):
        schema = _schema("omc_customer_profile")
        register_as = _field(schema, "register_as")
        customer_type = _field(schema, "customer_type")
        manual_status = _field(schema, "manual_customer_status")

        self.assertEqual(register_as.get("default"), "Customer")
        self.assertEqual(int(register_as.get("hidden") or 0), 1)
        self.assertEqual(int(register_as.get("read_only") or 0), 1)
        self.assertEqual(customer_type.get("default"), "Customer")
        self.assertEqual(int(customer_type.get("hidden") or 0), 1)
        self.assertEqual(int(customer_type.get("read_only") or 0), 1)
        self.assertEqual(int(manual_status.get("hidden") or 0), 1)
        self.assertEqual(int(manual_status.get("read_only") or 0), 1)

    def test_service_request_provenance_is_not_desk_editable(self):
        schema = _schema("omc_service_request")
        for fieldname in (
            "service",
            "customer_profile",
            "requested_by",
            "requested_for_customer",
            "customer_mode",
            "submission_mode",
            "referral_owner",
            "referral_record",
            "source_channel",
            "company_snapshot",
        ):
            self.assertEqual(
                int(_field(schema, fieldname).get("read_only") or 0),
                1,
                fieldname,
            )

        manual = _field(schema, "manual_customer")
        self.assertEqual(int(manual.get("hidden") or 0), 1)
        self.assertEqual(int(manual.get("read_only") or 0), 1)
