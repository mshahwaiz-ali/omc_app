from __future__ import annotations

import frappe

from omc_app.api import customer_documents, payment_opening

TERMINAL_SERVICE_REQUEST_STATUSES = {"Completed", "Cancelled"}


def _document_not_found():
    frappe.throw("Document not found", frappe.DoesNotExistError)


def _load_document_with_parent(document_id):
    if not document_id or not frappe.db.exists("OMC Service Document", document_id):
        _document_not_found()

    document = frappe.get_doc("OMC Service Document", document_id)
    service_request = (getattr(document, "service_request", None) or "").strip()
    if not service_request or not frappe.db.exists(
        "OMC Service Request",
        service_request,
    ):
        _document_not_found()

    request_status = frappe.db.get_value(
        "OMC Service Request",
        service_request,
        "status",
    )
    if request_status is None:
        _document_not_found()
    return document, service_request, request_status


def _same_text(current, requested):
    return requested is None or (current or "") == (requested or "")


def _review_is_noop(document, *, status, remarks=None):
    current_remarks = (
        getattr(document, "review_remarks", None)
        or getattr(document, "remarks", None)
        or ""
    )
    return (document.status or "") == (status or "") and _same_text(
        current_remarks,
        remarks,
    )


@frappe.whitelist()
def get_document(document_id=None):
    _load_document_with_parent(document_id)
    return customer_documents.get_document(document_id=document_id)


@frappe.whitelist(methods=["POST"])
def update_service_document_status(document_id=None, status=None, remarks=None):
    customer_documents._require_document_review_access()
    document, service_request, request_status = _load_document_with_parent(document_id)

    if request_status in TERMINAL_SERVICE_REQUEST_STATUSES:
        frappe.throw(
            f"Documents cannot be reviewed after service request {service_request} "
            f"is {request_status}."
        )

    if _review_is_noop(document, status=status, remarks=remarks):
        payment_name = (
            payment_opening.ensure_service_payment(service_request)
            if (status or "").strip() == "Approved"
            else None
        )
        return {
            "name": document.name,
            "case_id": service_request,
            "status": document.status,
            "updated": False,
            "message": "Service document already has this status.",
            "payment_id": payment_name,
            "case_status": request_status,
        }

    response = customer_documents.update_service_document_status(
        document_id=document_id,
        status=status,
        remarks=remarks,
    )
    if (status or "").strip() == "Approved":
        payment_name = payment_opening.ensure_service_payment(service_request)
        if isinstance(response, dict):
            response["payment_id"] = payment_name
    return response
