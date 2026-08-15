from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP
from typing import Any

import frappe

from omc_app.api import access


COMMISSION_DOCTYPE = "OMC Referral Commission"
SETTLEMENT_DOCTYPE = "OMC Commission Settlement"
PAGE_LIMIT = 20
MAX_PAGE_LIMIT = 100


def _text(value: Any) -> str:
    return str(value or "").strip()


def _link(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def _money(value: Any, precision: int = 2) -> Decimal:
    quantum = Decimal(1).scaleb(-precision)
    return Decimal(str(value or 0)).quantize(quantum, rounding=ROUND_HALF_UP)


def _page_value(value, *, default, minimum, maximum):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(parsed, maximum))


def _current_user() -> str:
    return getattr(getattr(frappe, "session", None), "user", None) or "Guest"


def _capabilities(user=None) -> dict:
    return access.get_mobile_capabilities(user=user or _current_user()) or {}


def _require_view_access() -> tuple[str, dict]:
    user = _current_user()
    capabilities = _capabilities(user)
    if user == "Guest" or not capabilities.get("can_view_referral_commissions"):
        frappe.throw(
            "You do not have permission to view referral commissions.",
            frappe.PermissionError,
        )
    return user, capabilities


def _require_manage_access() -> tuple[str, dict]:
    user = _current_user()
    capabilities = _capabilities(user)
    if user == "Guest" or not capabilities.get("can_manage_referral_commissions"):
        frappe.throw(
            "Only an OMC manager or administrator may manage referral commissions.",
            frappe.PermissionError,
        )
    return user, capabilities


def _eligible_referral(request):
    profile_name = _link(getattr(request, "customer_profile", None))
    if not profile_name or not frappe.db.exists("OMC Customer Profile", profile_name):
        return None, None

    profile = frappe.get_doc("OMC Customer Profile", profile_name)
    if not int(getattr(profile, "referral_assistance_consent", 0) or 0):
        return profile, None

    referral_name = (
        _link(getattr(request, "referral_record", None))
        or _link(getattr(profile, "referral_record", None))
    )
    if not referral_name or not frappe.db.exists("OMC Referral", referral_name):
        return profile, None

    referral = frappe.get_doc("OMC Referral", referral_name)
    if not int(getattr(referral, "is_active", 0) or 0):
        return profile, None
    if _text(getattr(referral, "status", None)) in {"Inactive", "Revoked"}:
        return profile, None

    referrer = _link(getattr(referral, "referrer_user", None))
    request_owner = _link(getattr(request, "referral_owner", None))
    profile_owner = _link(getattr(profile, "referred_by", None))
    if not referrer or (request_owner and request_owner != referrer):
        return profile, None
    if profile_owner and profile_owner != referrer:
        return profile, None
    return profile, referral


