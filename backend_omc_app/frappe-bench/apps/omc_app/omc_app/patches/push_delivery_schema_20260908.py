import hashlib
import uuid
import frappe


def execute():
    for name in ('omc_customer_preference', 'omc_notification', 'omc_push_token', 'omc_push_delivery'):
        frappe.reload_doc('omc_app', 'doctype', name)
    # Existing inbox history remains visible; no historical push is requested.
    frappe.db.sql('UPDATE `tabOMC Notification` SET in_app_delivery_enabled=1 WHERE in_app_delivery_enabled IS NULL')
    seen = set()
    for row in frappe.get_all('OMC Push Token', fields=['name', 'token', 'binding_id'], order_by='modified desc, name asc'):
        digest = hashlib.sha256((row.token or '').encode()).hexdigest()
        if digest in seen:
            frappe.db.set_value('OMC Push Token', row.name, {'is_active': 0, 'token_hash': None})
            continue
        seen.add(digest)
        frappe.db.set_value('OMC Push Token', row.name, {'token_hash': digest, 'binding_id': row.binding_id or uuid.uuid4().hex})
