from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup import roles


class TestRolePermissionSafety(FrappeTestCase):
    def test_omc_owned_doctypes_use_namespace_boundary(self):
        with patch.object(
            roles.frappe,
            "get_all",
            return_value=[
                "OMC Service Request",
                "OMC Service Payment",
                "OMC User Type",
            ],
        ) as get_all:
            result = roles._omc_owned_doctypes()

        self.assertEqual(
            result,
            {
                "OMC Service Request",
                "OMC Service Payment",
                "OMC User Type",
            },
        )

        get_all.assert_called_once_with(
            "DocType",
            filters={"name": ["like", "OMC %"]},
            pluck="name",
            limit_page_length=1000,
        )

    def test_remove_role_docperms_is_scoped_to_owned_doctypes(self):
        with (
            patch.object(
                roles.frappe,
                "get_all",
                return_value=["DOCPERM-TEST-1"],
            ) as get_all,
            patch.object(
                roles.frappe,
                "delete_doc",
            ) as delete_doc,
        ):
            roles._remove_role_docperms(
                {"System Manager", "OMC Admin"},
                doctypes={
                    "OMC Service Request",
                    "OMC Service Payment",
                    "OMC User Type",
                },
            )

        call = get_all.call_args
        self.assertEqual(call.args[0], "DocPerm")

        filters = call.kwargs["filters"]

        self.assertEqual(
            filters["role"],
            ["in", ["OMC Admin", "System Manager"]],
        )
        self.assertEqual(
            filters["parent"],
            [
                "in",
                [
                    "OMC Service Payment",
                    "OMC Service Request",
                    "OMC User Type",
                ],
            ],
        )

        delete_doc.assert_called_once_with(
            "DocPerm",
            "DOCPERM-TEST-1",
            ignore_permissions=True,
            force=True,
        )

    def test_system_manager_custom_docperm_cleanup_is_scoped(self):
        with (
            patch.object(
                roles.frappe,
                "get_all",
                return_value=["CUSTOM-DOCPERM-TEST-1"],
            ) as get_all,
            patch.object(
                roles.frappe,
                "delete_doc",
            ) as delete_doc,
        ):
            roles._remove_role_custom_docperms(
                {"System Manager"},
                doctypes={"OMC Service Request", "OMC User Type"},
            )

        call = get_all.call_args
        self.assertEqual(call.args[0], "Custom DocPerm")

        filters = call.kwargs["filters"]

        self.assertEqual(
            filters["role"],
            ["in", ["System Manager"]],
        )
        self.assertEqual(
            filters["parent"],
            [
                "in",
                [
                    "OMC Service Request",
                    "OMC User Type",
                ],
            ],
        )

        delete_doc.assert_called_once_with(
            "Custom DocPerm",
            "CUSTOM-DOCPERM-TEST-1",
            ignore_permissions=True,
            force=True,
        )

    def test_empty_scope_never_queries_or_deletes_permissions(self):
        with (
            patch.object(roles.frappe, "get_all") as get_all,
            patch.object(roles.frappe, "delete_doc") as delete_doc,
        ):
            roles._remove_role_docperms(
                {"System Manager"},
                doctypes=set(),
            )
            roles._remove_role_custom_docperms(
                {"System Manager"},
                doctypes=set(),
            )

        get_all.assert_not_called()
        delete_doc.assert_not_called()
