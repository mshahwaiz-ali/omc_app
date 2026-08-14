from types import SimpleNamespace
from unittest.mock import call, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_documents


class TestCustomerDocumentScope(FrappeTestCase):
    def _document_capabilities(self):
        return {
            "can_access_internal_workspace": True,
            "can_view_document_queue": False,
            "can_view_document_summaries": True,
            "can_view_document_attachments": True,
            "can_review_documents": False,
        }

    @patch.object(customer_documents, "_has_field", return_value=False)
    @patch.object(customer_documents.frappe, "get_all")
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(
        customer_documents,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_internal_list_is_limited_to_canonical_service_scope(
        self,
        _is_internal,
        require_scope,
        get_all,
        _has_field,
    ):
        require_scope.return_value = (
            "consultant@example.com",
            self._document_capabilities(),
            ["OMC-SR-ASSIGNED"],
        )
        get_all.side_effect = [
            ["OMC-SR-ASSIGNED"],
            [],
        ]

        result = customer_documents.get_documents()

        self.assertEqual(result, {"documents": []})
        self.assertEqual(
            get_all.call_args_list[0],
            call(
                "OMC Service Request",
                filters={"name": ["in", ["OMC-SR-ASSIGNED"]]},
                pluck="name",
            ),
        )

    @patch.object(customer_documents, "_has_field", return_value=False)
    @patch.object(customer_documents.frappe, "get_all")
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(
        customer_documents,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_all_case_capability_keeps_internal_list_unrestricted(
        self,
        _is_internal,
        require_scope,
        get_all,
        _has_field,
    ):
        capabilities = {
            **self._document_capabilities(),
            "can_view_all_service_cases": True,
        }
        require_scope.return_value = (
            "administrator@example.com",
            capabilities,
            None,
        )
        get_all.side_effect = [
            ["OMC-SR-1"],
            [],
        ]

        result = customer_documents.get_documents()

        self.assertEqual(result, {"documents": []})
        self.assertEqual(
            get_all.call_args_list[0],
            call(
                "OMC Service Request",
                filters={},
                pluck="name",
            ),
        )

    @patch.object(customer_documents.frappe, "get_all")
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(
        customer_documents,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_explicit_unscoped_service_request_returns_empty_list(
        self,
        _is_internal,
        require_scope,
        get_all,
    ):
        require_scope.return_value = (
            "consultant@example.com",
            self._document_capabilities(),
            ["OMC-SR-ASSIGNED"],
        )

        result = customer_documents.get_documents(
            service_request="OMC-SR-OTHER",
        )

        self.assertEqual(result, {"documents": []})
        get_all.assert_not_called()

    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
        side_effect=frappe.PermissionError,
    )
    @patch.object(
        customer_documents,
        "_can_access_internal_workspace",
        return_value=True,
    )
    def test_internal_document_detail_enforces_service_case_scope(
        self,
        _is_internal,
        require_scope,
        get_doc,
        _exists,
    ):
        get_doc.return_value = SimpleNamespace(
            name="OMC-DOC-1",
            service_request="OMC-SR-OTHER",
            visible_to_customer=1,
        )

        with self.assertRaises(frappe.PermissionError):
            customer_documents.get_document("OMC-DOC-1")

        require_scope.assert_called_once_with("OMC-SR-OTHER")

    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(customer_documents, "_canonical_capabilities", return_value={})
    @patch.object(customer_documents, "_assert_approved_customer")
    @patch.object(
        customer_documents,
        "_can_access_internal_workspace",
        return_value=False,
    )
    def test_customer_document_detail_keeps_profile_ownership_check(
        self,
        _is_internal,
        assert_customer,
        _capabilities,
        get_doc,
        _exists,
    ):
        assert_customer.return_value = SimpleNamespace(name="OMC-CUST-OWN")
        get_doc.side_effect = [
            SimpleNamespace(
                name="OMC-DOC-1",
                service_request="OMC-SR-OTHER",
                visible_to_customer=1,
            ),
            SimpleNamespace(
                name="OMC-SR-OTHER",
                customer_profile="OMC-CUST-OTHER",
            ),
        ]

        with self.assertRaises(frappe.PermissionError):
            customer_documents.get_document("OMC-DOC-1")
