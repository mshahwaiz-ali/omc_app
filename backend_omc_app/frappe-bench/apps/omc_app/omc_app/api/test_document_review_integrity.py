from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_documents


class TestDocumentReviewIntegrity(FrappeTestCase):
    def _document(self, status="Uploaded"):
        doc = MagicMock()
        doc.name = "OMC-DOC-1"
        doc.service_request = "OMC-SR-1"
        doc.status = status
        doc.document_title = "CNIC"
        doc.remarks = ""
        return doc

    def _service_case(self, status="In Progress"):
        return SimpleNamespace(
            name="OMC-SR-1",
            status=status,
        )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_same_status_is_idempotent_noop(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        doc = self._document(status="Uploaded")
        get_doc.side_effect = [
            doc,
            self._service_case(),
        ]

        result = customer_documents.update_service_document_status(
            document_id=doc.name,
            status="Uploaded",
            remarks="Repeated request",
        )

        self.assertFalse(result["updated"])
        doc.save.assert_not_called()

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_rejection_requires_remarks(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        get_doc.side_effect = [
            self._document(status="Uploaded"),
            self._service_case(),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Rejected",
                remarks="",
            )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_approved_review_is_final(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        get_doc.side_effect = [
            self._document(status="Approved"),
            self._service_case(),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Rejected",
                remarks="Changed decision",
            )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_rejected_review_is_final(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        get_doc.side_effect = [
            self._document(status="Rejected"),
            self._service_case(),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
                remarks="Changed decision",
            )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_uploaded_cannot_return_to_pending(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        get_doc.side_effect = [
            self._document(status="Uploaded"),
            self._service_case(),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Pending",
            )

    @patch.object(
        customer_documents,
        "_require_document_review_access",
        return_value={"can_review_documents": True},
    )
    @patch.object(
        customer_documents.mobile,
        "_require_service_case_read_scope",
    )
    @patch.object(customer_documents.frappe, "get_doc")
    @patch.object(
        customer_documents.frappe.db,
        "exists",
        return_value=True,
    )
    def test_terminal_case_still_rejects_review(
        self,
        _exists,
        get_doc,
        _scope,
        _review_access,
    ):
        get_doc.side_effect = [
            self._document(status="Uploaded"),
            self._service_case(status="Completed"),
        ]

        with self.assertRaises(frappe.ValidationError):
            customer_documents.update_service_document_status(
                document_id="OMC-DOC-1",
                status="Approved",
            )
