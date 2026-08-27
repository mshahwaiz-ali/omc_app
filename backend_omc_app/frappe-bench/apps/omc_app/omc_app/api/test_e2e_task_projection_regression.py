from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_task_status_sync


class TestE2eTaskProjectionRegression(FrappeTestCase):
    def test_pending_at_client_projects_waiting_for_customer(self):
        self.assertEqual(
            erp_task_status_sync.customer_status(
                "Working",
                "Pending at Client",
            ),
            "Waiting for Customer",
        )

    def test_operation_status_remains_authoritative_over_working(self):
        self.assertEqual(
            erp_task_status_sync.customer_status(
                "Working",
                "Pending at Operation Side",
            ),
            "In Progress",
        )
