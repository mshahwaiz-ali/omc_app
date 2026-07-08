import frappe
from frappe.model.document import Document


class OMCServicePayment(Document):
    def before_insert(self):
        if not self.currency:
            self.currency = "PKR"

    def before_save(self):
        if self.status == "Paid" and not self.paid_on:
            self.paid_on = frappe.utils.now_datetime()

        if self.status != "Paid":
            self.paid_on = None
