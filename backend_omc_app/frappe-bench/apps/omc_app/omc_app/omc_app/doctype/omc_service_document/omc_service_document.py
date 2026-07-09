import frappe
from frappe.model.document import Document


def _get_service_customer_profile(service_request):
    if not service_request:
        return ""

    return frappe.db.get_value(
        "OMC Service Request",
        service_request,
        "customer_profile",
    ) or ""


class OMCServiceDocument(Document):
    def before_insert(self):
        if not self.uploaded_by:
            self.uploaded_by = frappe.session.user

        if not self.uploaded_on:
            self.uploaded_on = frappe.utils.now_datetime()

        self._fill_customer_profile()
        self._fill_defaults()

    def before_save(self):
        self._fill_customer_profile()
        self._fill_defaults()

    def _fill_customer_profile(self):
        if self.service_request and not self.customer_profile:
            self.customer_profile = _get_service_customer_profile(self.service_request)

    def _fill_defaults(self):
        if not self.source:
            self.source = "Service Upload"

        if not self.archive_reason and not self.is_archived:
            self.archive_reason = ""

        if self.is_archived and not self.archived_on:
            self.archived_on = frappe.utils.now_datetime()
