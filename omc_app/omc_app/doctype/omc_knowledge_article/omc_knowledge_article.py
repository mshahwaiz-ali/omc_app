import frappe
from frappe.model.document import Document


class OMCKnowledgeArticle(Document):
    def before_save(self):
        if not self.article_id and self.title:
            self.article_id = frappe.scrub(self.title).replace("_", "-")
