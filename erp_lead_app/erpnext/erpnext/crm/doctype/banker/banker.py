# Copyright (c) 2025, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document

class Banker(Document):
	pass

@frappe.whitelist()
def create_user(email, first_name, last_name):
    if frappe.db.exists("User", email):
        frappe.throw("User with this email already exists!")

    user = frappe.get_doc({
        "doctype": "User",
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
        "send_welcome_email": 1,
        "enabled": 1,
        "role_profile_name": "Banker",  # Set default roles if needed
        "omc_user_type": "Banker"
    })
    user.insert(ignore_permissions=True)

    return email  # Returning email to set in user_id field
