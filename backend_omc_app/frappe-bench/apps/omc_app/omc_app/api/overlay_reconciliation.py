from __future__ import annotations

import hashlib
import json

import frappe
from frappe.utils import now_datetime

from omc_app.api import access, capabilities, identity, security
from omc_app.setup.roles import ERP_STAFF_PERSONAS


CUSTOMER_ACCOUNT = "OMC Customer Account"
STAFF_ACCESS = "OMC Staff Access"
REVIEW = "OMC Reconciliation Review"


def _text(value) -> str:
    return str(value or "").strip()


def _key(*parts: str) -> str:
    return hashlib.sha256("|".join(_text(part) for part in parts).encode("utf-8")).hexdigest()


def _review_name(domain: str, source_doctype: str, source_name: str, reason: str) -> str:
    return _key(domain, source_doctype, source_name, reason)


def _record_review(*, domain: str, source_doctype: str, source_name: str, reason: str, source_version: str, run_id: str) -> str:
    name = frappe.db.get_value(
        REVIEW,
        {
            "domain": domain,
            "source_doctype": source_doctype,
            "source_name": source_name,
            "reason_code": reason,
        },
        "name",
    )
    evidence = json.dumps({"candidate_count": 0, "reason_code": reason}, sort_keys=True)
    if name:
        frappe.db.set_value(
            REVIEW,
            name,
            {"source_version": source_version, "run_id": run_id, "safe_evidence_json": evidence},
            update_modified=False,
        )
        return name
    doc = frappe.get_doc({
        "doctype": REVIEW,
        "domain": domain,
        "source_doctype": source_doctype,
        "source_name": source_name,
        "source_version": source_version,
        "reason_code": reason,
        "safe_evidence_json": evidence,
        "status": "Open",
        "run_id": run_id,
    })
    doc.insert(ignore_permissions=True)
    return doc.name


def _profile_user(profile) -> str:
    values = {_text(profile.get("user")), _text(profile.get("linked_app_user"))}
    values.discard("")
    return next(iter(values)) if len(values) == 1 else ""


def _customer_decision(profile) -> dict:
    user = _profile_user(profile)
    customer = _text(profile.get("linked_erpnext_customer"))
    if not user:
        return {"action": "review", "reason": "missing_or_conflicting_user"}
    if not frappe.db.exists("User", user):
        return {"action": "review", "reason": "user_missing"}
    if identity.user_type(user) == "System User":
        return {"action": "review", "reason": "system_user_excluded"}
    if not customer or not frappe.db.exists("Customer", customer):
        return {"action": "review", "reason": "erp_customer_missing"}
    if frappe.db.count("OMC Customer Profile", {"linked_erpnext_customer": customer}) != 1:
        return {"action": "review", "reason": "duplicate_customer_link"}
    existing_user = frappe.db.get_value(CUSTOMER_ACCOUNT, {"user": user}, "name")
    existing_customer = frappe.db.get_value(CUSTOMER_ACCOUNT, {"erp_customer": customer}, "name")
    if existing_user and existing_customer and existing_user != existing_customer:
        return {"action": "review", "reason": "user_already_mapped"}
    if existing_user:
        existing = frappe.get_doc(CUSTOMER_ACCOUNT, existing_user)
        if _text(existing.erp_customer) != customer:
            return {"action": "review", "reason": "user_already_mapped"}
        return {"action": "link", "user": user, "customer": customer}
    if existing_customer:
        return {"action": "review", "reason": "customer_already_mapped"}
    return {"action": "link", "user": user, "customer": customer}


def _persona(user: str, profile) -> tuple[str, str, str]:
    user_value = ""
    try:
        if frappe.get_meta("User").has_field("omc_user_type"):
            user_value = _text(frappe.db.get_value("User", user, "omc_user_type"))
    except Exception:
        user_value = ""
    profile_value = _text(profile.get("staff_role"))
    if user_value and profile_value and user_value != profile_value:
        return "", "", "persona_conflict"
    value = user_value or profile_value
    if value not in ERP_STAFF_PERSONAS and value not in access.ROLE_CAPABILITIES:
        return "", "", "persona_missing_or_unsupported"
    return value, "User.omc_user_type" if user_value else "Reviewed", ""


def _staff_decision(profile) -> dict:
    user = _text(profile.get("user"))
    if not user or not frappe.db.exists("User", user):
        return {"action": "review", "reason": "staff_user_missing"}
    if identity.user_type(user) != "System User":
        return {"action": "review", "reason": "staff_not_system_user"}
    employee = _text(profile.get("linked_employee"))
    if employee:
        matches = frappe.get_all("Employee", filters={"user_id": user}, pluck="name", limit_page_length=2)
        if matches != [employee]:
            return {"action": "review", "reason": "employee_link_conflict"}
    persona, source, reason = _persona(user, profile)
    if reason:
        return {"action": "review", "reason": reason}
    return {"action": "link", "user": user, "employee": employee, "persona": persona, "persona_source": source}


