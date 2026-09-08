"""Durable, recipient-bound delivery work; no external I/O in business hooks."""
import hashlib
import random
from datetime import timedelta

import frappe
from omc_app.api import fcm_http
from omc_app.api.notification_channels import channels_for_customer
from omc_app.api.push_retry_policy import owns_claim, retry_plan


def _diagnostic(code):
    try:
        frappe.log_error(message=code, title='OMC push delivery')
    except Exception:
        pass


def create_deliveries_safely(notification):
    # A failed ledger insert must not roll back a payment/document/support action.
    # Never commit the caller's transaction and never log raw exception contents.
    savepoint = 'omc_push_' + hashlib.sha256(str(notification.name).encode()).hexdigest()[:16]
    saved = False
    try:
        frappe.db.savepoint(savepoint)
        saved = True
        create_deliveries(notification)
    except Exception:
        if saved:
            frappe.db.rollback(save_point=savepoint)
        _diagnostic('PUSH_LEDGER_CREATION_FAILED')


def create_deliveries(notification):
    if not notification.get('visible_to_customer') or not notification.get('push_delivery_enabled') or not fcm_http.operational():
        return
    filters = {'is_active': 1, 'platform': 'android'}
    if notification.customer_profile:
        filters['customer_profile'] = notification.customer_profile
    elif notification.recipient_user:
        filters['user'] = notification.recipient_user
    else:
        return
    tokens = frappe.get_all('OMC Push Token', filters=filters, fields=['name', 'user', 'binding_id'])
    for token in tokens:
        if not token.binding_id:
            continue
        key = hashlib.sha256(f'{notification.name}:{token.name}:{token.binding_id}'.encode()).hexdigest()
        if frappe.db.exists('OMC Push Delivery', key):
            continue
        doc = frappe.get_doc({'doctype': 'OMC Push Delivery', 'name': key,
            'notification': notification.name, 'push_token': token.name,
            'recipient_user': token.user, 'binding_id': token.binding_id,
            'status': 'Pending', 'attempts': 0, 'next_attempt': frappe.utils.now_datetime()})
        doc.insert(ignore_permissions=True, set_name=key, ignore_if_duplicate=True)
    # The scheduler is the durable handoff. No Redis/provider failure is allowed
    # to escape this transaction's notification hook.


def sweep():
    if not fcm_http.operational():
        return
    now = frappe.utils.now_datetime()
    for state, time_field, condition in (('Pending', 'next_attempt', ['<=', now]), ('Retry', 'next_attempt', ['<=', now]), ('Sending', 'lease_until', ['<=', now]), ('Sending', 'lease_until', ['is', 'not set'])):
        names = frappe.get_all('OMC Push Delivery', filters={'status': state, time_field: condition},
                               pluck='name', order_by='creation asc', limit_page_length=100)
        for name in names:
            try:
                frappe.enqueue('omc_app.api.push_delivery.deliver', delivery_id=name,
                               queue='short', enqueue_after_commit=True)
            except Exception:
                _diagnostic('PUSH_ENQUEUE_FAILED')


def _authorized(notification, user):
    from omc_app.api import capabilities, mobile
    authority = capabilities.effective(user)
    if not notification.get('visible_to_customer'):
        return False
    if not frappe.db.get_value('User', user, 'enabled'):
        return False
    if notification.customer_profile:
        profile = mobile._assert_approved_customer()
        if profile.name != notification.customer_profile:
            return False
    elif notification.recipient_user != user or not authority.get('can_access_internal_workspace'):
        return False
    targets = {
        'OMC Service Request': ('omc_app.api.service_case_contract.get_service_case', 'case_id'),
        'OMC Service Document': ('omc_app.api.service_document_guard.get_document', 'document_id'),
        'OMC Service Payment': ('omc_app.api.payment_read_guard.get_payment', 'payment_id'),
        'OMC Support Ticket': ('omc_app.api.support_ticket_read_guard.get_support_ticket', 'ticket_id'),
        'Task': ('omc_app.api.task_read_guard.get_task', 'task_id'),
    }
    if notification.reference_doctype:
        target = targets.get(notification.reference_doctype)
        if not target or not notification.reference_name:
            return False
        if frappe.get_attr(target[0])(**{target[1]: notification.reference_name}) is None:
            return False
    return True


