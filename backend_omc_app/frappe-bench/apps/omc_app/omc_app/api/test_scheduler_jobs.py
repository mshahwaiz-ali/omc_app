from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import scheduler_jobs


class TestSchedulerJobs(FrappeTestCase):
    @patch("omc_app.api.scheduler_jobs.frappe.log_error")
    @patch("omc_app.api.scheduler_jobs.frappe.get_traceback", return_value="trace")
    @patch("omc_app.api.scheduler_jobs.frappe.db.rollback")
    def test_failed_job_rolls_back_and_is_reported(
        self,
        rollback,
        get_traceback,
        log_error,
    ):
        job = MagicMock(side_effect=RuntimeError("boom"))
        job.__module__ = "omc_app.tests"
        job.__name__ = "failing_job"

        result = scheduler_jobs._run_job(job)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["job"], "omc_app.tests.failing_job")
        self.assertIsNone(result["result"])
        rollback.assert_called_once_with()
        log_error.assert_called_once_with(
            title="OMC scheduled job failed: omc_app.tests.failing_job",
            message="trace",
        )

    @patch("omc_app.api.scheduler_jobs.frappe.log_error")
    @patch("omc_app.api.scheduler_jobs.frappe.db.rollback")
    def test_successful_job_returns_result_without_rollback(
        self,
        rollback,
        log_error,
    ):
        job = MagicMock(return_value={"processed": 3})
        job.__module__ = "omc_app.tests"
        job.__name__ = "successful_job"

        result = scheduler_jobs._run_job(job)

        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["result"], {"processed": 3})
        rollback.assert_not_called()
        log_error.assert_not_called()

    def test_runner_continues_after_sibling_failure(self):
        first = MagicMock(side_effect=RuntimeError("first failed"))
        first.__module__ = "omc_app.tests"
        first.__name__ = "first"
        second = MagicMock(return_value={"processed": 2})
        second.__module__ = "omc_app.tests"
        second.__name__ = "second"

        with (
            patch("omc_app.api.scheduler_jobs.frappe.db.rollback"),
            patch("omc_app.api.scheduler_jobs.frappe.get_traceback", return_value="trace"),
            patch("omc_app.api.scheduler_jobs.frappe.log_error"),
        ):
            result = scheduler_jobs._run_jobs((first, second))

        self.assertEqual(result["completed"], 1)
        self.assertEqual(result["failed"], 1)
        second.assert_called_once_with()
        self.assertEqual(
            [item["status"] for item in result["jobs"]],
            ["failed", "completed"],
        )

    @patch("omc_app.api.scheduler_jobs._run_jobs")
    def test_hourly_runner_uses_canonical_jobs(self, run_jobs):
        run_jobs.return_value = {"completed": 2, "failed": 0, "jobs": []}

        result = scheduler_jobs.run_hourly_jobs()

        jobs = run_jobs.call_args.args[0]
        self.assertEqual(
            jobs,
            (
                scheduler_jobs.workflow_automation.run_hourly_workflow_checks,
                scheduler_jobs.auth_cleanup.cleanup_pending_registrations,
            ),
        )
        self.assertEqual(result["completed"], 2)

    @patch("omc_app.api.scheduler_jobs._run_jobs")
    def test_daily_runner_uses_canonical_jobs(self, run_jobs):
        run_jobs.return_value = {"completed": 2, "failed": 0, "jobs": []}

        result = scheduler_jobs.run_daily_jobs()

        jobs = run_jobs.call_args.args[0]
        self.assertEqual(
            jobs,
            (
                scheduler_jobs.workflow_automation.run_daily_workflow_checks,
                scheduler_jobs.mobile.cleanup_notifications,
            ),
        )
        self.assertEqual(result["completed"], 2)