def create_earning_for_posted_payment(payment, *, request, invoice):
    """Create the immutable earning for a fully posted ERP payment exactly once."""
    payment_name = _link(getattr(payment, "name", None))
    event_key = f"payment:{payment_name}:finance-posted"
    if not payment_name:
        frappe.throw("A named OMC payment is required for commission calculation.")

    existing = frappe.db.get_value(
        COMMISSION_DOCTYPE,
        {"unique_event_key": event_key},
        "name",
    )
    if existing:
        return {"created": False, "earning": existing, "reason": "already_exists"}

    service_name = _link(getattr(request, "service", None))
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        return {"created": False, "earning": None, "reason": "service_missing"}

    service = frappe.get_doc("OMC Service", service_name)
    if not int(getattr(service, "referral_commission_enabled", 0) or 0):
        return {"created": False, "earning": None, "reason": "commission_disabled"}

    rate = Decimal(str(getattr(service, "referral_commission_percent", 0) or 0))
    if rate <= 0:
        return {"created": False, "earning": None, "reason": "zero_rate"}
    if rate > 100:
        frappe.throw("Referral commission percent cannot exceed 100.")

    profile, referral = _eligible_referral(request)
    if not referral:
        return {"created": False, "earning": None, "reason": "no_eligible_referral"}

    if int(getattr(invoice, "docstatus", 0) or 0) != 1:
        frappe.throw("Commission requires a submitted ERP Sales Invoice.")
    if Decimal(str(getattr(invoice, "outstanding_amount", 0) or 0)) > 0:
        frappe.throw("Commission requires a fully paid ERP Sales Invoice.")

    basis = _money(getattr(invoice, "grand_total", 0))
    if basis <= 0:
        frappe.throw("Commission basis must be greater than zero.")
    amount = (basis * rate / Decimal("100")).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )
    if amount <= 0:
        return {"created": False, "earning": None, "reason": "rounded_to_zero"}

    earned_on = frappe.utils.now_datetime()
    earning = frappe.new_doc(COMMISSION_DOCTYPE)
    earning.referrer_user = referral.referrer_user
    earning.referral_record = referral.name
    earning.customer_profile = profile.name
    earning.service_request = request.name
    earning.service = service.name
    earning.qualifying_payment = payment_name
    earning.qualifying_erp_invoice = invoice.name
    earning.basis_amount = float(basis)
    earning.commission_percent_snapshot = float(rate)
    earning.commission_amount = float(amount)
    earning.currency = _text(getattr(invoice, "currency", None)) or "PKR"
    earning.earning_status = "Earned"
    earning.earned_on = earned_on
    earning.period_month = earned_on.strftime("%Y-%m")
    earning.unique_event_key = event_key
    try:
        earning.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        existing = frappe.db.get_value(
            COMMISSION_DOCTYPE,
            {"unique_event_key": event_key},
            "name",
        )
        if not existing:
            raise
        return {"created": False, "earning": existing, "reason": "already_exists"}

    from omc_app.api import mobile

    mobile._create_customer_notification(
        recipient_user=referral.referrer_user,
        title="Referral commission earned",
        message=(
            f"Commission of {earning.currency} {earning.commission_amount:,.2f} "
            f"was earned for service request {request.name}."
        ),
        notification_type="Commission",
        reference_doctype=COMMISSION_DOCTYPE,
        reference_name=earning.name,
        mobile_route=f"/my-commissions/{earning.name}",
        event_key=f"{event_key}:commission-earned",
    )
    return {"created": True, "earning": earning.name, "reason": "earned"}


def _earning_payload(row) -> dict:
    return {
        "id": row.name,
        "referrer_user": row.referrer_user,
        "referral_record": row.referral_record,
        "customer_profile": row.customer_profile,
        "customer_name": frappe.db.get_value("OMC Customer Profile", row.customer_profile, "full_name") or "",
        "service_request": row.service_request,
        "service": row.service,
        "service_title": frappe.db.get_value("OMC Service", row.service, "title") or row.service,
        "qualifying_payment": row.qualifying_payment,
        "qualifying_erp_invoice": row.qualifying_erp_invoice,
        "basis_amount": row.basis_amount,
        "commission_percent": row.commission_percent_snapshot,
        "commission_amount": row.commission_amount,
        "currency": row.currency,
        "status": row.earning_status,
        "earned_on": str(row.earned_on or ""),
        "period_month": row.period_month,
        "settlement_reference": row.settlement_reference or "",
        "settled_on": str(row.settled_on or ""),
        "reversed_on": str(row.reversed_on or ""),
        "reversal_reason": row.reversal_reason or "",
    }


def _filters_for_user(user, *, period_month=None, status=None, customer_profile=None, service=None):
    filters = {"referrer_user": user}
    if _text(period_month):
        filters["period_month"] = _text(period_month)
    if _text(status):
        normalized = _text(status).title()
        if normalized not in {"Earned", "Settled", "Reversed"}:
            frappe.throw("Unsupported commission status.")
        filters["earning_status"] = normalized
    if _text(customer_profile):
        filters["customer_profile"] = _text(customer_profile)
    if _text(service):
        filters["service"] = _text(service)
    return filters


