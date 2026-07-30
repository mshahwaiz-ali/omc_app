
from __future__ import unicode_literals
import json
import frappe
import requests 
from frappe import _
from frappe.utils.password import get_decrypted_password, set_encrypted_password
from frappe.utils.password import update_password, decrypt, check_password
from lead_app.lead_app.fcm import send_notification
from lead_app.epg import initiate_payment as epg_initiate_payment


@frappe.whitelist(allow_guest=True)
def sign_up():
            args = frappe.form_dict
            if frappe.db.exists("User",args.email):
                    frappe.throw("User already exists with same email")
            doc = frappe.get_doc({
                        "doctype": "User",
                        "email": args.email,
                        "first_name": args.first_name,
                        "send_welcome_email" : 0,
                        "new_password": args.pwd,
                       "username":args.first_name,
                       "omc_user_type":args.role

                    }).insert(ignore_permissions=True)
            # set_encrypted_password("User", doc.name, self.name.replace("-","@"), "password")
            doc.add_roles('Sales Manager', 'Sales User', 'Sales Master Manager', 'Projects User', 'Projects Manager')
            update_password(user=doc.name, pwd=args.pwd)
            frappe.db.commit()
            if args.role == "Business Partner":
                 frappe.get_doc({
                        "doctype": args.role,
                        "email_id": args.email,
                        "full_name": args.first_name,
                        "mobile" : args.mobile_no, 
                        "cnic":args.cnic,
                        "whatsapp":args.whatsapp,
                        "user_link":doc.name,
                        # "bank_name":args.bank_name,
                        # "branch_name":args.branch_name,
                        # "address" :args.bank_area,
                        #"consultant":args.consultant                   
                    }).insert(ignore_permissions=True)
            elif args.role == "Tax Associates":
                 frappe.get_doc({
                        "doctype": args.role,
                        "email_id": args.email,
                        "full_name": args.first_name,
                        "mobile" : args.mobile_no, 
                        "cnic":args.cnic,
                        "whatsapp":args.whatsapp,
                        "user_link":doc.name,
                        "address":args.address,
                        "education":args.education,
                        "experience":args.experience,
                        "remarks": args.remarks                 
                    }).insert(ignore_permissions=True)
            else:
                 frappe.get_doc({
                        "doctype": args.role,
                        "email_id": args.email,
                        "full_name": args.first_name,
                        "mobile" : args.mobile_no, 
                        "cnic":args.cnic,
                        "whatsapp":args.whatsapp,
                        "user_link":doc.name,
                        "address":args.address                     
                    }).insert(ignore_permissions=True)
            #return True



@frappe.whitelist(allow_guest=True)
def login():  
    args = frappe.form_dict
    try:
        login_manager = frappe.auth.LoginManager()
        login_manager.authenticate(user=args.user, pwd=args.pwd)
        login_manager.post_login()

        user = frappe.get_doc('User', frappe.session.user)

        
        try:
          
            
            notification_response = send_notification(
                token=user.device_id ,
                title='Welcome To OMC House',
                body=f'{user.full_name}',
                payload={
                    
                }
            )

            notification = frappe.get_doc({
                "doctype":"App Notification",
                "title": 'Welcome To OMC House',
                "sub_title":f'{user.full_name}',
                "user": user.name,
                
            }).insert(ignore_permissions=True)

            
        except Exception as e:
            frappe.log_error(f"Error in Submit: {str(e)}", "Notification Error")
            
        
        frappe.response["message"] = {
            "success_key": 1,
            "message": "Authentication success",
            "sid": frappe.session.sid,
            "username": user.username,
            "email": user.email
        }

    except frappe.exceptions.AuthenticationError: 
        frappe.clear_messages()
        frappe.local.response["message"] = {
            "success_key": 0,
            "message": "Authentication Error!"
        }

    return


@frappe.whitelist(allow_guest=True)
def create_service(): 
      data = frappe.form_dict
      lead = frappe.get_doc({
            "doctype":"Lead",
            "full_name": data.full_name,
            "company_name": data.full_name,
            "mobile_no": data.mobile_no,
            "task_type": data.service_type,
            "serives_amount": data.service_amount,
            "discount": data.discount,
            "net_service_amount": data.net_service_amount,
            "user_link":data.user_link,
            "custom_remarks":data.custom_remarks,
            "cnic":data.cnic,
            "source":frappe.db.get_value("User",{"email":data.user_link},"omc_user_type") or None,
            "sales_person":data.user_link
            
      }).insert(ignore_permissions=True)
      return "Success"

