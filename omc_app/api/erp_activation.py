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

from omc_app.api import erp_service_task_adapter


PAYMENT_DOCTYPE = "OMC Service Payment"


def _text(value: Any) -> str:
    return str(value or "").strip()


def request_amount(request, service) -> float:
    final_price = getattr(request, "final_price", None)
    if final_price is not None:
        return flt(final_price)

    return flt(getattr(service, "base_price", None) or 0)


def _paid_payment_exists(request_name: str) -> bool:
    request_name = _text(request_name)
    if not request_name:
        return False

    if not frappe.db.exists("DocType", PAYMENT_DOCTYPE):
        return False

    return bool(
        frappe.db.exists(
            PAYMENT_DOCTYPE,
            {
                "service_request": request_name,
                "status": "Paid",
            },
        )
    )


def readiness(request, service) -> dict:
    amount = request_amount(request, service)

    if amount > 0:
        if _paid_payment_exists(getattr(request, "name", None)):
            return {
                "ready": True,
                "amount": amount,
                "reason": "",
            }

        return {
            "ready": False,
            "amount": amount,
            "reason": (
                "Payment must be confirmed before ERP Service and "
                "ERP Task creation."
            ),
        }

    if amount == 0:
        if _text(getattr(request, "status", None)) == "In Progress":
            return {
                "ready": True,
                "amount": 0,
                "reason": "",
            }

        return {
            "ready": False,
            "amount": 0,
            "reason": (
                "Zero-price request is not ready for ERP activation yet."
            ),
        }

    return {
        "ready": False,
        "amount": amount,
        "reason": "Service request has an invalid negative price.",
    }


def activate_request(
    request,
    *,
    service,
    profile=None,
    manual_customer=None,
    repair=False,
):
    erp_service = _text(getattr(request, "erp_service", None))
    erp_task = _text(getattr(request, "erp_task", None))

    # Preserve already-completed legacy/current links. This prevents the new
    # payment gate from interfering with ERP records created before this change.
    if (
        erp_service
        and erp_task
        and frappe.db.exists("Service", erp_service)
        and frappe.db.exists("Task", erp_task)
    ):
        result = erp_service_task_adapter.sync_request(
            request,
            service=service,
            profile=profile,
            manual_customer=manual_customer,
            repair=repair,
        )
        return {
            **result,
            "eligible": True,
        }

    state = readiness(request, service)
    if not state["ready"]:
        return {
            "status": "Not Started",
            "erp_customer": _text(
                getattr(request, "erp_customer", None)
            ),
            "erp_service": erp_service,
            "erp_task": erp_task,
            "task_assignment": None,
            "created": False,
            "eligible": False,
            "reason": state["reason"],
        }

    result = erp_service_task_adapter.sync_request(
        request,
        service=service,
        profile=profile,
        manual_customer=manual_customer,
        repair=repair,
    )

    return {
        **result,
        "eligible": True,
    }
