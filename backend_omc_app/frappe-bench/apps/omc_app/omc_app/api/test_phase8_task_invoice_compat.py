from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import accounting_reconciliation, task_invoice_compat


class TestPhase8TaskInvoiceCompatibility(FrappeTestCase):
    def _request(self, **overrides):
        request = MagicMock()
        values = {
            "name": "OMC-SR-PHASE8",
            "erp_task": "TASK-PHASE8",
            "payment_execution_mode": "Pay Later",
            "post_paid_approved_by": "finance@example.com",
            "post_paid_approved_at": "2026-09-19 02:00:00",
            "pay_later_reason": "Approved credit exception.",
            "request_state": "Activated",
            "status": "In Progress",
            "erp_customer": "CUST-PHASE8",
            "payable_amount": 30000,
            "final_price": 30000,
            "pricing_currency": "PKR",
        }
        values.update(overrides)
        for key, value in values.items():
            setattr(request, key, value)

        def get_value(key, default=None):
            if key == "company_snapshot":
                return "Omc House"
            return getattr(request, key, default)

        request.get.side_effect = get_value
        return request

    def _task(self, **overrides):
        values = {
            "name": "TASK-PHASE8",
            "status": "Completed",
            "customer": "CUST-PHASE8",
            "rate": 30000,
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def _invoice(self, **overrides):
        values = {
            "name": "SINV-PHASE8",
            "docstatus": 0,
            "is_return": 0,
            "customer": "CUST-PHASE8",
            "company": "Omc House",
            "currency": "PKR",
            "grand_total": 30000,
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_mode_aware_mk_inv_routes_pay_later_to_guarded_path(self):
        request = self._request()
        with (
            patch.object(
                task_invoice_compat,
                "_request_for_task",
                return_value=request.name,
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                task_invoice_compat,
                "_pay_later_invoice",
                return_value="SINV-PHASE8",
            ) as pay_later_invoice,
        ):
            result = task_invoice_compat.mk_inv("TASK-PHASE8")

        self.assertEqual(result, "SINV-PHASE8")
        pay_later_invoice.assert_called_once_with(
            "TASK-PHASE8",
            request.name,
        )

    def test_pay_later_delegates_existing_task_function_then_adopts_draft(self):
        request = self._request()
        task = self._task()
        invoice = self._invoice()

        with (
            patch.object(
                task_invoice_compat,
                "_assert_pay_later_invoice_access",
                return_value=("finance@example.com", "can_manage_tasks"),
            ),
            patch.object(
                task_invoice_compat,
                "_load_pay_later_invoice_context",
                return_value=(request, task, 30000),
            ),
            patch.object(
                task_invoice_compat,
                "_existing_pay_later_invoice",
                return_value="",
            ),
            patch(
                "erpnext.projects.doctype.task.task.mk_inv",
                return_value=invoice.name,
            ) as legacy_mk_inv,
            patch.object(
                task_invoice_compat.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                return_value=invoice,
            ),
            patch.object(
                task_invoice_compat,
                "_adopt_pay_later_invoice",
                return_value=invoice.name,
            ) as adopt,
            patch.object(
                task_invoice_compat.frappe.db,
                "savepoint",
            ) as savepoint,
            patch.object(
                task_invoice_compat.frappe.db,
                "rollback",
            ) as rollback,
        ):
            result = task_invoice_compat._pay_later_invoice(
                task.name,
                request.name,
            )

        self.assertEqual(result, invoice.name)
        savepoint.assert_called_once_with("omc_pay_later_task_invoice")
        legacy_mk_inv.assert_called_once_with(task.name)
        adopt.assert_called_once_with(
            request,
            task,
            invoice,
            actor="finance@example.com",
            capability="can_manage_tasks",
            expected_amount=30000,
        )
        rollback.assert_not_called()

    def test_repeated_pay_later_generation_reuses_existing_invoice(self):
        request = self._request()
        task = self._task()

        with (
            patch.object(
                task_invoice_compat,
                "_assert_pay_later_invoice_access",
                return_value=("finance@example.com", "can_manage_tasks"),
            ),
            patch.object(
                task_invoice_compat,
                "_load_pay_later_invoice_context",
                return_value=(request, task, 30000),
            ),
            patch.object(
                task_invoice_compat,
                "_existing_pay_later_invoice",
                return_value="SINV-PHASE8",
            ),
            patch(
                "erpnext.projects.doctype.task.task.mk_inv",
            ) as legacy_mk_inv,
            patch.object(task_invoice_compat.frappe.db, "savepoint"),
            patch.object(task_invoice_compat.frappe.db, "rollback") as rollback,
        ):
            result = task_invoice_compat._pay_later_invoice(
                task.name,
                request.name,
            )

        self.assertEqual(result, "SINV-PHASE8")
        legacy_mk_inv.assert_not_called()
        rollback.assert_not_called()

    def test_pay_later_context_requires_exact_completed_task_customer_and_rate(self):
        request = self._request()
        task = self._task()

        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                side_effect=[request.name, task.name],
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                task_invoice_compat.service_task_links,
                "task_names",
                return_value=[task.name],
            ),
        ):
            loaded_request, loaded_task, amount = (
                task_invoice_compat._load_pay_later_invoice_context(
                    task.name,
                    request.name,
                )
            )

        self.assertIs(loaded_request, request)
        self.assertIs(loaded_task, task)
        self.assertEqual(amount, 30000)

    def test_pay_later_context_requires_completed_task(self):
        request = self._request()
        task = self._task(status="Open")

        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                side_effect=[request.name, task.name],
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                task_invoice_compat.service_task_links,
                "task_names",
                return_value=[task.name],
            ),
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "must be Completed",
            ):
                task_invoice_compat._load_pay_later_invoice_context(
                    task.name,
                    request.name,
                )

    def test_pay_later_context_rejects_multiple_linked_tasks(self):
        request = self._request()
        task = self._task()

        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                side_effect=[request.name, task.name],
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                task_invoice_compat.service_task_links,
                "task_names",
                return_value=[task.name, "TASK-SECONDARY"],
            ),
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "exactly one ERP Task",
            ):
                task_invoice_compat._load_pay_later_invoice_context(
                    task.name,
                    request.name,
                )

    def test_pay_later_context_rejects_customer_mismatch(self):
        request = self._request()
        task = self._task(customer="OTHER-CUSTOMER")

        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                side_effect=[request.name, task.name],
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                task_invoice_compat.service_task_links,
                "task_names",
                return_value=[task.name],
            ),
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "Customer does not match",
            ):
                task_invoice_compat._load_pay_later_invoice_context(
                    task.name,
                    request.name,
                )

    def test_pay_later_context_rejects_rate_mismatch(self):
        request = self._request()
        task = self._task(rate=29999)

        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                side_effect=[request.name, task.name],
            ),
            patch.object(
                task_invoice_compat.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                task_invoice_compat.service_task_links,
                "task_names",
                return_value=[task.name],
            ),
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "rate does not match",
            ):
                task_invoice_compat._load_pay_later_invoice_context(
                    task.name,
                    request.name,
                )

    def test_assigned_task_capability_cannot_invoice_another_users_task(self):
        with (
            patch.object(
                task_invoice_compat,
                "_current_user",
                return_value="consultant@example.com",
            ),
            patch.object(
                task_invoice_compat.access,
                "get_mobile_capabilities",
                return_value={
                    "can_access_internal_workspace": True,
                    "can_manage_tasks": False,
                    "can_manage_assigned_tasks": True,
                },
            ),
            patch.object(
                task_invoice_compat.task_read_guard,
                "_task_assignment_names",
                return_value={"TASK-OTHER"},
            ),
            patch.object(
                task_invoice_compat.security,
                "enforce_rate_limit",
            ) as rate_limit,
        ):
            with self.assertRaises(frappe.PermissionError):
                task_invoice_compat._assert_pay_later_invoice_access(
                    "TASK-PHASE8"
                )

        rate_limit.assert_not_called()

    def test_task_generated_draft_invoice_must_match_request_total(self):
        request = self._request()
        invoice = self._invoice(grand_total=29999)

        with self.assertRaisesRegex(
            frappe.ValidationError,
            "total does not match",
        ):
            task_invoice_compat._validate_pay_later_invoice(
                request,
                invoice,
                expected_amount=30000,
            )

    def test_adoption_creates_unmatched_base_link_without_reconciliation(self):
        request = self._request()
        task = self._task()
        invoice = self._invoice()
        link = SimpleNamespace(source_version="phase8-source")

        with (
            patch.object(
                task_invoice_compat,
                "_validate_pay_later_invoice",
            ),
            patch.object(
                task_invoice_compat.frappe.db,
                "get_value",
                return_value=None,
            ),
            patch.object(
                task_invoice_compat.accounting_reconciliation,
                "_upsert_link",
                return_value=link,
            ) as upsert,
            patch.object(
                task_invoice_compat.accounting_reconciliation,
                "reconcile_request",
            ) as reconcile,
            patch.object(
                task_invoice_compat.security,
                "audit_event",
            ) as audit,
            patch.object(
                task_invoice_compat,
                "project_task_invoice_flag",
            ) as project,
        ):
            result = task_invoice_compat._adopt_pay_later_invoice(
                request,
                task,
                invoice,
                actor="finance@example.com",
                capability="can_manage_tasks",
                expected_amount=30000,
            )

        self.assertEqual(result, invoice.name)
        upsert.assert_called_once_with(
            request,
            invoice,
            state="Unmatched",
        )
        reconcile.assert_not_called()
        audit.assert_called_once()
        project.assert_called_once_with(
            request_name=request.name,
            task_name=task.name,
        )

    def test_task_rate_projects_before_invoice_exists(self):
        with (
            patch.object(
                task_invoice_compat.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                task_invoice_compat,
                "_project_task_rate",
                return_value=True,
            ) as project_rate,
            patch.object(
                task_invoice_compat,
                "_base_invoice",
                return_value=None,
            ),
        ):
            result = task_invoice_compat.project_task_invoice_flag(
                request_name="OMC-SR-PHASE8",
                task_name="TASK-PHASE8",
            )

        self.assertTrue(result["rate_updated"])
        self.assertEqual(result["invoice"], "")
        project_rate.assert_called_once_with(
            "OMC-SR-PHASE8",
            "TASK-PHASE8",
        )

    def test_submitting_adopted_pay_later_invoice_triggers_reconciliation(self):
        invoice = SimpleNamespace(
            name="SINV-PHASE8",
            is_return=0,
            return_against=None,
        )

        with (
            patch.object(
                accounting_reconciliation.frappe,
                "get_all",
                return_value=["OMC-SR-PHASE8"],
            ),
            patch.object(
                accounting_reconciliation,
                "reconcile_request",
            ) as reconcile,
        ):
            accounting_reconciliation.sales_invoice_submitted(invoice)

        reconcile.assert_called_once_with("OMC-SR-PHASE8")
