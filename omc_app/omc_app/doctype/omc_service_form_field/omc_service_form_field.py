import frappe
from frappe.model.document import Document


class OMCServiceFormField(Document):
    def before_validate(self):
        if self.fieldname:
            return

        base = frappe.scrub(self.label or "").strip("_")
        if not base:
            frappe.throw("Label is required to generate the fieldname.")

        candidate = base
        counter = 2
        while frappe.db.exists(
            "OMC Service Form Field",
            {"service": self.service, "fieldname": candidate},
        ):
            candidate = f"{base}_{counter}"
            counter += 1

        self.fieldname = candidate