def _apply_customer(profile, decision: dict, run_id: str) -> str:
    existing = frappe.db.get_value(CUSTOMER_ACCOUNT, {"user": decision["user"]}, "name")
    if existing:
        return existing
    approved = (
        _text(profile.get("customer_status")) == "Active"
        and _text(profile.get("approval_status")) == "Approved"
        and int(profile.get("is_active") or 0)
    )
    doc = frappe.get_doc({
        "doctype": CUSTOMER_ACCOUNT,
        "user": decision["user"],
        "erp_customer": decision["customer"],
        "legacy_customer_profile": profile.name,
        "identity_proof_status": "Verified",
        "account_link_status": "Linked",
        "service_access_status": "Approved" if approved else "Pending Review",
        "mapping_provenance": "Deterministic Legacy Link",
        "mapping_confidence": "Exact Link",
        "source_version": _text(profile.modified),
        "last_reconciled_at": now_datetime(),
    })
    doc.insert(ignore_permissions=True)
    security.audit_event(
        event_type="customer_account.reconciled",
        capability="can_manage_customers",
        target_doctype=CUSTOMER_ACCOUNT,
        target_name=doc.name,
        new_state=doc.service_access_status,
        source_version=doc.source_version,
        idempotency_key=run_id,
    )
    return doc.name


def _apply_staff(profile, decision: dict, run_id: str) -> str:
    existing = frappe.db.get_value(STAFF_ACCESS, {"user": decision["user"]}, "name")
    if existing:
        return existing
    approved = (
        _text(profile.get("staff_status")) == "Active"
        and _text(profile.get("approval_status")) == "Approved"
        and int(profile.get("is_active") or 0)
    )
    capability_set = sorted(access.ROLE_CAPABILITIES.get(decision["persona"], set()))
    doc = frappe.get_doc({
        "doctype": STAFF_ACCESS,
        "user": decision["user"],
        "employee": decision["employee"] or None,
        "legacy_staff_profile": profile.name,
        "access_status": "Approved" if approved else "Pending Review",
        "persona_snapshot": decision["persona"],
        "persona_source": decision["persona_source"],
        "source_version": identity.source_version(profile.modified, decision["persona"], decision["employee"]),
        "reconciliation_status": "Current",
        "capabilities": [{"capability": code} for code in capability_set],
        "approved_by": "Administrator" if approved else None,
        "approved_at": now_datetime() if approved else None,
        "last_reconciled_at": now_datetime(),
    })
    doc.insert(ignore_permissions=True)
    security.audit_event(
        event_type="staff_access.reconciled",
        capability="can_manage_staff",
        target_doctype=STAFF_ACCESS,
        target_name=doc.name,
        new_state=doc.access_status,
        source_version=doc.source_version,
        idempotency_key=run_id,
    )
    return doc.name


def _source_doctype(domain: str) -> str:
    if domain == "customer":
        return "OMC Customer Profile"
    if domain == "staff":
        return "OMC Staff Profile"
    frappe.throw("domain must be customer or staff.", frappe.ValidationError)


def run(*, domain: str, mode: str = "preview", run_id: str | None = None, cursor: int = 0, limit: int = 100) -> dict:
    domain = _text(domain).lower()
    mode = _text(mode).lower()
    if mode not in {"preview", "apply", "resume"}:
        frappe.throw("mode must be preview, apply, or resume.", frappe.ValidationError)
    if mode == "resume" and not _text(run_id):
        frappe.throw("run_id is required when resuming.", frappe.ValidationError)
    effective_mode = "apply" if mode == "resume" else mode
    run_id = _text(run_id) or frappe.generate_hash(length=20)
    start = max(int(cursor or 0), 0)
    page_length = min(max(int(limit or 100), 1), 500)
    doctype = _source_doctype(domain)
    total = frappe.db.count(doctype)
    selected = frappe.get_all(
        doctype,
        pluck="name",
        order_by="name asc",
        limit_start=start,
        limit_page_length=page_length,
    )
    results = []
    for name in selected:
        profile = frappe.get_doc(doctype, name)
        decision = _customer_decision(profile) if domain == "customer" else _staff_decision(profile)
        outcome = {
            "source_hash": _key(name),
            "action": decision["action"],
            "reason": decision.get("reason", ""),
        }
        for sensitive_field in ("user", "customer", "employee"):
            if decision.get(sensitive_field):
                outcome[f"{sensitive_field}_hash"] = _key(decision[sensitive_field])
        if decision.get("persona"):
            outcome["persona"] = decision["persona"]
        if effective_mode == "apply":
            if decision["action"] == "link":
                target = _apply_customer(profile, decision, run_id) if domain == "customer" else _apply_staff(profile, decision, run_id)
                outcome["target_hash"] = _key(target)
            else:
                review = _record_review(
                    domain="Identity" if domain == "customer" else "Staff",
                    source_doctype=doctype,
                    source_name=name,
                    reason=decision["reason"],
                    source_version=_text(profile.modified),
                    run_id=run_id,
                )
                outcome["review_hash"] = _key(review)
        results.append(outcome)
    return {
        "read_only": effective_mode == "preview",
        "mode": mode,
        "domain": domain,
        "run_id": run_id,
        "cursor": start,
        "next_cursor": start + len(selected),
        "has_more": start + len(selected) < total,
        "total": total,
        "batch_checksum": _key(*[
            _key(item["source_hash"], item["action"], item.get("reason", ""))
            for item in results
        ]),
        "linked": sum(item["action"] == "link" for item in results),
        "review": sum(item["action"] == "review" for item in results),
        "items": results,
    }


@frappe.whitelist(methods=["POST"])
def reconcile_overlays(domain=None, mode="preview", run_id=None, cursor=0, limit=100):
    required = "can_manage_customers" if _text(domain).lower() == "customer" else "can_manage_staff"
    capabilities.require(required)
    security.enforce_rate_limit("staff_mutation")
    return run(domain=domain, mode=mode, run_id=run_id, cursor=cursor, limit=limit)
