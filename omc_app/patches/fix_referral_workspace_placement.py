from __future__ import annotations

import frappe


WORKSPACE = "OMC App"
TARGET_CARD = "Customers & Support"
LINKS = (
    ("Referrals", "OMC Referral"),
    ("Manual Customers", "OMC Manual Customer"),
)


def execute():
    if not frappe.db.exists("Workspace", WORKSPACE):
        return

    workspace = frappe.get_doc("Workspace", WORKSPACE)

    # Remove existing copies wherever the earlier patch placed them.
    targets = {doctype for _, doctype in LINKS}
    rows_to_remove = [
        row
        for row in workspace.links
        if (row.type or "") == "Link"
        and (row.link_to or "").strip() in targets
    ]
    for row in rows_to_remove:
        workspace.links.remove(row)

    target_card_index = next(
        (
            index
            for index, row in enumerate(workspace.links)
            if (row.type or "") == "Card Break"
            and (row.label or "").strip() == TARGET_CARD
        ),
        None,
    )
    if target_card_index is None:
        frappe.log_error(
            title="OMC referral workspace placement",
            message=f'Workspace card "{TARGET_CARD}" was not found in "{WORKSPACE}".',
        )
        return

    # Insert at the end of Customers & Support, before the next card.
    insert_at = next(
        (
            index
            for index in range(target_card_index + 1, len(workspace.links))
            if (workspace.links[index].type or "") == "Card Break"
        ),
        len(workspace.links),
    )

    new_rows = []
    for label, doctype in LINKS:
        if not frappe.db.exists("DocType", doctype):
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

    for row in new_rows:
        workspace.links.remove(row)

    for offset, row in enumerate(new_rows):
        workspace.links.insert(insert_at + offset, row)

    for index, row in enumerate(workspace.links, start=1):
        row.idx = index

    workspace.save(ignore_permissions=True)
    frappe.clear_cache()
