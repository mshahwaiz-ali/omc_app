import frappe
from frappe.model.document import Document


class OMCServiceTimeline(Document):
    def before_insert(self):
        if not self.created_by:
            self.created_by = frappe.session.user

        if not self.event_time:
            self.event_time = frappe.utils.now_datetime()
