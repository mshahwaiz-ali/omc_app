import frappe
from frappe.model.document import Document


class OMCExpenseCategory(Document):
    def validate(self):
        if self.transaction_type not in {"Income", "Expense"}:
            frappe.throw("Transaction Type must be Income or Expense")
