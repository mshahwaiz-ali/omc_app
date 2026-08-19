from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCCustomerAccount(Document):
    def validate(self):
        self.user = str(self.user or "").strip()
        if not self.user or self.user.lower() == "guest":
            frappe.throw("A customer account requires a valid User.", frappe.ValidationError)
        if frappe.db.get_value("User", self.user, "user_type") == "System User":
            frappe.throw("System Users cannot be customer accounts.", frappe.ValidationError)
        before = None if self.is_new() else self.get_doc_before_save()
        if before and before.user != self.user:
            frappe.throw("Customer Account user is immutable.", frappe.ValidationError)
        if self.account_link_status == "Linked" and not self.erp_customer:
            frappe.throw("A linked account requires an ERP Customer.", frappe.ValidationError)
        if self.erp_customer and self.account_link_status != "Linked":
            frappe.throw("An ERP Customer link requires Linked account status.", frappe.ValidationError)
