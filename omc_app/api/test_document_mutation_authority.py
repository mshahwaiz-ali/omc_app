from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_documents, document_upload


class TestDocumentMutationAuthority(FrappeTestCase):
    def test_completed_request_rejects_document_upload(self):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_service_request_accepts_documents(
                SimpleNamespace(status="Completed")
            )

    def test_cancelled_request_rejects_document_upload(self):
        with self.assertRaises(frappe.ValidationError):
            document_upload._assert_service_request_accepts_documents(
                SimpleNamespace(status="Cancelled")
            )

    def test_open_request_accepts_document_upload(self):
        document_upload._assert_service_request_accepts_documents(
            SimpleNamespace(status="Open")
        )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
        side_effect=frappe.PermissionError,
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    def test_review_enforces_canonical_service_case_scope(
        self,
        _exists,
        get_doc,
        require_scope,
        _review_access,
    ):
        get_doc.return_value = SimpleNamespace(
            name="OMC-DOC-1",
            service_request="OMC-SR-OTHER",
        )

        with self.assertRaises(frappe.PermissionError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
            )

        require_scope.assert_called_once_with("OMC-SR-OTHER")

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
        return_value=(
            "reviewer@example.com",
            {"can_review_documents": True},
            ["OMC-SR-1"],
        ),
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(customer_documents.frappe.db, "exists", return_value=True)
    def test_terminal_request_rejects_document_review(
        self,
        _exists,
        get_doc,
        _require_scope,
        _review_access,
    ):
        get_doc.side_effect = [
            SimpleNamespace(
                name="OMC-DOC-1",
                service_request="OMC-SR-1",
                status="Uploaded",
            ),
            SimpleNamespace(
                name="OMC-SR-1",
                status="Completed",
            ),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
            )
