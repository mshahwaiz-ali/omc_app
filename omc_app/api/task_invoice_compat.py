"""Mode-aware guard for the client's legacy Task invoice actions.

Prepaid OMC Tasks reuse the canonical submitted Sales Invoice created by the
payment workflow. Pay Later OMC Tasks preserve the client's existing Task
Generate Invoice action, but only after guarded OMC validation; the returned
draft invoice is then adopted as the request's canonical accounting evidence.

Non-OMC Tasks delegate to the client's ERPNext implementation unchanged.
"""
from __future__ import annotations

import json

import frappe
from frappe.utils import flt

from omc_app.api import (
    accounting_reconciliation,
    access,
    security,
    service_task_links,
    task_read_guard,
)


REQUEST_DOCTYPE = "OMC Service Request"
LINK_DOCTYPE = "OMC Accounting Link"


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> float:
    return round(flt(value or 0), 6)


def _current_user() -> str:
    return _text(getattr(getattr(frappe, "session", None), "user", None)) or "Guest"


def _execution_mode(request) -> str:
    return _text(getattr(request, "payment_execution_mode", None)) or "Prepaid"


def _request_for_task(task_name: str) -> str:
    """Return the unique OMC request that owns an ERP Task, if any."""
    return service_task_links.request_for_task(_text(task_name))


def _base_invoice(request_name: str):
    return frappe.db.get_value(
        LINK_DOCTYPE,
        {"base_request_key": request_name},
        ["name", "sales_invoice", "accounting_status"],
        as_dict=True,
    )


def _project_task_rate(request_name: str, task_name: str) -> bool:
    """Project the immutable OMC payable amount onto legacy ``Task.rate``.

    ``Task.rate`` is compatibility/operational metadata for OMC Tasks only. It
    must never become accounting authority; the canonical ERP Sales Invoice
    remains the financial source of truth.
    """
    meta = frappe.get_meta("Task")
    if not meta.get_field("rate"):
        return False

    pricing = frappe.db.get_value(
        REQUEST_DOCTYPE,
        request_name,
        ["payable_amount", "final_price"],
        as_dict=True,
    )
    if not pricing:
        return False

    payable = getattr(pricing, "payable_amount", None)
    if payable is None:
        payable = getattr(pricing, "final_price", None)
    expected = max(_money(payable), 0)
    if expected <= 0:
        return False

    current = _money(
        frappe.db.get_value("Task", task_name, "rate")
    )
    if abs(current - expected) <= 0.000001:
        return False

    frappe.db.set_value(
        "Task",
        task_name,
        "rate",
        expected,
        update_modified=False,
    )
    return True


def project_task_invoice_flag(*, request_name: str = "", task_name: str = "") -> dict:
    """Project canonical OMC invoicing into legacy ``Task.invoiced``.

    The flag is compatibility/UI state only. Once an OMC accounting link owns
    a canonical invoice, the legacy Task must remain marked invoiced even if
    that invoice is later cancelled; finance reconciliation, not Task, owns
    repair of the accounting source.
    """
    request_name = _text(request_name)
    task_name = _text(task_name)
    if not request_name and task_name:
        request_name = _request_for_task(task_name)
    if request_name and not task_name:
        task_name = _text(
            frappe.db.get_value(REQUEST_DOCTYPE, request_name, "erp_task")
        )
    if not request_name or not task_name or not frappe.db.exists("Task", task_name):
        return {
            "updated": False,
            "rate_updated": False,
            "request": request_name,
            "task": task_name,
            "invoice": "",
        }

    rate_updated = _project_task_rate(request_name, task_name)
    link = _base_invoice(request_name)
    invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
    if not invoice_name:
        return {
            "updated": False,
            "rate_updated": rate_updated,
            "request": request_name,
            "task": task_name,
            "invoice": "",
        }

    meta = frappe.get_meta("Task")
    if not meta.get_field("invoiced"):
        return {
            "updated": False,
            "rate_updated": rate_updated,
            "request": request_name,
            "task": task_name,
            "invoice": invoice_name,
        }

    current = int(frappe.db.get_value("Task", task_name, "invoiced") or 0)
    if current != 1:
        frappe.db.set_value(
            "Task",
            task_name,
            "invoiced",
            1,
            update_modified=False,
        )
    return {
        "updated": current != 1,
        "rate_updated": rate_updated,
        "request": request_name,
        "task": task_name,
        "invoice": invoice_name,
    }