@frappe.whitelist(allow_guest=True)
def create_lead():
    data = frappe.form_dict

    is_social = frappe.utils.cint(data.get("is_social_login"))

    customer = None
    customer_name = None
    full_name = None
    mobile_no = None
    cnic = None
    custom_customer_type = None 
    lead=None
    lead_mobile = None
    lead_cnic = None

    # ---------------- SOCIAL LOGIN CASE ----------------
    if is_social:
        # Find customer by user_link (email)
        customer = frappe.db.get_value(
            "Lead",
            {"user_link": data.get("user_link")},
            ["name", "company_name", "mobile_no", "custom_cnic"],
            as_dict=True
        )

        if not customer:
            frappe.throw("No Customer linked with this social account")

        lead = customer.company_name
        lead_mobile = customer.mobile_no
        customer_name = customer.company_name
        lead_cnic = customer.custom_cnic or ""
        custom_customer_type = "Lead"

    # ---------------- NORMAL LOGIN CASE ----------------
    else:
        cnic = data.get("cnic")
        customer_name = frappe.db.get_value(
            "Customer",
            {"tax_id": cnic},
            "name"
        )
       
        full_name = data.get("full_name")
        mobile_no = data.get("mobile_no")
        custom_customer_type = "Customer" 

    # ---------------- CREATE SERVICE DOC ----------------
    doc = frappe.get_doc({
        "doctype": "Service",
        "customer": customer_name,
        "full_name": full_name,
        "mobile_no": mobile_no,
        "cnic": cnic,
        # Social login fields
        "lead": lead,
        "lead_mobile": lead_mobile,
        "lead_cnic": lead_cnic,
        "service_type": data.get("service_type"),
        "service_amount": data.get("service_amount"), 
        "custom_remarks": data.get("remarks") or "",
        "discount": data.get("discount") or 0,
        "net_service_amount": data.get("net_service_amount") or data.get("service_amount"),
        "user_link": data.get("user_link"),
        "custom_status": "In Progress",
        "custom_customer_type": custom_customer_type,
    })

    # ✅ Using save instead of insert
    doc.save(ignore_permissions=True)

    return doc.name


@frappe.whitelist()
def save_device_token():
        args = frappe.form_dict 
        #name = frappe.db.get_value("User",args.get("email"),"name") 
        # doc=frappe.get_doc("Employee",name)
        frappe.db.sql(""" update tabUser set device_id=%s where name=%s""",(args.get("token"),args.get("userEmail")))  
        return { 'email':args.get("email"), 
                        'token':args.get("token") }


@frappe.whitelist()
def submit_leave_through_system(title=None, description=None,user=None):
    try:
        args = frappe.form_dict 
        token = frappe.db.get_value("User", (user or frappe.session.user), "device_id")

        # if not token:
        #     frappe.log_error(f"No device token found for employee: {employee}", "Notification Error")
        #     return {
        #         "status": "error",
        #         "message": f"No device token found for employee: {employee}"
        #     }

        notification_response = send_notification(
            token=token ,#"fwY97ojASEaaM-dbXuLkIU:APA91bGPg_uZFXFsfmJ74DlbNlMtPTv1_PIecM3-tpnS0x_eTo-oYXAHCzpHdCw2U6qTK-inOseGzAo-UETaQDVGvYSuTHfO4M7Plt-sclgwBjixxTcUMt8",
            title= title if title else 'Notification Sent',
            body=description if description else f'Your notification sent',
            payload={
                
            }
        )

        notification = frappe.get_doc({
            "doctype":"App Notification",
            "title": title if title else 'Notification Sent',
            "sub_title": description if description else f'Your notification sent',
            "user": user or frappe.session.user,
            
        }).insert(ignore_permissions=True)

        frappe.log_error(str(notification_response), "Notification Response")

        if notification_response['status'] == 'success':
            return {
                "status": "success",
                "message": "Success."
            }
        
        else:
            return {
                "status": "error",
                "message": f'Failed to send notification. Error: {notification_response["message"]}'
            }
    except Exception as e:
        frappe.log_error(f"Error in Submit: {str(e)}", "Notification Error")
        return {
            "status": "error",  
            "message": f"Exception occurred: {str(e)}"}
    



@frappe.whitelist(allow_guest=True)
def generate_cookies():  
    args = frappe.form_dict
    try:
        login_manager = frappe.auth.LoginManager()
        login_manager.authenticate(user=args.user, pwd=args.pwd)
        login_manager.post_login()

        user = frappe.get_doc('User', frappe.session.user)

        
        frappe.response["message"] = {
            "success_key": 1,
            "message": "Authentication success",
            "sid": frappe.session.sid,
            "username": user.username,
            "email": user.email
        }

    except frappe.exceptions.AuthenticationError: 
        frappe.clear_messages()
        frappe.local.response["message"] = {
            "success_key": 0,
            "message": "Authentication Error!"
        }

    return

	


