from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestLegacyTaskRoleRetirement(FrappeTestCase):
    def test_role_setup_no_longer_grants_legacy_task(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "setup" / "roles.py").read_text(
            encoding="utf-8"
        )

        self.assertNotIn('"OMC Task"', source)
        self.assertNotIn("'OMC Task'", source)

    def test_canonical_task_capabilities_are_not_defined_by_doctype_grants(self):
        app_root = Path(__file__).resolve().parents[1]
        access_source = (app_root / "api" / "access.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("INTERNAL_CAPABILITY_KEYS", access_source)
        self.assertNotIn("System Manager\": set(INTERNAL_CAPABILITY_KEYS)", access_source)
        self.assertIn("can_manage_assigned_tasks", access_source)
