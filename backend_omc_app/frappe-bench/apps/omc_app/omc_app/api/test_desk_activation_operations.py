from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestDeskActivationOperations(FrappeTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()

        cls.source = (
            Path(__file__).resolve().parents[1]
            / "omc_app"
            / "doctype"
            / "omc_service_request"
            / "omc_service_request.js"
        ).read_text(encoding="utf-8")

    def test_desk_uses_guarded_admin_context(self):
        self.assertIn(
            '"omc_app.api.admin_control"',
            self.source,
        )
        self.assertIn(
            '".get_case_admin_options"',
            self.source,
        )
        self.assertIn(
            "omc_add_request_erp_actions",
            self.source,
        )

    def test_reassignment_uses_authoritative_backend(self):
        self.assertIn(
            '".reassign_service_request"',
            self.source,
        )
        self.assertIn(
            "capabilities.can_reassign",
            self.source,
        )
        self.assertIn(
            "Reassign Service Request",
            self.source,
        )

    def test_retry_uses_guarded_sync_recovery(self):
        self.assertIn(
            '".retry_service_sync"',
            self.source,
        )
        self.assertIn(
            "capabilities.can_retry_sync",
            self.source,
        )
        self.assertIn(
            'requestState === "Activation Failed"',
            self.source,
        )
        self.assertIn(
            "Retry ERP Sync",
            self.source,
        )

    def test_erp_task_is_navigation_only(self):
        self.assertIn(
            "Open ERP Task",
            self.source,
        )
        self.assertIn(
            'frappe.set_route("Form", "Task", cleanTask)',
            self.source,
        )

        # Activation remains exclusively owned by the durable
        # payment/bridge authority. Desk must not expose a
        # manual activation shortcut.
        self.assertNotIn(
            '__("Activate Request")',
            self.source,
        )
        self.assertNotIn(
            '__("Activate Service")',
            self.source,
        )

    def test_terminal_cases_do_not_offer_mutation_actions(self):
        for marker in (
            '"Historical"',
            '"Expired"',
            '"Cancelled"',
            '"Completed"',
        ):
            self.assertIn(marker, self.source)
