import frappe
import random
import string
@frappe.whitelist()
def create_task_from_service(customer):
    service = frappe.get_doc('Customer', customer)
    if service.task_created:
        return None

    customer = frappe.get_doc('Customer', customer)

    task = frappe.new_doc('Task')
    task.type = service.service_type
    task.subject = f"Task for {service.customer_name} {service.service_type}"
    task.description = f"Net Amount: {service.service_amount}"
    task.customer = service.name
    task.rate = service.service_amount

    # You can store custom fields like this (ensure custom fields exist in Task doctype)
    task.source = customer.source
    task.sales_person = customer.sales_person
    task.senior_tax_associates = customer.senior_tax_associates
    task.user_link = customer.user_link
    task.consultant_id = customer.consultant_id
    task.reference_business_partner = customer.reference_business_partner
    task.structure_name = customer.structure_name
    task.omc_commission = customer.omc_commission
    task.banker_commission = customer.banker_commission
    task.consultant_commission = customer.consultant_commission
    task.ref_commission = customer.ref_commission

    task.insert(ignore_permissions=True)

    frappe.db.set_value('Customer', service.name, 'task_created', 1)
    frappe.db.set_value('Customer', service.name, 'task_link', task.name)

    return task.name
@frappe.whitelist()
def create_task_from_service_dt(service_name):
    service = frappe.get_doc('Service', service_name)
    if service.task_created:
        return None

    customer = frappe.get_doc('Customer', service.customer)

    task = frappe.new_doc('Task')
    task.type = service.service_type
    task.subject = f"Task for {service.full_name} {service.service_type}"
    task.description = f"Net Amount: {service.service_amount}"
    task.customer = service.customer
    task.rate = service.service_amount

    # You can store custom fields like this (ensure custom fields exist in Task doctype)
    task.source = customer.source
    task.sales_person = customer.sales_person
    task.senior_tax_associates = customer.senior_tax_associates
    task.user_link = customer.sales_person
    task.consultant_id = customer.consultant_id
    task.reference_business_partner = customer.reference_business_partner
    task.structure_name = customer.structure_name
    task.omc_commission = customer.omc_commission
    task.banker_commission = customer.banker_commission
    task.consultant_commission = customer.consultant_commission
    task.ref_commission = customer.ref_commission

    task.insert(ignore_permissions=True)

    frappe.db.set_value('Service', service.name, 'task_created', 1)
    frappe.db.set_value('Service', service.name, 'task_link', task.name)

    return task.name
def update_service_status(doc, method):
    # Check if any Service is linked to this Task
    services = frappe.get_all(
        "Service",
        filters={"task_link": doc.name},
        fields=["name"]
    )
    for service in services:
        frappe.db.set_value("Service", service.name, "status", doc.status)

@frappe.whitelist()
def generate_fbr_passwords():
    customers = frappe.get_all("Customer", fields=["name"])

    for cust in customers:
        password = _generate_password()
        frappe.db.set_value("Customer", cust.name, "password", password)

    frappe.db.commit()
    return "done"

def _generate_password(length=8):
    """Generate random password of given length"""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))