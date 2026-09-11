from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase
from frappe.utils import now_datetime

from omc_app.api import assisted_service_policy, document_reuse


class TestRecurringDocumentReuse(FrappeTestCase):
    def test_always_new_is_not_automatically_reused(self):
        self.assertNotIn("Always New", document_reuse.REUSE_POLICIES)

    def test_newest_rejected_replacement_blocks_older_approved_document(self):
        rows = [
            SimpleNamespace(
                name="DOC-NEW-REJECTED",
                status="Rejected",
                quarantine_status="Not Required",
            ),
            SimpleNamespace(
                name="DOC-OLD-APPROVED",
                status="Approved",
                quarantine_status="Clean",
            ),
        ]
        with patch.object(
            document_reuse.frappe,
            "get_all",
            return_value=rows,
        ):
            result = document_reuse._latest_prior_document(
                ["OMC-SR-OLD"],
                "identity-document",
            )

        self.assertIsNone(result)

    def test_time_limited_reuse_rejects_expired_approval(self):
        requirement = SimpleNamespace(
            reuse_policy="Reusable for N Days",
            reuse_validity_days=30,
        )
        source = SimpleNamespace(
            reviewed_on=now_datetime() - timedelta(days=31),
            uploaded_on=None,
            creation=None,
        )

        self.assertFalse(
            document_reuse._within_reuse_window(requirement, source)
        )

    def test_time_limited_reuse_accepts_current_approval(self):
        requirement = SimpleNamespace(
            reuse_policy="Reusable for N Days",
            reuse_validity_days=30,
        )
        source = SimpleNamespace(
            reviewed_on=now_datetime() - timedelta(days=10),
            uploaded_on=None,
            creation=None,
        )

        self.assertTrue(
            document_reuse._within_reuse_window(requirement, source)
        )

    def test_assisted_repeat_booking_reuses_before_opening_payment(self):
        events = []

        def reuse(request_name, *, actor=None):
            events.append(("reuse", request_name, actor))
            return {
                "reused": 2,
                "reused_documents": ["DOC-1", "DOC-2"],
            }

        def payment(request_name):
            events.append(("payment", request_name))
            return "OMC-PAY-NEW"

        with (
            patch.object(
                assisted_service_policy.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                assisted_service_policy.frappe.session,
                "user",
                "consultant@example.com",
            ),
            patch.object(
                assisted_service_policy.document_reuse,
                "reuse_approved_documents",
                side_effect=reuse,
            ),
            patch.object(
                assisted_service_policy.payment_opening,
                "ensure_service_payment",
                side_effect=payment,
            ),
        ):
            response = assisted_service_policy._ensure_payment_from_response(
                {"service_request": "OMC-SR-NEW"}
            )

        self.assertEqual(response["reused_document_count"], 2)
        self.assertEqual(response["reused_documents"], ["DOC-1", "DOC-2"])
        self.assertEqual(response["payment_id"], "OMC-PAY-NEW")
        self.assertEqual(events[0][0], "reuse")
        self.assertEqual(events[1][0], "payment")

    def test_duplicate_assisted_request_does_not_reuse_documents(self):
        with (
            patch.object(
                assisted_service_policy.document_reuse,
                "reuse_approved_documents",
            ) as reuse,
            patch.object(
                assisted_service_policy.payment_opening,
                "ensure_service_payment",
            ) as payment,
        ):
            response = assisted_service_policy._ensure_payment_from_response(
                {"duplicate": True, "service_request": "OMC-SR-EXISTING"}
            )

        self.assertTrue(response["duplicate"])
        reuse.assert_not_called()
        payment.assert_not_called()
