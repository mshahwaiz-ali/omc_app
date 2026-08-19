import frappe
from frappe.model.document import Document


class OMCReconciliationReview(Document):
    IMMUTABLE_FIELDS = {
        "domain", "source_doctype", "source_name", "reason_code",
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
                "Reconciliation review source identity is immutable.",
                frappe.ValidationError,
            )
