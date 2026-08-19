import frappe
from frappe.model.document import Document


class OMCAccountingLink(Document):
    IMMUTABLE_FIELDS = {
        "source_key", "service_request", "sales_invoice", "payment_entry",
        "payment_reference_row",
    }

    def validate(self):
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
