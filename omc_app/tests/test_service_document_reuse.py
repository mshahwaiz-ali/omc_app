from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import document_upload, payment_opening, service_document_reuse


class TestServiceDocumentReusePolicy(FrappeTestCase):
    def test_always_new_never_reuses(self):
        source = SimpleNamespace(reviewed_on="2026-09-10 12:00:00")
        self.assertFalse(
            service_document_reuse._source_within_validity(
                {"reuse_policy": "Always New"},
                source,
                reference_time="2026-09-14 12:00:00",
            )
        )

    def test_reusable_until_replaced_is_reusable(self):
        source = SimpleNamespace(reviewed_on="2026-01-01 12:00:00")
        self.assertTrue(
            service_document_reuse._source_within_validity(
                {"reuse_policy": "Reusable Until Replaced"},
                source,
                reference_time="2026-09-14 12:00:00",
            )
        )

    def test_reusable_for_n_days_expires(self):
        source = SimpleNamespace(reviewed_on="2026-09-10 12:00:00")
        self.assertTrue(
            service_document_reuse._source_within_validity(
                {"reuse_policy": "Reusable for N Days", "reuse_validity_days": 5},
                source,
                reference_time="2026-09-14 12:00:00",
            )
        )
        self.assertFalse(
            service_document_reuse._source_within_validity(
                {"reuse_policy": "Reusable for N Days", "reuse_validity_days": 3},
                source,
                reference_time="2026-09-14 12:00:00",
            )
        )

    def test_only_completed_archive_remains_reusable(self):
        self.assertTrue(
            service_document_reuse._source_archive_is_eligible(
                SimpleNamespace(is_archived=1, archive_reason="Service Completed")
            )
        )
        self.assertFalse(
            service_document_reuse._source_archive_is_eligible(
                SimpleNamespace(is_archived=1, archive_reason="Replaced")
            )
        )

    def test_source_request_scope_is_same_erp_customer_and_service(self):
        request = SimpleNamespace(
            name="OMC-SR-NEW",
            service="ntn-registration",
            erp_customer="ERP-CUST-1",
            customer_profile="OMC-CUST-NEW",
            creation="2026-09-14 12:00:00",
        )
        with patch.object(service_document_reuse.frappe, "get_all", return_value=[]) as get_all:
            service_document_reuse._source_request_names(request)
        filters = get_all.call_args.kwargs["filters"]
        self.assertEqual(filters["service"], "ntn-registration")
        self.assertEqual(filters["erp_customer"], "ERP-CUST-1")
        self.assertNotIn("customer_profile", filters)
        self.assertEqual(filters["name"], ["!=", "OMC-SR-NEW"])
        self.assertEqual(filters["creation"], ["<", "2026-09-14 12:00:00"])

    def test_source_request_scope_falls_back_to_legacy_profile(self):
        request = SimpleNamespace(
            name="OMC-SR-NEW",
            service="ntn-registration",
            erp_customer="",
            customer_profile="OMC-CUST-LEGACY",
            creation=None,
        )
        with patch.object(service_document_reuse.frappe, "get_all", return_value=[]) as get_all:
            service_document_reuse._source_request_names(request)
        filters = get_all.call_args.kwargs["filters"]
        self.assertEqual(
            filters["customer_profile"],
            "OMC-CUST-LEGACY",
        )
        self.assertNotIn("erp_customer", filters)

    def test_stable_document_key_selects_reusable_source(self):
        sources = [
            SimpleNamespace(
                name="DOC-OLD",
                document_key="cnic-front",
                document_title="Old title",
                document_type="Identity",
                attachment="/private/files/cnic.pdf",
                status="Approved",
                reviewed_on="2026-09-10 12:00:00",
            )
        ]
        selected = service_document_reuse._find_reusable_source(
            {
                "document_key": "cnic-front",
                "document_title": "CNIC Front",
                "document_type": "Identity",
                "reuse_policy": "Reusable Until Replaced",
            },
            sources,
        )
        self.assertIs(selected, sources[0])


class TestReusableDocumentReplacement(FrappeTestCase):
    @staticmethod
    def _row(source):
        return SimpleNamespace(
            name="OMC-DOC-REUSED",
            document_key="cnic-front",
            document_title="CNIC Front",
            document_type="Identity",
            status="Approved",
            is_archived=0,
            source=source,
        )

    def test_existing_document_projection_can_be_replaced(self):
        with (
            patch.object(document_upload, "_has_field", return_value=True),
            patch.object(document_upload.frappe, "get_all", return_value=[self._row("Existing Document")]),
        ):
            result = document_upload._assert_document_submission_available(
                SimpleNamespace(name="OMC-SR-1"),
                "CNIC Front",
                "Identity",
                document_key="cnic-front",
            )
        self.assertEqual(result, "OMC-DOC-REUSED")

    def test_real_active_upload_still_blocks_duplicate(self):
        with (
            patch.object(document_upload, "_has_field", return_value=True),
            patch.object(document_upload.frappe, "get_all", return_value=[self._row("Service Upload")]),
            self.assertRaises(frappe.ValidationError),
        ):
            document_upload._assert_document_submission_available(
                SimpleNamespace(name="OMC-SR-1"),
                "CNIC Front",
                "Identity",
                document_key="cnic-front",
            )


class TestPaymentOpeningReuseGate(FrappeTestCase):
    def test_reuse_is_materialized_before_required_document_gate(self):
        request = SimpleNamespace(
            name="OMC-SR-TEST",
            request_state="Pending Payment",
            discount_status="",
        )
        with (
            patch.object(payment_opening.frappe.db, "get_value", return_value=request.name),
            patch.object(payment_opening.frappe, "get_doc", return_value=request),
            patch.object(
                payment_opening.service_document_reuse,
                "ensure_reusable_documents",
            ) as ensure_reuse,
            patch.object(payment_opening, "_required_documents_uploaded", return_value=False),
        ):
            result = payment_opening.ensure_service_payment(request.name)

        ensure_reuse.assert_called_once_with(request)
        self.assertIsNone(result)
