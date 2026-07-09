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

        if self.payment_method not in {"Cash", "Card", "Bank Transfer", "Wallet"}:
            frappe.throw("Payment Method must be Cash, Card, Bank Transfer or Wallet")

        if not self.source:
            self.source = "Mobile"

        if self.source not in {"Mobile", "Import", "Desk"}:
            frappe.throw("Source must be Mobile, Import or Desk")

        if not self.status:
            self.status = "Active"

        if self.status not in {"Active", "Archived"}:
            frappe.throw("Status must be Active or Archived")

        if not self.user and frappe.session.user != "Guest":
            self.user = frappe.session.user

        self._validate_sync_id()

    def _validate_sync_id(self):
        if not self.sync_id or not self.customer_profile:
            return

        existing = frappe.db.get_value(
            "OMC Expense Entry",
            {
                "customer_profile": self.customer_profile,
                "sync_id": self.sync_id,
                "name": ["!=", self.name],
            },
            "name",
        )
        if existing:
            frappe.throw("Duplicate mobile sync id for this customer")
