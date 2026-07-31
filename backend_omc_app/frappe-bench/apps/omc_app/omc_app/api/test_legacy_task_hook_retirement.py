from frappe.tests.utils import FrappeTestCase

from omc_app import hooks


class TestLegacyTaskHookRetirement(FrappeTestCase):
    def test_legacy_task_removed_from_permission_query_hooks(self):
        self.assertNotIn(
            "OMC Task",
            hooks.permission_query_conditions,
        )

    def test_legacy_task_removed_from_has_permission_hooks(self):
        self.assertNotIn(
            "OMC Task",
            hooks.has_permission,
        )

    def test_legacy_task_removed_from_doc_events(self):
        self.assertNotIn(
            "OMC Task",
            hooks.doc_events,
        )

    def test_canonical_mobile_task_routes_remain_overridden(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.get_tasks"
            ],
            "omc_app.api.task_read_guard.get_tasks",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.get_task"
            ],
            "omc_app.api.task_read_guard.get_task",
        )

    def test_erp_task_status_sync_remains_active(self):
        self.assertEqual(
            hooks.doc_events["Task"]["on_update"],
            "omc_app.api.erp_task_status_sync.sync_task_status",
        )
