from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCCommissionAllocation(Document):
    IMMUTABLE_FIELDS = {
        "allocation_key", "payment_entry", "payment_reference_row", "sales_invoice",
        "service_request", "erp_customer", "referral_attribution", "component",
        "beneficiary_type", "beneficiary", "beneficiary_user",
        "source_persona_snapshot", "currency", "exchange_rate", "basis_amount",
        "commission_percent_snapshot", "commission_amount", "structure_snapshot",
        "calculation_version", "earned_on",
    }

    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(before.get(field) != self.get(field) for field in self.IMMUTABLE_FIELDS):
            frappe.throw("Commission allocation snapshots are immutable.", frappe.ValidationError)

    def on_trash(self):
        frappe.throw("Commission allocations cannot be deleted.", frappe.PermissionError)

