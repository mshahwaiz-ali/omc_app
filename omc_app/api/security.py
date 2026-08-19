from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass

import frappe
from frappe.utils import cint, now_datetime


LOGGER_NAME = "omc_app.security"
SAFE_CODE = re.compile(r"^[a-z0-9_.:-]{1,140}$")

RATE_LIMITS = {
    "login": (5, 3600),
    "identity": (5, 3600),
    "reset": (5, 3600),
    "token_resend": (1, 60),
    "signup": (5, 3600),
    "service_request": (5, 3600),
    "upload": (30, 3600),
    "authenticated_list": (120, 300),
    "customer_mutation": (120, 3600),
    "staff_mutation": (60, 3600),
}


@dataclass(frozen=True)
class RateLimitResult:
    action: str
    count: int
    limit: int
    retry_after: int


def _text(value) -> str:
    return str(value or "").strip()


def _safe_code(value: str, fallback: str = "unspecified") -> str:
    value = _text(value).lower().replace(" ", "_")
    return value if SAFE_CODE.fullmatch(value) else fallback


def correlation_id() -> str:
    try:
        supplied = _text(frappe.get_request_header("X-Correlation-ID"))
    except Exception:
        supplied = ""
    if supplied and SAFE_CODE.fullmatch(supplied.lower()):
        return supplied[:140]
    return frappe.generate_hash(length=24)


def _request_ip() -> str:
    # Frappe populates request_ip after applying its trusted-proxy handling.
    return _text(getattr(frappe.local, "request_ip", "")) or "unknown"


def _subject_hash(value: str) -> str:
    return hashlib.sha256(_text(value).lower().encode("utf-8")).hexdigest()[:32]


def enforce_rate_limit(
    action: str,
    *,
    actor: str | None = None,
    limit: int | None = None,
    window_seconds: int | None = None,
) -> RateLimitResult:
    action = _safe_code(action)
    default_limit, default_window = RATE_LIMITS.get(action, (60, 3600))
    configured_limit = cint(limit or default_limit)
    configured_window = cint(window_seconds or default_window)
    if configured_limit <= 0 or configured_window <= 0:
        frappe.throw("Rate-limit configuration is invalid.", frappe.ValidationError)

    subject = actor or getattr(getattr(frappe, "session", None), "user", "") or "guest"
    bucket = int(now_datetime().timestamp()) // configured_window
    signals = (
        ("actor", _subject_hash(subject)),
        ("ip", _subject_hash(_request_ip())),
    )
    cache = frappe.cache()
    highest = 0
    for signal, digest in signals:
        key = f"omc:rate:{action}:{signal}:{digest}:{bucket}"
        count = int(cache.incr(key) or 0)
        highest = max(highest, count)
        if count == 1:
            cache.expire(key, configured_window + 5)
        signal_limit = configured_limit if signal == "actor" else configured_limit * 12
        if count > signal_limit:
            retry_after = configured_window - (int(now_datetime().timestamp()) % configured_window)
            audit_event(
                event_type="rate_limit.exceeded",
                capability=action,
                safe_reason=signal,
            )
            error = frappe.ValidationError("Too many requests. Try again later.")
            setattr(error, "retry_after", retry_after)
            raise error
    return RateLimitResult(action, highest, configured_limit, configured_window)


def audit_event(
    *,
    event_type: str,
    capability: str = "",
    target_doctype: str = "",
    target_name: str = "",
    old_state: str = "",
    new_state: str = "",
    source_version: str = "",
    idempotency_key: str = "",
    safe_reason: str = "",
    override_expires_at=None,
    actor: str | None = None,
) -> str:
    event_id = frappe.generate_hash(length=32)
    values = {
        "doctype": "OMC Security Audit Event",
        "event_id": event_id,
        "event_type": _safe_code(event_type, "security.event"),
        "occurred_at": now_datetime(),
        "correlation_id": correlation_id(),
        "actor": actor or getattr(getattr(frappe, "session", None), "user", None),
        "effective_capability": _safe_code(capability, "") if capability else "",
        "target_doctype": _text(target_doctype)[:140],
        "target_name": _text(target_name)[:140],
        "old_state": _safe_code(old_state, "") if old_state else "",
        "new_state": _safe_code(new_state, "") if new_state else "",
        "source_version": _text(source_version)[:140],
        "idempotency_key": _text(idempotency_key)[:140],
        "safe_reason": _safe_code(safe_reason, "unspecified") if safe_reason else "",
        "override_expires_at": override_expires_at,
    }
    try:
        frappe.get_doc(values).insert(ignore_permissions=True)
    except Exception:
        frappe.logger(LOGGER_NAME).error(
            "Security audit persistence failed event_type=%s correlation_id=%s",
            values["event_type"],
            values["correlation_id"],
        )
        raise
    return event_id


def revoke_user_sessions(user: str) -> None:
    user = _text(user)
    if not user or user in {"Guest", "Administrator"}:
        return
    try:
        from frappe.sessions import clear_sessions

        clear_sessions(user=user, keep_current=False)
    except TypeError:
        clear_sessions(user=user)
    frappe.cache().delete_key(f"user_permissions::{user}")
