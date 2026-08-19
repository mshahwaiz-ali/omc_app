from __future__ import annotations

import frappe

from omc_app.api import dashboard, dashboard_scope


def _service_for_request(service_request):
    request_name = str(service_request or "").strip()
    if not request_name:
        return ""
    return frappe.db.get_value("OMC Service Request", request_name, "service") or ""


def _correct_activity_color_family(item):
    corrected = dict(item or {})
    service_request = corrected.get("service_request")
    if not service_request:
        return corrected

    current_family = str(corrected.get("color_family") or "").strip()
    if current_family and current_family != "Services":
        return corrected

    service = _service_for_request(service_request)
    if service:
        corrected["color_family"] = dashboard._service_color_family(service) or current_family
    return corrected


def _correct_activity(payload):
    if not isinstance(payload, dict):
        return payload
    corrected = dict(payload)
    corrected["recent_activity"] = [
        _correct_activity_color_family(item)
        for item in (payload.get("recent_activity") or [])
    ]
    return corrected


@frappe.whitelist()
def get_dashboard_data():
    user = dashboard._current_user()
    if dashboard._can_access_internal_workspace(user):
        response = dashboard_scope.get_internal_dashboard_data(user)
    else:
        response = dashboard.get_dashboard_data()

    if not isinstance(response, dict):
        return response

    # Direct calls return the payload itself. Some legacy tests/integration wrappers
    # pass an already wrapped {"message": payload}; support both without changing
    # the public response contract.
    message = response.get("message")
    if isinstance(message, dict):
        return {**response, "message": _correct_activity(message)}
    return _correct_activity(response)
