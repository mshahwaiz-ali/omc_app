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
		commission_percent = frappe.utils.flt(
			self.get("referral_commission_percent") or 0,
			4,
		)
		if commission_percent < 0 or commission_percent > 100:
			frappe.throw(
				"Referral commission percent must be between 0 and 100.",
				frappe.ValidationError,
			)
		self.referral_commission_percent = commission_percent
		if not self.get("referral_commission_enabled"):
			self.referral_commission_percent = 0

		if not self.service_id:
			self.service_id = self.name or frappe.scrub(self.title or "").replace("_", "-").strip("-")
