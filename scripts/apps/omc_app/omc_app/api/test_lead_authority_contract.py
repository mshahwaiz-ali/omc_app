from pathlib import Path
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile


def _function_source(source, function_name):
    marker = f"def {function_name}("
    start = source.index(marker)
    next_function = source.find(chr(10) + "def ", start + len(marker))
    next_decorated = source.find(chr(10) + "@frappe.whitelist()", start + len(marker))
    candidates = [position for position in (next_function, next_decorated) if position != -1]
    end = min(candidates) if candidates else len(source)
    return source[start:end]


class TestLeadAuthorityContract(FrappeTestCase):
    @patch("omc_app.api.lead_read_guard.get_leads")
    def test_mobile_list_delegates_to_canonical_guard(self, guarded_get_leads):
        guarded_get_leads.return_value = {"leads": []}
        self.assertEqual(mobile.get_leads(), {"leads": []})
        guarded_get_leads.assert_called_once_with()

    @patch("omc_app.api.lead_read_guard.get_lead")
    def test_mobile_detail_delegates_to_canonical_guard(self, guarded_get_lead):
        guarded_get_lead.return_value = {"lead": {"name": "OMC-LEAD-0001"}}
        result = mobile.get_lead(lead_id="OMC-LEAD-0001")
        self.assertEqual(result, {"lead": {"name": "OMC-LEAD-0001"}})
        guarded_get_lead.assert_called_once_with(lead_id="OMC-LEAD-0001")

    def test_mobile_lead_payload_excludes_erp_sync_metadata(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "api" / "mobile.py").read_text(encoding="utf-8")
        serializer = _function_source(source, "_lead_to_dict")
        for fieldname in (
            "erp_doctype",
            "erp_document_name",
            "erp_sync_status",
            "erp_last_synced_at",
            "erp_sync_error",
        ):
            self.assertNotIn(fieldname, serializer)

    def test_mobile_create_uses_omc_lead_authority(self):
        app_root = Path(__file__).resolve().parents[1]
        source = (app_root / "api" / "mobile.py").read_text(encoding="utf-8")
        creator = _function_source(source, "create_lead") + _function_source(
            source, "_create_lead"
        )
        self.assertIn("idempotency.begin", creator)
        self.assertIn('frappe.new_doc("OMC Lead")', creator)
        self.assertNotIn('frappe.new_doc("Lead")', creator)
