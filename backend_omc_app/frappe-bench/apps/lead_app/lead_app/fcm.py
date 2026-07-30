# fcm.py
import firebase_admin
from firebase_admin import credentials, messaging
import frappe

# Initialize the Firebase Admin SDK
cred = credentials.Certificate('/home/frappe/frappe-bench/apps/lead_app/lead_app/lead_app/firebase-adminsdk.json')
firebase_admin.initialize_app(cred)

def send_notification(token, title, body, payload):
    """Send a notification to a specific device token."""
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        token=token,
        data=payload,   
    )

    try:
        response = messaging.send(message)
        frappe.log(f'Successfully sent message: {response}')
        return {"status": "success", "message": f'Successfully sent message: {response}'}
    except Exception as e:
        frappe.log_error(f'Error sending message: {e}')
