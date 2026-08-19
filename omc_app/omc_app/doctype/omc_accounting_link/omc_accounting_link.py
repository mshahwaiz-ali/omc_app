import frappe
from frappe.model.document import Document


class OMCAccountingLink(Document):
    IMMUTABLE_FIELDS = {
        "source_key",
        "service_request",
        "sales_invoice",
        "base_invoice_key",
        "base_request_key",
        "payment_entry",
        "payment_reference_row",
        "linked_by",
        "linked_at",
    }

    def before_insert(self):
        is_allocation = bool(self.payment_entry)
        self.base_invoice_key = None if is_allocation else self.sales_invoice
        self.base_request_key = None if is_allocation else self.service_request

    def validate(self):
        if self.payment_entry and (self.base_invoice_key or self.base_request_key):
            frappe.throw(
                "Payment allocation evidence cannot claim base accounting keys.",
                frappe.ValidationError,
            )
        if not self.payment_entry:
            if self.base_invoice_key != self.sales_invoice:
                frappe.throw(
                    "Base accounting evidence must use the linked Sales Invoice as its unique key.",
                    frappe.ValidationError,
                )
            if self.base_request_key != self.service_request:
                frappe.throw(
                    "Base accounting evidence must use the service request as its unique request key.",
                    frappe.ValidationError,
                )
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(
            before.get(fieldname) != self.get(fieldname)
            for fieldname in self.IMMUTABLE_FIELDS
        ):
            frappe.throw(
                "Accounting evidence identities are immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Accounting evidence cannot be deleted; reconcile or reverse it through the guarded finance workflow.",
            frappe.PermissionError,
        )
