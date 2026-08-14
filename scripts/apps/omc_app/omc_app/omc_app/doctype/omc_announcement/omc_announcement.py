import frappe
from frappe.model.document import Document


class OMCAnnouncement(Document):
    def before_save(self):
        if not self.announcement_id and self.title:
            self.announcement_id = frappe.scrub(self.title).replace("_", "-")
