import frappe

from omc_app.api import expense


@frappe.whitelist(methods=["POST"])
def upload_expense_receipt(entry_id=None, file_url=None, docname=None):
    """Require receipt bytes to pass the canonical upload validation path."""
    if file_url:
        frappe.throw(
            "Direct receipt URLs are not accepted. Upload the receipt file instead.",
            frappe.ValidationError,
        )

    entry_id = str(entry_id or "").strip()
    docname = str(docname or "").strip()
    if entry_id and docname and entry_id != docname:
        frappe.throw("Conflicting expense entry identifiers", frappe.ValidationError)
    entry_id = entry_id or docname
    if not entry_id:
        frappe.throw("Expense entry is required", frappe.ValidationError)

    if not getattr(frappe, "request", None) or not frappe.request.files:
        frappe.throw("An uploaded receipt file is required", frappe.ValidationError)

    return expense.upload_expense_receipt(entry_id=entry_id)
