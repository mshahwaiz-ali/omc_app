from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup import erp_contract


class _Meta:
    def __init__(self, fields):
        self._fields = fields

    def get_field(self, fieldname):
        return self._fields.get(fieldname)


def _field(fieldtype, options=""):
    return SimpleNamespace(fieldtype=fieldtype, options=options)


def _compatible_meta():
    return {
        "Customer": _Meta({"user_link": _field("Link", "User")}),
        "Service": _Meta({
            "customer": _field("Link", "Customer"),
            "service_type": _field("Link", "Task Type"),
            "task_created": _field("Check"),
            "task_link": _field("Link", "Task"),
            "user_link": _field("Link", "User"),
        }),
        "Task": _Meta({
            "subject": _field("Data"),
            "type": _field("Link", "Task Type"),
            "status": _field("Select", "Open\nWorking\nCompleted\nCancelled"),
            "user_link": _field("Link", "User"),
            "customer": _field("Link", "Customer"),
            "custom_operation_status": _field("Select", "Open\nIn Progress\nCompleted"),
        }),
    }


class TestClientErpInstallContract(FrappeTestCase):
    def _inspect(self, apps=None, doctypes=None, meta=None):
        apps = ["frappe", "erpnext"] if apps is None else apps
        doctypes = set(erp_contract.REQUIRED_DOCTYPES) if doctypes is None else set(doctypes)
        meta = _compatible_meta() if meta is None else meta
        with (
            patch.object(erp_contract.frappe, "get_installed_apps", return_value=apps),
            patch.object(
                erp_contract.frappe.db,
                "exists",
                side_effect=lambda doctype, name: doctype == "DocType" and name in doctypes,
            ),
            patch.object(erp_contract.frappe, "get_meta", side_effect=lambda doctype: meta[doctype]),
        ):
            return erp_contract.inspect_client_erp_contract()

    def test_compatible_client_schema_passes(self):
        self.assertEqual(self._inspect(), [])

    def test_missing_erpnext_is_reported(self):
        self.assertEqual(
            self._inspect(apps=["frappe"], doctypes=set(), meta={}),
            ["Required app is not installed on this site: erpnext"],
        )

    def test_missing_service_is_reported(self):
        doctypes = set(erp_contract.REQUIRED_DOCTYPES) - {"Service"}
        self.assertIn("Missing required ERP DocType: Service", self._inspect(doctypes=doctypes))

    def test_missing_task_customer_is_reported(self):
        meta = _compatible_meta()
        meta["Task"] = _Meta({k: v for k, v in meta["Task"]._fields.items() if k != "customer"})
        self.assertIn("Missing required ERP field: Task.customer", self._inspect(meta=meta))

    def test_wrong_service_type_target_is_reported(self):
        meta = _compatible_meta()
        meta["Service"]._fields["service_type"] = _field("Link", "Item")
        self.assertIn(
            "Invalid ERP field target: Service.service_type must point to Task Type, found Item",
            self._inspect(meta=meta),
        )

    def test_missing_required_task_status_option_is_reported(self):
        meta = _compatible_meta()
        meta["Task"]._fields["status"] = _field("Select", "Open\nWorking\nCompleted")
        self.assertIn(
            "Missing required ERP select option: Task.status must allow Cancelled",
            self._inspect(meta=meta),
        )

    def test_missing_operation_open_option_is_reported(self):
        meta = _compatible_meta()
        meta["Task"]._fields["custom_operation_status"] = _field(
            "Select", "In Progress\nCompleted"
        )
        self.assertIn(
            "Missing required ERP select option: Task.custom_operation_status must allow Open",
            self._inspect(meta=meta),
        )

    def test_optional_service_fields_are_not_required(self):
        fields = set(erp_contract.REQUIRED_FIELDS["Service"])
        for fieldname in ("custom_status", "custom_customer_type", "custom_remarks", "status"):
            self.assertNotIn(fieldname, fields)

    def test_missing_selling_defaults_are_non_blocking_warnings(self):
        with (
            patch.object(
                erp_contract.frappe,
                "get_installed_apps",
                return_value=["frappe", "erpnext"],
            ),
            patch.object(
                erp_contract.frappe.db,
                "get_single_value",
                return_value=None,
            ),
        ):
            warnings = erp_contract.inspect_client_erp_capability_warnings()
        self.assertEqual(len(warnings), 2)
        self.assertTrue(any("customer_group" in warning for warning in warnings))
        self.assertTrue(any("territory" in warning for warning in warnings))

    def test_validator_is_read_only(self):
        source = Path(erp_contract.__file__).read_text(encoding="utf-8")
        for marker in (
            "new_doc(", "insert(", "save(", "delete(", "set_value(",
            "create_custom_fields", "make_property_setter",
        ):
            self.assertNotIn(marker, source)
