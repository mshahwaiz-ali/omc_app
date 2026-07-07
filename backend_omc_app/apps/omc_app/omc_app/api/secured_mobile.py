"""Permission-guarded mobile API overrides.

These wrappers keep customer-facing mobile routes stable while enforcing
server-side capability checks for internal-only service case actions.
"""

import frappe

from omc_app.api import mobile


@frappe.whitelist()
def get_service_case(case_id=None, name=None, service_request=None, request_id=None):
    """Return service case detail with backend-owned customer/admin gates.

    The mobile app should prefer real OMC Service Timeline rows. When a case has
    no timeline rows yet, return deterministic backend-generated stages instead
    of letting the Flutter client invent production tracking steps locally.
    """

    resolved_case_id = case_id or name or service_request or request_id
    response = mobile.get_service_case(case_id=resolved_case_id)
    service_case = response.get("case") if isinstance(response, dict) else None

    if not isinstance(service_case, dict):
        return response

    _apply_service_case_capabilities(service_case)

    timeline = service_case.get("timeline")
    if isinstance(timeline, list) and timeline:
        return response

    service_case["timeline"] = _fallback_service_case_timeline(service_case)
    return response


def _apply_service_case_capabilities(service_case):
    """Keep internal-only fields and controls backend-driven."""

    can_access_internal_workspace = mobile._can_access_internal_workspace()

    service_case["can_update_status"] = can_access_internal_workspace
    service_case["can_review_documents"] = can_access_internal_workspace
    service_case["can_view_internal_notes"] = can_access_internal_workspace

    if not can_access_internal_workspace:
        service_case["remarks"] = ""


def _fallback_service_case_timeline(service_case):
    status = (service_case.get("status") or "").strip()
    normalized_status = status.lower()
    progress = _progress_number(service_case.get("progress"))
    created_on = service_case.get("submitted_on") or service_case.get("created_at") or ""
    expected_completion = service_case.get("expected_completion_date") or ""
    next_step = service_case.get("next_step") or "OMC team will update this service request shortly."

    stages = [
        {
            "title": "Request received",
            "subtitle": created_on or "Your request has been received by OMC.",
            "is_done": progress >= 0.05 or bool(created_on),
        },
        {
            "title": "Documents review",
            "subtitle": _documents_stage_subtitle(service_case, normalized_status),
            "is_done": progress >= 0.35,
        },
        {
            "title": "OMC processing",
            "subtitle": next_step,
            "is_done": progress >= 0.65,
        },
    ]

    if expected_completion:
        stages.append(
            {
                "title": "Expected completion",
                "subtitle": expected_completion,
                "is_done": normalized_status == "completed",
            }
        )

    stages.append(
        {
            "title": "Completed",
            "subtitle": "Service completed." if normalized_status == "completed" else "Pending completion.",
            "is_done": normalized_status == "completed" or progress >= 1,
        }
    )

    return stages


def _documents_stage_subtitle(service_case, normalized_status):
    missing_count = _int_number(service_case.get("missing_documents_count"))
    submitted_count = _int_number(service_case.get("submitted_documents_count"))

    if missing_count > 0:
        return f"{missing_count} document(s) still needed."

    if submitted_count > 0:
        return f"{submitted_count} document(s) submitted for review."

    if normalized_status == "waiting for customer":
        return "OMC is waiting for customer input."

    return "OMC will confirm document requirements."


def _progress_number(value):
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return 0.0

    if number > 1:
        number = number / 100

    return max(0.0, min(1.0, number))


def _int_number(value):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


@frappe.whitelist()
def update_service_case_status(
    case_id=None,
    name=None,
    service_request=None,
    request_id=None,
    status=None,
    note=None,
    expected_completion_date=None,
):
    """Allow only internal workspace users to update service case status."""

    mobile._assert_internal_workspace_access()

    resolved_case_id = case_id or name or service_request or request_id

    return mobile.update_service_case_status(
        case_id=resolved_case_id,
        status=status,
        note=note,
        expected_completion_date=expected_completion_date,
    )


@frappe.whitelist()
def update_service_document_status(
    document_id=None,
    document=None,
    name=None,
    status=None,
    remarks=None,
):
    """Allow only internal workspace users to approve/reject documents."""

    mobile._assert_internal_workspace_access()

    resolved_document_id = document_id or document or name

    return mobile.update_service_document_status(
        document_id=resolved_document_id,
        status=status,
        remarks=remarks,
    )
