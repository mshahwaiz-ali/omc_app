import frappe
from frappe.model.document import Document


class OMCSupportTicket(Document):
    def before_insert(self):
        if not self.status:
            self.status = "Open"

        if not self.priority:
            self.priority = "Medium"

        if not self.raised_on:
            self.raised_on = frappe.utils.now_datetime()
