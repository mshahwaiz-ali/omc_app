"""Canonical notification event and deep-link contract.

Callers persist through ``mobile._create_customer_notification`` until the
legacy notification helpers are fully decomposed. Route templates here are the
single reviewable matrix used by tests and new event producers.
"""

EVENT_MATRIX = {
    "service.status": ("Service Request", "OMC Service Request", "/my-services/{reference}"),
    "document.review": ("Document", "OMC Service Document", "/documents/{reference}"),
    "payment.review": ("Payment", "OMC Payment", "/payments/{reference}"),
    "task.assignment": ("Service Request", "Task", "/tasks/{reference}"),
    "support.reply": ("Support", "OMC Support Ticket", "/support/tickets/{reference}"),
    "service.escalation": ("Service Request", "OMC Service Request", "/my-services/{reference}"),
    "commission.earned": ("Commission", "OMC Referral Commission", "/my-commissions/{reference}"),
    "commission.settled": ("Commission", "OMC Referral Commission", "/my-commissions/{reference}"),
    "commission.reversed": ("Commission", "OMC Referral Commission", "/my-commissions/{reference}"),
}


def event_contract(event_name: str, reference: str):
    category, doctype, route = EVENT_MATRIX[event_name]
    return {
        "category": category,
        "reference_doctype": doctype,
        "reference_name": reference,
        "mobile_route": route.format(reference=reference),
        "event_key": f"{event_name}:{reference}",
    }


def validated_mobile_route(route: str) -> str:
    clean = str(route or "").strip()
    allowed_roots = (
        "/my-services/",
        "/documents/",
        "/payments/",
        "/tasks/",
        "/support-tickets/",
        "/my-commissions/",
        "/notifications/",
    )
    if not clean.startswith(allowed_roots):
        return ""
    if ":" in clean or "//" in clean or "?" in clean or "#" in clean:
        return ""
    return clean
