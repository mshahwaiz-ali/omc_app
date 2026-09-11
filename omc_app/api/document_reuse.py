from __future__ import annotations

import frappe
from frappe.utils import add_to_date, cint, get_datetime, now_datetime
from frappe.utils.file_manager import save_file

from omc_app.api import access, mobile, payment_opening, security


REUSE_POLICIES = {
    "Reusable Until Replaced",
    "Reusable for N Days",
}


def _text(value) -> str:
    return str(value or "").strip()


def _current_user() -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", None))
    return user or "Guest"


def _reuse_supported() -> bool:
    return bool(
        mobile._doctype_has_field(
            "OMC Service Required Document",
            "reuse_policy",
        )
        and mobile._doctype_has_field(
            "OMC Service Document",
            "source_document",
        )
    )


def _requirements(request) -> list:
    if not _reuse_supported():
        return []

    fields = [
        "name",
        "document_key",
        "document_title",
        "document_type",
        "is_required",
        "reuse_policy",
        "reuse_validity_days",
        "sort_order",
    ]
    if mobile._doctype_has_field(
        "OMC Service Required Document",
        "effective_from",
    ):
        fields.append("effective_from")

    rows = frappe.get_all(
        "OMC Service Required Document",
        filters={
            "service": request.service,
            "is_active": 1,
        },
        fields=fields,
        order_by="sort_order asc, creation asc",
        limit_page_length=1000,
    )
    request_creation = mobile._service_request_creation(request)
    return [
        row
        for row in rows
        if mobile._required_document_applies_to_request(
            row,
            request_creation,
        )
    ]


def _prior_request_names(request) -> list[str]:
    if not request.customer_profile or not request.service:
        return []

    rows = frappe.get_all(
        "OMC Service Request",
        filters={
            "customer_profile": request.customer_profile,
            "service": request.service,
            "name": ["!=", request.name],
            "status": ["!=", "Cancelled"],
        },
        pluck="name",
        order_by="creation desc",
        limit_page_length=500,
    )
    return [_text(name) for name in rows if _text(name)]


def _current_request_has_document(request_name: str, document_key: str) -> bool:
    return bool(
        frappe.db.exists(
            "OMC Service Document",
            {
                "service_request": request_name,
                "document_key": document_key,
                "is_archived": 0,
            },
        )
    )


def _latest_prior_document(prior_requests: list[str], document_key: str):
    if not prior_requests or not document_key:
        return None

    rows = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": ["in", prior_requests],
            "document_key": document_key,
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "service_request",
            "status",
            "attachment",
            "quarantine_status",
            "uploaded_on",
            "reviewed_on",
            "reviewed_by",
            "review_remarks",
            "source_document",
            "creation",
        ],
        order_by="uploaded_on desc, creation desc",
        limit_page_length=20,
    )
    if not rows:
        return None

    # The newest evidence wins even when its attachment is empty. Never fall
    # back to an older approved file after a newer replacement was rejected,
    # cleared, or is still awaiting review.
    latest = rows[0]
    if _text(latest.status) != "Approved":
        return None
    if _text(latest.quarantine_status) == "Rejected":
        return None
    if not _text(latest.attachment):
        return None
    return latest


def _within_reuse_window(requirement, source) -> bool:
    policy = _text(requirement.reuse_policy) or "Always New"
    if policy == "Reusable Until Replaced":
        return True
    if policy != "Reusable for N Days":
        return False

    validity_days = max(cint(requirement.reuse_validity_days or 0), 0)
    if validity_days <= 0:
        return False

    evidence_time = (
        getattr(source, "reviewed_on", None)
        or getattr(source, "uploaded_on", None)
        or getattr(source, "creation", None)
    )
    if not evidence_time:
        return False

    try:
        cutoff = get_datetime(
            add_to_date(
                now_datetime(),
                days=-validity_days,
            )
        )
        return get_datetime(evidence_time) >= cutoff
    except Exception:
        return False


def _source_file(source):
    file_name = frappe.db.get_value(
        "File",
        {"file_url": source.attachment},
        "name",
    )
    if not file_name:
        return None
    return frappe.get_doc("File", file_name)


