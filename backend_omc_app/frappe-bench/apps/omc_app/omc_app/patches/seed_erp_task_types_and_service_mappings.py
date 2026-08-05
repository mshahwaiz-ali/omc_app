import frappe


TASK_TYPES = {
    "NTN Registration",
}

SERVICE_MAPPINGS = {
    "ntn-registration": "NTN Registration",
}


def execute():
    for task_type_name in sorted(TASK_TYPES):
        if not frappe.db.exists("Task Type", task_type_name):
            task_type = frappe.new_doc("Task Type")
            task_type.service_name = task_type_name
            task_type.insert(ignore_permissions=True)

    for service_id, task_type_name in SERVICE_MAPPINGS.items():
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
