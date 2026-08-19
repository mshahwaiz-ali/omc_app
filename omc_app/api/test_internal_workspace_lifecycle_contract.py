from frappe.tests.utils import FrappeTestCase

from omc_app.api import internal_workspace


class TestInternalWorkspaceLifecycleContract(FrappeTestCase):
    def test_queue_summary_uses_request_state_as_lifecycle_authority(self):
        cases = [
            {
                "request_state": "Cancelled",
                "status": "Open",
                "operational_status": "Open",
                "document_summary": {},
            },
            {
                "request_state": "Expired",
                "status": "Open",
                "operational_status": "Open",
                "document_summary": {},
            },
            {
                "request_state": "Pending Payment",
                "status": "Open",
                "operational_status": "Open",
                "document_summary": {},
            },
            {
                "request_state": "Activated",
                "status": "Completed",
                "operational_status": "Completed",
                "document_summary": {},
            },
            {
                "request_state": "Activated",
                "status": "In Progress",
                "operational_status": "In Progress",
                "document_summary": {},
            },
        ]

        summary = internal_workspace._queue_summary(cases)

        self.assertEqual(summary["total"], 5)
        self.assertEqual(summary["active"], 2)
        self.assertEqual(summary["cancelled"], 1)
        self.assertEqual(summary["expired"], 1)
        self.assertEqual(summary["waiting_for_payment"], 1)
        self.assertEqual(summary["completed"], 1)
        self.assertEqual(summary["in_progress"], 1)
