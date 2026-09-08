"""Pure policy tests; no site, Redis, database, credentials or provider calls."""
import unittest
from datetime import datetime, timedelta
from omc_app.api.push_retry_policy import enabled, owns_claim, response_failure, retry_plan


class TestPushRetryPolicy(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 9, 8, 12, 0)

    def test_false_string_cannot_enable_dispatch(self):
        for value in (False, 0, '0', 'false', 'off', '', None):
            self.assertFalse(enabled(value), repr(value))

    def test_explicit_true_values_enable_dispatch(self):
        for value in (True, 1, 'true', '1', 'on'):
            self.assertTrue(enabled(value))

    def test_generic_404_does_not_revoke_a_token(self):
        self.assertNotEqual(response_failure(404, {})[0], 'UNREGISTERED')

    def test_only_typed_fcm_unregistered_is_revocable(self):
        payload = {'error': {'details': [{'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode': 'UNREGISTERED'}]}}
        self.assertEqual(response_failure(404, payload), ('UNREGISTERED', False))
        self.assertNotEqual(response_failure(400, payload)[0], 'UNREGISTERED')

    def test_untyped_error_code_does_not_revoke(self):
        self.assertNotEqual(response_failure(404, {'error': {'details': [{'errorCode': 'UNREGISTERED'}]}})[0], 'UNREGISTERED')

    def test_html_or_malformed_transient_response_still_retries(self):
        for status in (408, 429, 500, 502, 503, 504):
            self.assertTrue(response_failure(status, '<html>unavailable</html>')[1])

    def test_invalid_error_details_are_safe(self):
        for payload in (None, [], {'error': None}, {'error': {'details': None}}, {'error': {'details': [42, {'errorCode': []}]}}):
            self.assertFalse(response_failure(400, payload)[1])

    def test_auth_and_payload_errors_are_not_transient(self):
        for status in (400, 401, 403):
            self.assertFalse(response_failure(status, {})[1])

    def test_retry_after_takes_precedence(self):
        self.assertEqual(retry_plan(1, self.now, self.now, retryable=True, retry_after=600), ('Retry', self.now + timedelta(seconds=600)))

    def test_backoff_and_jitter(self):
        self.assertEqual(retry_plan(3, self.now, self.now, retryable=True, jitter=10), ('Retry', self.now + timedelta(seconds=250)))

    def test_attempt_limit_is_terminal(self):
        self.assertEqual(retry_plan(8, self.now, self.now, retryable=True)[0], 'Failed')

    def test_age_limit_is_terminal(self):
        self.assertEqual(retry_plan(2, self.now-timedelta(hours=24), self.now, retryable=True)[0], 'Failed')

    def test_no_retry_is_scheduled_outside_lifetime(self):
        self.assertEqual(retry_plan(2, self.now-timedelta(hours=23, minutes=59), self.now, retryable=True)[0], 'Failed')

    def test_huge_provider_delay_cannot_overflow_datetime(self):
        self.assertEqual(retry_plan(1, self.now, self.now, retryable=True, retry_after=10**100)[0], 'Failed')

    def test_stale_attempt_cannot_finish_a_new_claim(self):
        self.assertFalse(owns_claim({'status': 'Sending', 'attempts': 2}, 1))
        self.assertTrue(owns_claim({'status': 'Sending', 'attempts': 2}, 2))

    def test_finished_delivery_cannot_be_reclaimed_by_completion(self):
        for state in ('Sent', 'Failed', 'Skipped'):
            self.assertFalse(owns_claim({'status': state, 'attempts': 1}, 1))
