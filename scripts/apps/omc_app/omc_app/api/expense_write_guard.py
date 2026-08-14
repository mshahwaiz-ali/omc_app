import json
import math

import frappe

from omc_app.api import expense

MAX_BULK_ENTRIES = 200
MAX_BULK_BYTES = 200_000
MAX_AMOUNT = 1_000_000_000_000
TEXT_LIMITS = {
    "sync_id": 140,
    "id": 140,
    "category": 140,
    "account": 140,
    "payment_method": 140,
    "paymentMethod": 140,
    "merchant": 140,
    "note": 2000,
    "receipt_file": 500,
    "receiptFile": 500,
    "source": 80,
    "status": 80,
}


def _validate_amount(value, fieldname="amount", allow_zero=False):
    try:
        amount = float(value)
    except (TypeError, ValueError):
        frappe.throw(f"{fieldname} must be a number", frappe.ValidationError)
    if not math.isfinite(amount):
        frappe.throw(f"{fieldname} must be finite", frappe.ValidationError)
    if amount < 0 or (amount == 0 and not allow_zero):
        comparator = "non-negative" if allow_zero else "greater than zero"
        frappe.throw(f"{fieldname} must be {comparator}", frappe.ValidationError)
    if amount > MAX_AMOUNT:
        frappe.throw(f"{fieldname} exceeds the supported maximum", frappe.ValidationError)
    return amount


def _bounded_text(value, fieldname, max_length):
    if value is None:
        return value
    if not isinstance(value, (str, int, float)):
        frappe.throw(f"{fieldname} must be text", frappe.ValidationError)
    text = str(value).strip()
    if len(text) > max_length:
        frappe.throw(
            f"{fieldname} must be {max_length} characters or fewer",
            frappe.ValidationError,
        )
    return text


def _validated_entry(payload):
    if not isinstance(payload, dict):
        frappe.throw("Each expense entry must be an object", frappe.ValidationError)
    data = dict(payload)
    if "amount" in data:
        data["amount"] = _validate_amount(data.get("amount"))
    for fieldname, max_length in TEXT_LIMITS.items():
        if fieldname in data:
            data[fieldname] = _bounded_text(data.get(fieldname), fieldname, max_length)
    return data


def _validated_entries(entries):
    parsed = expense._parse_entries(entries)
    if len(parsed) > MAX_BULK_ENTRIES:
        frappe.throw(
            f"A bulk sync may contain at most {MAX_BULK_ENTRIES} entries",
            frappe.ValidationError,
        )
    encoded = json.dumps(parsed, default=str).encode("utf-8")
    if len(encoded) > MAX_BULK_BYTES:
        frappe.throw("Bulk expense payload is too large", frappe.ValidationError)
    return [_validated_entry(item) for item in parsed]


@frappe.whitelist()
def create_expense_entry(**kwargs):
    return expense.create_expense_entry(**_validated_entry(kwargs))


@frappe.whitelist()
def update_expense_entry(entry_id=None, name=None, **kwargs):
    return expense.update_expense_entry(
        entry_id=entry_id,
        name=name,
        **_validated_entry(kwargs),
    )


@frappe.whitelist()
def bulk_sync_expense_entries(entries=None, **kwargs):
    validated = _validated_entries(entries if entries is not None else kwargs.get("entries"))
    return expense.bulk_sync_expense_entries(entries=validated)


@frappe.whitelist()
def save_expense_budget(**kwargs):
    data = dict(kwargs or {})
    if "limit_amount" in data:
        data["limit_amount"] = _validate_amount(data.get("limit_amount"))
    if "alert_threshold" in data:
        threshold = _validate_amount(
            data.get("alert_threshold"),
            fieldname="alert_threshold",
            allow_zero=True,
        )
        if threshold > 100:
            frappe.throw("alert_threshold cannot exceed 100", frappe.ValidationError)
        data["alert_threshold"] = threshold
    if "category" in data:
        data["category"] = _bounded_text(data.get("category"), "category", 140)
    return expense.save_expense_budget(**data)
