import frappe
from frappe.model.document import Document


class OMCSupportTicketMessage(Document):
    def before_insert(self):
        if not self.sender_user:
            self.sender_user = frappe.session.user if getattr(frappe, "session", None) else None

        if not self.sender_type:
            self.sender_type = "Customer"

    def validate(self):
        if not (self.message or "").strip() and not self.attachment:
            frappe.throw("Message or attachment is required.")
