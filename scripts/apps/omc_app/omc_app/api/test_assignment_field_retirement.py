from unittest.mock import call, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.patches import backfill_service_request_assigned_staff


class TestAssignmentFieldRetirement(FrappeTestCase):
    def test_service_request_schema_has_only_canonical_assignment_field(self):
        meta = frappe.get_meta("OMC Service Request")

        self.assertTrue(meta.has_field("assigned_staff"))
        self.assertFalse(meta.has_field("assigned_to"))

    def test_legacy_assignment_is_backfilled_before_field_retirement(self):
        with (
            patch.object(
                backfill_service_request_assigned_staff,
                "_column_exists",
                side_effect=lambda fieldname: fieldname
                in {"assigned_staff", "assigned_to"},
            ) as column_exists,
            patch.object(
                backfill_service_request_assigned_staff.frappe.db,
                "sql",
            ) as sql,
        ):
            backfill_service_request_assigned_staff.execute()

        self.assertEqual(
            column_exists.call_args_list,
            [call("assigned_staff"), call("assigned_to")],
        )
        query = sql.call_args.args[0]
        self.assertIn("set assigned_staff = assigned_to", query)
        self.assertIn("coalesce(assigned_staff, '') = ''", query)
        self.assertIn("coalesce(assigned_to, '') != ''", query)

    def test_backfill_is_noop_without_legacy_column(self):
        with (
            patch.object(
                backfill_service_request_assigned_staff,
                "_column_exists",
                side_effect=lambda fieldname: fieldname == "assigned_staff",
            ),
            patch.object(
                backfill_service_request_assigned_staff.frappe.db,
                "sql",
            ) as sql,
        ):
            backfill_service_request_assigned_staff.execute()

        sql.assert_not_called()
