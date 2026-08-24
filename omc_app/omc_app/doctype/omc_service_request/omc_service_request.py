import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime

from omc_app.api.request_lifecycle import REQUEST_STATE_TRANSITIONS, compatibility_status


SNAPSHOT_FIELDS = (
	"customer_account", "company_snapshot", "service_version_snapshot", "pricing_version_snapshot",
	"payment_policy_snapshot", "tax_policy_snapshot", "tax_rate_snapshot",
	"tax_amount", "payable_amount", "pricing_snapshot_json", "referral_attribution",
	"submission_data_json", "historical_evidence_json", "customer_consent_reference", "customer_mode",
	"submission_mode", "referral_record", "referral_owner",
)


class OMCServiceRequest(Document):
	def before_insert(self):
		if not self.naming_series:
			self.naming_series = "OMC-SR-.YYYY.-.#####"

		if not self.request_state:
			self.request_state = "Draft"

		historical_import = (
			self.request_state == "Historical"
			and self.source_channel == "Imported"
		)

		if not self.requested_by and not historical_import:
			self.requested_by = frappe.session.user

		self.activation_version = self.activation_version or 1

		if self.meta.get_field("company_snapshot") and not historical_import:
			company = ""
			if self.service:
				company = frappe.db.get_value("OMC Service", self.service, "company") or ""
			if not company:
				frappe.throw(
					"This service has no authoritative Company configured. Configure the OMC Service before creating requests.",
					frappe.ValidationError,
				)
			self.company_snapshot = company

	def before_save(self):
		previous = self.get_doc_before_save()
		self._validate_request_state(previous)
		self._protect_snapshots(previous)
		self._project_compatibility_status()
		if self.service and not self.service_title:
			self.service_title = frappe.db.get_value("OMC Service", self.service, "title") or self.service

		if self.customer_profile and not self.customer_name:
			self.customer_name = frappe.db.get_value("OMC Customer Profile", self.customer_profile, "full_name") or ""

		if self._entered_terminal_status():
			from omc_app.api.customer_documents import archive_service_documents_for_status

			# Terminal cleanup must be transactional. If archival fails, the save
			# must fail too instead of committing a partially terminal request.
			archive_service_documents_for_status(self.name, self.status)

	def _validate_request_state(self, previous):
		if not previous or previous.request_state == self.request_state:
			return
		allowed = REQUEST_STATE_TRANSITIONS.get(previous.request_state or "Draft", set())
		if self.request_state not in allowed:
			frappe.throw(
				f"Request state cannot change from {previous.request_state or 'Draft'} "
				f"to {self.request_state}."
			)
		if self.request_state in {"Pending Payment", "Payment Not Required"} and not self.final_confirmation:
			frappe.throw("Final confirmation is required before submitting a request.")
		if self.request_state == "Activated":
			if not self.erp_service or not self.erp_task:
				frappe.throw(
					"ERP Service and ERP Task evidence are required before activation can complete.",
					frappe.ValidationError,
				)
			if not self.activated_at:
				self.activated_at = now_datetime()
		if self.request_state == "Ready for Activation" and not self.ready_for_activation_at:
			self.ready_for_activation_at = now_datetime()

	def _protect_snapshots(self, previous):
		if not previous:
			return
		for fieldname in SNAPSHOT_FIELDS:
			if previous.get(fieldname) != self.get(fieldname):
				frappe.throw(f"{self.meta.get_label(fieldname)} is immutable after request creation.")

	def _project_compatibility_status(self):
		self.status = compatibility_status(
			self.request_state or "Draft",
			self.status or "",
			activated_at=self.activated_at,
		)

	def _entered_terminal_status(self):
		if self.status not in {"Completed", "Cancelled"}:
			return False

		previous = self.get_doc_before_save()
		return previous is None or previous.status != self.status
