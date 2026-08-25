from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile, workflow_automation


class TestCrossFlowCompletionAuthority(FrappeTestCase):
    @patch.object(mobile.frappe, "get_all", return_value=[])
    def test_payment_contract_uses_locked_request_price(
        self,
        _get_all,
    ):
        service_case = SimpleNamespace(
            name="OMC-SR-1",
            status="Open",
            final_price=2500,
        )

        result = mobile._service_case_payment_contract(
            service_case,
            documents=[],
            required_document_templates=[],
        )

        self.assertTrue(result["payment_eligible"])
        self.assertEqual(
            result["payment_block_reason"],
            "payment_not_opened",
        )

    @patch.object(mobile.frappe, "get_all", return_value=[])
    def test_zero_locked_price_blocks_payment(
        self,
        _get_all,
    ):
        service_case = SimpleNamespace(
            name="OMC-SR-1",
            status="Open",
            final_price=0,
        )

        result = mobile._service_case_payment_contract(
            service_case,
            documents=[],
            required_document_templates=[],
        )

        self.assertFalse(result["payment_eligible"])
        self.assertEqual(
            result["payment_block_reason"],
            "service_fee_not_configured",
        )

    @patch.object(
        workflow_automation.mobile,
        "_doctype_has_field",
        return_value=True,
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
    )
    def test_corrected_document_clears_old_rejection(
        self,
        required_documents,
        get_all,
        _doctype_has_field,
    ):
        required_documents.return_value = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]
        get_all.side_effect = [
            [
                SimpleNamespace(
                    document_title="CNIC Front",
                    document_type="CNIC",
                    status="Rejected",
                    attachment="/private/files/old.pdf",
                ),
                SimpleNamespace(
                    document_title="CNIC Front",
                    document_type="CNIC",
                    status="Approved",
                    attachment="/private/files/new.pdf",
                ),
            ],
            [
                SimpleNamespace(status="Paid"),
            ],
        ]

        blockers = workflow_automation.completion_blockers(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertEqual(blockers, [])

    @patch.object(
        workflow_automation.mobile,
        "_doctype_has_field",
        return_value=True,
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
    )
    def test_missing_approved_replacement_still_blocks(
        self,
        required_documents,
        get_all,
        _doctype_has_field,
    ):
        required_documents.return_value = [
            {
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]
        get_all.side_effect = [
            [
                SimpleNamespace(
                    document_title="CNIC Front",
                    document_type="CNIC",
                    status="Rejected",
                    attachment="/private/files/old.pdf",
                ),
            ],
            [
                SimpleNamespace(status="Paid"),
            ],
        ]

        blockers = workflow_automation.completion_blockers(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertIn(
            "Required documents are not fully approved.",
            blockers,
        )

    @patch.object(
        workflow_automation.mobile,
        "_doctype_has_field",
        return_value=True,
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
    )
    def test_wrong_document_key_does_not_clear_completion_blocker(
        self,
        required_documents,
        get_all,
        _doctype_has_field,
    ):
        required_documents.return_value = [
            {
                "document_key": "cnic_front_image",
                "title": "CNIC Front",
                "document_type": "CNIC",
                "is_required": 1,
            }
        ]

        get_all.side_effect = [
            [
                SimpleNamespace(
                    document_key="different_requirement",
                    document_title="CNIC Front",
                    document_type="CNIC",
                    status="Approved",
                    attachment="/private/files/wrong.pdf",
                ),
            ],
            [
                SimpleNamespace(status="Paid"),
            ],
        ]

        blockers = workflow_automation.completion_blockers(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertIn(
            "Required documents are not fully approved.",
            blockers,
        )

    @patch.object(
        workflow_automation.mobile,
        "_doctype_has_field",
        return_value=True,
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
        return_value=[],
    )
    def test_unpaid_active_payment_blocks_completion(
        self,
        _required_documents,
        get_all,
        _doctype_has_field,
    ):
        get_all.side_effect = [
            [],
            [SimpleNamespace(status="Pending")],
        ]

        blockers = workflow_automation.completion_blockers(
            SimpleNamespace(
                name="OMC-SR-1",
                service="OMC-SERVICE-1",
            )
        )

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )
