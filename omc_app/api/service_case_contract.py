from __future__ import annotations

import frappe

from omc_app.api import access, secured_mobile, service_case_read


def _text(value) -> str:
    return str(value or "").strip()


def _display_status(request_state: str, operational_status: str) -> str:
    if request_state == "Activated":
        return operational_status or "Activated"
    return {
        "Draft": "Draft",
        "Pending Payment": "Payment Required",
        "Payment Not Required": "Ready for Activation",
        "Ready for Activation": "Ready for Activation",
        "Activating": "Activating",
        "Activation Failed": "Activation Requires Review",
        "Financial Hold": "Financial Hold",
        "Expired": "Expired",
        "Cancelled": "Cancelled",
    }.get(request_state, operational_status or request_state or "Open")


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
            "payment_policy_snapshot",
            "payable_amount",
            "pricing_currency",
            "financial_hold_reason",
            "ready_for_activation_at",
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
            "visible_to_customer": 1,
            "status": ["!=", "Cancelled"],
        },
        fields=[
            "name",
            "service_request",
            "status",
            "receipt_status",
            "accounting_status",
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

    link_rows = frappe.get_all(
        "OMC Accounting Link",
        filters={"service_request": ["in", names]},
        fields=[
            "service_request",
            "sales_invoice",
            "payment_entry",
            "accounting_status",
            "allocated_amount",
            "invoice_docstatus",
            "payment_docstatus",
            "invoice_outstanding_amount",
            "reconciled_at",
        ],
        order_by="creation asc, name asc",
        limit_page_length=min(max(len(names) * 20, len(names)), 2000),
    )
    base_link_map = {}
    allocation_totals = {name: 0.0 for name in names}
    for row in link_rows:
        if not _text(row.payment_entry):
            base_link_map.setdefault(row.service_request, row)
        if (
            _text(row.accounting_status) in {"Partially Settled", "Settled"}
            and int(row.invoice_docstatus or 0) == 1
            and int(row.payment_docstatus or 0) == 1
        ):
            allocation_totals[row.service_request] = frappe.utils.flt(
                allocation_totals.get(row.service_request, 0)
                + frappe.utils.flt(row.allocated_amount or 0),
                6,
            )

    bridge_rows = frappe.get_all(
        "OMC Bridge Operation",
        filters={"service_request": ["in", names]},
        fields=[
            "service_request",
            "state",
            "attempt_count",
            "completed_at",
        ],
        limit_page_length=len(names),
    )
    bridge_map = {row.service_request: row for row in bridge_rows}

    internal = access.is_internal_user(
        str(getattr(getattr(frappe, "session", None), "user", None) or "Guest")
    )
    result = {}
    for name in names:
        request = request_map.get(name)
        if not request:
            continue
        payment = payment_map.get(name)
        base_link = base_link_map.get(name)
        request_state = _text(request.request_state) or "Draft"
        operational_status = _text(request.status) or "Open"
        policy = _text(request.payment_policy_snapshot) or "Full Settlement"
        payable = frappe.utils.flt(request.payable_amount or 0, 6)
        no_charge = policy == "No Charge" and payable <= 0

        receipt_status = (
            "Not Required"
            if no_charge
            else _text(getattr(payment, "receipt_status", None)) or "Not Submitted"
        )
        payment_status = (
            "Not Required"
            if no_charge
            else _text(getattr(payment, "status", None)) or "Pending"
        )
        accounting_status = (
            "Not Required"
            if no_charge
            else _text(getattr(payment, "accounting_status", None))
            or _text(getattr(base_link, "accounting_status", None))
            or "Unmatched"
        )
        review_kind = ""
        if accounting_status == "Quarantined":
            review_kind = "technical_quarantine"
        elif accounting_status == "Review Required":
            review_kind = "human_review"

        bridge = bridge_map.get(name)
        bridge_state = _text(getattr(bridge, "state", None)) or "Not Started"
        raw_hold_reason = _text(request.financial_hold_reason)
        customer_hold_reason = (
            "Settlement requires OMC review." if request_state == "Financial Hold" else ""
        )
        hold_reason = raw_hold_reason if internal else customer_hold_reason
        evidence_complete = bool(
            request.activated_at and request.erp_service and request.erp_task
        )

        result[name] = {
            "request_state": request_state,
            "status": operational_status,
            "operational_status": operational_status,
            "display_status": _display_status(request_state, operational_status),
            "financial_hold": {
                "active": request_state == "Financial Hold",
                "reason": hold_reason,
            },
            "receipt": {
                "status": receipt_status,
                "payment_status": payment_status,
                "payment_id": _text(getattr(payment, "name", None)),
            },
            "settlement": {
                "status": accounting_status,
                "sales_invoice": _text(getattr(base_link, "sales_invoice", None)),
                "payment_entry": _text(getattr(payment, "linked_payment_entry", None)),
                "allocated_amount": allocation_totals.get(name, 0.0),
                "payable_amount": payable,
                "currency": _text(getattr(payment, "currency", None) or request.pricing_currency)
                or "PKR",
                "outstanding_amount": frappe.utils.flt(
                    getattr(base_link, "invoice_outstanding_amount", 0) or 0,
                    6,
                ),
                "reconciled_at": str(getattr(base_link, "reconciled_at", None) or ""),
                "review_kind": review_kind,
            },
            "activation": {
                "state": request_state,
                "bridge_state": bridge_state,
                "attempt_count": int(getattr(bridge, "attempt_count", 0) or 0),
                "activated": request_state == "Activated",
                "evidence_complete": evidence_complete,
                "ready_at": str(request.ready_for_activation_at or ""),
                "activated_at": str(request.activated_at or ""),
                "erp_service": _text(request.erp_service) if internal else "",
                "erp_task": _text(request.erp_task) if internal else "",
            },
            "receipt_status": receipt_status,
            "accounting_status": accounting_status,
            "payment_status": payment_status,
            "financial_hold_reason": hold_reason,
        }
    return result


def _apply_contract(payload: dict, contract: dict) -> dict:
    payload.update(contract)
    # `status` is operational progress only. `request_state` owns request
    # lifecycle, while receipt/settlement/activation/hold remain independent.
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
def get_service_case(case_id=None, request_id=None, name=None, service_request=None):
    response = secured_mobile.get_service_case(
        case_id=case_id or service_request,
        request_id=request_id,
        name=name,
    )
    if not isinstance(response, dict):
        return response
    payload = response.get("case") if isinstance(response.get("case"), dict) else response
    request_name = _text(
        payload.get("name")
        or payload.get("id")
        or case_id
        or request_id
        or name
        or service_request
    )
    contract = _bulk_contract([request_name]).get(request_name, {})
    _apply_contract(payload, contract)
    return response
