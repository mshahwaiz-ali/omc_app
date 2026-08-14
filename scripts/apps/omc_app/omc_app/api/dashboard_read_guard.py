from __future__ import annotations

import frappe

from omc_app.api import dashboard


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


@frappe.whitelist()
def get_dashboard_data():
    response = dashboard.get_dashboard_data()
    if not isinstance(response, dict):
        return response

    message = response.get("message")
    if not isinstance(message, dict):
        return response

    corrected_message = dict(message)
    corrected_message["recent_activity"] = [
        _correct_activity_color_family(item)
        for item in (message.get("recent_activity") or [])
    ]
    return {**response, "message": corrected_message}
