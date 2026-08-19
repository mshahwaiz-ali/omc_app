from __future__ import annotations

import frappe
from frappe.model.document import Document


IMMUTABLE_FIELDS = {
    "quarantine_key",
    "domain",
    "source_doctype",
    "source_name",
    "source_version",
    "failure_code",
    "first_seen_at",
}


class OMCTechnicalQuarantine(Document):
    def validate(self):
        if self.is_new():
            return
        before = self.get_doc_before_save()
        if not before:
            return
        changed = [
            fieldname
            for fieldname in IMMUTABLE_FIELDS
            if str(before.get(fieldname) or "") != str(self.get(fieldname) or "")
        ]
        if changed:
            frappe.throw(
                "Technical quarantine identity/evidence fields are immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Technical quarantine records are retained as operational evidence.",
            frappe.ValidationError,
        )
