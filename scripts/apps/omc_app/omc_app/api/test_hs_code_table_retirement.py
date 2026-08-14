from unittest import TestCase
from unittest.mock import patch

import frappe

from omc_app.patches import drop_retired_omc_hs_code_table as retirement


class TestHsCodeTableRetirement(TestCase):
    def test_refuses_drop_when_doctype_exists(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=True),
            patch.object(retirement.frappe.db, "sql_ddl") as sql_ddl,
            self.assertRaises(frappe.ValidationError),
        ):
            retirement.execute()
        sql_ddl.assert_not_called()

    def test_refuses_drop_when_orphan_table_has_rows(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=False),
            patch.object(retirement.frappe.db, "table_exists", return_value=True),
            patch.object(retirement.frappe.db, "sql", return_value=[[1]]),
            patch.object(retirement.retirement, "_nonempty_references", return_value=[]),
            patch.object(retirement.frappe.db, "sql_ddl") as sql_ddl,
            self.assertRaises(frappe.ValidationError),
        ):
            retirement.execute()
        sql_ddl.assert_not_called()

    def test_drops_only_empty_unowned_orphan_table(self):
        with (
            patch.object(retirement.frappe.db, "exists", return_value=False),
            patch.object(retirement.frappe.db, "table_exists", return_value=True),
            patch.object(retirement.frappe.db, "sql", return_value=[[0]]),
            patch.object(retirement.retirement, "_nonempty_references", return_value=[]),
            patch.object(retirement.frappe.db, "sql_ddl") as sql_ddl,
        ):
            retirement.execute()
        sql_ddl.assert_called_once_with("DROP TABLE `tabHS Code`")
