import frappe
from frappe.model.document import Document


class OMCOnboardingSlide(Document):
    def before_save(self):
        if not self.slide_id and self.title:
            self.slide_id = frappe.scrub(self.title).replace("_", "-")[:120]
