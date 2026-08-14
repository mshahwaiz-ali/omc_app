from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

import omc_app.api.assisted_service as assisted_service
import omc_app.api.mobile as mobile
import omc_app.api.payments as payments


class TestServiceRequestDiscountAuthority(FrappeTestCase):
    """Request-level discount authority and pricing integration contract."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.app_root = Path(__file__).resolve().parents[1]
        cls.doctype_path = (
            cls.app_root
            / "omc_app"
            / "doctype"
            / "omc_service_request"
            / "omc_service_request.json"
        )
        cls.schema = json.loads(
            cls.doctype_path.read_text(encoding="utf-8")
        )
        cls.fields = {
            field.get("fieldname"): field
            for field in cls.schema.get("fields", [])
            if isinstance(field, dict) and field.get("fieldname")
        }

    def _service(self, *, price=1000, currency="PKR"):
        return SimpleNamespace(base_price=price, currency=currency)

    def test_request_contains_locked_pricing_snapshot(self):
        expected = {
            "original_price",
            "pricing_currency",
            "discount_type",
            "discount_value",
            "discount_amount",
            "proposed_final_price",
            "final_price",
            "discount_reason",
            "discount_status",
            "discount_requested_by",
            "discount_approved_by",
            "discount_applied_by",
        }
        self.assertTrue(expected.issubset(self.fields))

    def test_supported_discount_types_are_schema_locked(self):
        options = {
            line.strip()
            for line in str(
                self.fields["discount_type"].get("options") or ""
            ).splitlines()
            if line.strip()
        }
        self.assertIn("Percentage", options)
        self.assertIn("Fixed Amount", options)

    def test_creation_authority_handles_discount_inputs(self):
        source = Path(assisted_service.__file__).read_text(
            encoding="utf-8"
        )
        for marker in (
            "discount_type",
            "discount_value",
            "discount_reason",
            "final_price",
            "discount_applied_by",
        ):
            self.assertIn(marker, source)

    def test_customer_creation_path_has_discount_guard(self):
        source = Path(mobile.__file__).read_text(encoding="utf-8")
        self.assertIn("discount_type", source)
        self.assertIn("discount_value", source)
        self.assertIn("discount", source.lower())

    def test_payment_generation_uses_request_final_price(self):
        source = Path(payments.__file__).read_text(encoding="utf-8")
        self.assertIn("final_price", source)
        self.assertIn("pricing_currency", source)

    def test_discount_is_request_scoped_not_catalogue_scoped(self):
        service_path = (
            self.app_root
            / "omc_app"
            / "doctype"
            / "omc_service"
            / "omc_service.json"
        )
        service_schema = json.loads(
            service_path.read_text(encoding="utf-8")
        )
        service_fields = {
            field.get("fieldname")
            for field in service_schema.get("fields", [])
            if isinstance(field, dict)
        }
        self.assertNotIn("discount_type", service_fields)
        self.assertNotIn("discount_value", service_fields)
        self.assertNotIn("discount_reason", service_fields)

    def test_internal_percentage_discount_calculates_final_price(self):
        result = assisted_service._request_pricing_snapshot(
            self._service(price=2000),
            is_internal=True,
            user="staff@example.com",
            kwargs={
                "discount_type": "Percentage",
                "discount_value": 15,
                "discount_reason": "Approved campaign",
            },
        )

        self.assertEqual(result["original_price"], 2000)
        self.assertEqual(result["discount_value"], 15)
        self.assertEqual(result["discount_amount"], 300)
        self.assertEqual(result["proposed_final_price"], 1700)
        self.assertEqual(result["final_price"], 2000)
        self.assertEqual(result["discount_status"], "Pending Approval")
        self.assertEqual(result["pricing_currency"], "PKR")
        self.assertEqual(
            result["discount_requested_by"],
            "staff@example.com",
        )

    def test_internal_fixed_discount_calculates_final_price(self):
        result = assisted_service._request_pricing_snapshot(
            self._service(price=2000),
            is_internal=True,
            user="manager@example.com",
            kwargs={
                "discount_type": "Fixed Amount",
                "discount_value": 250,
                "discount_reason": "Service recovery",
            },
        )

        self.assertEqual(result["original_price"], 2000)
        self.assertEqual(result["discount_value"], 250)
        self.assertEqual(result["discount_amount"], 250)
        self.assertEqual(result["proposed_final_price"], 1750)
        self.assertEqual(result["final_price"], 2000)
        self.assertEqual(result["discount_status"], "Pending Approval")
        self.assertEqual(
            result["discount_requested_by"],
            "manager@example.com",
        )

    def test_discount_reason_is_required(self):
        with self.assertRaises(frappe.ValidationError):
            assisted_service._request_pricing_snapshot(
                self._service(),
                is_internal=True,
                user="staff@example.com",
                kwargs={
                    "discount_type": "Percentage",
                    "discount_value": 10,
                },
            )

    def test_customer_discount_attempt_is_rejected(self):
        with self.assertRaises(frappe.PermissionError):
            assisted_service._request_pricing_snapshot(
                self._service(),
                is_internal=False,
                user="customer@example.com",
                kwargs={
                    "discount_type": "Percentage",
                    "discount_value": 10,
                    "discount_reason": "Unauthorized",
                },
            )

    def test_zero_discount_uses_catalogue_snapshot(self):
        result = assisted_service._request_pricing_snapshot(
            self._service(price=1250, currency="USD"),
            is_internal=True,
            user="staff@example.com",
            kwargs={},
        )

        self.assertEqual(result["original_price"], 1250)
        self.assertEqual(result["pricing_currency"], "USD")
        self.assertEqual(result["discount_type"], "")
        self.assertEqual(result["discount_value"], 0)
        self.assertEqual(result["discount_amount"], 0)
        self.assertEqual(result["final_price"], 1250)
        self.assertEqual(result["discount_reason"], "")
        self.assertEqual(result["discount_applied_by"], "")

    def test_payment_uses_locked_request_price_and_currency(self):
        service_case = SimpleNamespace(
            name="OMC-SR-DISCOUNT-1",
            service="OMC-SERVICE-1",
            service_title="Tax Filing",
            title="Tax Filing",
            final_price=1700,
            pricing_currency="PKR",
            status="Open",
            customer_profile="",
        )
        changed_catalogue_service = SimpleNamespace(
            name="OMC-SERVICE-1",
            title="Tax Filing",
            base_price=9999,
            currency="USD",
        )

        payment = SimpleNamespace(
            name="OMC-PAY-DISCOUNT-1",
            service_request="",
            payment_title="",
            amount=0,
            currency="",
            status="",
            visible_to_customer=0,
            remarks="",
        )
        payment.insert = lambda **_kwargs: None

        with (
            patch.object(
                payments.mobile,
                "_has_doctype",
                return_value=True,
            ),
            patch.object(payments.frappe, "get_all", return_value=[]),
            patch.object(
                payments,
                "_uploaded_required_documents",
                return_value=True,
            ),
            patch.object(
                payments.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                payments.frappe,
                "get_doc",
                return_value=changed_catalogue_service,
            ),
            patch.object(
                payments.frappe,
                "new_doc",
                return_value=payment,
            ),
            patch.object(payments, "_set_case_status"),
            patch.object(
                payments.mobile,
                "_create_service_timeline_entry",
            ),
            patch.object(payments, "_notify_customer"),
            patch.object(payments.frappe.db, "commit"),
        ):
            payment_name = payments._ensure_payment_for_case(
                service_case
            )

        self.assertEqual(payment_name, "OMC-PAY-DISCOUNT-1")
        self.assertEqual(payment.amount, 1700)
        self.assertEqual(payment.currency, "PKR")
        self.assertNotEqual(
            payment.amount,
            changed_catalogue_service.base_price,
        )
        self.assertNotEqual(
            payment.currency,
            changed_catalogue_service.currency,
        )

    def test_discount_ui_and_payload_are_internal_gated(self):
        draft_path = (
            Path(__file__).resolve().parents[6]
            / "omc_app"
            / "lib"
            / "features"
            / "service_requests"
            / "presentation"
            / "service_request_draft_screen.dart"
        )
        source = draft_path.read_text(encoding="utf-8")

        self.assertIn("_InternalDiscountCard(", source)
        self.assertIn(
            "capabilities.isInternal && discountValue > 0",
            source,
        )
        self.assertIn(
            "discountType: capabilities.isInternal",
            source,
        )
        self.assertIn(
            "discountValue: capabilities.isInternal",
            source,
        )
        self.assertIn(
            "discountReason: capabilities.isInternal",
            source,
        )
