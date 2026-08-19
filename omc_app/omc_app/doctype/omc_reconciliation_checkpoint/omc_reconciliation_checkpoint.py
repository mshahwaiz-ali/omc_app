from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCReconciliationCheckpoint(Document):
    def on_trash(self):
        frappe.throw(
            "Reconciliation checkpoints are retained as operational state.",
            frappe.ValidationError,
        )
