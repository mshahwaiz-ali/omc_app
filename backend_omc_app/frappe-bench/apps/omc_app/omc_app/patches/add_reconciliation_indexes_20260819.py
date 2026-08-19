import frappe


INDEXES = (
    (
        "OMC Technical Quarantine",
        ["status", "domain", "last_seen_at"],
        "idx_omc_quarantine_queue",
    ),
    (
        "OMC Reconciliation Review",
        ["status", "domain", "creation"],
        "idx_omc_review_queue",
    ),
    (
        "OMC Reconciliation Run",
        ["job_key", "status", "started_at"],
        "idx_omc_reconciliation_run",
    ),
    (
        "OMC Reconciliation Checkpoint",
        ["job_key", "domain"],
        "idx_omc_reconciliation_checkpoint",
    ),
)


def execute():
    for doctype, fields, index_name in INDEXES:
        if not frappe.db.exists("DocType", doctype):
            continue

        available = {field.fieldname for field in frappe.get_meta(doctype).fields}
        if all(field in available or field == "creation" for field in fields):
            frappe.db.add_index(doctype, fields, index_name=index_name)
