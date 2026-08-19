from unittest import TestCase

from omc_app.api import service_case_contract


class TestServiceCaseCustomerPresentation(TestCase):
    def test_detail_snapshot_maps_counts_without_fake_documents(self):
        snapshot = service_case_contract._customer_lifecycle_snapshot(
            {
                "name": "SR-DETAIL-001",
                "request_state": "Draft",
                "status": "Open",
                "required_documents_count": 0,
                "submitted_documents_count": 0,
                "approved_documents_count": 0,
                "missing_documents_count": 0,
                "rejected_documents_count": 0,
                "receipt": {"status": "Not Required"},
                "settlement": {"status": "Not Required"},
            }
        )

        self.assertEqual(snapshot["document_summary"]["total"], 0)
        self.assertEqual(snapshot["document_summary"]["missing"], 0)
        self.assertEqual(snapshot["receipt"]["status"], "Not Required")
        self.assertEqual(snapshot["settlement"]["status"], "Not Required")

    def test_detail_snapshot_keeps_required_document_counts_exact(self):
        snapshot = service_case_contract._customer_lifecycle_snapshot(
            {
                "name": "SR-DETAIL-002",
                "request_state": "Draft",
                "status": "Open",
                "required_documents_count": 3,
                "submitted_documents_count": 2,
                "approved_documents_count": 1,
                "missing_documents_count": 1,
                "rejected_documents_count": 0,
            }
        )

        self.assertEqual(snapshot["document_summary"]["total"], 3)
        self.assertEqual(snapshot["document_summary"]["missing"], 1)
        self.assertEqual(snapshot["document_summary"]["uploaded"], 1)
        self.assertEqual(snapshot["document_summary"]["approved"], 1)

    def test_recent_activity_filters_only_synthetic_lifecycle_rows(self):
        activity = service_case_contract._customer_recent_activity(
            {
                "timeline": [
                    {
                        "title": "Request received",
                        "subtitle": "synthetic",
                    },
                    {
                        "title": "Payment review",
                        "subtitle": "synthetic",
                    },
                    {
                        "title": "Consultant requested clarification",
                        "subtitle": "Please confirm your filing year.",
                    },
                ]
            }
        )

        self.assertEqual(len(activity), 1)
        self.assertEqual(
            activity[0]["title"],
            "Consultant requested clarification",
        )

    def test_attached_customer_presentation_is_nested_and_backward_compatible(self):
        payload = {
            "name": "SR-DETAIL-003",
            "request_state": "Payment Not Required",
            "status": "Open",
            "current_stage": "legacy-stage",
            "milestones": ["request_created"],
            "required_documents_count": 0,
            "submitted_documents_count": 0,
            "approved_documents_count": 0,
            "missing_documents_count": 0,
            "rejected_documents_count": 0,
            "receipt": {"status": "Not Required"},
            "settlement": {"status": "Not Required"},
            "timeline": [],
        }

        service_case_contract._attach_customer_presentation(payload)

        self.assertEqual(payload["current_stage"], "legacy-stage")
        self.assertEqual(payload["milestones"], ["request_created"])
        self.assertEqual(
            payload["customer_lifecycle"]["current_stage"],
            "Ready for processing",
        )
        self.assertTrue(payload["customer_lifecycle"]["payment_not_required"])
        self.assertEqual(payload["recent_activity"], [])
