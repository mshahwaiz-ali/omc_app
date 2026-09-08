import frappe
from frappe.model.document import Document


class OMCManualCustomer(Document):
    def before_insert(self):
        frappe.throw(
            "OMC Manual Customer is retired. Create or activate a normal OMC Customer Profile instead.",
            frappe.ValidationError,
        )
