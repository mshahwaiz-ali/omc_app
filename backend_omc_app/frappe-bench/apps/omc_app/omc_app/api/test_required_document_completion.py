from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile, payments


class TestRequiredDocumentCompletion(FrappeTestCase):
    def test_exact_title_and_type_are_required(self):
        templates = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "title": "CNIC Back",
                "document_type": "CNIC",
                "status": "Approved",
                "file_url": "/private/files/back.pdf",
            }
        ]

        self.assertFalse(
            mobile._required_documents_complete(
                templates,
                documents,
            )
        )

    def test_one_document_cannot_satisfy_two_templates(self):
        templates = [
            {
                "title": "Bank Statement",
                "document_type": "Financial",
                "is_required": 1,
            },
            {
                "title": "Bank Statement",
                "document_type": "Financial",
                "is_required": 1,
            },
        ]
        documents = [
            {
                "title": "Bank Statement",
                "document_type": "Financial",
                "status": "Approved",
                "file_url": "/private/files/statement.pdf",
            }
        ]

        self.assertFalse(
            mobile._required_documents_complete(
                templates,
                documents,
            )
        )

    def test_two_distinct_approved_files_satisfy_two_templates(self):
        templates = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            },
            {
                "title": "CNIC Back",
                "document_type": "CNIC",
                "is_required": 1,
            },
        ]
        documents = [
            {
                "title": " cnic   front ",
                "document_type": "cnic",
                "status": "Approved",
                "attachment": "/private/files/front.pdf",
            },
            {
                "title": "CNIC Back",
                "document_type": "CNIC",
                "status": "Approved",
                "attachment": "/private/files/back.pdf",
            },
        ]

        self.assertTrue(
            mobile._required_documents_complete(
                templates,
                documents,
            )
        )

    def test_rejected_or_unattached_document_does_not_count(self):
        templates = [
            {
                "title": "NTN Certificate",
                "document_type": "Tax",
                "is_required": 1,
            }
        ]

        rejected = [
            {
                "title": "NTN Certificate",
                "document_type": "Tax",
                "status": "Rejected",
                "attachment": "/private/files/ntn.pdf",
            }
        ]
        unattached = [
            {
                "title": "NTN Certificate",
                "document_type": "Tax",
                "status": "Approved",
                "attachment": "",
            }
        ]

        self.assertFalse(
            mobile._required_documents_complete(
                templates,
                rejected,
            )
        )
        self.assertFalse(
            mobile._required_documents_complete(
                templates,
                unattached,
            )
        )

    def test_optional_templates_do_not_block_completion(self):
        templates = [
            {
                "title": "Optional Letter",
                "document_type": "Other",
                "is_required": 0,
            }
        ]

        self.assertTrue(
            mobile._required_documents_complete(
                templates,
                [],
            )
        )

    @patch.object(payments.frappe, "get_all")
    @patch.object(payments.mobile, "_service_required_documents")
    def test_payment_gate_uses_shared_strict_completion(
        self,
        required_documents,
        get_all,
    ):
        required_documents.return_value = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]
        get_all.return_value = [
            SimpleNamespace(
                document_title="CNIC Back",
                document_type="CNIC",
                status="Approved",
                attachment="/private/files/back.pdf",
            )
        ]

        result = payments._approved_required_documents(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertFalse(result)
