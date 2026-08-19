from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCReconciliationRun(Document):
    IMMUTABLE_FIELDS = {
        "run_id",
        "job_key",
        "domain",
        "checkpoint_key",
        "started_at",
        "triggered_by",
    }

    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(
            str(before.get(fieldname) or "") != str(self.get(fieldname) or "")
            for fieldname in self.IMMUTABLE_FIELDS
        ):
            frappe.throw(
                "Reconciliation run identity is immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Reconciliation run records are retained as operational evidence.",
            frappe.ValidationError,
        )
