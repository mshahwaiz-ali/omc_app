# Copyright (c) 2025, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

import frappe
import re
from frappe.model.document import Document

class BusinessPartner(Document):
	def validate(self):
		# CNIC Validation
		if self.cnic:
			cnic_str = str(self.cnic).strip()
			if not re.match(r"^\d{13}$", cnic_str):
				frappe.throw(
					msg="CNIC must be exactly 13 digits long and contain only numbers (no dashes or spaces).",
					title="Invalid CNIC Format"
				)
			self.cnic = cnic_str

		# Mobile Validation
		if self.mobile:
			mobile_str = str(self.mobile).strip()
			if not re.match(r"^\d{12}$", mobile_str):
				frappe.throw(
					msg="Mobile Number must be exactly 12 digits long and contain only numbers (no dashes or spaces). Please type the mobile number in this format: 92xxxxxxxxxx without the leading 0.",
					title="Invalid Mobile Number Format"
				)
			self.mobile = mobile_str

	def before_insert(self):
		# Keep static defaults here
		self.whatsapp_send = 1

	def after_insert(self):
		# Web Form creation moved here so self.name is fully available
		if not self.cnic:
			return  # Safeguard if CNIC is empty
			
		web_form_route = str(self.cnic).strip()

		# 1. Prevent duplicate creation errors if the CNIC Web Form already exists
		if not frappe.db.exists("Web Form", web_form_route):
			
			# Check if our base template web form exists
			template_form_name = "affiliate-pograme"
			if frappe.db.exists("Web Form", template_form_name):
				
				# 2. Duplicate the existing web form template doc
				base_doc = frappe.get_doc("Web Form", template_form_name)
				web_form = frappe.copy_doc(base_doc)
				
				# 3. Update the specific variable values for this partner
				web_form.name = web_form_route
				web_form.route = web_form_route
				
				# Absolute String Force using format-strings
				mobile_string = f"{self.mobile}".strip() if self.mobile else ""
				web_form.custom_mobile_number = mobile_string
				
				# Set personalized introduction text
				web_form.introduction_text = f"""<center><h3><strong>Welcome to OMC House</strong></h3></center>
					<p>Your trusted tax advisory, now just a click away — reference from <strong>{self.full_name}</strong>.</p>
				"""
				
				# 4. Clear and force data types inside the web form fields child table
				if hasattr(web_form, "web_form_fields"):
					for field in web_form.web_form_fields:
						if field.fieldname == "custom_mobile_number":
							field.default = f"{mobile_string}"
							
						# Inject Default for Source
						elif field.fieldname == "source":
							field.default = "Business Partner"
							
						# Inject Default for Sales Person using the newly generated doc name
						elif field.fieldname == "sales_person":
							field.default = self.name
				
				# 5. Insert the new duplicated form into database
				web_form.insert(ignore_permissions=True)


@frappe.whitelist()
def create_user_permissions_for_partner(doc):
	"""
	Create 4 user permissions:
	1. Consultant → can access Business Partner
	2. Consultant → can access Employee
	3. Employee   → can access Business Partner
	4. Employee   → can access Consultant
	"""
	if not doc.consultant or not doc.employee:
		frappe.throw("Both Consultant and Employee must be set.")

	consultant_user = doc.consultant 
	employee_user = frappe.db.get_value("Employee", doc.employee, "user_id")

	if not employee_user:
		frappe.throw(f"Employee '{doc.employee}' has no user_id set.")

	perms = [
		{"user": consultant_user, "allow": "Business Partner", "for_value": doc.name},
		{"user": consultant_user, "allow": "Employee", "for_value": doc.employee},
		{"user": employee_user, "allow": "Business Partner", "for_value": doc.name},
		{"user": employee_user, "allow": "Consultant", "for_value": doc.consultant},
	]

	for perm in perms:
		if not frappe.db.exists("User Permission", {
			"user": perm["user"],
			"allow": perm["allow"],
			"for_value": perm["for_value"]
		}):
			user_perm = frappe.new_doc("User Permission")
			user_perm.update({
				"user": perm["user"],
				"allow": perm["allow"],
				"for_value": perm["for_value"],
				"apply_to_all_doctypes": 0
			})
			user_perm.insert(ignore_permissions=True)
			frappe.msgprint(f"User Permission created for {perm['user']} → {perm['allow']} = {perm['for_value']}")


@frappe.whitelist()
def create_user(email, first_name):
	if frappe.db.exists("User", email):
		frappe.throw("User with this email already exists!")

	user = frappe.get_doc({
		"doctype": "User",
		"email": email,
		"first_name": first_name,
		"send_welcome_email": 1,
		"enabled": 1,
		"role_profile_name": "Business Partner",
		"omc_user_type": "Business Partner",
		"module_profile": "User",
		"user_type": "System User",
	})
	user.insert(ignore_permissions=True)
	return email