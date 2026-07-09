import frappe
from frappe.model.document import Document


class OMCExpenseCategory(Document):
    def validate(self):
        if self.transaction_type not in {"Income", "Expense"}:
            frappe.throw("Transaction Type must be Income or Expense")

        if not self.icon:
            self.icon = "category"

        if self.enabled is None:
            self.enabled = 1

        if self.sort_order is None:
            self.sort_order = 0
