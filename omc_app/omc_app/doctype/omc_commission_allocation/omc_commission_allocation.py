from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCCommissionAllocation(Document):
    IMMUTABLE_FIELDS = {
        "allocation_key", "provenance", "payment_entry", "payment_reference_row",
        "sales_invoice", "service_request", "erp_customer", "legacy_journal_entry",
        "referral_attribution", "component", "beneficiary_type", "beneficiary",
        "beneficiary_user", "source_persona_snapshot", "currency", "exchange_rate",
        "basis_amount", "commission_percent_snapshot", "commission_amount",
        "structure_snapshot", "calculation_version", "earned_on",
    }

    CURRENT_REQUIRED_FIELDS = {
        "payment_entry",
        "payment_reference_row",
        "sales_invoice",
        "service_request",
        "erp_customer",
    }
    HISTORICAL_REQUIRED_FIELDS = {
        "payment_entry",
        "erp_customer",
        "legacy_journal_entry",
    }

    def validate(self):
        self.provenance = str(self.provenance or "Current OMC").strip()
        if self.provenance not in {"Current OMC", "Historical Legacy"}:
            frappe.throw("Unsupported commission allocation provenance.", frappe.ValidationError)

        required = (
            self.HISTORICAL_REQUIRED_FIELDS
            if self.provenance == "Historical Legacy"
            else self.CURRENT_REQUIRED_FIELDS
        )
        missing = sorted(field for field in required if not self.get(field))
        if missing:
            frappe.throw(
                "Commission allocation evidence is incomplete: " + ", ".join(missing),
                frappe.ValidationError,
            )

        if self.provenance == "Historical Legacy":
            if self.payment_reference_row or self.sales_invoice or self.service_request:
                frappe.throw(
                    "Historical legacy allocations must not fabricate current OMC request/invoice reference evidence.",
                    frappe.ValidationError,
                )
            if self.referral_attribution:
                frappe.throw(
                    "Historical legacy allocations do not require a fabricated referral attribution link.",
                    frappe.ValidationError,
                )

        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(before.get(field) != self.get(field) for field in self.IMMUTABLE_FIELDS):
            frappe.throw("Commission allocation snapshots are immutable.", frappe.ValidationError)

    def on_trash(self):
        frappe.throw("Commission allocations cannot be deleted.", frappe.PermissionError)
