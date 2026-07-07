import frappe
from frappe.model.document import Document


class OMCAppBanner(Document):
    def before_save(self):
        if not self.banner_id and self.title:
            self.banner_id = frappe.scrub(self.title).replace("_", "-")