def backfill_task_invoice_flags(limit: int = 500, dry_run: bool = True) -> dict:
    """Backfill legacy ``Task.invoiced`` from canonical OMC accounting links.

    Safe to run repeatedly. This function never creates, submits, repairs, or
    relinks accounting documents; it only projects an existing canonical OMC
    Sales Invoice into legacy Task compatibility fields.
    """
    limit = min(max(int(limit or 500), 1), 5000)
    dry_run = bool(int(dry_run)) if isinstance(dry_run, (str, int)) else bool(dry_run)
    rows = frappe.get_all(
        REQUEST_DOCTYPE,
        filters={"erp_task": ["is", "set"]},
        fields=["name", "erp_task"],
        order_by="creation asc, name asc",
        limit_page_length=limit,
    )

    summary = {
        "dry_run": dry_run,
        "scanned": 0,
        "would_update": 0,
        "updated": 0,
        "already_projected": 0,
        "missing_task": 0,
        "missing_canonical_invoice": 0,
        "task_field_missing": 0,
        "samples": {
            "would_update": [],
            "updated": [],
            "missing_task": [],
            "missing_canonical_invoice": [],
        },
    }
    task_meta = frappe.get_meta("Task")
    has_invoiced = bool(task_meta.get_field("invoiced"))

    for row in rows:
        summary["scanned"] += 1
        request_name = _text(row.name)
        task_name = _text(row.erp_task)
        if not task_name or not frappe.db.exists("Task", task_name):
            summary["missing_task"] += 1
            if len(summary["samples"]["missing_task"]) < 25:
                summary["samples"]["missing_task"].append(
                    {"request": request_name, "task": task_name}
                )
            continue

        link = _base_invoice(request_name)
        invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
        if not invoice_name:
            summary["missing_canonical_invoice"] += 1
            if len(summary["samples"]["missing_canonical_invoice"]) < 25:
                summary["samples"]["missing_canonical_invoice"].append(
                    {"request": request_name, "task": task_name}
                )
            continue

        if not has_invoiced:
            summary["task_field_missing"] += 1
            continue

        current = int(frappe.db.get_value("Task", task_name, "invoiced") or 0)
        if current == 1:
            summary["already_projected"] += 1
            if not dry_run:
                _project_task_rate(request_name, task_name)
            continue

        if dry_run:
            summary["would_update"] += 1
            if len(summary["samples"]["would_update"]) < 25:
                summary["samples"]["would_update"].append(
                    {
                        "request": request_name,
                        "task": task_name,
                        "invoice": invoice_name,
                    }
                )
            continue

        result = project_task_invoice_flag(
            request_name=request_name,
            task_name=task_name,
        )
        if result.get("updated"):
            summary["updated"] += 1
            if len(summary["samples"]["updated"]) < 25:
                summary["samples"]["updated"].append(
                    {
                        "request": request_name,
                        "task": task_name,
                        "invoice": invoice_name,
                    }
                )
        else:
            summary["already_projected"] += 1

    return summary


def sync_task_status(doc, method=None):
    """Project invoice compatibility, then preserve the existing status sync."""
    task_name = _text(getattr(doc, "name", None))
    request_name = _request_for_task(task_name) if task_name else ""
    if request_name:
        project_task_invoice_flag(
            request_name=request_name,
            task_name=task_name,
        )

    from omc_app.api.erp_task_status_sync import sync_task_status as legacy_sync

    return legacy_sync(doc, method)





def _assert_pay_later_invoice_access(task_name: str) -> tuple[str, str]:
    actor = _current_user()
    values = access.get_mobile_capabilities(user=actor)
    if (
        actor == "Guest"
        or not values.get("can_access_internal_workspace")
        or not (
            values.get("can_manage_tasks")
            or values.get("can_manage_assigned_tasks")
        )
    ):
        frappe.throw(
            "You do not have permission to generate invoices for this OMC Task.",
            frappe.PermissionError,
        )

    capability = (
        "can_manage_tasks"
        if values.get("can_manage_tasks")
        else "can_manage_assigned_tasks"
    )
    if capability != "can_manage_tasks":
        assigned = set(task_read_guard._task_assignment_names(actor))
        if task_name not in assigned:
            frappe.throw(
                "You do not have permission to generate an invoice for this Task.",
                frappe.PermissionError,
            )

    security.enforce_rate_limit("staff_mutation", actor=actor)
    return actor, capability


