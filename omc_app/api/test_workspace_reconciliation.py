import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup import desk_metadata


class TestWorkspaceReconciliation(FrappeTestCase):
    def test_reconciliation_replaces_stale_workspace_rows_from_source(self):
        source = json.loads(
            desk_metadata._WORKSPACE_SOURCE.read_text(encoding="utf-8")
        )
        workspace = MagicMock()
        workspace.flags = SimpleNamespace(ignore_permissions=False)

        with (
            patch.object(desk_metadata.frappe.db, "exists", return_value=True),
            patch.object(desk_metadata.frappe, "get_doc", return_value=workspace),
        ):
            desk_metadata._reconcile_omc_workspace_from_source()

        workspace.set.assert_any_call("links", source.get("links") or [])
        workspace.set.assert_any_call(
            "quick_lists", source.get("quick_lists") or []
        )
        self.assertEqual(workspace.content, source.get("content") or "[]")
        self.assertTrue(workspace.flags.ignore_permissions)
        workspace.save.assert_called_once_with(ignore_permissions=True)

    def test_reconciliation_is_noop_before_workspace_exists(self):
        with (
            patch.object(desk_metadata.frappe.db, "exists", return_value=False),
            patch.object(desk_metadata.frappe, "get_doc") as get_doc,
        ):
            desk_metadata._reconcile_omc_workspace_from_source()

        get_doc.assert_not_called()
