import json
from pathlib import Path
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import scheduler_jobs


class TestProductionHardeningSmoke(FrappeTestCase):
    def test_omc_request_schema_contains_hardening_state(self):
        schema = json.loads(
            (
                Path(__file__).resolve().parents[1]
                / "omc_app/doctype/omc_service_request/omc_service_request.json"
            ).read_text(encoding="utf-8")
        )
        expected = {
            "submission_data_json",
            "submission_integrity_status",
            "submission_integrity_score",
            "submission_integrity_reasons_json",
            "submission_integrity_checked_at",
            "submission_documents_due_at",
            "potential_duplicate_of",
            "erp_retry_count",
            "erp_last_attempt_at",
            "erp_next_attempt_at",
            "erp_last_failure_category",
            "erp_retry_exhausted_at",
            "erp_last_success_at",
        }
        self.assertTrue(expected.issubset({field["fieldname"] for field in schema["fields"]}))

    def test_service_assignment_fields_are_placed_in_desk_order(self):
        schema = json.loads(
            (
                Path(__file__).resolve().parents[1]
                / "omc_app/doctype/omc_service/omc_service.json"
            ).read_text(encoding="utf-8")
        )
        field_order = schema["field_order"]
        self.assertIn("default_assignee", field_order)
        self.assertIn("default_assignment_role", field_order)

    @patch("frappe.sendmail")
    @patch("omc_app.api.scheduler_jobs._run_jobs")
    def test_hourly_pipeline_does_not_directly_send_email(self, run_jobs, sendmail):
        run_jobs.return_value = {"status": "completed", "jobs": []}
        scheduler_jobs.run_hourly_jobs()
        jobs = run_jobs.call_args.args[1]
        self.assertEqual(
            [job.__name__ for job in jobs],
            [
                "run_unassigned_recovery",
                "run_automatic_erp_sync_recovery",
                "run_review_assignment_checks",
                "run_integrity_rescore",
                "cleanup_pending_registrations",
            ],
        )
        sendmail.assert_not_called()

    def test_no_erpnext_source_file_is_part_of_omc_app(self):
        app_root = Path(__file__).resolve().parents[2]
        self.assertEqual(app_root.name, "omc_app")
        self.assertFalse(any("apps/erpnext" in str(path) for path in app_root.rglob("*.py")))
