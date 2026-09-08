"""FCM HTTP v1 using the Google Auth/requests APIs already required by Frappe v14.

No firebase-admin, PyJWT upgrade, or unrelated dependency installation required.
Only trusted site configuration supplies the credentials file and project ID.
"""
import os
import re
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone

import frappe
from omc_app.api.push_retry_policy import enabled, response_failure


def operational():
    conf = getattr(frappe.local, 'conf', None) or {}
    return bool(enabled(conf.get('omc_fcm_enabled')) and
                re.fullmatch(r'[a-z][a-z0-9-]{4,62}', str(conf.get('omc_fcm_project_id') or '')) and
                os.path.isfile(str(conf.get('omc_fcm_credentials_file') or '')))


class SendFailure(Exception):
    def __init__(self, code, retryable=False, retry_after=0):
        super().__init__(code)
        self.code, self.retryable, self.retry_after = code, retryable, retry_after


def retry_after_seconds(value):
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        try:
            return max(0, int((parsedate_to_datetime(value) - datetime.now(timezone.utc)).total_seconds()))
        except (TypeError, ValueError, OverflowError):
            return 0


def send(token, notification_id, binding_id):
    if not operational():
        raise SendFailure('NOT_CONFIGURED')
    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import AuthorizedSession
        credentials = service_account.Credentials.from_service_account_file(
            frappe.conf.omc_fcm_credentials_file,
            scopes=['https://www.googleapis.com/auth/firebase.messaging'])
    except Exception:
        raise SendFailure('PROVIDER_CREDENTIAL_CONFIGURATION_ERROR') from None
    try:
        with AuthorizedSession(credentials) as session:
            response = session.post(
                'https://fcm.googleapis.com/v1/projects/' + frappe.conf.omc_fcm_project_id + '/messages:send',
                json={'message': {
                    'token': token,
                    'notification': {'title': 'OMC House', 'body': 'You have an update. Open OMC to view it.'},
                    'data': {'notification_id': notification_id, 'binding_id': binding_id},
                    'android': {'priority': 'high', 'ttl': '86400s', 'notification': {
                        'channel_id': 'omc_updates', 'icon': 'ic_stat_omc',
                        'tag': notification_id, 'visibility': 'PRIVATE'}},
                }}, timeout=(5, 20), allow_redirects=False)
    except Exception:
        # Never persist provider bodies, token values, key paths or auth exceptions.
        raise SendFailure('TRANSPORT_OR_CREDENTIAL_ERROR', retryable=True) from None
    try:
        data = response.json()
    except (ValueError, TypeError):
        data = {}
    if response.ok and isinstance(data, dict) and isinstance(data.get('name'), str) and data['name']:
        return data['name'][:255]
    code, retryable = response_failure(response.status_code, data)
    raise SendFailure(code, retryable, retry_after_seconds(response.headers.get('Retry-After')))