@frappe.whitelist()
def get_dashboard_data():
    args = frappe.form_dict
    tasks = frappe.db.get_all("Task",filters={"user_link":args.user},fields=["*"])
    completed = 0
    in_progress = 0
    cancelled = 0
    for tsk in tasks:
        if tsk.status == "Completed":
            completed +=1
        if tsk.status == "Working":
            in_progress +=1
        if tsk.workflow_state == "Hold":
            cancelled +=1

    
    customer = frappe.db.get_value("Customer",{"user_link":args.user},"name")
    total_invoice = frappe.db.sql("select sum(debit) as amount from `tabGL Entry` where  is_cancelled=0 and party_type='Customer' and party=%s",(customer), as_dict=1)[0]["amount"] or 0
    total_payment =  frappe.db.sql("select sum(credit) as amount from `tabGL Entry` where  is_cancelled=0 and party_type='Customer' and party=%s",(customer), as_dict=1)[0]["amount"] or 0
    outstanding = total_invoice - total_payment
    return {
         "total_reffered_cases": len(tasks),
        "totalEarn": frappe.db.sql("select sum(credit) as amount from `tabGL Entry` where account='Commission Payable - O' and is_cancelled=0 and party=%s",(args.user), as_dict=1)[0]["amount"] or 0,
        "paid": frappe.db.sql("select sum(debit) as amount from `tabGL Entry` where account='Commission Payable - O' and is_cancelled=0 and party=%s",(args.user), as_dict=1)[0]["amount"] or 0,
        "unpaid": frappe.db.sql("select sum(credit - debit) as amount from `tabGL Entry` where account='Commission Payable - O' and is_cancelled=0 and party=%s",(args.user), as_dict=1)[0]["amount"] or 0,
        "daily_job_count": frappe.db.count("Lead",{"user_link": args.user}), #Daily Job
        "employeeCount": frappe.db.count("Employee",{"user_link": args.user}),
        "consultantCount": frappe.db.count("Consultant",{"user_link": args.user}),
        "partnerCount": frappe.db.count("Business Partner",{"user_link": args.user}),
        "taxAssociateCount": frappe.db.count("Tax Associates",{"user_link": args.user}),
        "completed": completed,
        "inProgress": in_progress,
        "declined": cancelled,
        "total_invoice": total_invoice,
        "total_payment": total_payment, 
        "outstanding": outstanding
    }
    
    
@frappe.whitelist()
def get_user_profile_data(user_email):
    for doctype in ["Consultant", "Business Partner", "Tax Associates"]:
        result = frappe.get_all(
            doctype,
            filters={"user_link": user_email},
            fields=["name", "full_name", "mobile_no","address"],
            limit_page_length=1
        )
        if result:
            return {"doctype": doctype, "data": result[0]}
    return {"message": "No data found"}

@frappe.whitelist(allow_guest=True)
def google_mobile_login(id_token):
    """
    Custom login endpoint for Flutter app using Google Sign-In ID token.
    """
    import requests

    try:
        # ✅ Verify ID token with Google
        verify_url = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
        res = requests.get(verify_url)
        if res.status_code != 200:
            frappe.throw("Invalid Google ID token")

        user_data = res.json()
        email = user_data.get("email")

        if not email:
            frappe.throw("Google account does not provide an email")

        # ✅ Check if user exists in ERPNext
        if frappe.db.exists("User", email):
            user = frappe.get_doc("User", email)
        else:
            # ✅ Auto-create user
            user = frappe.get_doc({
                "doctype": "User",
                "email": email,
                "first_name": user_data.get("given_name"),
                "last_name": user_data.get("family_name"),
                "enabled": 1,
            })
            user.insert(ignore_permissions=True)

            # ✅ Assign Role Profile "Customer"
            role_profile_name = "Customer"  # Change if your Role Profile name differs
            if frappe.db.exists("Role Profile", role_profile_name):
                user.role_profile_name = role_profile_name
                user.save(ignore_permissions=True)
            else:
                user.add_roles("Customer")

        # ✅ Login the user
        frappe.local.login_manager.user = email
        frappe.local.login_manager.post_login()
        frappe.db.commit()

        # ✅ Fetch session data for response
        frappe.response["message"] = {
            "success_key": 1,
            "message": "Authentication success",
            "sid": frappe.session.sid,
            "username": user.username,
            "email": user.email
        }

    except Exception as e:
        frappe.log_error(f"Google Login Error: {str(e)}", "google_mobile_login")
        frappe.response["message"] = {
            "success_key": 0,
            "message": f"Login Failed: {str(e)}"
        }

    return


@frappe.whitelist()
def initiate_service_payment(service_name):
    """Initiate EPG payment for a Service document."""
    service = frappe.get_doc("Service", service_name)

    amount = service.net_service_amount or service.service_amount
    if not amount or float(amount) <= 0:
        frappe.throw(_("Service amount must be greater than 0"))

    customer_name = service.full_name or service.customer or service_name

    result = epg_initiate_payment(
        amount=str(amount),
        order_id=service_name,
        order_name=customer_name,
        reference_doctype="Service",
        reference_name=service_name
    )

    return result


@frappe.whitelist()
def check_payment_status(service_name):
    """Check the latest EPG payment status for a Service document."""
    transactions = frappe.get_all(
        "EPG Payment Transaction",
        filters={
            "reference_doctype": "Service",
            "reference_name": service_name
        },
        fields=[
            "name", "status", "transaction_id", "amount",
            "currency", "approval_code", "initiated_at",
            "completed_at", "error_message"
        ],
        order_by="initiated_at desc",
        limit_page_length=1
    )

    if transactions:
        return {"exists": True, "transaction": transactions[0]}

    return {"exists": False, "transaction": None}

