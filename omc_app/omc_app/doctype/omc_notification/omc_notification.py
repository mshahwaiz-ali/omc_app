import frappe
from frappe.model.document import Document


class OMCNotification(Document):
    def after_insert(self):
        from omc_app.api.push_delivery import create_deliveries_safely
        create_deliveries_safely(self)

    def before_save(self):
        if self.is_read and not self.read_on:
            self.read_on = frappe.utils.now_datetime()

        if not self.is_read:
            self.read_on = None
