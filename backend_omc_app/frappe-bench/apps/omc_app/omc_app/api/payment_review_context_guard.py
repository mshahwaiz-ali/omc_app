from __future__ import annotations

import frappe
from frappe.utils import flt

from omc_app.api import payment_accounting, payments


@frappe.whitelist()
def get_review_context(payment_id=None, name=None):
    """Preserve review authorization while capping UI to this installment."""
    resolved = str(payment_id or name or "").strip()
    result = payment_accounting.get_review_context(
        payment_id=resolved,
        name=resolved,
    )
    if not resolved or not frappe.db.exists(payments.PAYMENT_DOCTYPE, resolved):
        return result

    installment_amount = max(
        flt(
            frappe.db.get_value(
                payments.PAYMENT_DOCTYPE,
                resolved,
                "amount",
            )
            or 0,
            6,
        ),
        0,
    )
    request_remaining = max(flt(result.get("remaining_amount") or 0, 6), 0)
    result["request_remaining_amount"] = request_remaining
    result["installment_amount"] = installment_amount
    result["remaining_amount"] = min(request_remaining, installment_amount)
    return result
