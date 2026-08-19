from unittest import TestCase

from omc_app.api import customer_lifecycle


class TestCustomerLifecycle(TestCase):
    def test_pending_payment_is_primary_customer_action(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-001",
                "request_state": "Pending Payment",
                "operational_status": "Waiting for Payment",
                "receipt": {"state": "not_submitted"},
                "document_summary": {"pending": 2, "total": 2},
            }
        )

        self.assertEqual(result["current_stage"], "Payment")
        self.assertEqual(result["next_action"]["type"], "complete_payment")
        self.assertEqual(result["next_action"]["route"], "/payments")
        self.assertTrue(result["action_required"])
        self.assertEqual(result["progress_percent"], 45)

    def test_submitted_payment_waits_for_review_without_requesting_second_payment(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-002",
                "request_state": "Pending Payment",
                "receipt": {"state": "submitted"},
                "payment_summary": {"receipt_submitted": 1},
            }
        )

        self.assertEqual(result["current_stage"], "Payment review")
        self.assertEqual(result["next_action"]["type"], "await_payment_review")
        self.assertFalse(result["action_required"])
        self.assertEqual(
            next(item for item in result["milestones"] if item["key"] == "payment")["state"],
            "current",
        )

    def test_payment_not_required_is_explicitly_skipped(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-003",
                "request_state": "Payment Not Required",
                "operational_status": "Open",
            }
        )
        payment = next(
            item for item in result["milestones"] if item["key"] == "payment"
        )

        self.assertEqual(payment["state"], "skipped")
        self.assertIn("No payment is required", payment["detail"])
        self.assertEqual(result["current_stage"], "Ready for processing")

    def test_financial_hold_is_attention_not_fake_progress(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-004",
                "request_state": "Financial Hold",
                "hold": {"active": True},
            }
        )

        self.assertEqual(result["current_stage"], "Finance review")
        self.assertEqual(result["next_action"]["type"], "review_financial_hold")
        self.assertEqual(result["attention_priority"], 100)
        self.assertTrue(result["action_required"])

    def test_waiting_customer_prefers_document_action_when_documents_need_attention(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-005",
                "request_state": "Activated",
                "operational_status": "Waiting for Customer",
                "settlement": {"state": "matched"},
                "document_summary": {"rejected": 1, "total": 2},
            }
        )

        self.assertEqual(result["current_stage"], "Waiting for you")
        self.assertEqual(result["next_action"]["type"], "upload_document")
        self.assertEqual(result["next_action"]["route"], "/documents")

    def test_completed_request_has_real_terminal_lifecycle(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-006",
                "request_state": "Activated",
                "operational_status": "Completed",
                "settlement": {"state": "matched"},
            }
        )

        self.assertTrue(result["completed"])
        self.assertEqual(result["progress_percent"], 100)
        self.assertEqual(result["current_stage"], "Completed")
        self.assertTrue(
            all(
                item["state"] in {"complete", "skipped"}
                for item in result["milestones"]
            )
        )

    def test_document_alias_counts_are_not_double_counted(self):
        result = customer_lifecycle.lifecycle_presentation(
            {
                "id": "SR-ALIAS",
                "request_state": "Draft",
                "document_summary": {
                    "pending": 1,
                    "missing": 1,
                    "uploaded": 2,
                    "under_review": 2,
                    "total": 3,
                },
            }
        )
        documents = next(
            item for item in result["milestones"] if item["key"] == "documents"
        )

        self.assertEqual(documents["state"], "attention")
        self.assertIn("1 document still required", documents["detail"])
        self.assertNotIn("2 documents still required", documents["detail"])

    def test_dashboard_surfaces_highest_attention_service_and_matching_action(self):
        payload = {
            "service_snapshots": [
                {
                    "id": "SR-RECENT",
                    "request_state": "Activated",
                    "operational_status": "In Progress",
                    "document_summary": {},
                    "payment_summary": {},
                    "settlement": {"state": "matched"},
                },
                {
                    "id": "SR-PAY",
                    "request_state": "Pending Payment",
                    "operational_status": "Waiting for Payment",
                    "receipt": {"state": "not_submitted"},
                    "document_summary": {},
                    "payment_summary": {"pending": 1},
                },
            ],
            "next_action": {"type": "legacy_aggregate_action"},
        }

        result = customer_lifecycle.enrich_dashboard(payload)

        self.assertEqual(result["service_snapshots"][0]["id"], "SR-PAY")
        self.assertEqual(result["next_action"]["type"], "complete_payment")
        self.assertEqual(
            result["next_action"],
            result["service_snapshots"][0]["next_action"],
        )
