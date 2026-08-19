from __future__ import annotations

import hashlib
from dataclasses import dataclass

import frappe
from frappe.utils import now_datetime


CUSTOMER_ACCOUNT = "OMC Customer Account"
STAFF_ACCESS = "OMC Staff Access"


@dataclass(frozen=True)
class CustomerContext:
    user: str
    account_name: str
    erp_customer: str
    legacy_profile: str


def _text(value) -> str:
    return str(value or "").strip()


def current_user(*, required: bool = True) -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", "")) or "Guest"
    if required and user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _doctype_exists(doctype: str) -> bool:
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def user_is_enabled(user: str) -> bool:
    return bool(user and user != "Guest" and frappe.db.exists("User", user) and int(frappe.db.get_value("User", user, "enabled") or 0))


def user_type(user: str) -> str:
    return _text(frappe.db.get_value("User", user, "user_type")) if frappe.db.exists("User", user) else ""


def get_customer_account(user: str | None = None, *, for_update: bool = False):
    user = _text(user or current_user())
    if not _doctype_exists(CUSTOMER_ACCOUNT):
        return None
    name = frappe.db.get_value(CUSTOMER_ACCOUNT, {"user": user}, "name", for_update=for_update)
    return frappe.get_doc(CUSTOMER_ACCOUNT, name) if name else None


def _legacy_profile_for_user(user: str):
    names = set(
        frappe.get_all("OMC Customer Profile", filters={"user": user}, pluck="name", limit_page_length=2)
    )
    names.update(
        frappe.get_all("OMC Customer Profile", filters={"linked_app_user": user}, pluck="name", limit_page_length=2)
    )
    if len(names) != 1:
        return None
    return frappe.get_doc("OMC Customer Profile", next(iter(names)))


def ensure_customer_account_from_legacy(user: str | None = None):
    user = _text(user or current_user())
    if user_type(user) == "System User":
        frappe.throw("System Users cannot be customer accounts.", frappe.PermissionError)
    existing = get_customer_account(user, for_update=True)
    if existing:
        return existing
    profile = _legacy_profile_for_user(user)
    if not profile:
        return None
    customer = _text(profile.get("linked_erpnext_customer"))
    if not customer or not frappe.db.exists("Customer", customer):
        return None
    duplicates = frappe.get_all(
        "OMC Customer Profile",
        filters={"linked_erpnext_customer": customer},
        pluck="name",
        limit_page_length=2,
    )
    if len(duplicates) != 1:
        return None
    doc = frappe.get_doc({
        "doctype": CUSTOMER_ACCOUNT,
        "user": user,
        "erp_customer": customer,
        "legacy_customer_profile": profile.name,
        "identity_proof_status": "Verified",
        "account_link_status": "Linked",
        "service_access_status": "Approved" if (
            _text(profile.get("approval_status")) == "Approved"
            and _text(profile.get("customer_status")) == "Active"
            and int(profile.get("is_active") or 0)
        ) else "Pending Review",
        "mapping_provenance": "Deterministic Legacy Link",
        "mapping_confidence": "Exact Link",
        "source_version": _text(profile.get("modified")),
        "last_reconciled_at": now_datetime(),
    })
    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        return get_customer_account(user, for_update=True)
    return doc


def require_customer_context(*, allow_lazy_link: bool = False) -> CustomerContext:
    user = current_user()
    if not user_is_enabled(user) or user_type(user) == "System User":
        frappe.throw("Customer access is not available.", frappe.PermissionError)
    account = get_customer_account(user, for_update=allow_lazy_link)
    if not account and allow_lazy_link:
        account = ensure_customer_account_from_legacy(user)
    if not account:
        frappe.throw("Customer access is not available.", frappe.PermissionError)
    if account.identity_proof_status != "Verified" or account.account_link_status != "Linked" or account.service_access_status != "Approved":
        frappe.throw("Customer access is not available.", frappe.PermissionError)
    customer = _text(account.erp_customer)
    if not customer or not frappe.db.exists("Customer", customer):
        frappe.throw("Customer access is not available.", frappe.PermissionError)
    return CustomerContext(user, account.name, customer, _text(account.legacy_customer_profile))


def get_staff_access(user: str | None = None, *, for_update: bool = False):
    user = _text(user or current_user())
    if not _doctype_exists(STAFF_ACCESS):
        return None
    name = frappe.db.get_value(STAFF_ACCESS, {"user": user}, "name", for_update=for_update)
    return frappe.get_doc(STAFF_ACCESS, name) if name else None


def source_version(*values) -> str:
    return hashlib.sha256("|".join(_text(value) for value in values).encode("utf-8")).hexdigest()


def request_is_owned(request, context: CustomerContext) -> bool:
    account = _text(request.get("customer_account")) if request.meta.has_field("customer_account") else ""
    if account:
        return account == context.account_name
    return bool(context.legacy_profile and _text(request.get("customer_profile")) == context.legacy_profile)


def require_owned_request(name: str, *, for_update: bool = False):
    context = require_customer_context()
    name = _text(name)
    if not name:
        frappe.throw("Request is not available.", frappe.DoesNotExistError)
    locked_name = frappe.db.get_value("OMC Service Request", name, "name", for_update=for_update)
    if not locked_name:
        frappe.throw("Request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked_name)
    if not request_is_owned(request, context):
        frappe.throw("Request is not available.", frappe.DoesNotExistError)
    return context, request

