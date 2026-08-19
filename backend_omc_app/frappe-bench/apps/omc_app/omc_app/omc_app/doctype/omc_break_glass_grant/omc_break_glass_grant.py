from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import add_to_date, get_datetime, now_datetime


class OMCBreakGlassGrant(Document):
    def validate(self):
        if self.is_new():
            self.granted_by = frappe.session.user
            self.granted_at = now_datetime()
        if not str(self.reason or "").strip():
            frappe.throw("A break-glass reason is required.", frappe.ValidationError)
        if not self.expires_at or get_datetime(self.expires_at) <= now_datetime():
            frappe.throw("A break-glass grant must expire in the future.", frappe.ValidationError)
        if get_datetime(self.expires_at) > add_to_date(now_datetime(), hours=8):
            frappe.throw("A break-glass grant cannot exceed eight hours.", frappe.ValidationError)
        if not self.is_new():
            before = self.get_doc_before_save()
            for fieldname in ("user", "capability", "scope_doctype", "scope_name", "reason", "granted_by", "granted_at", "expires_at"):
                if before and before.get(fieldname) != self.get(fieldname):
                    frappe.throw("Break-glass grant details are immutable.", frappe.ValidationError)

    def on_trash(self):
        frappe.throw(
            "Break-glass grants must be revoked, not deleted.",
            frappe.PermissionError,
        )
