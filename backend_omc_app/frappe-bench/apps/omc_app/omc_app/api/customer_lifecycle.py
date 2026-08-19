from __future__ import annotations


_TERMINAL_STATES = {"cancelled", "expired"}
_PAYMENT_COMPLETE_STATES = {
    "payment not required",
    "ready for activation",
    "activating",
    "activation failed",
    "activated",
}
_SETTLED_STATES = {"matched", "settled", "complete", "completed", "paid"}
_RECEIPT_REVIEW_STATES = {"submitted", "receipt submitted", "under review"}


def _text(value) -> str:
    return str(value or "").strip()


def _lower(value) -> str:
    return _text(value).lower()


def _count(summary, key) -> int:
    try:
        return max(int((summary or {}).get(key) or 0), 0)
    except (TypeError, ValueError, AttributeError):
        return 0


def _item_count(item, key) -> int:
    try:
        return max(int((item or {}).get(key) or 0), 0)
    except (TypeError, ValueError, AttributeError):
        return 0


def _document_summary(item: dict) -> dict:
    for key in ("document_summary", "documents"):
        value = item.get(key)
        if isinstance(value, dict):
            return value

    total = _item_count(item, "required_documents_count")
    submitted = _item_count(item, "submitted_documents_count")
    missing = _item_count(item, "missing_documents_count")
    approved = _item_count(item, "approved_documents_count")
    rejected = _item_count(item, "rejected_documents_count")
    uploaded = max(submitted - approved, 0)
    return {
        "total": total,
        "pending": missing,
        "missing": missing,
        "uploaded": uploaded,
        "under_review": uploaded,
        "approved": approved,
        "rejected": rejected,
    }


def _payment_summary(item: dict) -> dict:
    for key in ("payment_summary", "payments"):
        value = item.get(key)
        if isinstance(value, dict):
            return value

    total = _item_count(item, "payments_count")
    paid = _item_count(item, "paid_payments_count")
    open_count = _item_count(item, "open_payments_count")
    rejected = _item_count(item, "rejected_payments_count")
    return {
        "total": total,
        "pending": open_count,
        "payments_due": open_count,
        "paid": paid,
        "rejected": rejected,
    }


def _milestone(key, label, state, detail=""):
    return {
        "key": key,
        "label": label,
        "state": state,
        "detail": _text(detail),
    }


def _case_route(case_id: str) -> str:
    return f"/my-services/{case_id}" if case_id else "/my-services"


def _action(action_type, title, subtitle, route, button_label, *, required=False):
    return {
        "type": action_type,
        "title": title,
        "subtitle": subtitle,
        "route": route,
        "button_label": button_label,
        "required": bool(required),
    }


