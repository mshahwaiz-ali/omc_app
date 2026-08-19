from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCReconciliationCheckpoint(Document):
    IMMUTABLE_FIELDS = {"checkpoint_key", "job_key", "domain"}

    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(
            str(before.get(fieldname) or "") != str(self.get(fieldname) or "")
            for fieldname in self.IMMUTABLE_FIELDS
        ):
            frappe.throw(
                "Reconciliation checkpoint identity is immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Reconciliation checkpoints are retained as operational state.",
            frappe.ValidationError,
        )
