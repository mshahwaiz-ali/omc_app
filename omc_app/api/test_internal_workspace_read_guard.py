from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import internal_workspace_read_guard


class TestInternalWorkspaceReadGuard(FrappeTestCase):
    def test_pagination_is_bounded(self):
        self.assertEqual(
            internal_workspace_read_guard._pagination(-2, 500),
            (0, internal_workspace_read_guard.MAX_PAGE_SIZE),
        )
        self.assertEqual(
            internal_workspace_read_guard._pagination(25, 0),
            (25, internal_workspace_read_guard.DEFAULT_PAGE_SIZE),
        )

    @patch(
        "omc_app.api.internal_workspace_read_guard.permissions.service_request_query",
        return_value="`tabOMC Service Request`.assigned_staff = 'agent@example.com'",
    )
    def test_where_clause_reuses_canonical_scope(self, service_scope):
        where, params = internal_workspace_read_guard._where_clause(
            "agent@example.com",
            search="Acme",
            status="In Progress",
            document_status="uploaded",
        )

        self.assertIn("assigned_staff", where)
        self.assertIn("like %s", where)
        self.assertIn("scoped_document.status = %s", where)
        self.assertIn("In Progress", params)
        self.assertIn("%Acme%", params)
        self.assertIn("Uploaded", params)
        service_scope.assert_called_once_with("agent@example.com")

    @patch("omc_app.api.internal_workspace_read_guard._total_count", return_value=75)
    @patch("omc_app.api.internal_workspace_read_guard.internal_workspace._queue_summary")
    @patch("omc_app.api.internal_workspace_read_guard.internal_workspace._case_to_queue_item")
    @patch("omc_app.api.internal_workspace_read_guard.service_case_contract._bulk_contract")
    @patch("omc_app.api.internal_workspace_read_guard._rows_for_names")
    @patch("omc_app.api.internal_workspace_read_guard._case_names")
    @patch("omc_app.api.internal_workspace_read_guard._where_clause")
    @patch("omc_app.api.internal_workspace_read_guard.access.get_mobile_capabilities")
    @patch("omc_app.api.internal_workspace_read_guard.mobile._assert_internal_workspace_access")
    def test_reader_returns_page_metadata(
        self,
        assert_access,
        capabilities,
        where_clause,
        case_names,
        rows_for_names,
        bulk_contract,
        case_to_item,
        queue_summary,
        total_count,
    ):
        assert_access.return_value = "agent@example.com"
        capabilities.return_value = {
            "can_view_all_service_cases": False,
            "can_view_relevant_service_cases": True,
            "can_view_assigned_service_cases": False,
        }
        where_clause.return_value = ("1=1", [])
        names = [f"SR-{index:04d}" for index in range(51)]
        case_names.return_value = names
        rows = [SimpleNamespace(name=name) for name in names[:50]]
        rows_for_names.return_value = rows
        bulk_contract.return_value = {}
        case_to_item.side_effect = lambda row, contract=None: {"id": row.name}
        queue_summary.return_value = {"total": 50}

        result = internal_workspace_read_guard.get_service_cases(
            limit_start=0,
            limit_page_length=50,
        )

        self.assertEqual(len(result["cases"]), 50)
        self.assertTrue(result["has_more"])
        self.assertEqual(result["next_start"], 50)
        self.assertEqual(result["total_count"], 75)
        self.assertEqual(result["limit_page_length"], 50)
        self.assertEqual(result["capabilities"], capabilities.return_value)
