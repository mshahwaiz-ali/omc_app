from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import idempotency


class TestIdempotency(FrappeTestCase):
    def test_begin_creates_processing_claim_without_storing_payload(self):
        record = MagicMock()
        record.name = "record-name"
        with (
            patch.object(idempotency.frappe.db, "get_value", return_value=None),
            patch.object(idempotency.frappe, "new_doc", return_value=record),
        ):
            claim = idempotency.begin(
                operation="service_request.create",
                actor="user@example.com",
                payload={
                    "idempotency_key": "omc-1234567890123456",
                    "description": "private customer content",
                },
            )

        self.assertEqual(claim.name, "record-name")
        self.assertEqual(record.state, "Processing")
        self.assertEqual(len(record.request_hash), 64)
        self.assertNotIn("private customer content", record.request_hash)
        record.insert.assert_called_once_with(ignore_permissions=True)

    def test_completed_claim_replays_only_matching_payload(self):
        payload = {
            "idempotency_key": "omc-1234567890123456",
            "service_id": "SERVICE-1",
        }
        request_hash = idempotency._request_hash(payload)
        existing = SimpleNamespace(
            request_hash=request_hash,
            state="Completed",
            response_json='{"request_id": "REQ-1"}',
        )
        with patch.object(
            idempotency.frappe.db,
            "get_value",
            return_value=existing,
        ):
            claim = idempotency.begin(
                operation="service_request.create",
                actor="user@example.com",
                payload=payload,
            )

        self.assertEqual(claim.replay["request_id"], "REQ-1")
        self.assertTrue(claim.replay["idempotent_replay"])

    def test_reused_key_with_changed_payload_is_rejected(self):
        existing = SimpleNamespace(
            request_hash="different",
            state="Completed",
            response_json="{}",
        )
        with (
            patch.object(
                idempotency.frappe.db,
                "get_value",
                return_value=existing,
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            idempotency.begin(
                operation="service_request.create",
                actor="user@example.com",
                payload={
                    "idempotency_key": "omc-1234567890123456",
                    "service_id": "SERVICE-2",
                },
            )
