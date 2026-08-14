import frappe
from frappe.model.document import Document


class OMCPaymentAccount(Document):
    def validate(self):
        self.title = (self.title or "").strip()
        self.bank_name = (self.bank_name or "").strip()
        self.account_title = (self.account_title or "").strip()
        self.account_number = (self.account_number or "").strip()
        self.iban = (self.iban or "").strip()
        self.branch = (self.branch or "").strip()
        self.currency = (self.currency or "PKR").strip() or "PKR"
        self.whatsapp_number = (self.whatsapp_number or "").strip()
        self.instructions = (self.instructions or "").strip()

        if not self.title:
            frappe.throw("Title is required.")
