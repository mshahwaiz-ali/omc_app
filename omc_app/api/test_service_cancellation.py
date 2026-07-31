from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

from omc_app.api import secured_mobile


class TestServiceCancellation(TestCase):
    def test_customer_cancellation_uses_canonical_finalizer_before_commit(self):
        request = SimpleNamespace(
            name="OMC-SR-1",
            title="Tax Filing",
            status="Open",
            closed_on=None,
            customer_profile="OMC-CUST-1",
            assigned_staff="staff@example.com",
            erp_task="TASK-1",
            erp_service="SERVICE-1",
            add_comment=MagicMock(),
            save=MagicMock(),
        )
        profile = SimpleNamespace(name="OMC-CUST-1")

        with (
            patch.object(
                secured_mobile.frappe,
                "session",
                SimpleNamespace(user="customer@example.com"),
            ),
            patch.object(
                secured_mobile.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                secured_mobile.mobile,
                "_can_access_internal_workspace",
                return_value=False,
            ),
            patch.object(
                secured_mobile.mobile,
                "get_current_customer_profile",
                return_value=profile,
            ),
            patch.object(
                secured_mobile,
                "_can_customer_cancel_service_case",
                return_value=True,
            ),
            patch(
                "omc_app.api.workflow_automation.finalize_cancelled_case",
            ) as finalize,
            patch.object(
                secured_mobile.frappe.utils,
                "now_datetime",
                return_value="2026-07-31 05:30:00",
            ),
            patch.object(
                secured_mobile.frappe.db,
                "commit",
            ) as commit,
        ):
            result = secured_mobile.cancel_service_request(
                case_id="OMC-SR-1",
                reason="No longer required",
            )

        self.assertEqual(result["status"], "Cancelled")
        request.save.assert_called_once_with(ignore_permissions=True)
        finalize.assert_called_once_with(
            request,
            reason="No longer required",
            cancelled_by_customer=True,
            sync_erp=True,
        )
        commit.assert_called_once()
