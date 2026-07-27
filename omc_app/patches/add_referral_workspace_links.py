from __future__ import annotations

import frappe


WORKSPACE = "OMC App"
LINKS = (
    ("Referrals", "OMC Referral"),
    ("Manual Customers", "OMC Manual Customer"),
)


def execute():
    if not frappe.db.exists("Workspace", WORKSPACE):
        return

    workspace = frappe.get_doc("Workspace", WORKSPACE)
    existing_targets = {
        (row.link_to or "").strip()
        for row in workspace.links
        if (row.type or "") == "Link"
    }

    new_rows = []
    for label, doctype in LINKS:
        if doctype in existing_targets or not frappe.db.exists("DocType", doctype):
            continue
        new_rows.append(
            workspace.append(
                "links",
                {
                    "type": "Link",
                    "label": label,
                    "link_type": "DocType",
                    "link_to": doctype,
                    "hidden": 0,
                    "onboard": 0,
                    "is_query_report": 0,
                    "link_count": 0,
                },
            )
        )

    if not new_rows:
        return

    insert_at = next(
        (
            index
            for index, row in enumerate(workspace.links)
            if (row.type or "") == "Card Break"
            and (row.label or "") == "Mobile Content"
        ),
        len(workspace.links),
    )

    for row in new_rows:
        workspace.links.remove(row)

    for offset, row in enumerate(new_rows):
        workspace.links.insert(insert_at + offset, row)

    for index, row in enumerate(workspace.links, start=1):
        row.idx = index

    workspace.save(ignore_permissions=True)
    frappe.clear_cache()
