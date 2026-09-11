from __future__ import annotations

import frappe
from frappe.model.document import Document


class OMCPaymentReceipt(Document):
    IMMUTABLE_FIELDS = {
        "service_payment",
        "service_request",
        "source_key",
        "receipt_attachment",
        "submitted_reference",
        "submitted_remarks",
        "submitted_by",
        "submitted_at",
        "currency",
    }

    def before_insert(self):
        # The parent payment can be system-created, so its owner is not proof
        # of who uploaded the receipt. Preserve the actual attached File actor.
        file_row = None
        if self.receipt_attachment and self.service_payment:
            file_row = frappe.db.get_value(
                "File",
                {
                    "file_url": self.receipt_attachment,
                    "attached_to_doctype": "OMC Service Payment",
                    "attached_to_name": self.service_payment,
                },
                ["owner", "creation"],
                as_dict=True,
            )
        if file_row:
            self.submitted_by = file_row.owner
            self.submitted_at = file_row.creation
        self.review_status = self.review_status or "Submitted"
        self.accounting_state = self.accounting_state or "Not Started"

    def validate(self):
        if frappe.utils.flt(self.verified_amount or 0) < 0:
            frappe.throw("Verified amount cannot be negative.", frappe.ValidationError)
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if before and any(
            before.get(fieldname) != self.get(fieldname)
            for fieldname in self.IMMUTABLE_FIELDS
        ):
            frappe.throw(
                "Payment receipt evidence identity is immutable.",
                frappe.ValidationError,
            )
        if before and before.accounting_state == "Completed":
            protected = {
                "review_status",
                "verified_amount",
                "payment_account",
                "reviewed_by",
                "reviewed_at",
                "verification_source",
                "gateway_transaction_id",
                "sales_invoice",
                "payment_entry",
            }
            if any(before.get(fieldname) != self.get(fieldname) for fieldname in protected):
                frappe.throw(
                    "Completed payment receipt evidence cannot be rewritten.",
                    frappe.ValidationError,
                )

    def on_trash(self):
        frappe.throw(
            "Payment receipt evidence cannot be deleted; reject or reverse it through the guarded payment workflow.",
            frappe.PermissionError,
        )
