import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime


REQUEST_STATE_TRANSITIONS = {
	"Draft": {"Pending Payment", "Payment Not Required", "Cancelled"},
	"Pending Payment": {"Ready for Activation", "Expired", "Cancelled", "Financial Hold"},
	"Payment Not Required": {"Ready for Activation", "Expired", "Cancelled", "Financial Hold"},
	"Ready for Activation": {"Activating", "Financial Hold", "Cancelled"},
	"Activating": {"Activated", "Activation Failed", "Financial Hold"},
	"Activation Failed": {"Ready for Activation", "Activating", "Financial Hold", "Cancelled"},
	"Activated": {"Financial Hold", "Cancelled"},
	"Financial Hold": {"Ready for Activation", "Activated", "Cancelled"},
	"Expired": set(),
	"Cancelled": set(),
}

SNAPSHOT_FIELDS = (
	"customer_account", "service_version_snapshot", "pricing_version_snapshot",
	"payment_policy_snapshot", "tax_policy_snapshot", "tax_rate_snapshot",
	"tax_amount", "payable_amount", "pricing_snapshot_json", "referral_attribution",
	"submission_data_json", "customer_consent_reference", "customer_mode",
	"submission_mode", "referral_record", "referral_owner",
)


class OMCServiceRequest(Document):
	def before_insert(self):
		if not self.naming_series:
			self.naming_series = "OMC-SR-.YYYY.-.#####"

		if not self.requested_by:
			self.requested_by = frappe.session.user
		if not self.request_state:
			self.request_state = "Draft"
		self.activation_version = self.activation_version or 1

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
			try:
				from omc_app.api.customer_documents import archive_service_documents_for_status

				archive_service_documents_for_status(self.name, self.status)
			except Exception:
				frappe.log_error(
					frappe.get_traceback(),
					"OMC Service Document Auto Archive Failed",
				)

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
		if self.request_state == "Activated" and not self.erp_task:
			frappe.throw("An ERP Task is required before activation can complete.")
		if self.request_state == "Ready for Activation" and not self.ready_for_activation_at:
			self.ready_for_activation_at = now_datetime()
		if self.request_state == "Activated" and not self.activated_at:
			self.activated_at = now_datetime()

	def _protect_snapshots(self, previous):
		if not previous:
			return
		for fieldname in SNAPSHOT_FIELDS:
			if previous.get(fieldname) != self.get(fieldname):
				frappe.throw(f"{self.meta.get_label(fieldname)} is immutable after request creation.")

	def _project_compatibility_status(self):
		state = self.request_state or "Draft"
		if state in {"Draft", "Pending Payment", "Payment Not Required", "Ready for Activation"}:
			self.status = "Waiting for Payment" if state == "Pending Payment" else "Open"
		elif state in {"Activating", "Activated", "Activation Failed", "Financial Hold"}:
			if state == "Activated" and self.status == "Completed":
				return
			self.status = "In Progress" if state == "Activated" else "Open"
		elif state in {"Expired", "Cancelled"}:
			self.status = "Cancelled"

	def _entered_terminal_status(self):
		if self.status not in {"Completed", "Cancelled"}:
			return False

		previous = self.get_doc_before_save()
		return previous is None or previous.status != self.status
