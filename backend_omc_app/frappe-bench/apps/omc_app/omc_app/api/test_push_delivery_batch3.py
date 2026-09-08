"""Mocked production-function tests. No external sends or real DB writes."""
import unittest
from contextlib import ExitStack
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import frappe
from omc_app.api import fcm_http, push_delivery


class Row(dict):
    __getattr__ = dict.get
    def __setattr__(self, key, value):
        self[key] = value


class TestPushDeliveryBatch3(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.now = datetime(2026, 9, 8, 12, 0)
        self.delivery = Row(doctype='OMC Push Delivery', name='D', notification='N', push_token='T',
                            recipient_user='owner@example.invalid', binding_id='a'*32,
                            status='Pending', attempts=0, creation=self.now,
                            next_attempt=self.now, lease_until=None)
        self.token = Row(name='T', user='owner@example.invalid', binding_id='a'*32,
                         is_active=1, token='TEST_TOKEN_NEVER_SENT')
        self.notification = Row(name='N', visible_to_customer=1, push_delivery_enabled=1,
                                expires_on=None, customer_profile='C', notification_type='General')
        self.db = MagicMock()
        self.db.set_value.side_effect = self._set_value
        self.stack.enter_context(patch.object(frappe, 'db', self.db))
        self.stack.enter_context(patch.object(frappe, 'session', SimpleNamespace(user='Administrator')))
        self.stack.enter_context(patch.object(frappe, 'set_user', side_effect=lambda user: setattr(frappe.session, 'user', user)))
        self.stack.enter_context(patch.object(frappe.utils, 'now_datetime', return_value=self.now))
        self.stack.enter_context(patch.object(frappe.utils, 'get_datetime', side_effect=lambda value: value))
        self.stack.enter_context(patch.object(frappe, 'get_doc', side_effect=self._get_doc))
        self.stack.enter_context(patch.object(fcm_http, 'operational', return_value=True))
        self.sender = self.stack.enter_context(patch.object(fcm_http, 'send', return_value='projects/test/messages/id'))
        self.stack.enter_context(patch.object(push_delivery, 'channels_for_customer', return_value=(True, True)))
        self.authority = self.stack.enter_context(patch.object(push_delivery, '_authorized', return_value=True))

    def _get_doc(self, doctype, name):
        return {'OMC Push Delivery': self.delivery, 'OMC Push Token': self.token, 'OMC Notification': self.notification}[doctype]

    def _set_value(self, doctype, name, values, value=None):
        row = self._get_doc(doctype, name)
        row.update(values if isinstance(values, dict) else {values: value})

    def test_eligible_send_finishes_and_restores_actor(self):
        push_delivery.deliver('D')
        self.sender.assert_called_once()
        self.assertEqual(self.delivery.status, 'Sent')
        self.assertEqual(self.delivery.attempts, 1)
        self.assertEqual(frappe.session.user, 'Administrator')

    def test_duplicate_finished_job_does_not_send(self):
        self.delivery.status = 'Sent'
        push_delivery.deliver('D')
        self.sender.assert_not_called()

    def test_active_lease_is_not_reclaimed(self):
        self.delivery.update(status='Sending', lease_until=self.now+timedelta(minutes=1))
        push_delivery.deliver('D')
        self.sender.assert_not_called()

    def test_expired_lease_is_recovered(self):
        self.delivery.update(status='Sending', attempts=1, lease_until=self.now-timedelta(minutes=1))
        push_delivery.deliver('D')
        self.assertEqual(self.delivery.attempts, 2)
        self.assertEqual(self.delivery.status, 'Sent')

    def test_binding_rotation_skips_delivery(self):
        self.token.binding_id = 'b'*32
        push_delivery.deliver('D')
        self.sender.assert_not_called()
        self.assertEqual(self.delivery.status, 'Skipped')

    def test_expired_notification_is_not_sent(self):
        self.notification.expires_on = self.now
        push_delivery.deliver('D')
        self.sender.assert_not_called()

    def test_revoked_authority_is_not_sent(self):
        self.authority.return_value = False
        push_delivery.deliver('D')
        self.sender.assert_not_called()

    def test_unregistered_revokes_current_token_only(self):
        self.sender.side_effect = fcm_http.SendFailure('UNREGISTERED')
        push_delivery.deliver('D')
        self.assertEqual(self.token.is_active, 0)
        self.assertEqual(self.delivery.status, 'Failed')

    def test_transient_failure_respects_retry_after(self):
        self.sender.side_effect = fcm_http.SendFailure('TRANSIENT_PROVIDER_ERROR', True, 600)
        push_delivery.deliver('D')
        self.assertEqual(self.delivery.status, 'Retry')
        self.assertEqual(self.delivery.next_attempt, self.now+timedelta(seconds=600))

    def test_newer_claim_fences_older_worker(self):
        original = self._get_doc
        reads = 0
        def racing_get(doctype, name):
            nonlocal reads
            if doctype == 'OMC Push Delivery':
                reads += 1
                if reads == 2:
                    self.delivery.attempts = 2
            return original(doctype, name)
        with patch.object(frappe, 'get_doc', side_effect=racing_get):
            push_delivery.deliver('D')
        self.sender.assert_not_called()
        self.assertEqual(self.delivery.attempts, 2)
        self.assertEqual(self.delivery.status, 'Sending')

    def test_failed_ledger_insert_rolls_back_only_savepoint(self):
        with patch.object(push_delivery, 'create_deliveries', side_effect=RuntimeError('sensitive token')), patch.object(push_delivery, '_diagnostic') as diagnostic:
            push_delivery.create_deliveries_safely(self.notification)
        self.db.rollback.assert_called_once()
        self.assertIn('save_point', self.db.rollback.call_args.kwargs)
        self.db.commit.assert_not_called()
        diagnostic.assert_called_once_with('PUSH_LEDGER_CREATION_FAILED')


class TestFcmHttpBatch3(unittest.TestCase):
    def setUp(self):
        import sys
        import types
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.response = MagicMock(ok=True, status_code=200, headers={})
        self.response.json.return_value = {'name': 'projects/test/messages/123'}
        self.session = MagicMock()
        self.session.post.return_value = self.response
        authorized_session = MagicMock()
        authorized_session.return_value.__enter__.return_value = self.session
        self.credentials = MagicMock()
        modules = {}
        for name in ('google', 'google.oauth2', 'google.auth', 'google.auth.transport', 'google.auth.transport.requests'):
            modules[name] = types.ModuleType(name)
            modules[name].__path__ = []
        modules['google.oauth2'].service_account = SimpleNamespace(Credentials=self.credentials)
        modules['google.auth.transport.requests'].AuthorizedSession = authorized_session
        self.stack.enter_context(patch.dict(sys.modules, modules))
        self.stack.enter_context(patch.object(fcm_http, 'operational', return_value=True))
        self.stack.enter_context(patch.object(frappe, 'conf', SimpleNamespace(
            omc_fcm_project_id='test-project', omc_fcm_credentials_file='/not-read/test.json'), create=True))

    def test_real_send_function_preserves_generic_payload_and_disables_redirects(self):
        self.assertEqual(fcm_http.send('TEST_TOKEN', 'N', 'a'*32), 'projects/test/messages/123')
        args, kwargs = self.session.post.call_args
        self.assertEqual(args[0], 'https://fcm.googleapis.com/v1/projects/test-project/messages:send')
        self.assertFalse(kwargs['allow_redirects'])
        self.assertEqual(kwargs['timeout'], (5, 20))
        self.assertEqual(kwargs['json']['message']['data'], {'notification_id': 'N', 'binding_id': 'a'*32})

    def test_html_503_preserves_retry_after(self):
        self.response.ok = False
        self.response.status_code = 503
        self.response.headers = {'Retry-After': '600'}
        self.response.json.side_effect = ValueError('HTML response')
        with self.assertRaises(fcm_http.SendFailure) as caught:
            fcm_http.send('TEST_TOKEN', 'N', 'a'*32)
        self.assertTrue(caught.exception.retryable)
        self.assertEqual(caught.exception.retry_after, 600)

    def test_malformed_provider_error_details_are_sanitized(self):
        self.response.ok = False
        self.response.status_code = 400
        self.response.json.return_value = {'error': {'details': None, 'message': 'SENSITIVE_BODY'}}
        with self.assertRaises(fcm_http.SendFailure) as caught:
            fcm_http.send('TEST_TOKEN', 'N', 'a'*32)
        self.assertEqual(str(caught.exception), 'PROVIDER_PAYLOAD_ERROR')
        self.assertFalse(caught.exception.retryable)

    def test_credential_error_is_not_retried_as_network_failure(self):
        self.credentials.from_service_account_file.side_effect = ValueError('SENSITIVE_PATH_OR_KEY')
        with self.assertRaises(fcm_http.SendFailure) as caught:
            fcm_http.send('TEST_TOKEN', 'N', 'a'*32)
        self.assertEqual(str(caught.exception), 'PROVIDER_CREDENTIAL_CONFIGURATION_ERROR')
        self.assertFalse(caught.exception.retryable)
        self.session.post.assert_not_called()

    def test_transport_failure_does_not_log_token(self):
        self.session.post.side_effect = RuntimeError('SENSITIVE_TOKEN')
        with self.assertRaises(fcm_http.SendFailure) as caught:
            fcm_http.send('TEST_TOKEN', 'N', 'a'*32)
        self.assertTrue(caught.exception.retryable)
        self.assertNotIn('SENSITIVE', str(caught.exception))

    def test_unregistered_requires_confirmed_fcm_detail(self):
        self.response.ok = False
        self.response.status_code = 404
        self.response.json.return_value = {'error': {'details': [
            {'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode': 'UNREGISTERED'}]}}
        with self.assertRaises(fcm_http.SendFailure) as caught:
            fcm_http.send('TEST_TOKEN', 'N', 'a'*32)
        self.assertEqual(caught.exception.code, 'UNREGISTERED')
        self.assertFalse(caught.exception.retryable)

    def test_retry_after_malformed_or_negative_is_safe(self):
        for value in (None, '', 'bad', '-5'):
            self.assertEqual(fcm_http.retry_after_seconds(value), 0)
        self.assertEqual(fcm_http.retry_after_seconds('180'), 180)
