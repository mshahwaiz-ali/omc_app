from __future__ import annotations

import frappe

from omc_app.api import mobile

REFERENCE_DOCTYPES = {
    "assigned_to": "User",
    "customer_profile": "OMC Customer Profile",
    "converted_customer_profile": "OMC Customer Profile",
}


def _lead_not_found():
    frappe.throw("Lead not found", frappe.DoesNotExistError)


def _load_lead(lead_id):
    if not lead_id or not frappe.db.exists("Lead", lead_id):
        _lead_not_found()
    return frappe.get_doc("Lead", lead_id)


def _sanitize_lead_payload(payload):
    if not isinstance(payload, dict):
        return payload

    sanitized = dict(payload)
    for fieldname, doctype in REFERENCE_DOCTYPES.items():
        value = (sanitized.get(fieldname) or "").strip()
        if value and not frappe.db.exists(doctype, value):
            sanitized[fieldname] = ""
    return sanitized


@frappe.whitelist()
def get_leads(start=0, limit=100, search=None):
    from omc_app.api.public_catalogue import _pagination
    offset, length = _pagination(start, limit)
    mobile._assert_internal_workspace_access()
    mobile._require_canonical_capability(
        "can_manage_leads",
        message="You do not have permission to view leads.",
    )

    lead_names = frappe.get_all(
        "Lead",
        or_filters={field: ["like", "%" + str(search).strip()[:140] + "%"] for field in ("name", "lead_name", "email_id", "mobile_no", "phone")} if search else None,
        pluck="name",
        order_by="modified desc, name asc",
        limit_start=offset,
        limit_page_length=length + 1,
    )

    leads = []
    for lead_name in lead_names[:length]:
        try:
            lead = _load_lead(lead_name)
        except frappe.DoesNotExistError:
            continue
        leads.append(_sanitize_lead_payload(mobile._lead_to_dict(lead)))
    return {"leads": leads, "has_more": len(lead_names) > length, "next_start": offset + length if len(lead_names) > length else None}


@frappe.whitelist()
def get_lead(lead_id=None):
    mobile._assert_internal_workspace_access()
    mobile._require_canonical_capability(
        "can_manage_leads",
        message="You do not have permission to view leads.",
    )
    if not lead_id:
        frappe.throw("lead_id is required")

    lead = _load_lead(lead_id)
    return {"lead": _sanitize_lead_payload(mobile._lead_to_dict(lead))}
