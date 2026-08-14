import frappe
from frappe.model.document import Document


class OMCNotification(Document):
    def before_save(self):
        if self.is_read and not self.read_on:
            self.read_on = frappe.utils.now_datetime()

        if not self.is_read:
            self.read_on = None
