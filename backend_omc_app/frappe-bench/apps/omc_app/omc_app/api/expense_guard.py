import frappe

from omc_app.api import expense


@frappe.whitelist()
def upload_expense_receipt(entry_id=None, file_url=None):
    """Require receipt bytes to pass the canonical upload validation path."""
    if file_url:
        frappe.throw(
            "Direct receipt URLs are not accepted. Upload the receipt file instead.",
            frappe.ValidationError,
        )

    if not getattr(frappe, "request", None) or not frappe.request.files:
        frappe.throw("An uploaded receipt file is required", frappe.ValidationError)

    return expense.upload_expense_receipt(entry_id=entry_id)
