from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

import frappe
from frappe.utils import add_months, get_first_day, get_last_day

from omc_app.api import capabilities, security


DOCTYPE = "OMC Commission Allocation"
PAGE_LIMIT = 20
MAX_PAGE_LIMIT = 100


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> Decimal:
    return Decimal(str(value or 0)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _current_beneficiary() -> str:
    user = getattr(getattr(frappe, "session", None), "user", None) or "Guest"
    if user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    values = capabilities.effective(user)
    if not values.get("can_view_referral_commissions"):
        frappe.throw("You do not have permission to view referral commissions.", frappe.PermissionError)
    return user


def _page(value, default, minimum, maximum):
    try:
        return max(minimum, min(int(value), maximum))
    except (TypeError, ValueError):
        return default


def _period_filters(period_month):
    period = _text(period_month)
    if not period:
        return None
    try:
        start = get_first_day(f"{period}-01")
        end = get_last_day(start)
    except Exception:
        frappe.throw("period_month must use YYYY-MM format.", frappe.ValidationError)
    return ["between", [start, end]]


def _filters(user, *, period_month=None, status=None, customer_profile=None, service=None):
    filters = {"beneficiary_user": user}
    period = _period_filters(period_month)
    if period:
        filters["earned_on"] = period
    normalized = _text(status).title()
    if normalized:
        aliases = {"Earned": "Calculated", "Settled": "Paid"}
        normalized = aliases.get(normalized, normalized)
        if normalized not in {"Calculated", "Held", "Approved", "Payable", "Paid", "Rejected", "Reversed"}:
            frappe.throw("Unsupported commission status.", frappe.ValidationError)
        filters["status"] = normalized
    request_names = None
    if _text(customer_profile):
        request_names = frappe.get_all(
            "OMC Service Request", filters={"customer_profile": _text(customer_profile)},
            pluck="name", limit_page_length=1000,
        )
    if _text(service):
        service_requests = set(frappe.get_all(
            "OMC Service Request", filters={"service": _text(service)},
            pluck="name", limit_page_length=1000,
        ))
        request_names = list(service_requests.intersection(request_names)) if request_names is not None else list(service_requests)
    if request_names is not None:
        filters["service_request"] = ["in", request_names or ["__none__"]]
    return filters


def _payload(row):
    request = frappe.db.get_value(
        "OMC Service Request", row.service_request,
        ["customer_profile", "customer_name", "service", "service_title"], as_dict=True,
    ) or frappe._dict()
    legacy_status = {"Calculated": "Earned", "Paid": "Settled"}.get(row.status, row.status)
    return {
        "id": row.name,
        "name": row.name,
        "referrer_user": row.beneficiary_user,
        "referral_record": "",
        "customer_profile": request.customer_profile or "",
        "customer_name": request.customer_name or row.erp_customer or "",
        "service_request": row.service_request,
        "service": request.service or "",
        "service_title": request.service_title or request.service or "",
        "qualifying_payment": row.payment_entry,
        "qualifying_erp_invoice": row.sales_invoice,
        "basis_amount": row.basis_amount,
        "commission_percent": row.commission_percent_snapshot,
        "commission_percent_snapshot": row.commission_percent_snapshot,
        "commission_amount": row.commission_amount,
        "currency": row.currency or "PKR",
        "status": legacy_status,
        "earning_status": legacy_status,
        "earned_on": str(row.earned_on or ""),
        "period_month": str(row.earned_on or "")[:7],
        "settlement_reference": row.settlement_reference or "",
        "settled_on": str(row.settled_on or ""),
        "reversed_on": str(row.reversed_on or ""),
        "reversal_reason": row.reversal_reason or "",
        "component": row.component,
    }


@frappe.whitelist()
def get_my_commission_summary(period_month=None):
    user = _current_beneficiary()
    security.enforce_rate_limit("authenticated_list", actor=user)
    rows = frappe.get_all(
        DOCTYPE, filters=_filters(user, period_month=period_month),
        fields=[
            "status",
            "currency",
            "sum(commission_amount) as commission_amount",
            "count(name) as allocation_count",
        ],
        group_by="status, currency",
        limit_page_length=100,
    )
    totals = {}
    for row in rows:
        bucket = totals.setdefault(row.currency or "PKR", {"outstanding": 0.0, "settled": 0.0, "reversed": 0.0, "count": 0})
        key = "reversed" if row.status == "Reversed" else ("settled" if row.status == "Paid" else "outstanding")
        bucket[key] = float(_money(bucket[key]) + _money(row.commission_amount))
        bucket["count"] += int(row.allocation_count or 0)
    return {"period_month": _text(period_month), "currencies": totals}


@frappe.whitelist()
def get_my_commissions(start=0, limit=PAGE_LIMIT, period_month=None, status=None, customer_profile=None, service=None, **kwargs):
    user = _current_beneficiary()
    security.enforce_rate_limit("authenticated_list", actor=user)
    start = _page(kwargs.get("limit_start", start), 0, 0, 100000)
    limit = _page(kwargs.get("limit_page_length", limit), PAGE_LIMIT, 1, MAX_PAGE_LIMIT)
    rows = frappe.get_all(
        DOCTYPE,
        filters=_filters(user, period_month=period_month, status=status, customer_profile=customer_profile, service=service),
        fields=["*"], order_by="earned_on desc, name desc",
        limit_start=start, limit_page_length=limit + 1,
    )
    has_more = len(rows) > limit
    return {
        "items": [_payload(row) for row in rows[:limit]], "start": start, "limit": limit,
        "has_more": has_more, "next_start": start + limit if has_more else None,
    }


@frappe.whitelist()
def get_my_commission(earning_id=None, name=None):
    user = _current_beneficiary()
    security.enforce_rate_limit("authenticated_list", actor=user)
    allocation = _text(earning_id or name)
    row = frappe.db.get_value(DOCTYPE, allocation, ["name", "beneficiary_user"], as_dict=True)
    if not row or row.beneficiary_user != user:
        frappe.throw("Commission earning not found.", frappe.DoesNotExistError)
    return _payload(frappe.get_doc(DOCTYPE, row.name))
