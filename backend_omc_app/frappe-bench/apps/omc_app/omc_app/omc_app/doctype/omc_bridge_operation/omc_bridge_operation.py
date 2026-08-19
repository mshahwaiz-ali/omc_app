import frappe
from frappe.model.document import Document


class OMCBridgeOperation(Document):
    IMMUTABLE_FIELDS = {
        "operation_key", "operation_type", "service_request", "source_version",
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
                "Bridge operation identity is immutable.",
                frappe.ValidationError,
            )

    def on_trash(self):
        frappe.throw(
            "Bridge operation evidence cannot be deleted; complete, cancel, or recover it through the guarded activation workflow.",
            frappe.PermissionError,
        )