def _load_pay_later_invoice_context(task_name: str, request_name: str):
    locked_request = frappe.db.get_value(
        REQUEST_DOCTYPE,
        request_name,
        "name",
        for_update=True,
    )
    locked_task = frappe.db.get_value(
        "Task",
        task_name,
        "name",
        for_update=True,
    )
    if not locked_request or not locked_task:
        frappe.throw(
            "The OMC Task invoice context is no longer available.",
            frappe.DoesNotExistError,
        )

    request = frappe.get_doc(REQUEST_DOCTYPE, locked_request)
    task = frappe.get_doc("Task", locked_task)

    linked_tasks = service_task_links.task_names(request.name)
    if linked_tasks != [task.name]:
        frappe.throw(
            "Pay Later invoice generation requires exactly one ERP Task for this OMC request.",
            frappe.ValidationError,
        )
    if _text(getattr(request, "erp_task", None)) != task.name:
        frappe.throw(
            "The ERP Task does not match the request's primary Task.",
            frappe.ValidationError,
        )
    if _text(getattr(task, "status", None)) != "Completed":
        frappe.throw(
            "The ERP Task must be Completed before generating the Pay Later invoice.",
            frappe.ValidationError,
        )
    if _execution_mode(request) != "Pay Later":
        frappe.throw(
            "This request is not in Pay Later execution mode.",
            frappe.ValidationError,
        )
    if not (
        _text(getattr(request, "post_paid_approved_by", None))
        and getattr(request, "post_paid_approved_at", None)
        and _text(getattr(request, "pay_later_reason", None))
    ):
        frappe.throw(
            "Pay Later approval evidence is incomplete.",
            frappe.ValidationError,
        )
    if _text(getattr(request, "request_state", None)) != "Activated":
        frappe.throw(
            "The Pay Later service request must be Activated before Task invoicing.",
            frappe.ValidationError,
        )
    if _text(getattr(request, "status", None)) == "Cancelled":
        frappe.throw(
            "A cancelled service request cannot generate an invoice.",
            frappe.ValidationError,
        )

    expected_customer = _text(getattr(request, "erp_customer", None))
    task_customer = _text(getattr(task, "customer", None))
    if not expected_customer or task_customer != expected_customer:
        frappe.throw(
            "ERP Task Customer does not match the OMC request ERP Customer.",
            frappe.ValidationError,
        )

    expected_amount = _money(
        getattr(request, "payable_amount", None)
        if getattr(request, "payable_amount", None) is not None
        else getattr(request, "final_price", None)
    )
    task_rate = _money(getattr(task, "rate", None))
    if expected_amount <= 0:
        frappe.throw(
            "The OMC request has no positive payable amount for Task invoicing.",
            frappe.ValidationError,
        )
    if abs(task_rate - expected_amount) > 0.000001:
        frappe.throw(
            "ERP Task rate does not match the frozen OMC payable amount.",
            frappe.ValidationError,
        )

    return request, task, expected_amount


def _validate_pay_later_invoice(request, invoice, *, expected_amount: float) -> None:
    if int(getattr(invoice, "is_return", 0) or 0):
        frappe.throw(
            "A return Sales Invoice cannot be the Pay Later base invoice.",
            frappe.ValidationError,
        )
    if int(getattr(invoice, "docstatus", 0) or 0) == 2:
        frappe.throw(
            "The existing Pay Later invoice is cancelled. Finance must repair the canonical accounting source.",
            frappe.ValidationError,
        )

    expected_customer = _text(getattr(request, "erp_customer", None))
    expected_company = _text(request.get("company_snapshot"))
    expected_currency = _text(getattr(request, "pricing_currency", None))
    if _text(getattr(invoice, "customer", None)) != expected_customer:
        frappe.throw(
            "Task-generated Sales Invoice customer does not match the OMC request.",
            frappe.ValidationError,
        )
    if _text(getattr(invoice, "company", None)) != expected_company:
        frappe.throw(
            "Task-generated Sales Invoice company does not match the OMC request.",
            frappe.ValidationError,
        )
    if _text(getattr(invoice, "currency", None)) != expected_currency:
        frappe.throw(
            "Task-generated Sales Invoice currency does not match the OMC request.",
            frappe.ValidationError,
        )
    if abs(_money(getattr(invoice, "grand_total", None)) - expected_amount) > 0.000001:
        frappe.throw(
            "Task-generated Sales Invoice total does not match the frozen OMC payable amount.",
            frappe.ValidationError,
        )


def _adopt_pay_later_invoice(
    request,
    task,
    invoice,
    *,
    actor: str,
    capability: str,
    expected_amount: float,
) -> str:
    _validate_pay_later_invoice(
        request,
        invoice,
        expected_amount=expected_amount,
    )

    existing_invoice_request = frappe.db.get_value(
        LINK_DOCTYPE,
        {"base_invoice_key": invoice.name},
        "service_request",
    )
    if existing_invoice_request and existing_invoice_request != request.name:
        frappe.throw(
            "Task-generated Sales Invoice is already linked to another request.",
            frappe.ValidationError,
        )

    existing_request_invoice = frappe.db.get_value(
        LINK_DOCTYPE,
        {"base_request_key": request.name},
        "sales_invoice",
    )
    if existing_request_invoice and existing_request_invoice != invoice.name:
        frappe.throw(
            "Service request already has a canonical Sales Invoice.",
            frappe.ValidationError,
        )

    link = accounting_reconciliation._upsert_link(
        request,
        invoice,
        state="Unmatched",
    )
    security.audit_event(
        event_type="accounting.task_invoice_adopted",
        capability=capability,
        target_doctype=REQUEST_DOCTYPE,
        target_name=request.name,
        source_version=_text(getattr(link, "source_version", None)),
        actor=actor,
        safe_reason="pay_later_task_invoice",
    )
    project_task_invoice_flag(
        request_name=request.name,
        task_name=task.name,
    )
    return invoice.name


