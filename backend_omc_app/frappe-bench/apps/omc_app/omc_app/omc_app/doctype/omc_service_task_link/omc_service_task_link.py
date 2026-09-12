import frappe
from frappe.model.document import Document


class OMCServiceTaskLink(Document):
    def validate(self):
        if not frappe.db.exists("OMC Service Request", self.service_request):
            frappe.throw("Service Request does not exist.", frappe.ValidationError)
        if not frappe.db.exists("Task", self.erp_task):
            frappe.throw("ERP Task does not exist.", frappe.ValidationError)

        linked_request = frappe.db.get_value(
            "OMC Service Task Link",
            {"erp_task": self.erp_task, "name": ["!=", self.name]},
            "service_request",
        )
        if linked_request and linked_request != self.service_request:
            frappe.throw(
                f"ERP Task {self.erp_task} is already linked to {linked_request}.",
                frappe.ValidationError,
            )

        if self.is_primary:
            other_primary = frappe.db.get_value(
                "OMC Service Task Link",
                {
                    "service_request": self.service_request,
                    "is_primary": 1,
                    "name": ["!=", self.name],
                },
                "name",
            )
            if other_primary:
                frappe.throw(
                    "A Service Request can have only one primary ERP Task.",
                    frappe.ValidationError,
                )
