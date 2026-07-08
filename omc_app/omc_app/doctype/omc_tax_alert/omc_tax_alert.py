import frappe
from frappe.model.document import Document


class OMCTaxAlert(Document):
    def before_save(self):
        if not self.alert_id and self.title:
            self.alert_id = frappe.scrub(self.title).replace("_", "-")
