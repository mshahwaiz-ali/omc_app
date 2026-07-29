import frappe
from frappe.model.document import Document

TERMINAL_PAYMENT_STATUSES = {"Paid", "Cancelled"}
TERMINAL_SERVICE_REQUEST_STATUSES = {"Completed", "Cancelled"}
ALLOWED_PAYMENT_STATUS_TRANSITIONS = {
    "Pending": {"Receipt Submitted", "Under Review", "Cancelled"},
    "Receipt Submitted": {"Under Review", "Paid", "Rejected", "Cancelled"},
    "Under Review": {"Paid", "Rejected", "Cancelled"},
    "Rejected": {"Receipt Submitted", "Under Review", "Cancelled"},
    "Paid": set(),
    "Cancelled": set(),
}


def _clean_status(value):
    return (value or "").strip()


def _assert_payment_status_transition(previous_status, next_status):
    previous_status = _clean_status(previous_status)
    next_status = _clean_status(next_status)
    if not previous_status or previous_status == next_status:
        return

    allowed = ALLOWED_PAYMENT_STATUS_TRANSITIONS.get(previous_status, set())
    if next_status not in allowed:
        frappe.throw(
            f"Payment status cannot change from {previous_status} to {next_status}."
        )


class OMCServicePayment(Document):
    def before_insert(self):
        if not self.currency:
            self.currency = "PKR"
        self._assert_parent_is_mutable()

    def before_save(self):
        previous = self.get_doc_before_save()
        previous_status = getattr(previous, "status", None) if previous else None
        _assert_payment_status_transition(previous_status, self.status)

        if previous_status != self.status:
            self._assert_parent_is_mutable()

        if self.status == "Paid" and not self.paid_on:
            self.paid_on = frappe.utils.now_datetime()

        if self.status != "Paid":
            self.paid_on = None

    def _assert_parent_is_mutable(self):
        if not self.service_request:
            return

        request_status = frappe.db.get_value(
            "OMC Service Request",
            self.service_request,
            "status",
        )
        if request_status in TERMINAL_SERVICE_REQUEST_STATUSES:
            frappe.throw(
                f"Payments cannot be changed after service request {self.service_request} "
                f"is {request_status}."
            )
