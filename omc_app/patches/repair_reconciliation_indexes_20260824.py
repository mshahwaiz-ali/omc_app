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
    """Ensure required reconciliation queue indexes exist."""

    for doctype, fields, index_name in INDEXES:
        if not frappe.db.exists("DocType", doctype):
            frappe.throw(
                f"Required DocType missing while repairing indexes: "
                f"{doctype}"
            )

        available = {
            field.fieldname
            for field in frappe.get_meta(doctype).fields
        }

        missing = [
            fieldname
            for fieldname in fields
            if fieldname != "creation"
            and fieldname not in available
        ]

        if missing:
            frappe.throw(
                f"{doctype} is missing required index fields: "
                f"{', '.join(missing)}"
            )

        frappe.db.add_index(
            doctype,
            fields,
            index_name=index_name,
        )
