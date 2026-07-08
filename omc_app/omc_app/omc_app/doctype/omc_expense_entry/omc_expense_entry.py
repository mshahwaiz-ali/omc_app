import frappe
from frappe.model.document import Document


class OMCExpenseEntry(Document):
    def validate(self):
        if self.transaction_type not in {"Income", "Expense"}:
            frappe.throw("Transaction Type must be Income or Expense")

        if not self.amount or self.amount <= 0:
            frappe.throw("Amount must be greater than zero")

        if not self.transaction_date:
            self.transaction_date = frappe.utils.today()

        if not self.account:
            self.account = "Cash"

        if not self.payment_method:
            self.payment_method = "Cash"
