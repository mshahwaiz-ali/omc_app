from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCReconciliationRun(Document):
    def on_trash(self):
        frappe.throw(
            "Reconciliation run records are retained as operational evidence.",
            frappe.ValidationError,
        )
