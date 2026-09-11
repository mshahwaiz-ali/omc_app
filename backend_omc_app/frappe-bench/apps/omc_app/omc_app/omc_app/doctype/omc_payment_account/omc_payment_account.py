import frappe
from frappe.model.document import Document


class OMCPaymentAccount(Document):
    def validate(self):
        self.title = (self.title or "").strip()
        self.bank_name = (self.bank_name or "").strip()
        self.account_title = (self.account_title or "").strip()
        self.account_number = (self.account_number or "").strip()
        self.iban = (self.iban or "").strip()
        self.branch = (self.branch or "").strip()
        self.currency = (self.currency or "PKR").strip() or "PKR"
        self.whatsapp_number = (self.whatsapp_number or "").strip()
        self.instructions = (self.instructions or "").strip()

        if not self.title:
            frappe.throw("Title is required.")

        erp_account = (self.erp_account or "").strip()
        if erp_account:
            account = frappe.db.get_value(
                "Account",
                erp_account,
                ["is_group", "root_type", "account_currency"],
                as_dict=True,
            )
            if not account:
                frappe.throw("ERP Account does not exist.", frappe.ValidationError)
            if int(account.is_group or 0):
                frappe.throw("ERP Account must be a leaf account.", frappe.ValidationError)
            if (account.root_type or "").strip() != "Asset":
                frappe.throw("ERP Account must be an Asset account.", frappe.ValidationError)
            account_currency = (account.account_currency or "").strip()
            if account_currency and account_currency != self.currency:
                frappe.throw(
                    "ERP Account currency must match the OMC Payment Account currency.",
                    frappe.ValidationError,
                )

        if self.mode_of_payment and not frappe.db.exists(
            "Mode of Payment", self.mode_of_payment
        ):
            frappe.throw("Mode of Payment does not exist.", frappe.ValidationError)
