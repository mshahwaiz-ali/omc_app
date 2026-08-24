from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_read_guard


class TestTaskTrackingContext(FrappeTestCase):
    def test_task_query_fetches_customer_workflow_and_business_context(self):
        meta = SimpleNamespace(
            has_field=lambda fieldname: fieldname
            in {
                "description",
                "exp_start_date",
                "exp_end_date",
                "workflow_state",
                "custom_operation_status",
                "type",
                "customer",
                "full_name",
                "source",
                "company",
                "progress",
            }
        )

        with patch.object(task_read_guard.frappe, "get_meta", return_value=meta):
            fields = task_read_guard._task_fields()

        for fieldname in (
            "workflow_state",
            "custom_operation_status",
            "type",
            "customer",
            "full_name",
            "source",
            "company",
            "progress",
            "exp_start_date",
            "exp_end_date",
        ):
            self.assertIn(fieldname, fields)

    def test_payload_keeps_erp_status_workflow_and_operation_status_distinct(self):
        task = SimpleNamespace(
            name="TASK-2026-02831",
            subject="Task for Farzana Roohi",
            description=None,
            status="Open",
            workflow_state="Sales Received",
            custom_operation_status="Open",
            type="Family contribute",
            customer="Farzana Roohi",
            full_name="Farzana Roohi",
            source="Consultant",
            company="Omc House",
            progress=0.0,
            priority="Low",
            exp_start_date=date(2026, 8, 13),
            exp_end_date=date(2026, 8, 19),
            actual_end_date=None,
            completed_on=None,
            creation=None,
            modified=None,

            # A real Task DocType contains this field. It must never leak
            # through the mobile tracking payload.
            password="sensitive-value",
        )

        payload = task_read_guard._task_to_payload(
            task,
            assigned_users=["kainat@omchouse.com"],
        )

        self.assertEqual(payload["erp_status"], "Open")
        self.assertEqual(payload["workflow_state"], "Sales Received")
        self.assertEqual(payload["operation_status"], "Open")

        self.assertEqual(payload["task_type"], "Family contribute")
        self.assertEqual(payload["customer"], "Farzana Roohi")
        self.assertEqual(payload["customer_name"], "Farzana Roohi")
        self.assertEqual(payload["source"], "Consultant")
        self.assertEqual(payload["company"], "Omc House")
        self.assertEqual(payload["progress"], 0.0)

        self.assertEqual(payload["expected_start_date"], "2026-08-13")
        self.assertEqual(payload["due_date"], "2026-08-19")
        self.assertEqual(payload["assigned_to"], "kainat@omchouse.com")

        self.assertNotIn("password", payload)