def _existing_pay_later_invoice(
    request,
    task,
    *,
    expected_amount: float,
) -> str:
    link = _base_invoice(request.name)
    invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
    if not invoice_name:
        return ""
    if not frappe.db.exists("Sales Invoice", invoice_name):
        frappe.throw(
            f"Canonical Pay Later Sales Invoice {invoice_name} is missing. "
            "Finance must repair the accounting source before another invoice can be generated.",
            frappe.ValidationError,
        )

    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    _validate_pay_later_invoice(
        request,
        invoice,
        expected_amount=expected_amount,
    )
    project_task_invoice_flag(
        request_name=request.name,
        task_name=task.name,
    )
    return invoice.name


def _pay_later_invoice(task_name: str, request_name: str) -> str:
    actor, capability = _assert_pay_later_invoice_access(task_name)
    savepoint = "omc_pay_later_task_invoice"
    frappe.db.savepoint(savepoint)
    try:
        request, task, expected_amount = _load_pay_later_invoice_context(
            task_name,
            request_name,
        )

        existing = _existing_pay_later_invoice(
            request,
            task,
            expected_amount=expected_amount,
        )
        if existing:
            return existing

        from erpnext.projects.doctype.task.task import mk_inv as legacy_mk_inv

        invoice_name = _text(legacy_mk_inv(task.name))
        if not invoice_name or not frappe.db.exists("Sales Invoice", invoice_name):
            frappe.throw(
                "The ERP Task Generate Invoice action did not create a Sales Invoice.",
                frappe.ValidationError,
            )

        invoice = frappe.get_doc("Sales Invoice", invoice_name)
        return _adopt_pay_later_invoice(
            request,
            task,
            invoice,
            actor=actor,
            capability=capability,
            expected_amount=expected_amount,
        )
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise


def _canonical_invoice_or_throw(task_name: str, request_name: str) -> str:
    projection = project_task_invoice_flag(
        request_name=request_name,
        task_name=task_name,
    )
    invoice_name = _text(projection.get("invoice"))
    if not invoice_name:
        frappe.throw(
            "This OMC Task is payment-first and cannot generate an invoice. "
            "No canonical OMC Sales Invoice is linked; finance reconciliation "
            "must repair the request first.",
            frappe.ValidationError,
        )
    if not frappe.db.exists("Sales Invoice", invoice_name):
        frappe.throw(
            f"Canonical OMC Sales Invoice {invoice_name} is missing. "
            "Finance reconciliation must repair the accounting source before "
            "this Task can continue.",
            frappe.ValidationError,
        )
    docstatus = int(
        frappe.db.get_value("Sales Invoice", invoice_name, "docstatus") or 0
    )
    if docstatus != 1:
        frappe.throw(
            f"Canonical OMC Sales Invoice {invoice_name} is not submitted. "
            "A second invoice cannot be generated from the Task; finance must "
            "repair the canonical accounting source.",
            frappe.ValidationError,
        )
    return invoice_name


@frappe.whitelist()
def mk_inv(doc):
    """Use prepaid reuse or guarded Pay Later Task invoicing for OMC Tasks."""
    task_name = _text(doc)
    request_name = _request_for_task(task_name)
    if not request_name:
        from erpnext.projects.doctype.task.task import mk_inv as legacy_mk_inv

        return legacy_mk_inv(task_name)

    request = frappe.get_doc(REQUEST_DOCTYPE, request_name)
    if _execution_mode(request) == "Pay Later":
        return _pay_later_invoice(task_name, request_name)
    return _canonical_invoice_or_throw(task_name, request_name)


@frappe.whitelist()
def bulk_generate_invoices(tasks):
    """Reuse canonical OMC invoices and delegate non-OMC Tasks unchanged."""
    names = frappe.parse_json(tasks)
    if not isinstance(names, list):
        frappe.throw("tasks must be a list of Task names.", frappe.ValidationError)

    generated = []
    legacy_names = []
    for raw_name in names:
        task_name = _text(raw_name)
        if not task_name:
            continue
        request_name = _request_for_task(task_name)
        if not request_name:
            legacy_names.append(task_name)
            continue

        if _text(frappe.db.get_value("Task", task_name, "status")) != "Completed":
            continue
        generated.append(mk_inv(task_name))

    if legacy_names:
        from erpnext.projects.doctype.task.task import (
            bulk_generate_invoices as legacy_bulk_generate_invoices,
        )

        generated.extend(
            legacy_bulk_generate_invoices(json.dumps(legacy_names)) or []
        )
    return generated
