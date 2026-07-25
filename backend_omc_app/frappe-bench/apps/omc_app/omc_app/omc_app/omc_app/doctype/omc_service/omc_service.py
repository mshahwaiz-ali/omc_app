import frappe
from frappe.model.document import Document


class OMCService(Document):
	def autoname(self):
		base = frappe.scrub(self.title or "").replace("_", "-").strip("-")
		if not base:
			frappe.throw("Title is required to generate the service ID.")

		candidate = base
		counter = 2
		while frappe.db.exists("OMC Service", candidate):
			candidate = f"{base}-{counter}"
			counter += 1

		self.service_id = candidate
		self.name = candidate

	def before_save(self):
		if not self.service_id:
			self.service_id = self.name or frappe.scrub(self.title or "").replace("_", "-").strip("-")
