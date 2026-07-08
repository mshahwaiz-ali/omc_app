import frappe
from frappe.model.document import Document


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
