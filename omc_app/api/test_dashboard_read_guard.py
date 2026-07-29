from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import dashboard_read_guard


class TestDashboardReadGuard(FrappeTestCase):
    def test_hooks_route_dashboard_reads(self):
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.dashboard.get_dashboard_data"],
            "omc_app.api.dashboard_read_guard.get_dashboard_data",
        )

    @patch("omc_app.api.dashboard_read_guard.dashboard._service_color_family")
    @patch("omc_app.api.dashboard_read_guard.frappe.db.get_value")
    def test_service_activity_resolves_service_from_request(
        self,
        get_value,
        service_color_family,
    ):
        get_value.return_value = "Income Tax Filing"
        service_color_family.return_value = "Tax"

        result = dashboard_read_guard._correct_activity_color_family(
            {
                "service_request": "SR-0001",
                "color_family": "Services",
                "title": "Case updated",
            }
        )

        self.assertEqual(result["color_family"], "Tax")
        get_value.assert_called_once_with(
            "OMC Service Request",
            "SR-0001",
            "service",
        )
        service_color_family.assert_called_once_with("Income Tax Filing")

    @patch("omc_app.api.dashboard_read_guard.frappe.db.get_value")
    def test_non_service_activity_family_is_preserved(self, get_value):
        result = dashboard_read_guard._correct_activity_color_family(
            {
                "service_request": "SR-0001",
                "color_family": "Payments",
            }
        )

        self.assertEqual(result["color_family"], "Payments")
        get_value.assert_not_called()

    @patch("omc_app.api.dashboard_read_guard.dashboard.get_dashboard_data")
    @patch("omc_app.api.dashboard_read_guard.dashboard._service_color_family")
    @patch("omc_app.api.dashboard_read_guard.frappe.db.get_value")
    def test_dashboard_response_contract_and_scope_are_preserved(
        self,
        get_value,
        service_color_family,
        get_dashboard_data,
    ):
        original = {
            "message": {
                "access_state": "approved",
                "open_services": 2,
                "recent_activity": [
                    {
                        "id": "TL-1",
                        "service_request": "SR-0001",
                        "color_family": "Services",
                    }
                ],
                "service_snapshots": [{"id": "SR-0001"}],
            }
        }
        get_dashboard_data.return_value = original
        get_value.return_value = "Income Tax Filing"
        service_color_family.return_value = "Tax"

        result = dashboard_read_guard.get_dashboard_data()

        self.assertEqual(result["message"]["access_state"], "approved")
        self.assertEqual(result["message"]["open_services"], 2)
        self.assertEqual(
            result["message"]["service_snapshots"],
            [{"id": "SR-0001"}],
        )
        self.assertEqual(
            result["message"]["recent_activity"][0]["color_family"],
            "Tax",
        )
        get_dashboard_data.assert_called_once_with()

    @patch("omc_app.api.dashboard_read_guard.dashboard.get_dashboard_data")
    def test_non_mapping_response_is_returned_unchanged(self, get_dashboard_data):
        get_dashboard_data.return_value = ["unexpected"]

        result = dashboard_read_guard.get_dashboard_data()

        self.assertEqual(result, ["unexpected"])