@frappe.whitelist()
def get_my_commission_summary(period_month=None):
    user, _ = _require_view_access()
    filters = _filters_for_user(user, period_month=period_month)
    rows = frappe.get_all(
        COMMISSION_DOCTYPE,
        filters=filters,
        fields=["earning_status", "commission_amount", "currency"],
        limit_page_length=0,
    )
    totals = {}
    for row in rows:
        bucket = totals.setdefault(row.currency or "PKR", {"outstanding": 0.0, "settled": 0.0, "reversed": 0.0, "count": 0})
        key = {"Earned": "outstanding", "Settled": "settled", "Reversed": "reversed"}.get(row.earning_status)
        if key:
            bucket[key] = float(_money(bucket[key]) + _money(row.commission_amount))
        bucket["count"] += 1
    return {"period_month": _text(period_month), "currencies": totals}


@frappe.whitelist()
def get_my_commissions(start=0, limit=PAGE_LIMIT, period_month=None, status=None, customer_profile=None, service=None, **kwargs):
    user, _ = _require_view_access()
    start = _page_value(kwargs.get("limit_start", start), default=0, minimum=0, maximum=100000)
    limit = _page_value(kwargs.get("limit_page_length", limit), default=PAGE_LIMIT, minimum=1, maximum=MAX_PAGE_LIMIT)
    filters = _filters_for_user(
        user,
        period_month=period_month,
        status=status,
        customer_profile=customer_profile,
        service=service,
    )
    rows = frappe.get_all(
        COMMISSION_DOCTYPE,
        filters=filters,
        fields=["*"],
        order_by="earned_on desc, name desc",
        limit_start=start,
        limit_page_length=limit + 1,
    )
    has_more = len(rows) > limit
    items = [_earning_payload(row) for row in rows[:limit]]
    return {"items": items, "start": start, "limit": limit, "has_more": has_more, "next_start": start + limit if has_more else None}


@frappe.whitelist()
def get_my_commission(earning_id=None, name=None):
    user, _ = _require_view_access()
    earning_id = _text(earning_id or name)
    if not earning_id or not frappe.db.exists(COMMISSION_DOCTYPE, earning_id):
        frappe.throw("Commission earning not found.", frappe.DoesNotExistError)
    row = frappe.get_doc(COMMISSION_DOCTYPE, earning_id)
    if row.referrer_user != user:
        frappe.throw("Commission earning not found.", frappe.DoesNotExistError)
    return _earning_payload(row)


@frappe.whitelist()
def reverse_commission(earning_id=None, reason=None):
    user, _ = _require_manage_access()
    earning_id = _text(earning_id)
    reason = _text(reason)
    if not reason:
        frappe.throw("A reversal reason is required.")
    if not earning_id or not frappe.db.exists(COMMISSION_DOCTYPE, earning_id):
        frappe.throw("Commission earning not found.", frappe.DoesNotExistError)
    earning = frappe.get_doc(COMMISSION_DOCTYPE, earning_id)
    if earning.earning_status == "Reversed":
        return {"updated": False, "earning": _earning_payload(earning)}
    earning.earning_status = "Reversed"
    earning.reversed_on = frappe.utils.now_datetime()
    earning.reversal_reason = reason[:1000]
    earning.flags.ignore_permissions = True
    earning.flags.allow_commission_status_transition = True
    earning.save()
    frappe.get_doc({
        "doctype": "Comment",
        "comment_type": "Info",
        "reference_doctype": COMMISSION_DOCTYPE,
        "reference_name": earning.name,
        "content": f"Commission reversed by {user}: {frappe.utils.escape_html(reason)}",
    }).insert(ignore_permissions=True)
    from omc_app.api import mobile

    mobile._create_customer_notification(
        recipient_user=earning.referrer_user,
        title="Referral commission reversed",
        message=f"Commission {earning.name} was reversed. Reason: {reason}",
        notification_type="Commission",
        reference_doctype=COMMISSION_DOCTYPE,
        reference_name=earning.name,
        mobile_route=f"/my-commissions/{earning.name}",
        event_key=f"commission.reversed:{earning.name}",
    )
    return {"updated": True, "earning": _earning_payload(earning)}
