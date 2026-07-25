import frappe

from omc_app.api import mobile


def _public_service_payload(service, include_required_documents=False):
    payload = mobile._service_to_catalogue_dict(
        service,
        include_required_documents=include_required_documents,
    )
    payload.pop("wizard_config", None)
    return payload


@frappe.whitelist(allow_guest=True)
def get_service_catalogue():
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
            "fee_label",
            "government_fee_label",
            "support_message",
            "wizard_type",
            "wizard_config",
            "is_featured",
        ],
        order_by="sort_order asc, modified desc",
    )
    return {
        "services": [
            _public_service_payload(service, include_required_documents=True)
            for service in services
        ]
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
