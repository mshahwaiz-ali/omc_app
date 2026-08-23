from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import commission_projection


class TestCommissionHistoricalPersona(FrappeTestCase):
    def test_allocation_keeps_service_attribution_persona(self):
        payment = frappe._dict({
            "name": "PAY-HIST-1",
            "modified": "2026-08-23 12:00:00",
            "docstatus": 1,
            "posting_date": "2026-08-23",
            "custom_structure_name": "STRUCT-1",
            "custom_source": "Consultant",
            "custom_sales_person": "adnan@omchouse.com",
            "custom_sales_person_percentage": 10,
            "custom_business_partner_consultant": "",
            "custom_business_partner_consultant_percentage": 0,
            "custom_reference_business_partner": "",
            "custom_reference_business_partner_percentage": 0,
            "references": [
                frappe._dict({
                    "name": "PAY-REF-1",
                    "reference_doctype": "Sales Invoice",
                    "reference_name": "INV-HIST-1",
                })
            ],
        })

        link = frappe._dict({
            "service_request": "REQ-HIST-1",
            "erp_customer": "ERP-CUST-HIST-1",
            "allocated_amount": 1000,
            "exchange_rate": 1,
            "invoice_currency": "PKR",
        })

        request = frappe._dict({
            "name": "REQ-HIST-1",
            "referral_attribution": "ATTR-SVC-HIST-1",
        })

        created = {}

        def get_doc(doctype, name=None):
            if doctype == "OMC Service Request":
                return request

            if isinstance(doctype, dict):
                doc = frappe._dict(doctype)
                doc.name = "ALLOC-HIST-1"
                doc.insert = MagicMock()
                created["doc"] = doc
                return doc

            self.fail(f"Unexpected get_doc: {doctype} {name}")

        def get_value(doctype, name, field):
            if doctype == "Sales Invoice":
                return 1000
            if doctype == "OMC Referral Attribution":
                return "Consultant"
            self.fail(f"Unexpected get_value: {doctype} {field}")

        with (
            patch.object(
                commission_projection,
                "restore_commission_source",
            ),
            patch.object(
                commission_projection.frappe,
                "get_all",
                return_value=[link],
            ),
            patch.object(
                commission_projection,
                "_accounting_gate",
                return_value="ready",
            ),
            patch.object(
                commission_projection.frappe,
                "get_doc",
                side_effect=get_doc,
            ),
            patch.object(
                commission_projection.frappe.db,
                "get_value",
                side_effect=get_value,
            ),
            patch.object(
                commission_projection.frappe.db,
                "exists",
                side_effect=lambda doctype, name: (
                    doctype == "OMC Referral Attribution"
                ),
            ),
            patch.object(
                commission_projection,
                "_beneficiary_user",
                return_value="adnan@omchouse.com",
            ),
            patch.object(
                commission_projection.security,
                "audit_event",
            ),
        ):
            result = commission_projection.project_payment_entry(
                payment
            )

        self.assertEqual(result["created"], 1)
        self.assertEqual(
            created["doc"].source_persona_snapshot,
            "Consultant",
        )
        self.assertEqual(
            created["doc"].referral_attribution,
            "ATTR-SVC-HIST-1",
        )
        created["doc"].insert.assert_called_once_with(
            ignore_permissions=True
        )
