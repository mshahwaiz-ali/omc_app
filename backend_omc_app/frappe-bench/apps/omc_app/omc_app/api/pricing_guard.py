from __future__ import annotations

import json

import frappe
from frappe.utils import flt, now_datetime

from omc_app.api import capabilities, payment_opening, security


REVIEWABLE_REQUEST_STATES = {"Draft", "Pending Payment", "Payment Not Required"}


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> float:
    return flt(value or 0, 6)


def finalized_totals(*, final_price, tax_policy, tax_rate) -> dict:
    """Return canonical tax/payable totals for one reviewed final price."""
    final_price = _money(final_price)
    tax_rate = _money(tax_rate)
    tax_policy = _text(tax_policy) or "No Tax"

    if final_price < 0:
        frappe.throw("Final price cannot be negative.", frappe.ValidationError)
    if tax_rate < 0:
        frappe.throw("Tax rate cannot be negative.", frappe.ValidationError)
    if tax_policy not in {"No Tax", "Tax Exclusive", "Tax Included"}:
        frappe.throw("Unsupported tax policy.", frappe.ValidationError)

    tax_amount = 0.0
    payable_amount = final_price
    if tax_policy == "Tax Exclusive":
        tax_amount = _money(final_price * tax_rate / 100)
        payable_amount = _money(final_price + tax_amount)
    elif tax_policy == "Tax Included" and tax_rate:
        tax_amount = _money(final_price * tax_rate / (100 + tax_rate))

    return {
        "final_price": final_price,
        "tax_amount": tax_amount,
        "payable_amount": payable_amount,
    }


def _snapshot_payload(request, *, decision: str, reviewer: str, totals: dict) -> dict:
    return {
        "activation_policy": _text(request.payment_policy_snapshot) or "Full Settlement",
        "base_price": _money(request.original_price),
        "currency": _text(request.pricing_currency) or "PKR",
        "discount_amount": _money(request.discount_amount),
        "discount_reason": _text(request.discount_reason),
        "discount_status": decision,
        "discount_type": _text(request.discount_type),
        "discount_value": _money(request.discount_value),
        "final_price": totals["final_price"],
        "payable_amount": totals["payable_amount"],
        "pricing_version": _text(request.pricing_version_snapshot),
        "reviewed_by": reviewer,
        "reviewed_at": str(now_datetime()),
        "service_version": int(request.service_version_snapshot or 0),
        "tax_amount": totals["tax_amount"],
        "tax_policy": _text(request.tax_policy_snapshot) or "No Tax",
        "tax_rate": _money(request.tax_rate_snapshot),
    }


def finalize_discount_review(
    service_request: str,
    *,
    decision: str,
    reason: str = "",
    reviewer: str | None = None,
) -> dict:
    """Finalize a pending discount and its entire authoritative price snapshot.

    The request row is locked. Once a receipt/accounting path has started the
    pricing snapshot is immutable and the review is rejected.
    """
    service_request = _text(service_request)
    decision = _text(decision).lower()
    reason = _text(reason)
    reviewer = _text(reviewer) or frappe.session.user

    if decision not in {"approve", "reject"}:
        frappe.throw("decision must be approve or reject.", frappe.ValidationError)
    if decision == "reject" and not reason:
        frappe.throw("Review remarks are required when rejecting a discount.", frappe.ValidationError)

    locked = frappe.db.get_value(
        "OMC Service Request",
        service_request,
        "name",
        for_update=True,
    )
    if not locked:
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)

    request = frappe.get_doc("OMC Service Request", locked)
    if _text(request.discount_status) != "Pending Approval":
        frappe.throw("This request does not have a pending discount.", frappe.ValidationError)
    if _text(request.request_state) not in REVIEWABLE_REQUEST_STATES:
        frappe.throw(
            "Pricing can no longer change after request activation has started.",
            frappe.ValidationError,
        )
    if payment_opening.financial_processing_started(request.name):
        frappe.throw(
            "Pricing cannot change after receipt or accounting activity has started.",
            frappe.ValidationError,
        )

    original_price = _money(request.original_price)
    proposed_price = _money(request.proposed_final_price)
    final_price = proposed_price if decision == "approve" else original_price
    if final_price < 0 or final_price > original_price + 0.000001:
        frappe.throw("Reviewed final price is outside the allowed request price range.", frappe.ValidationError)

    totals = finalized_totals(
        final_price=final_price,
        tax_policy=request.tax_policy_snapshot,
        tax_rate=request.tax_rate_snapshot,
    )
    activation_policy = _text(request.payment_policy_snapshot) or "Full Settlement"
    if activation_policy == "No Charge" and abs(totals["payable_amount"]) > 0.000001:
        frappe.throw(
            "No Charge services must have an exact zero payable amount.",
            frappe.ValidationError,
        )

    final_discount_status = "Approved" if decision == "approve" else "Rejected"
    snapshot = _snapshot_payload(
        request,
        decision=final_discount_status,
        reviewer=reviewer,
        totals=totals,
    )
    values = {
        "final_price": totals["final_price"],
        "tax_amount": totals["tax_amount"],
        "payable_amount": totals["payable_amount"],
        "pricing_snapshot_json": json.dumps(snapshot, sort_keys=True, separators=(",", ":")),
        "discount_status": final_discount_status,
        "discount_approved_by": reviewer,
        "discount_applied_by": reviewer if decision == "approve" else None,
    }
    frappe.db.set_value(request.doctype, request.name, values, update_modified=False)
    request.update(values)

    request.add_comment(
        "Comment",
        text=(
            f"Discount {final_discount_status.lower()} by {reviewer}."
            + (f" Review remarks: {reason}" if reason else "")
            + f" Final payable amount: {_text(request.pricing_currency) or 'PKR'} {totals['payable_amount']:g}."
        ),
    )
    security.audit_event(
        event_type="pricing.discount_finalized",
        capability="can_manage_business_settings",
        target_doctype=request.doctype,
        target_name=request.name,
        old_state="pending_approval",
        new_state=final_discount_status.lower(),
        source_version=_text(request.pricing_version_snapshot),
        safe_reason="discount_review",
        actor=reviewer,
    )

    payment_name = payment_opening.ensure_service_payment(request.name)
    return {
        "service_request": request.name,
        "discount_status": final_discount_status,
        "final_price": totals["final_price"],
        "tax_amount": totals["tax_amount"],
        "payable_amount": totals["payable_amount"],
        "currency": _text(request.pricing_currency) or "PKR",
        "payment_id": payment_name,
        "pricing_finalized": True,
    }


@frappe.whitelist(methods=["POST"])
def review_discount(service_request=None, decision=None, reason=None):
    capabilities.require("can_manage_business_settings")
    security.enforce_rate_limit("staff_mutation")
    return finalize_discount_review(
        service_request,
        decision=decision,
        reason=reason,
        reviewer=frappe.session.user,
    )
