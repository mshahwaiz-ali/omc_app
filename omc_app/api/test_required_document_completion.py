from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload, mobile, payments, secured_mobile


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

    def test_document_key_survives_title_change(self):
        templates = [
            {
                "document_key": "cnic_copy",
                "title": "CNIC Copy",
                "document_type": "Identity",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "document_key": "cnic_copy",
                "title": "National Identity Card",
                "document_type": "Customer Document",
                "status": "Uploaded",
                "attachment": "/private/files/cnic.pdf",
            }
        ]

        self.assertTrue(
            mobile._required_documents_uploaded(
                templates,
                documents,
            )
        )

    def test_wrong_document_key_never_falls_back_to_matching_title(self):
        templates = [
            {
                "document_key": "cnic_front_image",
                "title": "CNIC Front",
                "document_type": "Identity",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "document_key": "cnic_back_image",
                "title": "CNIC Front",
                "document_type": "Identity",
                "status": "Uploaded",
                "attachment": "/private/files/wrong.pdf",
            }
        ]

        self.assertFalse(
            mobile._required_documents_uploaded(
                templates,
                documents,
            )
        )

    def test_keyed_template_accepts_legacy_unkeyed_exact_match(self):
        templates = [
            {
                "document_key": "bank_statement",
                "title": "Bank Statement",
                "document_type": "Financial",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "title": " bank   statement ",
                "document_type": "financial",
                "status": "Uploaded",
                "attachment": "/private/files/bank.pdf",
            }
        ]

        self.assertTrue(
            mobile._required_documents_uploaded(
                templates,
                documents,
            )
        )

    def test_upload_key_resolves_to_server_canonical_requirement(self):
        service_case = SimpleNamespace(
            name="OMC-SR-TEST",
            service="gst-registration",
        )

        requirement = SimpleNamespace(
            name="OMC-SRD-TEST",
            document_key="cnic_copy",
            document_title="CNIC Copy",
            document_type="Identity",
        )

        with (
            patch.object(
                document_upload,
                "_has_field",
                return_value=True,
            ),
            patch.object(
                document_upload.frappe,
                "get_all",
                return_value=[requirement],
            ),
        ):
            result = (
                document_upload._canonical_requirement_identity(
                    service_case,
                    document_key=" CNIC_COPY ",
                    document_title="Anything supplied by client",
                    document_type="Anything",
                )
            )

        self.assertEqual(
            result,
            (
                "cnic_copy",
                "CNIC Copy",
                "Identity",
            ),
        )

    def test_legacy_upload_can_upgrade_to_unique_document_key(self):
        service_case = SimpleNamespace(
            name="OMC-SR-TEST",
            service="gst-registration",
        )

        requirement = SimpleNamespace(
            name="OMC-SRD-TEST",
            document_key="bank_statement",
            document_title="Bank Statement",
            document_type="Financial",
        )

        with (
            patch.object(
                document_upload,
                "_has_field",
                return_value=True,
            ),
            patch.object(
                document_upload.frappe,
                "get_all",
                return_value=[requirement],
            ),
        ):
            result = (
                document_upload._canonical_requirement_identity(
                    service_case,
                    document_title=" bank   statement ",
                    document_type="financial",
                )
            )

        self.assertEqual(
            result,
            (
                "bank_statement",
                "Bank Statement",
                "Financial",
            ),
        )

    def test_case_document_merge_uses_stable_key_after_title_change(self):
        templates = [
            {
                "document_key": "cnic_copy",
                "title": "Updated CNIC Label",
                "document_type": "Identity",
                "is_required": 1,
                "instructions": "Upload a clear CNIC copy.",
            }
        ]
        documents = [
            {
                "document_key": "cnic_copy",
                "name": "OMC-DOC-1",
                "title": "Old CNIC Label",
                "document_type": "Legacy Identity",
                "status": "Uploaded",
                "attachment": "/private/files/cnic.pdf",
            }
        ]

        merged = secured_mobile._merged_document_details(
            documents,
            templates,
        )

        self.assertEqual(len(merged), 1)
        self.assertEqual(
            merged[0]["document_key"],
            "cnic_copy",
        )
        self.assertEqual(
            merged[0]["status"],
            "Uploaded",
        )
        self.assertEqual(
            merged[0]["file_url"],
            "/private/files/cnic.pdf",
        )
        self.assertEqual(
            merged[0]["is_required"],
            1,
        )

    def test_case_document_merge_rejects_wrong_key_even_when_title_matches(self):
        templates = [
            {
                "document_key": "cnic_front_image",
                "title": "CNIC Front",
                "document_type": "Identity",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "document_key": "cnic_back_image",
                "name": "OMC-DOC-1",
                "title": "CNIC Front",
                "document_type": "Identity",
                "status": "Uploaded",
                "attachment": "/private/files/wrong.pdf",
            }
        ]

        merged = secured_mobile._merged_document_details(
            documents,
            templates,
        )

        self.assertEqual(len(merged), 2)
        self.assertEqual(
            merged[0]["document_key"],
            "cnic_front_image",
        )
        self.assertEqual(
            merged[0]["status"],
            "Pending",
        )
        self.assertEqual(
            merged[1]["document_key"],
            "cnic_back_image",
        )
        self.assertEqual(
            merged[1]["status"],
            "Uploaded",
        )

    def test_case_document_merge_keeps_legacy_exact_match_compatible(self):
        templates = [
            {
                "document_key": "bank_statement",
                "title": "Bank Statement",
                "document_type": "Financial",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "name": "OMC-DOC-1",
                "title": " bank   statement ",
                "document_type": "financial",
                "status": "Uploaded",
                "attachment": "/private/files/bank.pdf",
            }
        ]

        merged = secured_mobile._merged_document_details(
            documents,
            templates,
        )

        self.assertEqual(len(merged), 1)
        self.assertEqual(
            merged[0]["document_key"],
            "bank_statement",
        )
        self.assertEqual(
            merged[0]["status"],
            "Uploaded",
        )

    def test_legacy_requirement_without_effective_from_applies(self):
        self.assertTrue(
            mobile._required_document_applies_to_request(
                {"effective_from": ""},
                "2026-08-01 10:00:00",
            )
        )

    def test_new_requirement_does_not_apply_to_older_request(self):
        self.assertFalse(
            mobile._required_document_applies_to_request(
                {
                    "effective_from":
                        "2026-08-25 15:00:00"
                },
                "2026-08-25 14:59:59",
            )
        )

    def test_new_requirement_applies_to_later_request(self):
        self.assertTrue(
            mobile._required_document_applies_to_request(
                {
                    "effective_from":
                        "2026-08-25 15:00:00"
                },
                "2026-08-25 15:00:01",
            )
        )

    def test_upload_key_rejects_requirement_outside_request_contract(self):
        service_case = SimpleNamespace(
            name="OMC-SR-TEST",
            service="gst-registration",
            creation="2026-08-25 14:00:00",
        )

        with (
            patch.object(
                document_upload,
                "_has_field",
                return_value=True,
            ),
            patch.object(
                document_upload,
                "_service_required_documents",
                return_value=[],
            ),
        ):
            with self.assertRaises(
                document_upload.frappe.ValidationError
            ):
                document_upload._canonical_requirement_identity(
                    service_case,
                    document_key="future_requirement",
                    document_title="Future Requirement",
                    document_type="General",
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
                document_upload.frappe.utils,
                "now_datetime",
                return_value="2026-08-25 13:47:00",
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
