import frappe


INDEXES = (
    ("OMC Service Request", ["customer_account", "request_state", "creation"], "idx_omc_request_account_state"),
    ("OMC Service Request", ["request_state", "expires_at"], "idx_omc_request_expiry"),
    ("OMC Accounting Link", ["service_request", "accounting_status"], "idx_omc_accounting_request_state"),
    ("OMC Accounting Link", ["sales_invoice", "payment_entry"], "idx_omc_accounting_invoice_payment"),
    ("OMC Bridge Operation", ["state", "next_attempt_at"], "idx_omc_bridge_due"),
    ("OMC Commission Allocation", ["beneficiary_user", "status", "earned_on"], "idx_omc_commission_beneficiary"),
    ("OMC Commission Allocation", ["payment_entry", "payment_reference_row"], "idx_omc_commission_payment_ref"),
    ("OMC Security Audit Event", ["occurred_at", "event_type"], "idx_omc_security_event_time"),
    ("OMC Staff Access", ["access_status", "reconciliation_status"], "idx_omc_staff_access_state"),
)


def execute():
    for doctype, fields, name in INDEXES:
        if not frappe.db.exists("DocType", doctype):
            continue
        available = {field.fieldname for field in frappe.get_meta(doctype).fields}
        if all(field in available for field in fields):
            frappe.db.add_index(doctype, fields, index_name=name)
