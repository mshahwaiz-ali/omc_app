"""ERP activation gate for OMC service requests.

OMC requests may exist before ERP Service/Task records are created.

Paid services become ERP-eligible only after payment confirmation.
Zero-price services become eligible once their workflow moves to In Progress.

Existing ERP links are preserved and can still be reconciled safely.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt

def _text(value: Any) -> str:
    return str(value or "").strip()


def request_amount(request, service) -> float:
    final_price = getattr(request, "final_price", None)
    if final_price is not None:
        return flt(final_price)

    return flt(getattr(service, "base_price", None) or 0)


def readiness(request, service) -> dict:
    from omc_app.api.bridge_outbox import eligibility

    state = eligibility(request)
    return {
        "ready": bool(state.get("eligible")),
        "amount": request_amount(request, service),
        "reason": state.get("reason") or "",
    }


def activate_request(
    request,
    *,
    service,
    profile=None,
    manual_customer=None,
    repair=False,
):
    state = readiness(request, service)
    if not state["ready"]:
        return {
            "status": "Not Started",
            "erp_customer": _text(getattr(request, "erp_customer", None)),
            "erp_service": _text(getattr(request, "erp_service", None)),
            "erp_task": _text(getattr(request, "erp_task", None)),
            "task_assignment": None,
            "created": False,
            "eligible": False,
            "reason": state["reason"],
        }

    from omc_app.api.bridge_outbox import enqueue_if_eligible

    operation = enqueue_if_eligible(request.name)
    return {
        "status": "Pending",
        "erp_customer": _text(getattr(request, "erp_customer", None)),
        "erp_service": _text(getattr(request, "erp_service", None)),
        "erp_task": _text(getattr(request, "erp_task", None)),
        "task_assignment": None,
        "created": False,
        "eligible": True,
        "operation": operation,
        "reason": "",
    }
