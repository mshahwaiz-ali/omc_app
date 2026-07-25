import frappe
from frappe.utils import validate_email_address

from omc_app.api import mobile

ALLOWED_PRIORITIES = {"Low", "Medium", "High", "Urgent"}


def _bounded_text(value, fieldname, max_length, required=False):
    if value is None:
        text = ""
    elif isinstance(value, (str, int, float)):
        text = str(value).strip()
    else:
        frappe.throw(f"{fieldname} must be text", frappe.ValidationError)

    if required and not text:
        frappe.throw(f"{fieldname} is required", frappe.ValidationError)
    if len(text) > max_length:
        frappe.throw(
            f"{fieldname} must be {max_length} characters or fewer",
            frappe.ValidationError,
        )
    return text


def _resolve_active_service(value):
    service_id = _bounded_text(value, "service_id", 140, required=True)
    service_name = frappe.db.get_value(
        "OMC Service",
        {"service_id": service_id, "is_active": 1},
        "name",
    )
    if not service_name and frappe.db.exists(
        "OMC Service",
        {"name": service_id, "is_active": 1},
    ):
        service_name = service_id
    if not service_name:
        frappe.throw("Active service not found", frappe.DoesNotExistError)
    return service_name


@frappe.whitelist()
def create_service(**kwargs):
    data = dict(kwargs or {})
    service_name = _resolve_active_service(data.get("service_id") or data.get("service"))
    service_id = frappe.db.get_value("OMC Service", service_name, "service_id") or service_name

    title = _bounded_text(data.get("title"), "title", 140)
    description = _bounded_text(data.get("description"), "description", 5000)
    contact_phone = _bounded_text(data.get("contact_phone"), "contact_phone", 40)
    contact_email = _bounded_text(data.get("contact_email"), "contact_email", 254)
    if contact_email and not validate_email_address(contact_email, throw=False):
        frappe.throw("contact_email must be valid", frappe.ValidationError)

    priority = _bounded_text(data.get("priority") or "Medium", "priority", 20)
    priority = priority.title()
    if priority not in ALLOWED_PRIORITIES:
        frappe.throw("Unsupported priority", frappe.ValidationError)

    return mobile.create_service(
        service_id=service_id,
        title=title,
        description=description,
        contact_phone=contact_phone,
        contact_email=contact_email,
        priority=priority,
    )
