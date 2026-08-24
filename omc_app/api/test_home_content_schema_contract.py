from unittest import TestCase
from unittest.mock import patch

import frappe

from omc_app.api import home_content


_STANDARD_COLUMNS = {
    "name",
    "creation",
    "modified",
    "owner",
    "modified_by",
    "docstatus",
    "idx",
}


class TestHomeContentSchemaContract(TestCase):
    def test_home_content_order_by_uses_existing_columns(self):
        with (
            patch.object(
                home_content.capabilities,
                "effective",
                return_value={"access_state": "internal"},
            ),
            patch.object(
                home_content.frappe,
                "get_all",
                return_value=[],
            ) as get_all,
        ):
            home_content.get_home_content()

        invalid = []

        for call in get_all.call_args_list:
            doctype = call.args[0]
            order_by = call.kwargs.get("order_by", "")

            available = {
                field.fieldname
                for field in frappe.get_meta(doctype).fields
            } | _STANDARD_COLUMNS

            for clause in order_by.split(","):
                clause = clause.strip()
                if not clause:
                    continue

                fieldname = clause.split()[0].strip("`")

                if fieldname not in available:
                    invalid.append(
                        f"{doctype}: {fieldname} from {order_by}"
                    )

        self.assertEqual(invalid, [])
