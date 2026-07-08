import frappe
from frappe.model.document import Document


class OMCService(Document):
	def before_save(self):
		if not self.service_id and self.title:
			self.service_id = frappe.scrub(self.title).replace("_", "-")