def lifecycle_presentation(snapshot: dict) -> dict:
    """Build customer-facing lifecycle metadata from canonical request evidence.

    This projection is presentation-only. It never grants authority or mutates
    business state. ``request_state`` plus receipt, settlement, activation and
    document evidence remain authoritative.
    """
    item = dict(snapshot or {})
    case_id = _text(item.get("id") or item.get("name"))
    request_state = _lower(item.get("request_state")) or "draft"
    operational_status = _lower(
        item.get("operational_status") or item.get("status")
    )
    receipt = item.get("receipt") if isinstance(item.get("receipt"), dict) else {}
    settlement = (
        item.get("settlement") if isinstance(item.get("settlement"), dict) else {}
    )
    documents = _document_summary(item)
    payments = _payment_summary(item)

    # Dashboard compatibility payloads expose pending/missing and
    # uploaded/under_review as aliases for the same underlying status. Use the
    # larger alias value rather than summing so copy never double-counts.
    pending_docs = max(
        _count(documents, "pending"),
        _count(documents, "missing"),
    )
    rejected_docs = _count(documents, "rejected")
    uploaded_docs = max(
        _count(documents, "uploaded"),
        _count(documents, "under_review"),
    )
    approved_docs = _count(documents, "approved")
    total_docs = _count(documents, "total")
    if not total_docs:
        total_docs = pending_docs + rejected_docs + uploaded_docs + approved_docs

    receipt_state = _lower(
        receipt.get("state")
        or receipt.get("status")
        or item.get("receipt_status")
    )
    payment_state = _lower(
        receipt.get("payment_status") or item.get("payment_status")
    )
    settlement_state = _lower(
        settlement.get("state")
        or settlement.get("status")
        or item.get("accounting_status")
    )
    receipt_under_review = (
        receipt_state in _RECEIPT_REVIEW_STATES
        or payment_state in _RECEIPT_REVIEW_STATES
        or _count(payments, "receipt_submitted") > 0
        or _count(payments, "under_review") > 0
    )
    receipt_rejected = (
        receipt_state == "rejected"
        or payment_state == "rejected"
        or _count(payments, "rejected") > 0
    )
    payment_not_required = (
        request_state == "payment not required"
        or receipt_state == "not required"
        or payment_state == "not required"
        or settlement_state == "not required"
    )
    payment_complete = (
        payment_not_required
        or request_state in _PAYMENT_COMPLETE_STATES
        or settlement_state in _SETTLED_STATES
    )

    terminal = request_state in _TERMINAL_STATES
    completed = request_state == "activated" and operational_status == "completed"

    request_milestone = _milestone(
        "request",
        "Request received",
        "complete",
        "Your service request is registered with OMC.",
    )

    if total_docs <= 0:
        documents_milestone = _milestone(
            "documents",
            "Documents",
            "skipped",
            "No documents are currently required.",
        )
    elif rejected_docs > 0:
        documents_milestone = _milestone(
            "documents",
            "Documents",
            "attention",
            f"{rejected_docs} document{'s' if rejected_docs != 1 else ''} need replacement.",
        )
    elif pending_docs > 0:
        documents_milestone = _milestone(
            "documents",
            "Documents",
            "attention",
            f"{pending_docs} document{'s' if pending_docs != 1 else ''} still required.",
        )
    elif uploaded_docs > 0:
        documents_milestone = _milestone(
            "documents",
            "Documents",
            "current",
            "Uploaded documents are waiting for OMC review.",
        )
    else:
        documents_milestone = _milestone(
            "documents",
            "Documents",
            "complete",
            "Required documents are approved.",
        )

    if payment_not_required:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "skipped",
            "No payment is required for this request.",
        )
    elif request_state == "financial hold":
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "attention",
            "A finance hold needs OMC review before the request can continue.",
        )
    elif payment_complete:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "complete",
            "Payment requirements are complete.",
        )
    elif request_state == "pending payment" and receipt_rejected:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "attention",
            "The submitted payment evidence needs correction.",
        )
    elif request_state == "pending payment" and receipt_under_review:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "current",
            "Your payment evidence is under review.",
        )
    elif request_state == "pending payment":
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "attention",
            "Payment is the next required step.",
        )
    else:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "pending",
            "Payment status will appear when this stage is reached.",
        )

    if completed:
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            "complete",
            "OMC processing is complete.",
        )
        completed_milestone = _milestone(
            "completed",
            "Completed",
            "complete",
            "This service request is complete.",
        )
    elif terminal:
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            "pending",
            "Processing is no longer active for this request.",
        )
        completed_milestone = _milestone(
            "completed",
            "Completed",
            "attention",
            "This request is no longer active.",
        )
    elif request_state == "activation failed":
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            "attention",
            "Activation needs OMC attention before work can continue.",
        )
        completed_milestone = _milestone("completed", "Completed", "pending")
    elif request_state in {"ready for activation", "activating", "payment not required"}:
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            "current",
            "Your request is entering OMC processing.",
        )
        completed_milestone = _milestone("completed", "Completed", "pending")
    elif request_state == "activated":
        if operational_status == "waiting for customer":
            detail = "OMC needs information or action from you."
            state = "attention"
        elif operational_status == "in progress":
            detail = "OMC is actively working on your request."
            state = "current"
        else:
            detail = "Your request is active with OMC."
            state = "current"
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            state,
            detail,
        )
        completed_milestone = _milestone("completed", "Completed", "pending")
    else:
        processing_milestone = _milestone(
            "processing",
            "OMC processing",
            "pending",
            "Processing begins after the request is ready.",
        )
        completed_milestone = _milestone("completed", "Completed", "pending")

    if completed:
        progress = 100
        current_stage = "Completed"
    elif terminal:
        progress = 0
        current_stage = "Cancelled" if request_state == "cancelled" else "Expired"
    elif request_state == "activation failed":
        progress = 70
        current_stage = "Activation needs attention"
    elif request_state == "financial hold":
        progress = 50
        current_stage = "Finance review"
    elif request_state == "activated":
        progress = 85
        current_stage = (
            "Waiting for you"
            if operational_status == "waiting for customer"
            else "OMC processing"
        )
    elif request_state == "activating":
        progress = 75
        current_stage = "Activating"
    elif request_state == "ready for activation":
        progress = 65
        current_stage = "Ready for processing"
    elif payment_not_required:
        progress = 60
        current_stage = "Ready for processing"
    elif request_state == "pending payment":
        progress = 50 if receipt_under_review else 45
        current_stage = "Payment review" if receipt_under_review else "Payment"
    elif rejected_docs > 0 or pending_docs > 0:
        progress = 25
        current_stage = "Documents"
    elif uploaded_docs > 0:
        progress = 30
        current_stage = "Document review"
    else:
        progress = 15
        current_stage = "Request received"

    if terminal:
        next_action = _action(
            "view_service",
            "Review service request",
            "This request is no longer active. Open it for the final status and history.",
            _case_route(case_id),
            "View request",
        )
        attention_priority = 5
    elif request_state == "financial hold":
        next_action = _action(
            "review_financial_hold",
            "Finance review in progress",
            "OMC is reviewing the financial hold. No new customer action is required right now.",
            _case_route(case_id),
            "View status",
        )
        attention_priority = 70
    elif request_state == "activation failed":
        next_action = _action(
            "review_activation_issue",
            "OMC is resolving an activation issue",
            "OMC needs to resolve the activation issue before work can continue. No new customer action is required right now.",
            _case_route(case_id),
            "View status",
        )
        attention_priority = 65
    elif request_state == "pending payment" and receipt_rejected:
        next_action = _action(
            "correct_payment_receipt",
            "Payment evidence needs correction",
            "Open payments and submit corrected payment evidence for this request.",
            "/payments",
            "Open payment",
            required=True,
        )
        attention_priority = 100
    elif request_state == "pending payment" and not receipt_under_review:
        next_action = _action(
            "complete_payment",
            "Complete payment",
            "Payment is the next required step for this service request.",
            "/payments",
            "Open payment",
            required=True,
        )
        attention_priority = 100
    elif request_state == "pending payment" and receipt_under_review:
        next_action = _action(
            "await_payment_review",
            "Payment under review",
            "OMC is reviewing your submitted payment evidence. No new payment action is needed right now.",
            "/payments",
            "View payment",
        )
        attention_priority = 60
    elif request_state == "activated" and operational_status == "waiting for customer":
        if rejected_docs > 0 or pending_docs > 0:
            next_action = _action(
                "upload_document",
                "Documents need your attention",
                "OMC is waiting for the required document update before work can continue.",
                "/documents",
                "Open documents",
                required=True,
            )
        else:
            next_action = _action(
                "customer_action_required",
                "OMC is waiting for you",
                "Open the service request to review the information or action OMC needs.",
                _case_route(case_id),
                "Review request",
                required=True,
            )
        attention_priority = 95
    elif rejected_docs > 0 or pending_docs > 0:
        next_action = _action(
            "upload_document",
            "Documents need your attention",
            "Upload or replace the required documents for this service request.",
            "/documents",
            "Open documents",
            required=True,
        )
        attention_priority = 90
    elif uploaded_docs > 0:
        next_action = _action(
            "await_document_review",
            "Documents under review",
            "OMC is reviewing your uploaded documents. No new upload is needed right now.",
            "/documents",
            "View documents",
        )
        attention_priority = 55
    elif completed:
        next_action = _action(
            "view_service",
            "Service completed",
            "Review the completed request and its recorded activity.",
            _case_route(case_id),
            "View service",
        )
        attention_priority = 0
    else:
        next_action = _action(
            "view_service",
            "Track service progress",
            "No new customer action is required right now. OMC will update this request as work progresses.",
            _case_route(case_id),
            "View progress",
        )
        attention_priority = 30

    milestones = [
        request_milestone,
        documents_milestone,
        payment_milestone,
        processing_milestone,
        completed_milestone,
    ]

    return {
        "current_stage": current_stage,
        "progress_percent": progress,
        "milestones": milestones,
        "next_step": next_action["title"],
        "next_action": next_action,
        "action_required": bool(next_action.get("required")),
        "attention_priority": attention_priority,
        "terminal": terminal,
        "completed": completed,
        "payment_not_required": payment_not_required,
    }


def enrich_service_snapshot(snapshot: dict) -> dict:
    enriched = dict(snapshot or {})
    lifecycle = lifecycle_presentation(enriched)
    enriched.update(lifecycle)
    # Keep legacy progress consumers correct while clients migrate to the
    # structured lifecycle contract.
    enriched["progress"] = lifecycle["progress_percent"] / 100.0
    return enriched


def enrich_dashboard(payload: dict) -> dict:
    enriched = dict(payload or {})
    snapshots = [
        enrich_service_snapshot(item)
        for item in (
            payload.get("service_snapshots")
            or payload.get("active_services")
            or []
        )
        if isinstance(item, dict)
    ]

    # Customer-required actions outrank informational OMC-side exceptions.
    # Python sort is stable, so equal priorities preserve backend ordering.
    snapshots.sort(
        key=lambda item: int(item.get("attention_priority") or 0),
        reverse=True,
    )
    enriched["service_snapshots"] = snapshots
    enriched["active_services"] = snapshots

    if snapshots:
        first_action = snapshots[0].get("next_action")
        if isinstance(first_action, dict):
            enriched["next_action"] = first_action
    return enriched
