import frappe


def execute():
    if not frappe.db.exists("DocType", "OMC Service Document"):
        return

    meta = frappe.get_meta("OMC Service Document")
    has_customer_profile = meta.has_field("customer_profile")
    has_source = meta.has_field("source")
    has_is_archived = meta.has_field("is_archived")
    has_archived_on = meta.has_field("archived_on")
    has_archive_reason = meta.has_field("archive_reason")

    docs = frappe.get_all(
        "OMC Service Document",
        fields=["name", "service_request"],
    )

    for doc in docs:
        updates = {}
        service_request = doc.service_request

        if has_customer_profile and service_request:
            customer_profile = frappe.db.get_value(
                "OMC Service Request",
                service_request,
                "customer_profile",
            )
            if customer_profile:
                updates["customer_profile"] = customer_profile

        if has_source:
            updates["source"] = "Service Upload"

        if service_request and has_is_archived:
            service_status = frappe.db.get_value(
                "OMC Service Request",
                service_request,
                "status",
            )
            archive_reason = ""
            if service_status == "Completed":
                archive_reason = "Service Completed"
            elif service_status == "Cancelled":
                archive_reason = "Service Cancelled"

            if archive_reason:
                updates["is_archived"] = 1
                if has_archived_on:
                    updates["archived_on"] = frappe.utils.now_datetime()
                if has_archive_reason:
                    updates["archive_reason"] = archive_reason
            else:
                updates["is_archived"] = 0

        if updates:
            frappe.db.set_value(
                "OMC Service Document",
                doc.name,
                updates,
                update_modified=False,
            )
