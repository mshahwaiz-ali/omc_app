import frappe
from frappe.model.document import Document


class OMCExpenseBudget(Document):
    def validate(self):
        if not self.user and frappe.session.user != "Guest":
            self.user = frappe.session.user

        if not self.month:
            self.month = frappe.utils.get_first_day(frappe.utils.today())
        else:
            self.month = frappe.utils.get_first_day(self.month)

        if not self.limit_amount or self.limit_amount <= 0:
            frappe.throw("Budget limit must be greater than zero")

        if self.alert_threshold is None:
            self.alert_threshold = 80

        if self.alert_threshold <= 0 or self.alert_threshold > 100:
            frappe.throw("Alert threshold must be between 1 and 100")

        if self.active is None:
            self.active = 1
