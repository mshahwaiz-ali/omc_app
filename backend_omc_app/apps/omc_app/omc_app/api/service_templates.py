import frappe


def _has_doctype(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _service_name(service_id=None):
    service_id = (service_id or "").strip()
    if not service_id:
        return ""
    return frappe.db.get_value("OMC Service", {"service_id": service_id}, "name") or service_id


def _split_options(value):
    text = (value or "").strip()
    if not text:
        return []
    return [item.strip() for item in text.replace(",", "\n").splitlines() if item.strip()]


def _field_to_dict(row):
    return {
        "name": row.name,
        "fieldname": row.fieldname or "",
        "label": row.label or "",
        "fieldtype": row.fieldtype or "Data",
        "options": _split_options(row.options),
        "options_raw": row.options or "",
        "placeholder": row.placeholder or "",
        "description": row.description or "",
        "is_required": int(row.is_required or 0),
        "default_value": row.default_value or "",
        "depends_on": row.depends_on or "",
        "sort_order": row.sort_order or 0,
    }


def _stage_to_dict(row):
    return {
        "name": row.name,
        "stage_key": row.stage_key or row.name,
        "title": row.stage_title or "",
        "description": row.description or "",
        "sort_order": row.sort_order or 0,
        "is_customer_visible": int(row.is_customer_visible or 0),
    }


@frappe.whitelist(allow_guest=True)
def get_service_template(service_id=None, service=None):
    service_name = _service_name(service_id or service)
    if not service_name:
        frappe.throw("service_id is required")
    if not frappe.db.exists("OMC Service", service_name):
        frappe.throw("Service not found", frappe.DoesNotExistError)

    fields = []
    if _has_doctype("OMC Service Form Field"):
        fields = [
            _field_to_dict(row)
            for row in frappe.get_all(
                "OMC Service Form Field",
                filters={"service": service_name, "is_active": 1},
                fields=[
                    "name",
                    "fieldname",
                    "label",
                    "fieldtype",
                    "options",
                    "placeholder",
                    "description",
                    "is_required",
                    "default_value",
                    "depends_on",
                    "sort_order",
                ],
                order_by="sort_order asc, creation asc",
            )
        ]

    stages = []
    if _has_doctype("OMC Service Stage Template"):
        stages = [
            _stage_to_dict(row)
            for row in frappe.get_all(
                "OMC Service Stage Template",
                filters={"service": service_name, "is_active": 1},
                fields=[
                    "name",
                    "stage_title",
                    "stage_key",
                    "description",
                    "sort_order",
                    "is_customer_visible",
                ],
                order_by="sort_order asc, creation asc",
            )
        ]

    return {
        "service": service_name,
        "form_schema": fields,
        "stages": stages,
    }
