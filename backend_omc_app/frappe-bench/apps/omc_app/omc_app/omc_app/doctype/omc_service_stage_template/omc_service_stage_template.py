import frappe
from frappe.model.document import Document


class OMCServiceStageTemplate(Document):
    def before_validate(self):
        if self.stage_key:
            return

        base = frappe.scrub(self.stage_title or "").strip("_")
        if not base:
            frappe.throw("Stage Title is required to generate the stage key.")

        candidate = base
        counter = 2

        while frappe.db.exists(
            "OMC Service Stage Template",
            {
                "service": self.service,
                "stage_key": candidate,
            },
        ):
            candidate = f"{base}_{counter}"
            counter += 1

        self.stage_key = candidate
