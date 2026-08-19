from frappe.tests.utils import FrappeTestCase

from omc_app.api import dashboard


class TestDashboardLifecycleContract(FrappeTestCase):
    def test_terminal_request_state_wins_over_operational_open(self):
        self.assertEqual(
            dashboard._service_lifecycle_bucket("Cancelled", "Open"),
            "cancelled",
        )
        self.assertEqual(
            dashboard._service_lifecycle_bucket("Expired", "Open"),
            "expired",
        )

    def test_completed_requires_activated_plus_operational_completed(self):
        self.assertEqual(
            dashboard._service_lifecycle_bucket(
                "Ready for Activation",
                "Completed",
            ),
            "active",
        )
        self.assertEqual(
            dashboard._service_lifecycle_bucket("Activated", "Completed"),
            "completed",
        )

    def test_pending_payment_remains_active(self):
        self.assertEqual(
            dashboard._service_lifecycle_bucket("Pending Payment", "Open"),
            "active",
        )
