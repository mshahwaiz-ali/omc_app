from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_service_task_adapter


class TestErpServiceTaskAdapter(FrappeTestCase):
    def _request(self):
        request = SimpleNamespace(
            doctype="OMC Service Request",
            name="OMC-SR-TEST-1",
            title="Tax Filing",
            description="Prepare and submit filing.",
            priority="High",
            assigned_staff="staff@example.com",
            expected_completion_date=None,
            erp_customer="",
            erp_service="",
            erp_task="",
        )
        request.meta = MagicMock()
        request.meta.get_field.return_value = True
        request.set = MagicMock()
        return request

    def test_service_remarks_fit_legacy_data_field_and_keep_request_identity(self):
        request = self._request()
        request.description = "Request detail " * 100

        remarks = erp_service_task_adapter._service_remarks(request)

        self.assertLessEqual(len(remarks), 140)
        self.assertIn(request.name, remarks)

    def test_missing_customer_and_task_type_returns_pending_configuration(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="")
        profile = SimpleNamespace(linked_erpnext_customer="")

        with patch.object(
            erp_service_task_adapter,
            "_set_request_state",
        ) as request_state:
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=profile,
            )

        self.assertEqual(result["status"], "Pending Configuration")
        self.assertFalse(result["created"])
        self.assertIn("no valid linked ERP Customer", result["reason"])
        self.assertIn("no ERP Task Type mapping", result["reason"])
        request_state.assert_called_once()
        self.assertEqual(
            request_state.call_args.kwargs["status"],
            "Pending Configuration",
        )

    def test_walk_in_customer_remains_pending_configuration(self):
        request = self._request()
        service = SimpleNamespace(
            name="company-registration",
            erp_task_type="Company Registration",
        )
        manual_customer = SimpleNamespace(name="OMC-MANUAL-1")

        with patch.object(
            erp_service_task_adapter,
            "_set_request_state",
        ) as request_state:
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                manual_customer=manual_customer,
            )

        self.assertEqual(result["status"], "Pending Configuration")
        self.assertIn("requires ERP Customer conversion", result["reason"])
        request_state.assert_called_once()

    def test_configured_request_creates_and_links_service_task_assignment(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        profile = SimpleNamespace(linked_erpnext_customer="ERP-CUST-1")
        erp_service = SimpleNamespace(name="ERP-SERVICE-1")
        erp_task = SimpleNamespace(name="ERP-TASK-1")

        with (
            patch.object(
                erp_service_task_adapter,
                "_linked_customer",
                return_value="ERP-CUST-1",
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
                return_value=erp_service,
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
                return_value=erp_task,
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_link_service_task",
            ) as link_service_task,
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
                return_value="TODO-1",
            ) as assign_task,
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
            ) as request_state,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=profile,
            )

        self.assertEqual(result["status"], "Synced")
        self.assertTrue(result["created"])
        self.assertEqual(result["erp_customer"], "ERP-CUST-1")
        self.assertEqual(result["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(result["erp_task"], "ERP-TASK-1")
        self.assertEqual(result["task_assignment"], "TODO-1")

        create_service.assert_called_once_with(
            request,
            service,
            profile,
            "ERP-CUST-1",
            "Tax Filing",
        )
        create_task.assert_called_once_with(
            request,
            erp_service,
            "ERP-CUST-1",
            "Tax Filing",
        )
        link_service_task.assert_called_once_with(erp_service, erp_task)
        assign_task.assert_called_once_with(
            erp_task,
            "staff@example.com",
            "High",
        )
        request_state.assert_called_once_with(
            request,
            status="Synced",
            customer="ERP-CUST-1",
            service="ERP-SERVICE-1",
            task="ERP-TASK-1",
        )

    def test_partial_existing_links_require_repair(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = ""
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="Tax Filing",
        )

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
            ) as request_state,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Repair Required")
        self.assertFalse(result["created"])
        self.assertIn("ERP Task link is missing", result["reason"])
        create_service.assert_not_called()
        create_task.assert_not_called()
        request_state.assert_called_once()
        self.assertEqual(
            request_state.call_args.kwargs["status"],
            "Repair Required",
        )

    def test_stale_existing_links_require_repair(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-MISSING"
        request.erp_task = "ERP-TASK-MISSING"
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="Tax Filing",
        )

        def exists(doctype, name):
            self.assertIn(doctype, {"Service", "Task"})
            return False

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
            ) as request_state,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Repair Required")
        self.assertIn(
            "linked ERP Service does not exist",
            result["reason"],
        )
        self.assertIn(
            "linked ERP Task does not exist",
            result["reason"],
        )
        create_service.assert_not_called()
        create_task.assert_not_called()
        request_state.assert_called_once()

    def test_existing_valid_links_are_idempotent(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = "ERP-TASK-1"
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Synced")
        self.assertFalse(result["created"])
        create_service.assert_not_called()
        create_task.assert_not_called()

    def test_repair_reuses_valid_service_and_recreates_only_missing_task(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = "ERP-TASK-MISSING"
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        service_doc = SimpleNamespace(name="ERP-SERVICE-1")
        task = SimpleNamespace(name="ERP-TASK-NEW")

        def exists(doctype, name):
            return (doctype, name) == ("Service", "ERP-SERVICE-1")

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(
                erp_service_task_adapter,
                "_linked_customer",
                return_value="ERP-CUST-1",
            ),
            patch.object(
                erp_service_task_adapter.frappe,
                "get_doc",
                return_value=service_doc,
            ) as get_doc,
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
                return_value=task,
            ) as create_task,
            patch.object(erp_service_task_adapter, "_link_service_task"),
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
                return_value="TODO-1",
            ),
            patch.object(erp_service_task_adapter, "_set_request_state") as state,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=SimpleNamespace(name="PROFILE-1"),
                repair=True,
            )

        self.assertEqual(result["status"], "Synced")
        self.assertEqual(result["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(result["erp_task"], "ERP-TASK-NEW")
        get_doc.assert_called_once_with("Service", "ERP-SERVICE-1")
        create_service.assert_not_called()
        create_task.assert_called_once()
        state.assert_called_once_with(
            request,
            status="Synced",
            customer="ERP-CUST-1",
            service="ERP-SERVICE-1",
            task="ERP-TASK-NEW",
        )

    def test_sync_request_never_commits_or_rolls_back_directly(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        profile = SimpleNamespace(linked_erpnext_customer="ERP-CUST-1")
        erp_service = SimpleNamespace(name="ERP-SERVICE-1")
        erp_task = SimpleNamespace(name="ERP-TASK-1")

        with (
            patch.object(erp_service_task_adapter, "_linked_customer", return_value="ERP-CUST-1"),
            patch.object(erp_service_task_adapter, "_create_service", return_value=erp_service),
            patch.object(erp_service_task_adapter, "_create_task", return_value=erp_task),
            patch.object(erp_service_task_adapter, "_link_service_task"),
            patch.object(erp_service_task_adapter, "_assign_task", return_value="TODO-1"),
            patch.object(erp_service_task_adapter, "_set_request_state"),
            patch.object(erp_service_task_adapter.frappe.db, "commit") as commit,
            patch.object(erp_service_task_adapter.frappe.db, "rollback") as rollback,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=profile,
            )

        self.assertEqual(result["status"], "Synced")
        commit.assert_not_called()
        rollback.assert_not_called()

    def test_service_creation_failure_propagates_and_stops_pipeline(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        profile = SimpleNamespace(linked_erpnext_customer="ERP-CUST-1")

        with (
            patch.object(erp_service_task_adapter, "_linked_customer", return_value="ERP-CUST-1"),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
                side_effect=RuntimeError("service insert failed"),
            ),
            patch.object(erp_service_task_adapter, "_create_task") as create_task,
            patch.object(erp_service_task_adapter, "_link_service_task") as link_service_task,
            patch.object(erp_service_task_adapter, "_assign_task") as assign_task,
            patch.object(erp_service_task_adapter, "_set_request_state") as request_state,
        ):
            with self.assertRaisesRegex(RuntimeError, "service insert failed"):
                erp_service_task_adapter.sync_request(
                    request,
                    service=service,
                    profile=profile,
                )

        create_task.assert_not_called()
        link_service_task.assert_not_called()
        assign_task.assert_not_called()
        request_state.assert_not_called()

    def test_task_creation_failure_propagates_and_stops_later_writes(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        profile = SimpleNamespace(linked_erpnext_customer="ERP-CUST-1")
        erp_service = SimpleNamespace(name="ERP-SERVICE-1")

        with (
            patch.object(erp_service_task_adapter, "_linked_customer", return_value="ERP-CUST-1"),
            patch.object(erp_service_task_adapter, "_create_service", return_value=erp_service),
            patch.object(
                erp_service_task_adapter,
                "_create_task",
                side_effect=RuntimeError("task insert failed"),
            ),
            patch.object(erp_service_task_adapter, "_link_service_task") as link_service_task,
            patch.object(erp_service_task_adapter, "_assign_task") as assign_task,
            patch.object(erp_service_task_adapter, "_set_request_state") as request_state,
        ):
            with self.assertRaisesRegex(RuntimeError, "task insert failed"):
                erp_service_task_adapter.sync_request(
                    request,
                    service=service,
                    profile=profile,
                )

        link_service_task.assert_not_called()
        assign_task.assert_not_called()
        request_state.assert_not_called()

    def test_assignment_failure_propagates_before_synced_state_is_written(self):
        request = self._request()
        service = SimpleNamespace(name="tax-filing", erp_task_type="Tax Filing")
        profile = SimpleNamespace(linked_erpnext_customer="ERP-CUST-1")
        erp_service = SimpleNamespace(name="ERP-SERVICE-1")
        erp_task = SimpleNamespace(name="ERP-TASK-1")

        with (
            patch.object(erp_service_task_adapter, "_linked_customer", return_value="ERP-CUST-1"),
            patch.object(erp_service_task_adapter, "_create_service", return_value=erp_service),
            patch.object(erp_service_task_adapter, "_create_task", return_value=erp_task),
            patch.object(erp_service_task_adapter, "_link_service_task"),
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
                side_effect=RuntimeError("assignment failed"),
            ),
            patch.object(erp_service_task_adapter, "_set_request_state") as request_state,
        ):
            with self.assertRaisesRegex(RuntimeError, "assignment failed"):
                erp_service_task_adapter.sync_request(
                    request,
                    service=service,
                    profile=profile,
                )

        request_state.assert_not_called()
