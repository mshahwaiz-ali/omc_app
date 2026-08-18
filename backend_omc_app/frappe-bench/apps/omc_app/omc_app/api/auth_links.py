from __future__ import annotations

from urllib.parse import urlencode

import frappe
from frappe.utils import get_url


APP_SCHEME = "omchouse"
APP_HOST = "auth"
PRODUCTION_APP_ORIGIN = "https://erp.omchouse.com"
WEB_BASE_URL_CONFIG_KEY = "omc_auth_web_base_url"


def _clean_token(token: str) -> str:
    return str(token or "").strip()


def _app_url(path: str, token: str) -> str:
    query = urlencode({"token": _clean_token(token)})
    return f"{APP_SCHEME}://{APP_HOST}/{path.lstrip('/')}?{query}"


def _web_url(path: str, token: str) -> str:
    configured_base = str(
        frappe.conf.get(WEB_BASE_URL_CONFIG_KEY) or ""
    ).strip().rstrip("/")
    query = urlencode({"token": _clean_token(token)})
    if configured_base:
        return f"{configured_base}/{path.lstrip('/')}?{query}"
    return get_url(f"/{path.lstrip('/')}?{query}")


def _universal_url(path: str, token: str) -> str:
    query = urlencode({"token": _clean_token(token)})
    return f"{PRODUCTION_APP_ORIGIN}/app/{path.lstrip('/')}?{query}"


def verification_links(token: str) -> dict[str, str]:
    return {
        "app_url": _app_url("verify-email", token),
        "universal_url": _universal_url("verify-email", token),
        "web_url": _web_url(
            "api/method/omc_app.api.pending_registration.verify_registration_web",
            token,
        ),
    }


def password_reset_links(token: str) -> dict[str, str]:
    return {
        "app_url": _app_url("reset-password", token),
        "universal_url": _universal_url("reset-password", token),
        "web_url": _web_url("reset-password", token),
    }



def customer_activation_links(token: str) -> dict[str, str]:
    return {
        "app_url": _app_url("activate-account", token),
        "universal_url": _universal_url("activate-account", token),
        "web_url": _web_url("activate-account", token),
    }
