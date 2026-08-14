import frappe
from frappe.model.document import Document


class OMCGuestSession(Document):
    def validate(self):
        if not self.first_active_on:
            self.first_active_on = frappe.utils.now_datetime()
        if not self.last_active_on:
            self.last_active_on = frappe.utils.now_datetime()
        if not self.conversion_status:
            self.conversion_status = "Anonymous"
