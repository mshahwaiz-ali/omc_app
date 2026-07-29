from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import scheduler_jobs


class TestSchedulerJobs(FrappeTestCase):
    @patch("omc_app.api.scheduler_jobs._log_completion")
    @patch("omc_app.api.scheduler_jobs.frappe.log_error")
    @patch("omc_app.api.scheduler_jobs.frappe.get_traceback", return_value="trace")
    @patch("omc_app.api.scheduler_jobs.frappe.db.commit")
    @patch("omc_app.api.scheduler_jobs.frappe.db.rollback")
    def test_failed_job_rolls_back_and_is_reported(
        self,
        rollback,
        commit,
        get_traceback,
        log_error,
        log_completion,
    ):
        job = MagicMock(side_effect=RuntimeError("boom"))
        job.__module__ = "omc_app.tests"
        job.__name__ = "failing_job"

        result = scheduler_jobs._run_job(job)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["job"], "omc_app.tests.failing_job")
        self.assertIsNone(result["result"])
        self.assertGreaterEqual(result["duration_ms"], 0)
        rollback.assert_called_once_with()
        commit.assert_not_called()
        log_error.assert_called_once_with(
            title="OMC scheduled job failed: omc_app.tests.failing_job",
            message="trace",
        )
        log_completion.assert_called_once_with(result)

    @patch("omc_app.api.scheduler_jobs._log_completion")
    @patch("omc_app.api.scheduler_jobs.frappe.log_error")
    @patch("omc_app.api.scheduler_jobs.frappe.db.commit")
    @patch("omc_app.api.scheduler_jobs.frappe.db.rollback")
    def test_successful_job_commits_and_returns_result(
        self,
        rollback,
        commit,
        log_error,
        log_completion,
    ):
        job = MagicMock(return_value={"processed": 3})
        job.__module__ = "omc_app.tests"
        job.__name__ = "successful_job"

        result = scheduler_jobs._run_job(job)

        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["result"], {"processed": 3})
        self.assertGreaterEqual(result["duration_ms"], 0)
        commit.assert_called_once_with()
        rollback.assert_not_called()
        log_error.assert_not_called()
        log_completion.assert_called_once_with(result)

    def test_runner_continues_after_sibling_failure(self):
        first = MagicMock(side_effect=RuntimeError("first failed"))
        first.__module__ = "omc_app.tests"
        first.__name__ = "first"
        second = MagicMock(return_value={"processed": 2})
        second.__module__ = "omc_app.tests"
        second.__name__ = "second"

        with (
            patch("omc_app.api.scheduler_jobs.frappe.db.commit") as commit,
            patch("omc_app.api.scheduler_jobs.frappe.db.rollback") as rollback,
            patch(
                "omc_app.api.scheduler_jobs.frappe.get_traceback",
                return_value="trace",
            ),
            patch("omc_app.api.scheduler_jobs.frappe.log_error"),
            patch("omc_app.api.scheduler_jobs._log_completion"),
            patch("omc_app.api.scheduler_jobs._log_run_summary") as log_summary,
        ):
            result = scheduler_jobs._run_jobs("hourly", (first, second))

        self.assertEqual(result["schedule"], "hourly")
        self.assertEqual(result["status"], "completed_with_failures")
        self.assertEqual(result["job_count"], 2)
        self.assertEqual(result["completed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertEqual(result["failed_jobs"], ["omc_app.tests.first"])
        self.assertGreaterEqual(result["duration_ms"], 0)
        rollback.assert_called_once_with()
        commit.assert_called_once_with()
        second.assert_called_once_with()
        self.assertEqual(
            [item["status"] for item in result["jobs"]],
            ["failed", "completed"],
        )
        log_summary.assert_called_once_with(result)

    @patch("omc_app.api.scheduler_jobs.frappe.logger")
    def test_completion_logging_is_structured(self, logger):
        result = {
            "job": "omc_app.tests.successful_job",
            "status": "completed",
            "result": None,
            "duration_ms": 17,
        }

        scheduler_jobs._log_completion(result)

        logger.assert_called_once_with(scheduler_jobs.LOGGER_NAME)
        logger.return_value.info.assert_called_once_with(
            "OMC scheduled job %s: %s (%sms)",
            "completed",
            "omc_app.tests.successful_job",
            17,
        )

    @patch("omc_app.api.scheduler_jobs.frappe.logger")
    def test_run_summary_logs_success_and_failures(self, logger):
        summary = {
            "schedule": "daily",
            "status": "completed_with_failures",
            "job_count": 2,
            "completed": 1,
            "failed": 1,
            "failed_jobs": ["omc_app.tests.failed"],
            "duration_ms": 41,
            "jobs": [],
        }

        scheduler_jobs._log_run_summary(summary)

        logger.assert_called_once_with(scheduler_jobs.LOGGER_NAME)
        logger.return_value.info.assert_called_once_with(
            "OMC %s scheduler run %s: %s completed, %s failed (%sms)",
            "daily",
            "completed_with_failures",
            1,
            1,
            41,
        )
        logger.return_value.warning.assert_called_once_with(
            "OMC %s scheduler failed jobs: %s",
            "daily",
            "omc_app.tests.failed",
        )

    @patch("omc_app.api.scheduler_jobs._run_jobs")
    def test_hourly_runner_uses_canonical_jobs(self, run_jobs):
        run_jobs.return_value = {
            "schedule": "hourly",
            "status": "completed",
            "job_count": 2,
            "completed": 2,
            "failed": 0,
            "failed_jobs": [],
            "duration_ms": 1,
            "jobs": [],
        }

        result = scheduler_jobs.run_hourly_jobs()

        schedule, jobs = run_jobs.call_args.args
        self.assertEqual(schedule, "hourly")
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
        run_jobs.return_value = {
            "schedule": "daily",
            "status": "completed",
            "job_count": 2,
            "completed": 2,
            "failed": 0,
            "failed_jobs": [],
            "duration_ms": 1,
            "jobs": [],
        }

        result = scheduler_jobs.run_daily_jobs()

        schedule, jobs = run_jobs.call_args.args
        self.assertEqual(schedule, "daily")
        self.assertEqual(
            jobs,
            (
                scheduler_jobs.workflow_automation.run_daily_workflow_checks,
                scheduler_jobs.mobile.cleanup_notifications,
            ),
        )
        self.assertEqual(result["completed"], 2)
