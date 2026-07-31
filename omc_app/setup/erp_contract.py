"""Read-only compatibility contract for the client's ERPNext schema."""

from __future__ import annotations

from dataclasses import dataclass

import frappe


@dataclass(frozen=True)
class FieldContract:
    fieldtype: str
    options: str = ""


REQUIRED_DOCTYPES = (
    "Customer",
    "Service",
    "Task",
    "Task Type",
    "Sales Invoice",
    "Payment Entry",
)

REQUIRED_FIELDS = {
    "Customer": {"user_link": FieldContract("Link", "User")},
    "Service": {
        "customer": FieldContract("Link", "Customer"),
        "service_type": FieldContract("Link", "Task Type"),
        "task_created": FieldContract("Check"),
        "task_link": FieldContract("Link", "Task"),
        "user_link": FieldContract("Link", "User"),
    },
    "Task": {
        "subject": FieldContract("Data"),
        "type": FieldContract("Link", "Task Type"),
        "status": FieldContract("Select"),
        "user_link": FieldContract("Link", "User"),
        "customer": FieldContract("Link", "Customer"),
        "custom_operation_status": FieldContract("Select"),
    },
}


def _text(value) -> str:
    return str(value or "").strip()


def inspect_client_erp_contract() -> list[str]:
    problems: list[str] = []
    if "erpnext" not in set(frappe.get_installed_apps()):
        return ["Required app is not installed on this site: erpnext"]

    available: set[str] = set()
    for doctype in REQUIRED_DOCTYPES:
        if frappe.db.exists("DocType", doctype):
            available.add(doctype)
        else:
            problems.append(f"Missing required ERP DocType: {doctype}")

    for doctype, fields in REQUIRED_FIELDS.items():
        if doctype not in available:
            continue
        meta = frappe.get_meta(doctype)
        for fieldname, expected in fields.items():
            field = meta.get_field(fieldname)
            qualified = f"{doctype}.{fieldname}"
            if not field:
                problems.append(f"Missing required ERP field: {qualified}")
                continue
            actual_type = _text(getattr(field, "fieldtype", None))
            if actual_type != expected.fieldtype:
                problems.append(
                    f"Invalid ERP field type: {qualified} must be {expected.fieldtype}, "
                    f"found {actual_type or 'empty'}"
                )
            if expected.options:
                actual_options = _text(getattr(field, "options", None))
                if actual_options != expected.options:
                    problems.append(
                        f"Invalid ERP field target: {qualified} must point to "
                        f"{expected.options}, found {actual_options or 'empty'}"
                    )
    return problems


def validate_client_erp_contract() -> dict[str, object]:
    problems = inspect_client_erp_contract()
    if problems:
        details = "\n".join(f"- {problem}" for problem in problems)
        frappe.throw(
            "OMC App cannot run because the client ERP contract is incomplete:\n"
            f"{details}\n\nNo ERPNext files or metadata were changed.",
            frappe.ValidationError,
        )
    return {
        "compatible": True,
        "required_app": "erpnext",
        "doctypes": list(REQUIRED_DOCTYPES),
        "validated_fields": sum(len(fields) for fields in REQUIRED_FIELDS.values()),
    }
