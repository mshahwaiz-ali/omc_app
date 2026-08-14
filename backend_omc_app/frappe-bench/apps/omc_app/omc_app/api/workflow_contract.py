"""Canonical customer-facing workflow projection for OMC service requests."""

from __future__ import annotations

from typing import Any, Mapping

SERVICE_STATUSES = ("Open", "In Progress", "Waiting for Customer", "Waiting for Payment", "Completed", "Cancelled")
DOCUMENT_STATUSES = ("Pending", "Uploaded", "Approved", "Rejected")
PAYMENT_STATUSES = ("Pending", "Receipt Submitted", "Under Review", "Paid", "Rejected", "Cancelled")
SERVICE_TRANSITIONS = {
    "Open": {"In Progress", "Waiting for Customer", "Waiting for Payment", "Cancelled"},
    "In Progress": {"Waiting for Customer", "Waiting for Payment", "Completed", "Cancelled"},
    "Waiting for Customer": {"In Progress", "Waiting for Payment", "Cancelled"},
    "Waiting for Payment": {"In Progress", "Waiting for Customer", "Cancelled"},
    "Completed": set(),
    "Cancelled": set(),
}
_SERVICE_ALIASES = {
    "pending": "Open", "submitted": "Open", "working": "In Progress",
    "processing": "In Progress", "waiting for documents": "Waiting for Customer",
    "payment required": "Waiting for Payment", "closed": "Completed", "canceled": "Cancelled",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> int:
    try:
        return max(int(value or 0), 0)
    except (TypeError, ValueError):
        return 0


def normalize_service_status(value: Any) -> str:
    status = _text(value)
    return status if status in SERVICE_STATUSES else _SERVICE_ALIASES.get(status.lower(), "Open")


def validate_service_transition(current: Any, target: Any) -> tuple[str, str]:
    current_status = normalize_service_status(current)
    target_status = normalize_service_status(target)
    if current_status != target_status and target_status not in SERVICE_TRANSITIONS[current_status]:
        raise ValueError(f"Invalid service transition: {current_status} -> {target_status}")
    return current_status, target_status


def project(case: Mapping[str, Any]) -> dict[str, Any]:
    status = normalize_service_status(case.get("status"))
    required = _number(case.get("required_documents_count"))
    submitted = _number(case.get("submitted_documents_count"))
    approved = _number(case.get("approved_documents_count"))
    missing = _number(case.get("missing_documents_count"))
    rejected_documents = _number(case.get("rejected_documents_count"))
    active_payments = _number(case.get("payments_count"))
    paid_payments = _number(case.get("paid_payments_count"))
    open_payments = _number(case.get("open_payments_count"))
    rejected_payments = _number(case.get("rejected_payments_count"))
    operational_complete = bool(case.get("operational_work_complete"))
    documents_complete = required == 0 or (
        submitted >= required
        and missing == 0
        and rejected_documents == 0
    )
    payment_complete = active_payments == 0 or (paid_payments >= active_payments and open_payments == 0)

    blockers = []
    if not documents_complete:
        blockers.append("Required documents are not fully uploaded.")
    if not payment_complete:
        blockers.append("Required payment has not been confirmed.")
    if rejected_documents or rejected_payments or status == "Waiting for Customer":
        blockers.append("Customer action is still unresolved.")
    if not operational_complete:
        blockers.append("Operational work is not complete.")

    customer_action = bool(missing or rejected_documents or rejected_payments)
    next_action = None
    if rejected_documents:
        next_action = {"type": "document", "action": "replace_rejected", "label": "Upload a corrected document"}
    elif missing:
        next_action = {"type": "document", "action": "upload", "label": "Upload required documents"}
    elif rejected_payments:
        next_action = {"type": "payment", "action": "replace_receipt", "label": "Upload a corrected receipt"}
    elif open_payments or status == "Waiting for Payment":
        customer_action = True
        next_action = {"type": "payment", "action": "pay_or_upload_receipt", "label": "Complete payment"}

    if status == "Completed":
        stage, progress, next_action = "completed", 100, None
    elif status == "Cancelled":
        stage, progress, next_action = "cancelled", 0, None
    elif not documents_complete:
        stage = "documents"
        progress = 15 + round((submitted / required if required else 0) * 30)
    elif not payment_complete or status == "Waiting for Payment":
        stage = "payment"
        progress = 50 + round((paid_payments / active_payments if active_payments else 0) * 20)
    else:
        stage, progress = "processing", (85 if status == "In Progress" else 75)

    milestones = ["request_created"]
    if required: milestones.append("documents_requested")
    if submitted or required and missing < required: milestones.append("documents_submitted")
    if documents_complete: milestones.append("documents_uploaded")
    if active_payments: milestones.append("payment_opened")
    if active_payments and open_payments and not rejected_payments: milestones.append("receipt_submitted")
    if payment_complete and active_payments: milestones.append("payment_paid")
    if status in {"In Progress", "Completed"}: milestones.append("work_started")
    if status == "Completed": milestones.append("service_completed")

    display_status = {"Waiting for Customer": "Customer Action Required", "Waiting for Payment": "Payment Required"}.get(status, status)
    return {
        "status": status, "display_status": display_status, "current_stage": stage,
        "progress": progress / 100, "progress_percent": progress,
        "customer_action_required": customer_action and status not in {"Completed", "Cancelled"},
        "next_action": next_action,
        "next_step": next_action["label"] if next_action else ("OMC is processing your request." if stage == "processing" else ""),
        "milestones": milestones,
        "completion_blockers": blockers,
        "completion_eligible": not blockers,
        "documents_complete": documents_complete, "payment_complete": payment_complete,
    }
