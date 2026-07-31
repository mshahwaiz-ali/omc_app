from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestLegacyTaskPermissionCodeRetirement(FrappeTestCase):
    def test_permissions_module_has_no_legacy_task_handlers(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "permissions.py").read_text(encoding="utf-8")

        self.assertNotIn('"OMC Task"', source)
        self.assertNotIn("'OMC Task'", source)
        self.assertNotIn("def validate_task_assignment(", source)
        self.assertNotIn("def task_query(", source)
        self.assertNotIn("def task_has_permission(", source)

    def test_hooks_have_no_legacy_task_permission_registration(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "hooks.py").read_text(encoding="utf-8")

        self.assertNotIn('"OMC Task"', source)
        self.assertNotIn("'OMC Task'", source)
