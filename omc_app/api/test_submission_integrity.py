import json
from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import submission_integrity


class TestSubmissionIntegrity(FrappeTestCase):
    def _field(self, name="tax_id", fieldtype="Data", required=1, **kwargs):
        return SimpleNamespace(
            fieldname=name,
            label=kwargs.get("label", name),
            fieldtype=fieldtype,
            options=kwargs.get("options", ""),
            is_required=required,
            depends_on=kwargs.get("depends_on", ""),
        )

    @patch.object(submission_integrity, "_canonical_fields", return_value=[])
    def test_malformed_json_is_rejected(self, _fields):
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission("SERVICE", {"form_data_json": "{"})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_unknown_key_is_rejected(self, fields):
        fields.return_value = [self._field()]
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission("SERVICE", {"form_data": {"other": "x"}})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_required_field_is_enforced(self, fields):
        fields.return_value = [self._field()]
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission("SERVICE", {"form_data": {}})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_client_schema_is_ignored_and_canonical_value_persisted(self, fields):
        fields.return_value = [self._field()]
        result = submission_integrity.validate_submission(
            "SERVICE",
            {
                "form_data": {"tax_id": "<b> 123 </b>"},
                "form_schema": [{"fieldname": "attacker"}],
            },
        )
        self.assertEqual(result["data"], {"tax_id": "123"})
        self.assertEqual(json.loads(result["json"]), {"tax_id": "123"})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_conflicting_aliases_are_rejected(self, fields):
        fields.return_value = [self._field()]
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission(
                "SERVICE",
                {"form_data": {"tax_id": "1"}, "form_data_json": '{"tax_id":"2"}'},
            )

    @patch.object(submission_integrity, "_canonical_fields")
    def test_conditional_configuration_fails_closed(self, fields):
        fields.return_value = [self._field(depends_on="other == 1")]
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission("SERVICE", {"form_data": {"tax_id": "1"}})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_nested_payload_is_rejected(self, fields):
        fields.return_value = [self._field()]
        with self.assertRaises(frappe.ValidationError):
            submission_integrity.validate_submission("SERVICE", {"form_data": {"tax_id": {"x": 1}}})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_select_and_numeric_types_are_normalized(self, fields):
        fields.return_value = [
            self._field("kind", "Select", options="A\nB"),
            self._field("amount", "Currency"),
        ]
        result = submission_integrity.validate_submission(
            "SERVICE", {"form_data": {"kind": "A", "amount": "12.5"}}
        )
        self.assertEqual(result["data"], {"kind": "A", "amount": 12.5})

    @patch.object(submission_integrity, "_canonical_fields")
    def test_legacy_rescore_counts_missing_invalid_and_unknown_values(self, fields):
        fields.return_value = [
            self._field("required_name", "Data"),
            self._field("amount", "Currency", required=0),
        ]
        request = SimpleNamespace(
            service="SERVICE",
            submission_data_json='{"amount":"NaN","legacy":"x"}',
        )

        reasons, score, incomplete = submission_integrity._structured_form_findings(request)

        self.assertTrue(incomplete)
        self.assertEqual(score, 55)
        self.assertEqual(
            {reason["code"] for reason in reasons},
            {
                "missing_required_form_value",
                "invalid_form_value",
                "unknown_legacy_key",
            },
        )

    @patch.object(submission_integrity, "_canonical_fields", return_value=[])
    def test_malformed_legacy_json_is_incomplete(self, _fields):
        request = SimpleNamespace(service="SERVICE", submission_data_json="{")
        reasons, score, incomplete = submission_integrity._structured_form_findings(request)
        self.assertTrue(incomplete)
        self.assertEqual(score, 20)
        self.assertEqual(reasons, [{"code": "invalid_form_data"}])
