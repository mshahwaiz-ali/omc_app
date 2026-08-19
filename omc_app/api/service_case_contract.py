from __future__ import annotations

import frappe

from omc_app.api import secured_mobile, service_case_read


def _text(value) -> str:
    return str(value or "").strip()


def _bulk_contract(request_names: list[str]) -> dict[str, dict]:
    names = sorted({_text(name) for name in request_names if _text(name)})
    if not names:
        return {}

    requests = frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", names]},
        fields=[
            "name",
            "request_state",
            "status",
            "financial_hold_reason",
            "activated_at",
            "erp_service",
            "erp_task",
        ],
        limit_page_length=len(names),
    )
    request_map = {row.name: row for row in requests}

    payment_rows = frappe.get_all(
        "OMC Service Payment",
        filters={
            "service_request": ["in", names],
            "status": ["!=", "Cancelled"],
        },
        fields=[
            "name",
            "service_request",
            "status",
            "receipt_status",
            "accounting_status",
            "quarantine_status",
            "amount",
            "currency",
            "linked_invoice",
            "linked_payment_entry",
            "settled_at",
            "creation",
        ],
        order_by="creation desc, name desc",
        limit_page_length=min(max(len(names) * 4, len(names)), 400),
    )
    payment_map = {}
    for row in payment_rows:
        payment_map.setdefault(row.service_request, row)

    base_links = frappe.get_all(
        "OMC Accounting Link",
        filters={"base_request_key": ["in", names]},
        fields=[
            "service_request",
            "sales_invoice",
            "accounting_status",
            "allocated_amount",
            "invoice_outstanding_amount",
            "reconciled_at",
        ],
        limit_page_length=len(names),
    )
    link_map = {row.service_request: row for row in base_links}

    result = {}
    for name in names:
        request = request_map.get(name)
        if not request:
            continue
        payment = payment_map.get(name)
        link = link_map.get(name)
        accounting_status = _text(
            getattr(link, "accounting_status", None)
            or getattr(payment, "accounting_status", None)
        ) or "Unmatched"
        receipt_status = _text(getattr(payment, "receipt_status", None)) or "Not Submitted"
        payment_status = _text(getattr(payment, "status", None)) or "Not Required"
        request_state = _text(request.request_state) or "Draft"
        result[name] = {
            "request_state": request_state,
            "operational_status": _text(request.status),
            "display_status": request_state if request_state != "Activated" else _text(request.status),
            "financial_hold": {
                "active": request_state == "Financial Hold",
                "reason": _text(request.financial_hold_reason),
            },
            "receipt": {
                "status": receipt_status,
                "payment_status": payment_status,
                "payment_id": _text(getattr(payment, "name", None)),
            },
            "settlement": {
                "status": accounting_status,
                "sales_invoice": _text(getattr(link, "sales_invoice", None)),
                "payment_entry": _text(getattr(payment, "linked_payment_entry", None)),
                "allocated_amount": float(getattr(link, "allocated_amount", 0) or 0),
                "outstanding_amount": float(
                    getattr(link, "invoice_outstanding_amount", 0) or 0
                ),
                "reconciled_at": str(getattr(link, "reconciled_at", None) or ""),
            },
            "activation": {
                "state": request_state,
                "activated": bool(request.activated_at or request.erp_service or request.erp_task),
                "activated_at": str(request.activated_at or ""),
                "erp_service": _text(request.erp_service),
                "erp_task": _text(request.erp_task),
            },
            # Compatibility aliases for clients migrating incrementally.
            "receipt_status": receipt_status,
            "accounting_status": accounting_status,
            "payment_status": payment_status,
            "financial_hold_reason": _text(request.financial_hold_reason),
        }
    return result


def _apply_contract(payload: dict, contract: dict) -> dict:
    payload.update(contract)
    # `status` remains the legacy operational projection. New clients must use
    # `request_state` for lifecycle and `operational_status` for ERP progress.
    return payload


@frappe.whitelist()
def get_service_cases(start=0, limit=20, limit_start=None, limit_page_length=None):
    response = service_case_read.get_service_cases(
        start=start,
        limit=limit,
        limit_start=limit_start,
        limit_page_length=limit_page_length,
    )
    cases = list(response.get("cases") or [])
    contracts = _bulk_contract([item.get("name") or item.get("id") for item in cases])
    response["cases"] = [
        _apply_contract(item, contracts.get(_text(item.get("name") or item.get("id")), {}))
        for item in cases
    ]
    return response


@frappe.whitelist()
def get_service_case(case_id=None, request_id=None, name=None):
    response = secured_mobile.get_service_case(
        case_id=case_id,
        request_id=request_id,
        name=name,
    )
    if not isinstance(response, dict):
        return response
    payload = response.get("case") if isinstance(response.get("case"), dict) else response
    request_name = _text(payload.get("name") or payload.get("id") or case_id or request_id or name)
    contract = _bulk_contract([request_name]).get(request_name, {})
    _apply_contract(payload, contract)
    return response
