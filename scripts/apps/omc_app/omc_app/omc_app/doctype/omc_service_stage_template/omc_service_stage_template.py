import frappe
from frappe.model.document import Document


class OMCServiceStageTemplate(Document):
    def validate(self):
        self._validate_unique_stage_key()

    def _validate_unique_stage_key(self):
        if not self.service or not self.stage_key:
            return

        filters = {
            "service": self.service,
            "stage_key": self.stage_key,
        }
        if not self.is_new():
            filters["name"] = ["!=", self.name]

        existing = frappe.db.exists("OMC Service Stage Template", filters)
        if existing:
            frappe.throw(
                f"Stage Key {frappe.bold(self.stage_key)} is already used for this service."
            )
