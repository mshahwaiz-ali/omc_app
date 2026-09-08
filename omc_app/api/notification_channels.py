import frappe


CATEGORY_FIELDS = {
    'service request': 'service_updates_enabled',
    'service update': 'service_updates_enabled',
    'support': 'service_updates_enabled',
    'task': 'service_updates_enabled',
    'task assignment': 'service_updates_enabled',
    'task update': 'service_updates_enabled',
    'general': 'service_updates_enabled',
    'document': 'document_reminders_enabled',
    'payment': 'payment_alerts_enabled',
    'tax': 'tax_alerts_enabled',
}


def channels_for_customer(customer_profile, notification_type):
    if not customer_profile:
        return True, True  # Internal recipient-user events do not use customer preferences.
    category = CATEGORY_FIELDS.get(str(notification_type or '').strip().lower(), 'service_updates_enabled')
    row = frappe.db.get_value('OMC Customer Preference', {'customer_profile': customer_profile},
                              [category, 'in_app_notifications_enabled', 'push_notifications_enabled'], as_dict=True)
    if not row:
        return True, True
    def enabled(field):
        return row.get(field) is None or bool(frappe.utils.cint(row.get(field)))
    allowed = enabled(category)
    return allowed and enabled('in_app_notifications_enabled'), allowed and enabled('push_notifications_enabled')
