from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload, mobile, payments


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

    def test_uploaded_required_file_allows_payment_before_review(self):
        templates = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "status": "Uploaded",
                "attachment": "/private/files/front.pdf",
            }
        ]

        self.assertTrue(
            mobile._required_documents_uploaded(
                templates,
                documents,
            )
        )

    def test_upload_gate_still_requires_exact_template_match(self):
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
                "status": "Uploaded",
                "attachment": "/private/files/back.pdf",
            }
        ]

        self.assertFalse(
            mobile._required_documents_uploaded(
                templates,
                documents,
            )
        )

    def test_upload_endpoint_attempts_payment_opening_immediately(self):
        context = SimpleNamespace(
            legacy_profile="OMC-CUST-TEST",
        )
        service_case = SimpleNamespace(
            name="OMC-SR-TEST",
            status="Open",
            customer_profile="OMC-CUST-TEST",
        )
        profile = SimpleNamespace(
            name="OMC-CUST-TEST",
        )
        uploaded_file = SimpleNamespace(
            name="FILE-TEST",
            file_url="/private/files/cnic.pdf",
            attached_to_doctype="",
            attached_to_name="",
        )

        document = MagicMock()
        document.name = "OMC-DOC-TEST"

        with (
            patch.object(
                document_upload.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                document_upload.identity,
                "require_owned_request",
                return_value=(context, service_case),
            ),
            patch.object(
                document_upload.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                document_upload,
                "_assert_document_submission_available",
            ),
            patch.object(
                document_upload,
                "_validate_uploaded_document",
                return_value=(
                    "/private/files/cnic.pdf",
                    uploaded_file,
                    "Clean",
                ),
            ),
            patch.object(
                document_upload,
                "_has_field",
                return_value=True,
            ),
            patch.object(
                document_upload.frappe,
                "new_doc",
                return_value=document,
            ),
            patch.object(
                document_upload.frappe.db,
                "set_value",
            ),
            patch.object(
                document_upload,
                "_create_service_timeline_entry",
            ),
            patch.object(
                document_upload.review_routing,
                "ensure_review_assignment",
            ),
            patch.object(
                document_upload.payment_opening,
                "ensure_service_payment",
                return_value="OMC-PAY-TEST",
            ) as ensure_payment,
        ):
            result = document_upload._upload_service_document(
                case_id=service_case.name,
                document_title="CNIC",
                document_type="Identity",
                attachment="/private/files/cnic.pdf",
            )

        document.insert.assert_called_once_with(
            ignore_permissions=True,
        )
        ensure_payment.assert_called_once_with(
            service_case.name,
        )

        self.assertTrue(result["uploaded"])
        self.assertEqual(
            result["payment_id"],
            "OMC-PAY-TEST",
        )
        self.assertEqual(
            result["document"]["status"],
            "Uploaded",
        )

    @patch.object(payments.frappe, "get_all")
    @patch.object(payments.mobile, "_service_required_documents")
    def test_payment_gate_uses_shared_upload_completion(
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

        result = payments._uploaded_required_documents(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertFalse(result)
