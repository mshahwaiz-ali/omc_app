import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup import desk_metadata, referral_workspace


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

    def test_my_referrals_roles_replace_stale_and_duplicate_rows(self):
        report = MagicMock()
        report.flags = SimpleNamespace(ignore_permissions=False)
        report.get.return_value = [
            {"role": "OMC Admin"},
            {"role": "OMC Admin"},
            {"role": "OMC Consultant"},
        ]

        with (
            patch.object(referral_workspace.frappe.db, "exists", return_value=True),
            patch.object(referral_workspace.frappe, "get_doc", return_value=report),
        ):
            referral_workspace._ensure_my_referrals_report_roles()

        expected = [
            {"role": role}
            for role in referral_workspace._MY_REFERRALS_REPORT_ROLE_CANDIDATES
        ]
        report.set.assert_called_once_with("roles", expected)
        self.assertTrue(report.flags.ignore_permissions)
        report.save.assert_called_once_with(ignore_permissions=True)

    def test_my_referrals_role_reconciliation_is_noop_when_exact(self):
        report = MagicMock()
        report.flags = SimpleNamespace(ignore_permissions=False)
        report.get.return_value = [
            {"role": role}
            for role in referral_workspace._MY_REFERRALS_REPORT_ROLE_CANDIDATES
        ]

        with (
            patch.object(referral_workspace.frappe.db, "exists", return_value=True),
            patch.object(referral_workspace.frappe, "get_doc", return_value=report),
        ):
            referral_workspace._ensure_my_referrals_report_roles()

        report.set.assert_not_called()
        report.save.assert_not_called()
