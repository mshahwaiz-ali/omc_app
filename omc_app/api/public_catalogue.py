import frappe

from omc_app.api import mobile


DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100


def _public_service_payload(service, include_required_documents=False):
    return mobile._service_to_catalogue_dict(
        service,
        include_required_documents=include_required_documents,
    )


def _pagination(start=0, limit=50, limit_start=None, limit_page_length=None):
    raw_start = limit_start if limit_start is not None else start
    raw_limit = limit_page_length if limit_page_length is not None else limit
    try:
        offset = max(int(raw_start or 0), 0)
        length = min(max(int(raw_limit or DEFAULT_PAGE_SIZE), 1), MAX_PAGE_SIZE)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)
    return offset, length


@frappe.whitelist(allow_guest=True)
def get_service_catalogue(start=0, limit=50, limit_start=None, limit_page_length=None):
    offset, length = _pagination(start, limit, limit_start, limit_page_length)
    services = frappe.get_all(
        "OMC Service",
        filters={"is_active": 1},
        fields=[
            "name",
            "service_id",
            "title",
            "category",
            "description",
            "short_description",
            "icon",
            "color_family",
            "estimated_duration",
            "completion_time",
            "base_price",
            "currency",
            "service_version",
            "pricing_version",
            "tax_policy",
            "tax_rate",
            "activation_policy",
            "fee_label",
            "government_fee_label",
            "support_message",
            "is_featured",
        ],
        order_by="sort_order asc, modified desc, name asc",
        limit_start=offset,
        limit_page_length=length + 1,
    )
    has_more = len(services) > length
    services = services[:length]
    payload = [
        _public_service_payload(service, include_required_documents=True)
        for service in services
    ]
    return {
        "services": payload,
        "limit_start": offset,
        "limit_page_length": length,
        "next_start": offset + len(payload) if has_more else None,
        "has_more": has_more,
    }


@frappe.whitelist(allow_guest=True)
def get_service_detail(service_id=None):
    service_id = str(service_id or "").strip()
    if not service_id:
        frappe.throw("service_id is required", frappe.ValidationError)
    if len(service_id) > 140:
        frappe.throw("service_id must be 140 characters or fewer", frappe.ValidationError)

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
        frappe.throw("Service not found", frappe.DoesNotExistError)

    service = frappe.get_doc("OMC Service", service_name)
    return _public_service_payload(service, include_required_documents=True)
