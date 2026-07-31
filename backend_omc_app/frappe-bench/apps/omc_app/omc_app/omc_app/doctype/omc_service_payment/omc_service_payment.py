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
        self._assert_financial_integrity()
        self._assert_single_active_payment()

    def before_save(self):
        previous = self.get_doc_before_save()
        previous_status = getattr(previous, "status", None) if previous else None
        _assert_payment_status_transition(previous_status, self.status)

        if previous_status != self.status:
            self._assert_parent_is_mutable()

        self._assert_financial_integrity(previous)

        if self.status == "Paid" and not self.paid_on:
            self.paid_on = frappe.utils.now_datetime()

        if self.status != "Paid":
            self.paid_on = None

    def _assert_financial_integrity(self, previous=None):
        amount = frappe.utils.flt(self.amount or 0)
        if amount <= 0:
            frappe.throw("Payment amount must be greater than zero.")

        if previous:
            if previous.service_request != self.service_request:
                frappe.throw(
                    "Payment service request cannot be changed after creation."
                )
            if frappe.utils.flt(previous.amount or 0) != amount:
                frappe.throw(
                    "Payment amount cannot be changed after creation."
                )

        if self.status in {"Paid", "Rejected"} and not self.receipt_attachment:
            frappe.throw(
                "A receipt must be attached before marking this payment "
                f"as {self.status}."
            )

    def _assert_single_active_payment(self):
        if not self.service_request or self.status == "Cancelled":
            return

        existing = frappe.db.exists(
            "OMC Service Payment",
            {
                "service_request": self.service_request,
                "visible_to_customer": 1,
                "status": ["!=", "Cancelled"],
            },
        )
        if existing:
            frappe.throw(
                f"An active payment already exists for service request "
                f"{self.service_request}."
            )

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
