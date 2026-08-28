from __future__ import annotations

import frappe

from omc_app.api import service_request_mutations, service_requests, tax_calculator
from omc_app.omc_app.doctype.omc_service.omc_service import pricing_version_for


TAX_SERVICE_IDS = {
    "salary": "salaried-tax-filing",
    "business": "business-tax-filing",
    "rental": "other-sources",
}


def _text(value) -> str:
    return str(value or "").strip()


def _service(service_name: str):
    service_name = _text(service_name)
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        frappe.throw("The linked tax service is unavailable.", frappe.ValidationError)
    service = frappe.get_doc("OMC Service", service_name)
    if not int(service.is_active or 0):
        frappe.throw("The linked tax service is inactive.", frappe.ValidationError)
    return service


def _canonical_service_for_calculation(log):
    income_type = _text(getattr(log, "income_type", None)).lower()
    service_id = TAX_SERVICE_IDS.get(income_type)
    if not service_id:
        frappe.throw(
            "The saved tax estimate does not have a supported income type.",
            frappe.ValidationError,
        )

    rows = frappe.get_all(
        "OMC Service",
        filters={"service_id": service_id},
        fields=["name"],
        limit=2,
    )
    if len(rows) != 1:
        frappe.throw(
            "The linked tax filing service is unavailable or ambiguous.",
            frappe.ValidationError,
        )
    return _service(rows[0].name)


@frappe.whitelist(methods=["POST"])
def share_tax_estimate_with_consultant(calculation_log=None, note=None):
    return tax_calculator.share_tax_estimate_with_consultant(
        calculation_log=calculation_log,
        note=note,
    )


@frappe.whitelist(methods=["POST"])
def download_tax_estimate_pdf(calculation_log=None):
    # The underlying helper creates a private File, so this is deliberately an
    # unsafe-method endpoint rather than a GET/read route.
    return tax_calculator.download_tax_estimate_pdf(
        calculation_log=calculation_log,
    )


@frappe.whitelist(methods=["POST"])
def start_service_from_calculation(calculation_log=None, service=None):
    """Create/resume the tax service through the canonical payment-first path.

    ``service`` is retained only for API compatibility. It is deliberately not
    authoritative: the server resolves the filing service from the owned saved
    calculation so a client cannot redirect this mutation to an arbitrary OMC
    service.
    """
    log = tax_calculator._get_owned_calculation_log(calculation_log)
    if log.linked_service_request and frappe.db.exists(
        "OMC Service Request", log.linked_service_request
    ):
        request = frappe.get_doc("OMC Service Request", log.linked_service_request)
        can_cancel = service_request_mutations._customer_cancellation_allowed(request)
        return {
            "service_request": request.name,
            "created_new": False,
            "can_cancel": bool(can_cancel),
            "request_state": request.request_state or "",
            "status": request.status or "",
            "message": "A tax filing service request is already linked to this estimate.",
        }

    service_doc = _canonical_service_for_calculation(log)
    response = service_requests.create_service(
        service_id=service_doc.service_id or service_doc.name,
        service_version=int(service_doc.service_version or 1),
        pricing_version=_text(service_doc.pricing_version) or pricing_version_for(service_doc),
        final_confirmation=1,
        description=tax_calculator._service_request_description(log),
        source_channel="Tax Calculator",
        idempotency_key=f"tax:{log.name}:{service_doc.name}",
    )
    request_name = _text(
        response.get("service_request")
        or response.get("request_id")
        or response.get("name")
        or (response.get("active_request") or {}).get("name")
    )
    if not request_name:
        frappe.throw(
            "Tax service request could not be created.",
            frappe.ValidationError,
        )
    if not frappe.db.exists("OMC Service Request", request_name):
        frappe.throw(
            "Tax service request could not be verified.",
            frappe.ValidationError,
        )

    request = frappe.get_doc("OMC Service Request", request_name)
    frappe.db.set_value(
        "OMC Tax Calculation Log",
        log.name,
        "linked_service_request",
        request.name,
        update_modified=False,
    )
    return {
        "service_request": request.name,
        "created_new": bool(response.get("created", not response.get("duplicate"))),
        "can_cancel": bool(service_request_mutations._customer_cancellation_allowed(request)),
        "request_state": request.request_state or "",
        "status": request.status or "",
        "message": response.get("message") or "Tax filing service request created successfully.",
    }
