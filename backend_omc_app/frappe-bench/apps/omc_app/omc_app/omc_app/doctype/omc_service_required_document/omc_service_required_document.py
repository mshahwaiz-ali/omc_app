import frappe
from frappe.model.document import Document
from frappe.utils import cint


REUSE_POLICIES = {
    "Always New",
    "Reusable Until Replaced",
    "Reusable for N Days",
}


class OMCServiceRequiredDocument(Document):
    def validate(self):
        if self.allowed_extensions:
            self.allowed_extensions = ",".join(
                ext.strip().lower().lstrip(".")
                for ext in self.allowed_extensions.split(",")
                if ext.strip()
            )

        if not self.max_size_mb:
            self.max_size_mb = 10

        self.reuse_policy = (self.reuse_policy or "Always New").strip()
        if self.reuse_policy not in REUSE_POLICIES:
            frappe.throw("Select a valid document reuse policy.", frappe.ValidationError)

        self.reuse_validity_days = max(cint(self.reuse_validity_days or 0), 0)
        if (
            self.reuse_policy == "Reusable for N Days"
            and self.reuse_validity_days <= 0
        ):
            frappe.throw(
                "Reuse Validity (Days) must be greater than zero for a time-limited reusable document.",
                frappe.ValidationError,
            )
