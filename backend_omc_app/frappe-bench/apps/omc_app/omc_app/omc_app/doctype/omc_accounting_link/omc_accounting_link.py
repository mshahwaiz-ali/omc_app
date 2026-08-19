import frappe
from frappe.model.document import Document


class OMCAccountingLink(Document):
    IMMUTABLE_FIELDS = {
        "source_key",
        "service_request",
        "sales_invoice",
        "base_invoice_key",
        "payment_entry",
        "payment_reference_row",
    }

    def before_insert(self):
        # Only the base invoice evidence row gets the unique invoice key.
        # Payment allocation evidence rows intentionally leave it empty so
        # many allocations can coexist for the same linked Sales Invoice.
        self.base_invoice_key = None if self.payment_entry else self.sales_invoice

    def validate(self):
        if self.payment_entry and self.base_invoice_key:
            frappe.throw(
                "Payment allocation evidence cannot claim the base invoice key.",
                frappe.ValidationError,
            )
        if not self.payment_entry and self.base_invoice_key != self.sales_invoice:
            frappe.throw(
                "Base accounting evidence must use the linked Sales Invoice as its unique key.",
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
