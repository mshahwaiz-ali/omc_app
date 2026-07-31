from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "omc_app" / "api"
DOCTYPE = (
    ROOT
    / "omc_app"
    / "omc_app"
    / "doctype"
    / "omc_service_request"
    / "omc_service_request.json"
)


class TestStaffCompletionPerformanceContract(unittest.TestCase):
    def test_completion_fields_exist(self):
        source = DOCTYPE.read_text(encoding="utf-8")
        self.assertIn('"fieldname": "completed_by"', source)
        self.assertIn('"options": "User"', source)
        self.assertIn('"fieldname": "completion_source"', source)
        self.assertIn("Mobile / Desk", source)
        self.assertIn("ERP Task", source)

    def test_shared_attribution_is_immutable(self):
        source = (
            API_DIR / "workflow_automation.py"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "def record_completion_attribution(",
            source,
        )
        self.assertIn(
            'existing_actor = getattr(service_case, "completed_by", None)',
            source,
        )
        self.assertIn(
            'existing_source = getattr(service_case, "completion_source", None)',
            source,
        )
        self.assertIn('"updated": False', source)

    def test_mobile_completion_records_session_actor(self):
        source = (
            API_DIR / "mobile.py"
        ).read_text(encoding="utf-8")

        self.assertIn('source="Mobile / Desk"', source)
        self.assertIn("actor=frappe.session.user", source)
        self.assertIn(
            '@frappe.whitelist()\ndef get_internal_workspace_summary():',
            source,
        )

    def test_erp_completion_records_assigned_staff(self):
        source = (
            API_DIR / "erp_task_status_sync.py"
        ).read_text(encoding="utf-8")

        self.assertIn('source="ERP Task"', source)
        self.assertIn(
            'actor=getattr(request, "assigned_staff", None)',
            source,
        )
        self.assertIn(
            'request_values["completed_by"]',
            source,
        )
        self.assertIn(
            'request_values["completion_source"]',
            source,
        )

    def test_workspace_summary_exposes_live_metrics(self):
        source = (
            API_DIR / "mobile.py"
        ).read_text(encoding="utf-8")

        for key in (
            "my_assigned_services",
            "my_active_services",
            "my_completed_services",
            "my_completed_this_month",
        ):
            self.assertIn(f'"{key}"', source)

        self.assertIn(
            'my_filters = {"assigned_staff": user}',
            source,
        )
        self.assertIn('"completed_by": user', source)

    def test_flutter_model_and_card_are_wired(self):
        project_root = ROOT.parents[3]
        flutter_root = project_root / "omc_app"

        model = (
            flutter_root
            / "lib"
            / "features"
            / "internal_workspace"
            / "domain"
            / "internal_workspace_summary.dart"
        ).read_text(encoding="utf-8")
        screen = (
            flutter_root
            / "lib"
            / "features"
            / "internal_workspace"
            / "presentation"
            / "internal_workspace_screen.dart"
        ).read_text(encoding="utf-8")

        for token in (
            "myAssignedServices",
            "myActiveServices",
            "myCompletedServices",
            "myCompletedThisMonth",
        ):
            self.assertIn(token, model)

        self.assertIn(
            "class _MyServicePerformanceCard",
            screen,
        )
        self.assertIn("My service performance", screen)


if __name__ == "__main__":
    unittest.main()
