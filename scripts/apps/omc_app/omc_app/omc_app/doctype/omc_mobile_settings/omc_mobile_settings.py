import frappe
from frappe.model.document import Document


ERP_DEFAULTS = {
	"customer_doctype": "Customer",
	"customer_name_field": "customer_name",
	"customer_email_field": "email_id",
	"customer_mobile_field": "mobile_no",
	"invoice_doctype": "Sales Invoice",
	"invoice_customer_field": "customer",
	"invoice_total_field": "grand_total",
	"invoice_outstanding_field": "outstanding_amount",
	"invoice_status_field": "status",
	"invoice_due_date_field": "due_date",
	"payment_doctype": "Payment Entry",
	"payment_party_field": "party",
	"payment_amount_field": "paid_amount",
	"payment_date_field": "posting_date",
}


STANDALONE_REQUIRED_DOCTYPES = [
	"OMC Mobile Settings",
]


class OMCMobileSettings(Document):
	def before_save(self):
		self.apply_standard_defaults()

	def apply_standard_defaults(self):
		if not self.integration_mode:
			self.integration_mode = "Standalone"

		if self.is_mobile_backend_active is None:
			self.is_mobile_backend_active = 1

		for fieldname, value in ERP_DEFAULTS.items():
			if not self.get(fieldname):
				self.set(fieldname, value)

	def validate_mobile_backend(self):
		errors = []
		warnings = []

		for doctype in STANDALONE_REQUIRED_DOCTYPES:
			if not frappe.db.exists("DocType", doctype):
				errors.append(f"Required OMC DocType not found: {doctype}")

		if self.erpnext_integration_enabled:
			erp_report = self.validate_erpnext_mapping(update_doc=False)
			errors.extend(erp_report.get("errors") or [])
			warnings.extend(erp_report.get("warnings") or [])
		else:
			warnings.append("ERPNext integration is disabled. Running in standalone OMC mode.")

		status = "Valid" if not errors else "Invalid"
		report = {
			"mode": self.integration_mode or "Standalone",
			"erpnext_integration_enabled": int(self.erpnext_integration_enabled or 0),
			"status": status,
			"errors": errors,
			"warnings": warnings,
		}

		self.last_validation_status = status
		self.last_validation_report = frappe.as_json(report, indent=2)
		self.save(ignore_permissions=True)

		return report

	def validate_erpnext_mapping(self, update_doc=True):
		errors = []
		warnings = []

		required_doctypes = [
			self.customer_doctype,
			self.invoice_doctype,
			self.payment_doctype,
		]

		for doctype in required_doctypes:
			if doctype and not frappe.db.exists("DocType", doctype):
				errors.append(f"ERPNext DocType not found: {doctype}")

		field_checks = [
			(self.customer_doctype, self.customer_name_field, "Customer name field"),
			(self.customer_doctype, self.customer_email_field, "Customer email field"),
			(self.customer_doctype, self.customer_mobile_field, "Customer mobile field"),
			(self.invoice_doctype, self.invoice_customer_field, "Invoice customer field"),
			(self.invoice_doctype, self.invoice_total_field, "Invoice total field"),
			(self.invoice_doctype, self.invoice_outstanding_field, "Invoice outstanding field"),
			(self.invoice_doctype, self.invoice_status_field, "Invoice status field"),
			(self.invoice_doctype, self.invoice_due_date_field, "Invoice due date field"),
			(self.payment_doctype, self.payment_party_field, "Payment party field"),
			(self.payment_doctype, self.payment_amount_field, "Payment amount field"),
			(self.payment_doctype, self.payment_date_field, "Payment date field"),
		]

		for doctype, fieldname, label in field_checks:
			if not doctype or not fieldname:
				warnings.append(f"{label} is not configured.")
				continue

			if not frappe.db.exists("DocType", doctype):
				continue

			if not frappe.get_meta(doctype).has_field(fieldname):
				errors.append(f"{label} not found: {doctype}.{fieldname}")

		status = "Valid" if not errors else "Invalid"
		report = {
			"mode": "ERPNext Hybrid",
			"status": status,
			"errors": errors,
			"warnings": warnings,
		}

		if update_doc:
			self.last_validation_status = status
			self.last_validation_report = frappe.as_json(report, indent=2)
			self.save(ignore_permissions=True)

		return report


@frappe.whitelist()
def auto_detect_mapping():
	settings = frappe.get_single("OMC Mobile Settings")
	settings.integration_mode = settings.integration_mode or "Standalone"

	for fieldname, value in ERP_DEFAULTS.items():
		if not settings.get(fieldname):
			settings.set(fieldname, value)

	settings.last_validation_status = "Not Validated"
	settings.last_validation_report = ""
	settings.save(ignore_permissions=True)

	return {
		"message": "Standard optional ERPNext mapping defaults applied.",
		"integration_mode": settings.integration_mode,
		"erpnext_integration_enabled": int(settings.erpnext_integration_enabled or 0),
		"settings": {fieldname: settings.get(fieldname) for fieldname in ERP_DEFAULTS},
	}


@frappe.whitelist()
def validate_mapping():
	settings = frappe.get_single("OMC Mobile Settings")
	return settings.validate_mobile_backend()


@frappe.whitelist()
def validate_erpnext_mapping():
	settings = frappe.get_single("OMC Mobile Settings")
	return settings.validate_erpnext_mapping()


@frappe.whitelist()
def activate_mobile_backend():
	settings = frappe.get_single("OMC Mobile Settings")
	report = settings.validate_mobile_backend()

	if report.get("errors"):
		frappe.throw("Cannot activate mobile backend. Fix validation errors first.")

	settings.is_mobile_backend_active = 1
	settings.save(ignore_permissions=True)

	return {
		"message": "OMC mobile backend activated.",
		"status": "Active",
		"mode": settings.integration_mode or "Standalone",
	}


@frappe.whitelist()
def deactivate_mobile_backend():
	settings = frappe.get_single("OMC Mobile Settings")
	settings.is_mobile_backend_active = 0
	settings.save(ignore_permissions=True)

	return {
		"message": "OMC mobile backend deactivated.",
		"status": "Inactive",
	}
