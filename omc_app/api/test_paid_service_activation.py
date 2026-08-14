from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import service_activation, service_assignment


class TestPaidServiceActivation(FrappeTestCase):
    def _request(self, status="Waiting for Payment"):
        request = MagicMock()
        request.doctype = "OMC Service Request"
        request.name = "OMC-SR-PAID-1"
        request.status = status
        request.service = "tax-filing"
        request.customer_profile = "OMC-CUST-1"
        request.manual_customer = ""
        request.assigned_staff = ""
        request.referral_owner = ""
        request.priority = "Medium"
        request.erp_customer = ""
        request.erp_service = ""
        request.erp_task = ""

        request.reload.side_effect = lambda: None
        return request

    def _service(self):
        return SimpleNamespace(
            name="tax-filing",
            title="Tax Filing",
            category="Tax",
            icon="tax",
            erp_task_type="Tax Filing",
            default_assignee="",
            default_assignment_role="OMC Tax Associate",
        )

    def test_activation_requires_paid_payment(self):
        request = self._request()

        with (
            patch.object(
                service_activation,
                "_paid_payment",
                return_value="",
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            service_activation.activate_paid_request(request)

    def test_paid_activation_runs_operational_flow_once(self):
        request = self._request()
        service = self._service()
        profile = SimpleNamespace(name="OMC-CUST-1")

        sync_result = {
            "status": "Synced",
            "erp_customer": "ERP-CUST-1",
            "erp_service": "ERP-SERVICE-1",
            "erp_task": "ERP-TASK-1",
            "task_assignment": "TASK-TODO-1",
        }

        assignment_result = {
            "todo": "REQUEST-TODO-1",
            "erp_task_assignment": {
                "todo": "TASK-TODO-1",
                "created": False,
                "conflict": None,
            },
        }

        def reload_request():
            request.erp_customer = "ERP-CUST-1"
            request.erp_service = "ERP-SERVICE-1"
            request.erp_task = "ERP-TASK-1"

        request.reload.side_effect = reload_request

        with (
            patch.object(
                service_activation,
                "_paid_payment",
                return_value="OMC-PAY-1",
            ),
            patch.object(
                service_activation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                service_activation.frappe,
                "get_doc",
                side_effect=lambda doctype, name: (
                    service
                    if doctype == "OMC Service"
                    else profile
                ),
            ),
            patch.object(
                service_activation.service_assignment,
                "resolve_assignee",
                return_value={
                    "candidate": "tax@example.com",
                    "source": "service_role",
                    "role": "OMC Tax Associate",
                    "rejected": [],
                },
            ) as resolve_assignee,
            patch.object(
                service_activation.erp_service_task_adapter,
                "sync_request",
                return_value=sync_result,
            ) as sync_request,
            patch.object(
                service_activation.service_assignment,
                "apply_assignment",
                return_value=assignment_result,
            ) as apply_assignment,
            patch.object(
                service_activation.mobile,
                "_create_service_timeline_entry",
            ) as timeline,
            patch.object(
                service_activation.frappe.db,
                "set_value",
            ),
        ):
            result = service_activation.activate_paid_request(request)

        self.assertTrue(result["activated"])
        self.assertEqual(result["assigned_staff"], "tax@example.com")
        self.assertEqual(result["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(result["erp_task"], "ERP-TASK-1")
        self.assertEqual(result["case_status"], "In Progress")

        resolve_assignee.assert_called_once()
        sync_request.assert_called_once()
        apply_assignment.assert_called_once()
        timeline.assert_called_once()

    def test_already_active_retry_does_not_repeat_status_transition(self):
        request = self._request(status="In Progress")
        request.assigned_staff = "tax@example.com"
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = "ERP-TASK-1"

        service = self._service()
        profile = SimpleNamespace(name="OMC-CUST-1")

        sync_result = {
            "status": "Synced",
            "erp_customer": "ERP-CUST-1",
            "erp_service": "ERP-SERVICE-1",
            "erp_task": "ERP-TASK-1",
            "task_assignment": None,
            "created": False,
        }

        with (
            patch.object(
                service_activation,
                "_paid_payment",
                return_value="OMC-PAY-1",
            ),
            patch.object(
                service_activation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                service_activation.frappe,
                "get_doc",
                side_effect=lambda doctype, name: (
                    service
                    if doctype == "OMC Service"
                    else profile
                ),
            ),
            patch.object(
                service_activation.service_assignment,
                "active_assignable_user",
                return_value="tax@example.com",
            ),
            patch.object(
                service_activation.erp_service_task_adapter,
                "sync_request",
                return_value=sync_result,
            ) as sync_request,
            patch.object(
                service_activation.service_assignment,
                "apply_assignment",
                return_value={
                    "todo": "REQUEST-TODO-1",
                    "erp_task_assignment": None,
                },
            ),
            patch.object(
                service_activation.mobile,
                "_create_service_timeline_entry",
            ) as timeline,
            patch.object(
                service_activation.frappe.db,
                "set_value",
            ),
        ):
            result = service_activation.activate_paid_request(request)

        self.assertTrue(result["activated"])
        self.assertTrue(result["already_active"])
        sync_request.assert_called_once()
        timeline.assert_not_called()
        request.save.assert_not_called()

    def test_unpaid_intake_statuses_are_not_recovery_targets(self):
        self.assertEqual(service_assignment.OPEN_CASE_STATUSES, ["In Progress"])
        self.assertNotIn("Open", service_assignment.OPEN_CASE_STATUSES)
        self.assertNotIn(
            "Waiting for Payment",
            service_assignment.OPEN_CASE_STATUSES,
        )


class TestPaidActivationFailureContract(FrappeTestCase):
    def test_non_synced_erp_result_fails_before_in_progress(self):
        request = MagicMock()
        request.doctype = "OMC Service Request"
        request.name = "OMC-SR-FAIL-1"
        request.status = "Waiting for Payment"
        request.service = "tax-filing"
        request.customer_profile = "OMC-CUST-1"
        request.manual_customer = ""
        request.assigned_staff = ""
        request.referral_owner = ""
        request.priority = "Medium"

        service = SimpleNamespace(name="tax-filing")
        profile = SimpleNamespace(name="OMC-CUST-1")

        with (
            patch.object(
                service_activation,
                "_paid_payment",
                return_value="OMC-PAY-1",
            ),
            patch.object(
                service_activation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                service_activation.frappe,
                "get_doc",
                side_effect=lambda doctype, name: (
                    service
                    if doctype == "OMC Service"
                    else profile
                ),
            ),
            patch.object(
                service_activation.service_assignment,
                "resolve_assignee",
                return_value={
                    "candidate": "tax@example.com",
                    "source": "service_role",
                },
            ),
            patch.object(
                service_activation.erp_service_task_adapter,
                "sync_request",
                return_value={
                    "status": "Pending Configuration",
                    "reason": "ERP Task Type missing",
                },
            ),
            patch.object(
                service_activation.frappe.db,
                "set_value",
            ),
            patch.object(
                service_activation.service_assignment,
                "apply_assignment",
            ) as apply_assignment,
        ):
            with self.assertRaises(frappe.ValidationError):
                service_activation.activate_paid_request(request)

        apply_assignment.assert_not_called()
        request.save.assert_not_called()
