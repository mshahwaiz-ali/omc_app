import frappe
from frappe.model.document import Document


class OMCFAQ(Document):
    def before_save(self):
        if not self.faq_id and self.question:
            self.faq_id = frappe.scrub(self.question).replace("_", "-")[:120]
