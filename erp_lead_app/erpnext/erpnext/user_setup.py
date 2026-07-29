import frappe
from frappe.model.document import Document
def before_insert(doc, method):
    user = frappe.session.user
    user_type = frappe.db.get_value('User', user, 'omc_user_type')

    if user_type == "Business Partner":
        bp = frappe.db.get_value('Business Partner', user,
            ['consultant', 'employee', 'reference_business_partner', 'commission_structure', 'name'], as_dict=True)
        if bp:
            doc.source = "Business Partner"
            doc.sales_person = bp.name
            doc.assign_to = bp.employee
            doc.reference_business_partner = bp.reference_business_partner
            doc.commission_structure = bp.commission_structure

    elif user_type == "Consultant":
        consultant = frappe.db.get_value('Consultant', user, ['name', 'commission_structure'], as_dict=True)
        if consultant:
            doc.source = "Consultant"
            doc.sales_person = consultant.name
            doc.commission_structure = consultant.commission_structure

    elif user_type == "Tax Associates":
        tax = frappe.db.get_value('Tax Associates', user, ['name', 'commission_structure'], as_dict=True)
        if tax:
            doc.source = "Tax Associates"
            doc.sales_person = tax.name
            doc.commission_structure = tax.commission_structure

    elif user_type == "Employee":
        emp = frappe.db.get_value('Employee', user, ['name', 'commission_structure'], as_dict=True)
        if emp:
            doc.source = "Employee"
            doc.sales_person = emp.name
            doc.commission_structure = emp.commission_structure