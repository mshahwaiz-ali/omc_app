import frappe
from frappe.model.document import Document


class OMCCustomerProfile(Document):
	def before_save(self):
		if self.email:
			self.email = self.email.strip().lower()

		if not self.full_name and self.user:
			self.full_name = frappe.db.get_value("User", self.user, "full_name") or self.user

		if not self.email and self.user and self.user != "Guest":
			self.email = self.user
