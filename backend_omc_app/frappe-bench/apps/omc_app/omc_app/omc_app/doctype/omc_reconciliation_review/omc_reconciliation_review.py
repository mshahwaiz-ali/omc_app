import frappe
from frappe.model.document import Document


class OMCReconciliationReview(Document):
    IMMUTABLE_FIELDS = {
        "review_key",
        "domain",
        "source_doctype",
        "source_name",
        "source_version",
        "reason_code",
        "safe_evidence_json",
    }

    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(
            str(before.get(fieldname) or "") != str(self.get(fieldname) or "")
            for fieldname in self.IMMUTABLE_FIELDS
        ):
            frappe.throw(
                "Reconciliation review source/evidence is immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Reconciliation reviews are retained as operational evidence.",
            frappe.ValidationError,
        )
