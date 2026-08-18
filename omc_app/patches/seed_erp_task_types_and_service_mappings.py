import frappe


SERVICE_MAPPINGS = {
    "ntn-registration": "NTN Registration",
}


def execute():
    """Map OMC services only to ERP Task Types that already exist.

    OMC App must not create or own client ERP Task Type master data.
    """

    for service_id, task_type_name in SERVICE_MAPPINGS.items():
        if not frappe.db.exists("Task Type", task_type_name):
            continue

        service_name = frappe.db.get_value(
            "OMC Service",
            {"service_id": service_id},
            "name",
        )

        if not service_name:
            continue

        current = frappe.db.get_value(
            "OMC Service",
            service_name,
            "erp_task_type",
        )

        if current != task_type_name:
            frappe.db.set_value(
                "OMC Service",
                service_name,
                "erp_task_type",
                task_type_name,
                update_modified=False,
            )
