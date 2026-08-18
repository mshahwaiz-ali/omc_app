from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile


class TestERPLeadIntegration(FrappeTestCase):
    def setUp(self):
        self.created_leads = []

    def tearDown(self):
        for name in self.created_leads:
            if frappe.db.exists("Lead", name):
                frappe.delete_doc(
                    "Lead",
                    name,
                    ignore_permissions=True,
                    force=True,
                )
        frappe.db.rollback()

    def _create(self, **kwargs):
        with patch.object(
            mobile,
            "_assert_internal_workspace_access",
        ), patch.object(
            mobile,
            "_require_canonical_capability",
        ):
            result = mobile._create_lead(**kwargs)

        name = result["lead"]["name"]
        self.created_leads.append(name)
        return result, frappe.get_doc("Lead", name)

    def test_mobile_creates_native_erp_lead(self):
        native_defaults = frappe.new_doc("Lead")

        result, lead = self._create(
            lead_name="OMC ERP Lead Contract Test",
            mobile_no="03000000000",
            task_type="NTN Registration",
        )

        self.assertEqual(lead.doctype, "Lead")
        self.assertEqual(
            lead.company_name,
            "OMC ERP Lead Contract Test",
        )
        self.assertEqual(lead.mobile_no, "03000000000")
        self.assertEqual(lead.task_type, "NTN Registration")

        # OMC must preserve ERP/Frappe defaults rather than inventing its own.
        self.assertEqual(lead.status, native_defaults.status)
        self.assertEqual(lead.source, native_defaults.source)

        payload = result["lead"]
        self.assertEqual(payload["task_type"], "NTN Registration")
        self.assertEqual(
            payload["service_interest"],
            "NTN Registration",
        )

    def test_person_name_falls_back_to_required_company_name(self):
        _, lead = self._create(
            first_name="Muhammad",
            last_name="Test",
            mobile_no="03000000001",
            task_type="NTN Registration",
        )

        self.assertEqual(lead.lead_name, "Muhammad Test")
        self.assertEqual(lead.company_name, "Muhammad Test")

    def test_mobile_number_is_required_by_client_erp_contract(self):
        with patch.object(
            mobile,
            "_assert_internal_workspace_access",
        ), patch.object(
            mobile,
            "_require_canonical_capability",
        ):
            with self.assertRaises(frappe.ValidationError):
                mobile._create_lead(
                    lead_name="Missing Mobile Test",
                    task_type="NTN Registration",
                )

    def test_invalid_task_type_is_rejected_before_insert(self):
        with patch.object(
            mobile,
            "_assert_internal_workspace_access",
        ), patch.object(
            mobile,
            "_require_canonical_capability",
        ):
            with self.assertRaises(frappe.ValidationError):
                mobile._create_lead(
                    lead_name="Invalid Task Type Test",
                    mobile_no="03000000002",
                    task_type="NOT-A-REAL-TASK-TYPE",
                )
