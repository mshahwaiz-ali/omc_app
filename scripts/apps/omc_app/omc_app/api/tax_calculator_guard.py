import json
import math

import frappe
from frappe.utils import flt

from omc_app.api import tax_calculator

MAX_PAYLOAD_BYTES = 20_000
MAX_ADVANCED_INPUTS = 50
MAX_AMOUNT = 1_000_000_000_000_000
ALLOWED_INCOME_TYPES = {"salary", "business", "sole_proprietor", "rental"}
ALLOWED_FILER_STATUSES = {"active_filer", "late_filer", "non_filer"}
ALLOWED_INCOME_MODES = {"monthly", "annual"}


def _normalized_key(value):
    return str(value or "").strip().lower().replace("-", "_").replace(" ", "_")


def _validate_amount(value, fieldname):
    if value in (None, ""):
        return
    if isinstance(value, (dict, list, tuple, set)):
        frappe.throw(f"{fieldname} must be a number", frappe.ValidationError)
    if isinstance(value, str) and len(value.strip()) > 64:
        frappe.throw(f"{fieldname} is too long", frappe.ValidationError)

    amount = flt(value)
    if not math.isfinite(amount):
        frappe.throw(f"{fieldname} must be a finite number", frappe.ValidationError)
    if amount < 0:
        frappe.throw(f"{fieldname} cannot be negative", frappe.ValidationError)
    if amount > MAX_AMOUNT:
        frappe.throw(
            f"{fieldname} exceeds the supported maximum",
            frappe.ValidationError,
        )


def _validate_advanced_inputs(value):
    advanced_inputs = tax_calculator._ensure_dict(value)
    if len(advanced_inputs) > MAX_ADVANCED_INPUTS:
        frappe.throw(
            f"advanced_inputs may contain at most {MAX_ADVANCED_INPUTS} fields",
            frappe.ValidationError,
        )

    for key, item in advanced_inputs.items():
        key_text = str(key or "").strip()
        if not key_text or len(key_text) > 80:
            frappe.throw("advanced_inputs contains an invalid field name", frappe.ValidationError)
        _validate_amount(item, f"advanced_inputs.{key_text}")


def _validated_payload(kwargs):
    payload = tax_calculator._extract_payload(kwargs)
    if not isinstance(payload, dict):
        frappe.throw("Tax calculator payload must be an object", frappe.ValidationError)

    try:
        encoded = json.dumps(payload, default=str).encode("utf-8")
    except (TypeError, ValueError):
        frappe.throw("Tax calculator payload is invalid", frappe.ValidationError)
    if len(encoded) > MAX_PAYLOAD_BYTES:
        frappe.throw(
            "Tax calculator payload is too large",
            frappe.ValidationError,
        )

    income_type = _normalized_key(payload.get("income_type") or "salary")
    if income_type not in ALLOWED_INCOME_TYPES:
        frappe.throw("Unsupported income type", frappe.ValidationError)

    filer_status = _normalized_key(payload.get("filer_status") or "active_filer")
    if filer_status not in ALLOWED_FILER_STATUSES:
        frappe.throw("Unsupported filer status", frappe.ValidationError)

    income_mode = _normalized_key(payload.get("income_mode") or "monthly")
    if income_mode not in ALLOWED_INCOME_MODES:
        frappe.throw("Unsupported income mode", frappe.ValidationError)

    for fieldname in ("income_amount", "monthly_income", "yearly_income"):
        _validate_amount(payload.get(fieldname), fieldname)

    _validate_advanced_inputs(payload.get("advanced_inputs"))
    return payload


@frappe.whitelist(allow_guest=True)
def calculate_tax(**kwargs):
    """Validate the public request before using the canonical calculator."""
    payload = _validated_payload(kwargs)
    return tax_calculator.calculate_tax(data=payload)
