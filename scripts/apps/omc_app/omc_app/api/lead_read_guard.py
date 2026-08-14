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
    if not lead_id or not frappe.db.exists("OMC Lead", lead_id):
        _lead_not_found()
    return frappe.get_doc("OMC Lead", lead_id)


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
def get_leads():
    mobile._assert_internal_workspace_access()
    mobile._require_canonical_capability(
        "can_manage_leads",
        message="You do not have permission to view leads.",
    )

    lead_names = frappe.get_all(
        "OMC Lead",
        pluck="name",
        order_by="modified desc",
        limit_page_length=100,
    )

    leads = []
    for lead_name in lead_names:
        try:
            lead = _load_lead(lead_name)
        except frappe.DoesNotExistError:
            continue
        leads.append(_sanitize_lead_payload(mobile._lead_to_dict(lead)))
    return {"leads": leads}


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
