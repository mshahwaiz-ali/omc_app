"""Pure, bounded push retry decisions; no provider secrets or database state."""
from datetime import timedelta


def enabled(value):
    return value is True or value == 1 or (
        isinstance(value, str) and value.strip().lower() in {'1', 'true', 'yes', 'on'}
    )


def response_failure(status, payload):
    error = payload.get('error') if isinstance(payload, dict) else None
    error = error if isinstance(error, dict) else {}
    details = error.get('details')
    details = details if isinstance(details, list) else []
    codes = {
        entry.get('errorCode') for entry in details
        if isinstance(entry, dict)
        and entry.get('@type') == 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
        and isinstance(entry.get('errorCode'), str)
    }
    # A generic 404 or a malformed payload is not proof that a token expired.
    if status == 404 and 'UNREGISTERED' in codes:
        return 'UNREGISTERED', False
    if status in {408, 429, 500, 502, 503, 504}:
        return 'TRANSIENT_PROVIDER_ERROR', True
    if status in {401, 403}:
        return 'PROVIDER_AUTH_OR_PROJECT_ERROR', False
    if status == 400:
        return 'PROVIDER_PAYLOAD_ERROR', False
    return 'PROVIDER_CONFIGURATION_OR_PAYLOAD_ERROR', False


def retry_plan(attempts, created, now, *, retryable, retry_after=0, jitter=0):
    """Never schedule an attempt beyond eight tries or the 24-hour window."""
    deadline = created + timedelta(hours=24)
    if not retryable or attempts >= 8 or now >= deadline:
        return 'Failed', now
    try:
        requested = max(0, int(retry_after or 0))
    except (TypeError, ValueError, OverflowError):
        requested = 0
    delay = max(requested, min(3600, 60 * 2 ** max(0, attempts - 1)) + max(0, min(30, jitter)))
    # Avoid constructing an overflowing datetime for an arbitrary provider header.
    if delay >= (deadline - now).total_seconds():
        return 'Failed', now
    return 'Retry', now + timedelta(seconds=delay)


def owns_claim(doc, attempt):
    return doc.get('status') == 'Sending' and int(doc.get('attempts') or 0) == attempt