def deliver(delivery_id):
    if not fcm_http.operational():
        return
    frappe.db.sql('SELECT name FROM `tabOMC Push Delivery` WHERE name=%s FOR UPDATE', delivery_id)
    doc = frappe.get_doc('OMC Push Delivery', delivery_id)
    now = frappe.utils.now_datetime()
    if doc.status not in ('Pending', 'Retry', 'Sending'):
        return
    if doc.status == 'Sending' and doc.lease_until and doc.lease_until > now:
        return
    if doc.status != 'Sending' and doc.next_attempt and doc.next_attempt > now:
        return
    if int(doc.attempts or 0) >= 8 or now - doc.creation > timedelta(hours=24):
        frappe.db.set_value(doc.doctype, doc.name, {'status': 'Failed', 'error_code': 'EXPIRED'})
        return
    attempts = int(doc.attempts or 0) + 1
    frappe.db.set_value(doc.doctype, doc.name, {'status': 'Sending', 'attempts': attempts, 'lease_until': now + timedelta(minutes=2)})
    frappe.db.commit()
    original_user = frappe.session.user
    status, error, provider_id = 'Skipped', '', ''
    next_attempt = now
    try:
        # Prevent ownership reassignment until this send finishes. Lease claim
        # above prevents duplicate workers; the token lock serializes registration.
        frappe.db.sql('SELECT name FROM `tabOMC Push Token` WHERE name=%s FOR UPDATE', doc.push_token)
        token = frappe.get_doc('OMC Push Token', doc.push_token)
        # Fence lease recovery using the existing monotonic attempt number.
        # Hold the delivery row with the token through the provider call.
        frappe.db.sql('SELECT name FROM `tabOMC Push Delivery` WHERE name=%s FOR UPDATE', delivery_id)
        current_claim = frappe.get_doc('OMC Push Delivery', delivery_id)
        if not owns_claim(current_claim, attempts):
            return
        now = frappe.utils.now_datetime()
        notification = frappe.get_doc('OMC Notification', doc.notification)
        if not token.is_active or token.user != doc.recipient_user or token.binding_id != doc.binding_id:
            return
        if not notification.get('visible_to_customer') or not notification.get('push_delivery_enabled') or (notification.expires_on and frappe.utils.get_datetime(notification.expires_on) <= now):
            return
        if not channels_for_customer(notification.customer_profile, notification.notification_type)[1]:
            return
        frappe.set_user(doc.recipient_user)
        if not _authorized(notification, doc.recipient_user):
            return
        if not fcm_http.operational():
            return
        provider_id = fcm_http.send(token.token, notification.name, doc.binding_id)
        status = 'Sent'
    except fcm_http.SendFailure as failure:
        error = failure.code
        if failure.code == 'UNREGISTERED':
            frappe.db.set_value('OMC Push Token', doc.push_token, 'is_active', 0)
        status, next_attempt = retry_plan(attempts, frappe.utils.get_datetime(doc.creation), frappe.utils.now_datetime(),
                                         retryable=failure.retryable, retry_after=failure.retry_after, jitter=random.randint(0, 30))
    except (frappe.PermissionError, frappe.DoesNotExistError):
        error = 'RECIPIENT_NO_LONGER_AUTHORIZED'
    except Exception:
        error = 'DELIVERY_CHECK_FAILED'
        status, next_attempt = retry_plan(attempts, frappe.utils.get_datetime(doc.creation), frappe.utils.now_datetime(),
                                         retryable=True, retry_after=300)
    finally:
        frappe.set_user(original_user)
        frappe.db.sql('SELECT name FROM `tabOMC Push Delivery` WHERE name=%s FOR UPDATE', delivery_id)
        current_claim = frappe.get_doc('OMC Push Delivery', delivery_id)
        if owns_claim(current_claim, attempts):
            frappe.db.set_value('OMC Push Delivery', doc.name, {'status': status, 'error_code': error,
                'provider_message_id': provider_id, 'next_attempt': next_attempt, 'lease_until': None})
        frappe.db.commit()
