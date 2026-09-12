import json
from types import SimpleNamespace
from unittest.mock import Mock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_invoice_compat


class TestTaskInvoiceCompatibility(FrappeTestCase):
    def test_non_omc_task_delegates_single_invoice_unchanged(self):
        with patch.object(task_invoice_compat, "_request_for_task", return_value=""), patch(
            "erpnext.projects.doctype.task.task.mk_inv",
            return_value="SINV-LEGACY-00001",
        ) as legacy:
            result = task_invoice_compat.mk_inv("TASK-LEGACY-00001")

        self.assertEqual(result, "SINV-LEGACY-00001")
        legacy.assert_called_once_with("TASK-LEGACY-00001")

    def test_omc_task_reuses_canonical_invoice(self):
        with patch.object(
            task_invoice_compat,
            "_request_for_task",
            return_value="OMC-SR-TEST-00001",
        ), patch.object(
            task_invoice_compat,
            "_canonical_invoice_or_throw",
            return_value="SINV-OMC-00001",
        ) as canonical:
            result = task_invoice_compat.mk_inv("TASK-OMC-00001")

        self.assertEqual(result, "SINV-OMC-00001")
        canonical.assert_called_once_with(
            "TASK-OMC-00001",
            "OMC-SR-TEST-00001",
        )

    def test_omc_task_without_canonical_invoice_never_falls_back(self):
        with patch.object(
            task_invoice_compat,
            "_request_for_task",
            return_value="OMC-SR-TEST-00001",
        ), patch.object(
            task_invoice_compat,
            "_canonical_invoice_or_throw",
            side_effect=RuntimeError("missing canonical invoice"),
        ), patch(
            "erpnext.projects.doctype.task.task.mk_inv",
        ) as legacy:
            with self.assertRaisesRegex(RuntimeError, "missing canonical invoice"):
                task_invoice_compat.mk_inv("TASK-OMC-00001")

        legacy.assert_not_called()

    def test_bulk_splits_omc_and_legacy_tasks(self):
        request_map = {
            "TASK-OMC-00001": "OMC-SR-TEST-00001",
            "TASK-LEGACY-00001": "",
        }

        def request_for_task(task_name):
            return request_map[task_name]

        def get_value(doctype, name, fieldname, *args, **kwargs):
            if doctype == "Task" and fieldname == "status":
                return "Completed"
            return None

        with patch.object(
            task_invoice_compat,
            "_request_for_task",
            side_effect=request_for_task,
        ), patch.object(
            task_invoice_compat,
            "_canonical_invoice_or_throw",
            return_value="SINV-OMC-00001",
        ), patch.object(
            task_invoice_compat.frappe.db,
            "get_value",
            side_effect=get_value,
        ), patch(
            "erpnext.projects.doctype.task.task.bulk_generate_invoices",
            return_value=["SINV-LEGACY-00001"],
        ) as legacy_bulk:
            result = task_invoice_compat.bulk_generate_invoices(
                json.dumps(["TASK-OMC-00001", "TASK-LEGACY-00001"])
            )

        self.assertEqual(
            result,
            ["SINV-OMC-00001", "SINV-LEGACY-00001"],
        )
        legacy_bulk.assert_called_once_with(
            json.dumps(["TASK-LEGACY-00001"])
        )

    def test_projection_sets_legacy_invoiced_flag_from_base_link(self):
        link = SimpleNamespace(
            sales_invoice="SINV-OMC-00001",
            accounting_status="Settled",
        )
        meta = Mock()
        meta.get_field.return_value = SimpleNamespace(fieldname="invoiced")

        with patch.object(
            task_invoice_compat.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            task_invoice_compat,
            "_base_invoice",
            return_value=link,
        ), patch.object(
            task_invoice_compat,
            "_project_task_rate",
            return_value=False,
        ), patch.object(
            task_invoice_compat.frappe,
            "get_meta",
            return_value=meta,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "get_value",
            return_value=0,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "set_value",
        ) as set_value:
            result = task_invoice_compat.project_task_invoice_flag(
                request_name="OMC-SR-TEST-00001",
                task_name="TASK-OMC-00001",
            )

        self.assertTrue(result["updated"])
        self.assertFalse(result["rate_updated"])
        self.assertEqual(result["invoice"], "SINV-OMC-00001")
        set_value.assert_called_once_with(
            "Task",
            "TASK-OMC-00001",
            "invoiced",
            1,
            update_modified=False,
        )

    def test_rate_projection_uses_authoritative_payable_amount(self):
        meta = Mock()
        meta.get_field.return_value = SimpleNamespace(fieldname="rate")

        def get_value(doctype, name, fieldname, *args, **kwargs):
            if doctype == task_invoice_compat.REQUEST_DOCTYPE:
                return SimpleNamespace(payable_amount=50000, final_price=45000)
            if doctype == "Task" and fieldname == "rate":
                return 35000
            return None

        with patch.object(
            task_invoice_compat.frappe,
            "get_meta",
            return_value=meta,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "get_value",
            side_effect=get_value,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "set_value",
        ) as set_value:
            updated = task_invoice_compat._project_task_rate(
                "OMC-SR-TEST-00001",
                "TASK-OMC-00001",
            )

        self.assertTrue(updated)
        set_value.assert_called_once_with(
            "Task",
            "TASK-OMC-00001",
            "rate",
            50000.0,
            update_modified=False,
        )

    def test_rate_projection_falls_back_to_final_price(self):
        meta = Mock()
        meta.get_field.return_value = SimpleNamespace(fieldname="rate")

        def get_value(doctype, name, fieldname, *args, **kwargs):
            if doctype == task_invoice_compat.REQUEST_DOCTYPE:
                return SimpleNamespace(payable_amount=None, final_price=50000)
            if doctype == "Task" and fieldname == "rate":
                return 35000
            return None

        with patch.object(
            task_invoice_compat.frappe,
            "get_meta",
            return_value=meta,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "get_value",
            side_effect=get_value,
        ), patch.object(
            task_invoice_compat.frappe.db,
            "set_value",
        ) as set_value:
            updated = task_invoice_compat._project_task_rate(
                "OMC-SR-TEST-00001",
                "TASK-OMC-00001",
            )

        self.assertTrue(updated)
        set_value.assert_called_once_with(
            "Task",
            "TASK-OMC-00001",
            "rate",
            50000.0,
            update_modified=False,
        )

    def test_task_update_projects_invoice_then_preserves_status_sync(self):
        doc = SimpleNamespace(name="TASK-OMC-00001")
        with patch.object(
            task_invoice_compat,
            "_request_for_task",
            return_value="OMC-SR-TEST-00001",
        ), patch.object(
            task_invoice_compat,
            "project_task_invoice_flag",
        ) as project, patch(
            "omc_app.api.erp_task_status_sync.sync_task_status",
            return_value={"updated": True},
        ) as status_sync:
            result = task_invoice_compat.sync_task_status(doc, "on_update")

        project.assert_called_once_with(
            request_name="OMC-SR-TEST-00001",
            task_name="TASK-OMC-00001",
        )
        status_sync.assert_called_once_with(doc, "on_update")
        self.assertEqual(result, {"updated": True})
