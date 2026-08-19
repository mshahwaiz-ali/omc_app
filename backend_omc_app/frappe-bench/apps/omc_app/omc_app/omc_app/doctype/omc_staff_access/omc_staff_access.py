from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCStaffAccess(Document):
    def validate(self):
        from omc_app.api.capabilities import INTERNAL_CAPABILITY_KEYS

        self.user = str(self.user or "").strip()
        if not self.user or not frappe.db.exists("User", self.user):
            frappe.throw("Staff Access requires an existing User.", frappe.ValidationError)
        if frappe.db.get_value("User", self.user, "user_type") != "System User":
            frappe.throw("Staff Access requires a System User.", frappe.ValidationError)
        before = None if self.is_new() else self.get_doc_before_save()
        if before and before.user != self.user:
            frappe.throw("Staff Access user is immutable.", frappe.ValidationError)
        seen = set()
        for row in self.capabilities or []:
            code = str(row.capability or "").strip()
            if not code or code in seen:
                frappe.throw("Staff capabilities must be non-empty and unique.", frappe.ValidationError)
            if code not in INTERNAL_CAPABILITY_KEYS:
                frappe.throw("Staff capability is not supported.", frappe.ValidationError)
            seen.add(code)
