import hashlib
import json

import frappe
from frappe.utils import cint, flt


def pricing_version_for(service):
	payload = {
		"activation_policy": getattr(service, "activation_policy", None) or "Full Settlement",
		"base_price": flt(getattr(service, "base_price", None) or 0, 6),
		"currency": str(getattr(service, "currency", None) or "PKR").strip().upper(),
		"service_id": getattr(service, "service_id", None) or getattr(service, "name", None),
		"service_version": max(cint(getattr(service, "service_version", None) or 1), 1),
		"tax_policy": getattr(service, "tax_policy", None) or "No Tax",
		"tax_rate": flt(getattr(service, "tax_rate", None) or 0, 6),
	}
	return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
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
		self._validate_commercial_policy()
		self.pricing_version = self._pricing_version()

	def _validate_commercial_policy(self):
		self.service_version = max(cint(self.service_version or 1), 1)
		self.pending_payment_expiry_hours = max(cint(self.pending_payment_expiry_hours or 72), 1)
		self.duplicate_window_hours = max(cint(self.duplicate_window_hours or 24), 1)
		self.currency = str(self.currency or "PKR").strip().upper()
		self.tax_rate = flt(self.tax_rate or 0, 6)
		if self.tax_rate < 0 or self.tax_rate > 100:
			frappe.throw("Tax rate must be between zero and one hundred.")
		if self.tax_policy == "No Tax" and self.tax_rate:
			frappe.throw("No Tax services must use a zero tax rate.")
		if self.activation_policy == "No Charge" and flt(self.base_price or 0, 6) != 0:
			frappe.throw("No Charge activation requires a zero base price.")

	def _pricing_version(self):
		return pricing_version_for(self)