def _copy_approved_document(request, requirement, source, *, actor: str):
    source_file = _source_file(source)
    if not source_file:
        return None

    content = source_file.get_content()
    if isinstance(content, str):
        content = content.encode("utf-8")
    if not content:
        return None

    document = frappe.new_doc("OMC Service Document")
    document.service_request = request.name
    document.customer_profile = request.customer_profile
    document.document_key = _text(requirement.document_key)
    document.document_title = _text(requirement.document_title)
    document.document_type = _text(requirement.document_type)
    document.status = "Approved"
    document.source = "Existing Document"
    document.source_document = source.name
    document.visible_to_customer = 1
    document.is_archived = 0
    document.quarantine_status = _text(source.quarantine_status) or "Not Required"
    document.uploaded_by = actor
    document.uploaded_on = now_datetime()
    document.reviewed_by = _text(source.reviewed_by)
    document.reviewed_on = source.reviewed_on
    document.review_remarks = (
        f"Reused from approved document {source.name} under the configured "
        f"{_text(requirement.reuse_policy)} policy."
    )
    document.remarks = f"Existing approved document reused from {source.service_request}."
    document.insert(ignore_permissions=True)

    copied_file = save_file(
        source_file.file_name,
        content,
        "OMC Service Document",
        document.name,
        is_private=1,
    )
    attachment = _text(getattr(copied_file, "file_url", None))
    if not attachment:
        frappe.throw(
            "Reusable document copy did not produce a private file URL.",
            frappe.ValidationError,
        )

    frappe.db.set_value(
        "OMC Service Document",
        document.name,
        "attachment",
        attachment,
        update_modified=False,
    )
    document.attachment = attachment
    return document


def reuse_approved_documents(service_request: str, *, actor: str | None = None) -> dict:
    """Reuse explicitly eligible approved evidence on a new assisted request.

    This function never changes the source document or its File record. A new
    request-scoped document row and private File attachment are created so the
    repeated service retains an auditable evidence snapshot.
    """

    request_name = _text(service_request)
    if not request_name or not frappe.db.exists("OMC Service Request", request_name):
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)

    request = frappe.get_doc("OMC Service Request", request_name)
    actor = _text(actor) or _current_user()
    state = _text(getattr(request, "request_state", None))
    if state in {"Historical", "Expired", "Cancelled"}:
        return {
            "service_request": request.name,
            "reused": 0,
            "reused_documents": [],
            "skipped": [],
        }
    if not request.customer_profile or not request.service:
        return {
            "service_request": request.name,
            "reused": 0,
            "reused_documents": [],
            "skipped": ["Request has no reusable customer/service identity."],
        }

    requirements = _requirements(request)
    prior_requests = _prior_request_names(request)
    reused = []
    skipped = []

    for requirement in requirements:
        key = _text(requirement.document_key)
        policy = _text(requirement.reuse_policy) or "Always New"
        title = _text(requirement.document_title) or key or requirement.name

        if policy not in REUSE_POLICIES:
            continue
        if not key:
            skipped.append(f"{title}: no stable document key")
            continue
        if _current_request_has_document(request.name, key):
            skipped.append(f"{title}: current request already has evidence")
            continue

        source = _latest_prior_document(prior_requests, key)
        if not source:
            skipped.append(f"{title}: no current approved source evidence")
            continue
        if not _within_reuse_window(requirement, source):
            skipped.append(f"{title}: prior approval is outside the reuse window")
            continue

        frappe.db.savepoint("omc_reuse_document")
        try:
            document = _copy_approved_document(
                request,
                requirement,
                source,
                actor=actor,
            )
            if not document:
                frappe.db.rollback(save_point="omc_reuse_document")
                skipped.append(f"{title}: source file is unavailable")
                continue
        except Exception:
            frappe.db.rollback(save_point="omc_reuse_document")
            frappe.log_error(
                frappe.get_traceback(),
                f"OMC Document Reuse Failed: {request.name} / {key}",
            )
            skipped.append(f"{title}: reusable evidence could not be copied")
            continue

        reused.append(document.name)
        security.audit_event(
            event_type="document.reused",
            target_doctype="OMC Service Document",
            target_name=document.name,
            source_version=source.name,
            safe_reason="configured_document_reuse",
            actor=actor,
        )

    if reused:
        mobile._create_service_timeline_entry(
            service_request=request.name,
            event_type="Document Uploaded",
            title="Approved Documents Reused",
            description=(
                f"{len(reused)} previously approved document"
                f"{'s were' if len(reused) != 1 else ' was'} reused under the "
                "configured document reuse policy."
            ),
            visible_to_customer=1,
        )

    return {
        "service_request": request.name,
        "reused": len(reused),
        "reused_documents": reused,
        "skipped": skipped,
    }


def _require_manual_reuse_access(request_name: str) -> str:
    actor = _current_user()
    if actor == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)

    capabilities = access.get_mobile_capabilities(user=actor)
    if not (
        capabilities.get("can_access_internal_workspace")
        and capabilities.get("can_create_service_for_customer")
    ):
        frappe.throw(
            "You do not have permission to reuse customer documents.",
            frappe.PermissionError,
        )

    mobile._require_service_case_read_scope(request_name)
    security.enforce_rate_limit("staff_mutation", actor=actor)
    return actor


@frappe.whitelist(methods=["POST"])
def reuse_existing_documents(service_request=None):
    request_name = _text(service_request)
    if not request_name:
        frappe.throw("service_request is required.", frappe.ValidationError)
    actor = _require_manual_reuse_access(request_name)
    result = reuse_approved_documents(request_name, actor=actor)
    result["payment_id"] = payment_opening.ensure_service_payment(request_name)
    return result
