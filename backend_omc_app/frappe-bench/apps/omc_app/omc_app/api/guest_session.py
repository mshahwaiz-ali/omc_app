import json

import frappe


def _clean_text(value, default=""):
    text = str(value or "").strip()
    return text or default


def _normalize_platform(value):
    platform = _clean_text(value, "unknown").lower()
    return platform if platform in {"android", "ios", "web", "unknown"} else "unknown"


def _normalize_interested_services(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (list, tuple, set)):
        cleaned = [str(item).strip() for item in value if str(item).strip()]
        return json.dumps(cleaned)
    return str(value).strip()


def _guest_session_to_dict(doc):
    """Return the public guest-session contract without account identifiers."""
    return {
        "name": doc.name,
        "session_id": doc.name,
        "device_id": doc.device_id or "",
        "platform": doc.platform or "unknown",
        "app_version": doc.app_version or "",
        "interested_services": doc.interested_services or "",
        "first_active_on": str(doc.first_active_on) if doc.first_active_on else "",
        "last_active_on": str(doc.last_active_on) if doc.last_active_on else "",
        "conversion_status": doc.conversion_status or "Anonymous",
        "is_converted": int(doc.is_converted or 0),
    }


@frappe.whitelist(allow_guest=True)
def create_guest_session(**kwargs):
    device_id = _clean_text(kwargs.get("device_id"))
    if not device_id:
        frappe.throw("device_id is required")

    now = frappe.utils.now_datetime()
    existing_name = frappe.db.get_value("OMC Guest Session", {"device_id": device_id}, "name")

    if existing_name:
        doc = frappe.get_doc("OMC Guest Session", existing_name)
    else:
        doc = frappe.new_doc("OMC Guest Session")
        doc.device_id = device_id
        doc.first_active_on = now

    doc.platform = _normalize_platform(kwargs.get("platform"))
    doc.app_version = _clean_text(kwargs.get("app_version"))
    doc.last_active_on = now

    interested_services = _normalize_interested_services(kwargs.get("interested_services"))
    if interested_services:
        doc.interested_services = interested_services
        if doc.conversion_status == "Anonymous":
            doc.conversion_status = "Interested"

    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)

    frappe.db.commit()
    return {"guest_session": _guest_session_to_dict(doc)}


@frappe.whitelist(allow_guest=True)
def update_guest_activity(**kwargs):
    session_id = _clean_text(kwargs.get("session_id") or kwargs.get("name"))
    device_id = _clean_text(kwargs.get("device_id"))

    doc = None
    if session_id:
        if not device_id:
            frappe.throw(
                "device_id is required when session_id is provided",
                frappe.ValidationError,
            )
        if not frappe.db.exists("OMC Guest Session", session_id):
            frappe.throw("Guest session not found", frappe.DoesNotExistError)

        candidate = frappe.get_doc("OMC Guest Session", session_id)
        if candidate.device_id != device_id:
            frappe.throw(
                "Guest session does not belong to this device",
                frappe.PermissionError,
            )
        doc = candidate
    elif device_id:
        existing_name = frappe.db.get_value(
            "OMC Guest Session",
            {"device_id": device_id},
            "name",
        )
        if existing_name:
            doc = frappe.get_doc("OMC Guest Session", existing_name)

    if doc is None:
        return create_guest_session(**kwargs)

    doc.last_active_on = frappe.utils.now_datetime()

    platform = kwargs.get("platform")
    if platform is not None:
        doc.platform = _normalize_platform(platform)

    app_version = _clean_text(kwargs.get("app_version"))
    if app_version:
        doc.app_version = app_version

    interested_services = _normalize_interested_services(kwargs.get("interested_services"))
    if interested_services:
        doc.interested_services = interested_services
        if doc.conversion_status == "Anonymous":
            doc.conversion_status = "Interested"

    current_user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    if current_user and current_user != "Guest":
        profile_name = (
            frappe.db.get_value(
                "OMC Customer Profile",
                {"user": current_user},
                "name",
            )
            or frappe.db.get_value(
                "OMC Customer Profile",
                {"email": current_user},
                "name",
            )
        )
        doc.converted_user = current_user
        if profile_name:
            doc.converted_customer_profile = profile_name
        doc.is_converted = 1
        doc.conversion_status = "Converted"

    doc.save(ignore_permissions=True)
    frappe.db.commit()

    return {"guest_session": _guest_session_to_dict(doc)}
