# Copyright (c) 2025, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document

class Consultant(Document):
	pass
@frappe.whitelist()
def create_user(email, first_name, last_name):
    if frappe.db.exists("User", email):
        frappe.throw("User with this email already exists!")

    # Create the user
    user = frappe.get_doc({
        "doctype": "User",
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
        "send_welcome_email": 1,
        "enabled": 1,
        "role_profile_name": "Consultant",
        "omc_user_type": "Consultant"
    })
    user.insert(ignore_permissions=True)

    # Add User Permission (Allow "Consultant" for this user)
    permission = frappe.get_doc({
        "doctype": "User Permission",
        "user": email,
        "allow": "Consultant",
        "for_value": email,  # assuming 'Consultant' value is user's email
        "apply_to_all_doctypes": 1  # or specify specific doctypes if needed
    })
    permission.insert(ignore_permissions=True)

    return email
