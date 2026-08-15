from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestErpTaskWriteRetirement(FrappeTestCase):
    def test_mobile_task_write_endpoints_are_absent(self):
        source = Path(__file__).with_name("task_write_guard.py").read_text()
        for endpoint in (
            "update_task_operation_status",
            "get_task_assignment_options",
            "assign_task",
            "update_task_details",
        ):
            self.assertNotIn(f"def {endpoint}", source)
        self.assertNotIn("@frappe.whitelist", source)

    def test_erp_operational_adapter_remains_available(self):
        source = Path(__file__).with_name("erp_service_task_adapter.py").read_text()
        self.assertIn("def sync_request", source)
        self.assertIn("def ensure_task_assignment", source)
