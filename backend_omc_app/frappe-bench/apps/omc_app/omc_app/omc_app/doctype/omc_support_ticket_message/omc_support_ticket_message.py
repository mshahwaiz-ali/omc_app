import frappe
from frappe.model.document import Document


class OMCSupportTicketMessage(Document):
    def before_insert(self):
        if not self.sender_user:
            self.sender_user = frappe.session.user if getattr(frappe, "session", None) else None

        if not self.sender_type:
            self.sender_type = "Customer"

        if not self.quarantine_status:
            self.quarantine_status = (
                "Manual Review" if self.attachment else "Not Required"
            )

    def validate(self):
        if not (self.message or "").strip() and not self.attachment:
            frappe.throw("Message or attachment is required.")
