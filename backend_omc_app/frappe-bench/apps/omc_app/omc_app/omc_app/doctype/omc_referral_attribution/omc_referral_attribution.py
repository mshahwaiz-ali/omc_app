from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCReferralAttribution(Document):
    IMMUTABLE_FIELDS = {
        "attribution_key", "attribution_type", "referral_registry",
        "referral_code_snapshot", "owner_user", "owner_persona_snapshot",
        "customer_account", "erp_customer", "service_request",
        "consent_version", "attributed_at", "source_version",
    }

    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(before.get(field) != self.get(field) for field in self.IMMUTABLE_FIELDS):
            frappe.throw("Referral attribution snapshots are immutable.", frappe.ValidationError)

    def on_trash(self):
        frappe.throw("Referral attributions cannot be deleted.", frappe.PermissionError)

