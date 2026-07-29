from __future__ import annotations

import frappe

from omc_app.api import expense


def _category_exists(category):
    value = str(category or "").strip()
    if not value or value == "Uncategorized":
        return True
    if not expense._has_doctype("OMC Expense Category"):
        return True
    return bool(frappe.db.exists("OMC Expense Category", value))


def _local_receipt_exists(file_url):
    value = str(file_url or "").strip()
    if not value:
        return True
    if value.startswith("http://") or value.startswith("https://"):
        return True
    if not value.startswith("/files/") and not value.startswith("/private/files/"):
        return True
    return bool(frappe.db.exists("File", {"file_url": value}))


def _sanitize_entry(entry):
    sanitized = dict(entry or {})
    if not _category_exists(sanitized.get("category")):
        sanitized["category"] = "Uncategorized"
    if not _local_receipt_exists(sanitized.get("receipt_file")):
        sanitized["receipt_file"] = ""
    return sanitized


def _sanitize_budget(row):
    sanitized = dict(row or {})
    category = sanitized.get("category")
    if category and not _category_exists(category):
        sanitized["category"] = ""
    return sanitized


@frappe.whitelist()
def get_expense_entries(month=None, limit=200, start=0):
    response = expense.get_expense_entries(month=month, limit=limit, start=start)
    entries = [_sanitize_entry(entry) for entry in response.get("entries") or []]
    return {
        **response,
        "entries": entries,
        "summary": expense._summary(entries),
    }


@frappe.whitelist()
def get_expense_summary(month=None):
    response = get_expense_entries(month=month)
    return response.get("summary") or expense._summary([])


@frappe.whitelist()
def get_expense_budgets(month=None):
    response = expense.get_expense_budgets(month=month)
    budgets = [_sanitize_budget(row) for row in response.get("budgets") or []]
    return {**response, "budgets": budgets}
