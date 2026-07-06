import frappe
from frappe.model.document import Document


class OMCServiceRequest(Document):
	def before_insert(self):
		if not self.naming_series:
			self.naming_series = "OMC-SR-.YYYY.-.#####"

		if not self.requested_by:
			self.requested_by = frappe.session.user

	def before_save(self):
		if self.service and not self.service_title:
			self.service_title = frappe.db.get_value("OMC Service", self.service, "title") or self.service

		if self.customer_profile and not self.customer_name:
			self.customer_name = frappe.db.get_value("OMC Customer Profile", self.customer_profile, "full_name") or ""
