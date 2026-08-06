"""Canonical mobile workflow contract for OMC-linked ERP Tasks."""

from __future__ import annotations

from typing import Any


OPERATION_STATUSES = (
    "Open",
    "Pending at Operation Side",
    "Pending at Tax Associate",
    "Pending at Client",
    "Submitted by Operation",
    "Pending at QC",
    "Submitted by QC",
)


STATUS_LABELS = {
    "Open": "Open",
    "Pending at Operation Side": "Pending at Operations",
    "Pending at Tax Associate": "Pending at Tax Associate",
    "Pending at Client": "Waiting for Customer",
    "Submitted by Operation": "Submit to QC",
    "Pending at QC": "QC Review",
    "Submitted by QC": "Complete QC Review",
}


TRANSITIONS = {
    "Open": (
        "Pending at Operation Side",
        "Pending at Tax Associate",
    ),
    "Pending at Operation Side": (
        "Pending at Tax Associate",
        "Pending at Client",
        "Submitted by Operation",
    ),
    "Pending at Tax Associate": (
        "Pending at Operation Side",
        "Pending at Client",
        "Submitted by Operation",
    ),
    "Pending at Client": (
        "Pending at Operation Side",
        "Pending at Tax Associate",
    ),
    "Submitted by Operation": (
        "Pending at QC",
        "Pending at Operation Side",
        "Pending at Tax Associate",
    ),
    "Pending at QC": (
        "Pending at Operation Side",
        "Pending at Tax Associate",
        "Submitted by QC",
    ),
    "Submitted by QC": (),
}


def text(value: Any) -> str:
    return str(value or "").strip()


def normalise_status(value: Any) -> str:
    clean_value = text(value)
    return clean_value if clean_value in OPERATION_STATUSES else "Open"


def allowed_status_values(current_status: Any) -> tuple[str, ...]:
    current = normalise_status(current_status)
    return TRANSITIONS.get(current, ())


def is_transition_allowed(current_status: Any, requested_status: Any) -> bool:
    requested = text(requested_status)
    return requested in allowed_status_values(current_status)


def allowed_transitions(current_status: Any) -> list[dict[str, Any]]:
    return [
        {
            "value": status,
            "label": STATUS_LABELS.get(status, status),
            "requires_confirmation": status == "Submitted by QC",
            "terminal": status == "Submitted by QC",
        }
        for status in allowed_status_values(current_status)
    ]
