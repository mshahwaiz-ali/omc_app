from __future__ import annotations

from urllib.parse import urlsplit

import frappe


CONFIG_KEY = "omc_cors_allowed_origins"


def _valid_origin(value: str) -> str:
    origin = str(value or "").strip().rstrip("/")
    if not origin or origin == "*" or origin.lower() == "null":
        return ""
    parsed = urlsplit(origin)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return ""
    if parsed.username or parsed.password or parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        return ""
    return f"{parsed.scheme}://{parsed.netloc}"


def _allowed_origins() -> frozenset[str]:
    """Return only origins explicitly configured in this site's config."""
    configured = frappe.conf.get(CONFIG_KEY)
    if isinstance(configured, str):
        configured = [item.strip() for item in configured.split(",")]
    values = {
        _valid_origin(value)
        for value in (configured or [])
        if str(value or "").strip()
    }
    values.discard("")
    return frozenset(values)


def add_cors_headers(response, request=None):
    origin = _valid_origin(frappe.get_request_header("Origin"))
    if origin and origin in _allowed_origins():
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = (
            "Content-Type, Authorization, X-Frappe-CSRF-Token, "
            "X-Requested-With, X-Idempotency-Key"
        )
        response.headers["Vary"] = "Origin"
    return response
