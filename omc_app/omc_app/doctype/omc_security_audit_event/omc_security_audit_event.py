from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCSecurityAuditEvent(Document):
    def before_insert(self):
        if not self.event_id:
            self.event_id = frappe.generate_hash(length=32)

    def validate(self):
        if not self.is_new() and self.get_doc_before_save():
            frappe.throw("Security audit events are append-only.", frappe.PermissionError)

    def on_trash(self):
        frappe.throw("Security audit events cannot be deleted.", frappe.PermissionError)
