import frappe
from frappe.model.document import Document


class OMCServiceCategory(Document):
	def autoname(self):
		explicit_name = str(self.category_name or "").strip()
		if explicit_name:
			# Source-controlled provisioning may supply a stable category ID
			# that intentionally differs from the display title.
			self.category_name = explicit_name
			self.name = explicit_name
			return

		base = frappe.scrub(self.title or "").replace("_", "-").strip("-")
		if not base:
			frappe.throw("Title is required to generate the category name.")

		candidate = base
		counter = 2
		while frappe.db.exists("OMC Service Category", candidate):
			candidate = f"{base}-{counter}"
			counter += 1

		self.category_name = candidate
		self.name = candidate

	def before_save(self):
		if not self.category_name:
			self.category_name = self.name or frappe.scrub(self.title or "").replace("_", "-").strip("-")
