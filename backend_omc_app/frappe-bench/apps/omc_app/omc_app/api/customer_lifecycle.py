from __future__ import annotations


_TERMINAL_STATES = {"cancelled", "expired"}


def _text(value) -> str:
    return str(value or "").strip()


def _lower(value) -> str:
    return _text(value).lower()


def _count(summary, key) -> int:
    try:
        return int((summary or {}).get(key) or 0)
    except (TypeError, ValueError, AttributeError):
        return 0


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
    """Build a customer-facing lifecycle from canonical request/evidence state.

    This is presentation metadata only. It never changes request state and never
    grants authority. request_state plus receipt/settlement/activation evidence
    remain the backend source of truth.
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
    documents = item.get("document_summary") or item.get("documents") or {}
    payments = item.get("payment_summary") or item.get("payments") or {}

    # Dashboard compatibility payloads expose pending/missing and
    # uploaded/under_review as aliases for the same underlying status. Use the
    # larger alias value rather than summing them so lifecycle copy never
    # doubles a customer's required-document count.
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

    receipt_state = _lower(receipt.get("state"))
    settlement_state = _lower(settlement.get("state"))
    receipt_under_review = receipt_state == "submitted" or (
        _count(payments, "receipt_submitted") + _count(payments, "under_review") > 0
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

    payment_complete = (
        request_state
        in {"payment not required", "ready for activation", "activating", "activation failed", "activated"}
        or settlement_state in {"matched", "settled", "complete", "completed", "paid"}
    )
    if request_state == "payment not required":
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
            "A finance hold needs review before the request can continue.",
        )
    elif payment_complete:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "complete",
            "Payment requirements are complete.",
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
    elif request_state in {"ready for activation", "activating"}:
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
    elif request_state == "payment not required":
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
            "Finance review required",
            "Open the request to see the current hold and what happens next.",
            _case_route(case_id),
            "Review hold",
            required=True,
        )
        attention_priority = 100
    elif request_state == "activation failed":
        next_action = _action(
            "review_activation_issue",
            "OMC needs to review activation",
            "Open the request for the latest status. OMC will resolve the activation issue.",
            _case_route(case_id),
            "Review case",
            required=True,
        )
        attention_priority = 95
    elif request_state == "pending payment" and not receipt_under_review:
        next_action = _action(
            "complete_payment",
            "Complete payment",
            "Payment is the next required step for this service request.",
            "/payments",
            "Open payment",
            required=True,
        )
        attention_priority = 90
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
        attention_priority = 85
    elif rejected_docs > 0 or pending_docs > 0:
        next_action = _action(
            "upload_document",
            "Documents need your attention",
            "Upload or replace the required documents for this service request.",
            "/documents",
            "Open documents",
            required=True,
        )
        attention_priority = 75
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
            "Open the request to review its completed status and history.",
            _case_route(case_id),
            "View service",
        )
        attention_priority = 0
    else:
        next_action = _action(
            "view_service",
            "Track service progress",
            "Open this request for its latest status and next expected step.",
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
        for item in (payload.get("service_snapshots") or payload.get("active_services") or [])
        if isinstance(item, dict)
    ]

    # Home should surface the service that most needs customer attention, not
    # merely the most recently modified row. Python sort is stable, so equal
    # priorities preserve the authoritative backend ordering.
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
