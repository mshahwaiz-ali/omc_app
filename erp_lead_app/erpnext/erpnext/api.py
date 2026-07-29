import frappe
from frappe.utils import nowdate

@frappe.whitelist()
def create_calling_from_lead(lead_name):
    lead = frappe.get_doc("Lead", lead_name)

    # Check if Calling already exists
    if lead.calling_id:
        return lead.calling_id

    # Get Employee linked to current user
    employee = frappe.db.get_value("Employee", {"user_id": frappe.session.user}, "name")

    # Create new Calling
    calling = frappe.new_doc("Calling")
    calling.date = nowdate()
    calling.client = lead.company_name
    calling.service_type = lead.task_type
    calling.mobile_no = lead.mobile_no
    calling.lead = lead.name
    calling.caller_employee = employee  # Optional, only if available
    calling.calling_source = "Lead"
    calling.flags.ignore_permissions = True  # If needed

    calling.insert()

    # Update lead with calling_id
    frappe.db.set_value("Lead", lead.name, "calling_id", calling.name)

    return calling.name
@frappe.whitelist()
def update_lead_from_calling(doc, method=None):
    if doc.lead:
        frappe.db.set_value("Lead", doc.lead, {
            "calling_id": doc.name,
            "calling_response": doc.response,
            "calling_state": doc.workflow_state,
        })
    if doc.lead and doc.workflow_state == "Converted":
        frappe.db.set_value("Lead", doc.lead, {
            "workflow_state": "Converted",
        })
    if doc.lead and doc.workflow_state == "Lead Lost":
        frappe.db.set_value("Lead", doc.lead, {
            "workflow_state": "Lead Lost",
        })