from __future__ import annotations

import hashlib
import json
import re

import frappe
from frappe.utils import cint, now_datetime

from omc_app.api import capabilities, security


REVIEW_DOCTYPE = "OMC Reconciliation Review"
QUARANTINE_DOCTYPE = "OMC Technical Quarantine"
_SAFE_CODE = re.compile(r"^[a-z0-9_.:-]{1,140}$")
DOMAIN_CAPABILITY = {
    "Identity": "can_manage_customers",
    "Staff": "can_manage_staff",
    "Accounting": "can_reconcile_settlement",
    "Commission": "can_approve_commissions",
    "Bridge": "can_retry_sync",
}


def _text(value) -> str:
    return str(value or "").strip()


def _code(value, fallback="unspecified") -> str:
    value = _text(value).lower().replace(" ", "_")
    return value if _SAFE_CODE.fullmatch(value) else fallback


def _key(*values) -> str:
    return hashlib.sha256("|".join(_text(value) for value in values).encode("utf-8")).hexdigest()


def _safe_evidence(values: dict | None) -> str:
    """Serialize explicitly redacted, bounded operational evidence only."""
    clean = {}
    for raw_key, raw_value in (values or {}).items():
        key = _code(raw_key, "")
        if not key:
            continue
        if isinstance(raw_value, bool):
            clean[key] = raw_value
        elif isinstance(raw_value, (int, float)):
            clean[key] = raw_value
        elif raw_value is not None:
            clean[key] = _text(raw_value)[:240]
    return json.dumps(clean, sort_keys=True, ensure_ascii=False)


def open_human_review(
    *,
    domain: str,
    source_doctype: str,
    source_name: str,
    reason_code: str,
    source_version: str = "",
    safe_evidence: dict | None = None,
    run_id: str = "",
):
    reason_code = _code(reason_code)
    review_key = _key(domain, source_doctype, source_name, source_version, reason_code)
    existing = frappe.db.get_value(REVIEW_DOCTYPE, {"review_key": review_key}, "name")
    if existing:
        return frappe.get_doc(REVIEW_DOCTYPE, existing)

    doc = frappe.get_doc(
        {
            "doctype": REVIEW_DOCTYPE,
            "review_key": review_key,
            "domain": _text(domain),
            "source_doctype": _text(source_doctype),
            "source_name": _text(source_name),
            "source_version": _text(source_version),
            "reason_code": reason_code,
            "safe_evidence_json": _safe_evidence(safe_evidence),
            "status": "Open",
            "run_id": _text(run_id),
        }
    )
    try:
        doc.insert(ignore_permissions=True)
        return doc
    except frappe.DuplicateEntryError:
        existing = frappe.db.get_value(REVIEW_DOCTYPE, {"review_key": review_key}, "name")
        if not existing:
            raise
        return frappe.get_doc(REVIEW_DOCTYPE, existing)


def open_technical_quarantine(
    *,
    domain: str,
    source_doctype: str,
    source_name: str,
    failure_code: str,
    source_version: str = "",
    safe_evidence: dict | None = None,
    run_id: str = "",
):
    failure_code = _code(failure_code)
    quarantine_key = _key(domain, source_doctype, source_name, failure_code)
    name = frappe.db.get_value(QUARANTINE_DOCTYPE, {"quarantine_key": quarantine_key}, "name")
    now = now_datetime()
    evidence = _safe_evidence(safe_evidence)
    if name:
        frappe.db.get_value(QUARANTINE_DOCTYPE, name, "name", for_update=True)
        attempts = cint(frappe.db.get_value(QUARANTINE_DOCTYPE, name, "attempt_count") or 0) + 1
        frappe.db.set_value(
            QUARANTINE_DOCTYPE,
            name,
            {
                "source_version": _text(source_version),
                "safe_evidence_json": evidence,
                "status": "Open",
                "last_seen_at": now,
                "attempt_count": attempts,
                "run_id": _text(run_id),
                "resolved_by": None,
                "resolved_at": None,
                "resolution_note": None,
            },
            update_modified=False,
        )
        return frappe.get_doc(QUARANTINE_DOCTYPE, name)

    doc = frappe.get_doc(
        {
            "doctype": QUARANTINE_DOCTYPE,
            "quarantine_key": quarantine_key,
            "domain": _text(domain),
            "source_doctype": _text(source_doctype),
            "source_name": _text(source_name),
            "source_version": _text(source_version),
            "failure_code": failure_code,
            "safe_evidence_json": evidence,
            "status": "Open",
            "first_seen_at": now,
            "last_seen_at": now,
            "attempt_count": 1,
            "run_id": _text(run_id),
        }
    )
    try:
        doc.insert(ignore_permissions=True)
        return doc
    except frappe.DuplicateEntryError:
        # A concurrent worker opened the same incident. Re-enter through the
        # locked update path so occurrence accounting remains monotonic.
        return open_technical_quarantine(
            domain=domain,
            source_doctype=source_doctype,
            source_name=source_name,
            failure_code=failure_code,
            source_version=source_version,
            safe_evidence=safe_evidence,
            run_id=run_id,
        )


def resolve_source_queues(
    *,
    domain: str,
    source_doctype: str,
    source_name: str,
    resolution_note: str = "Reconciliation recovered automatically.",
) -> dict[str, int]:
    now = now_datetime()
    actor = getattr(getattr(frappe, "session", None), "user", None)
    resolved = {"reviews": 0, "quarantines": 0}

    for doctype, key in ((REVIEW_DOCTYPE, "reviews"), (QUARANTINE_DOCTYPE, "quarantines")):
        names = frappe.get_all(
            doctype,
            filters={
                "domain": _text(domain),
                "source_doctype": _text(source_doctype),
                "source_name": _text(source_name),
                "status": ["in", ["Open", "Retrying"]] if doctype == QUARANTINE_DOCTYPE else "Open",
            },
            pluck="name",
            limit_page_length=100,
        )
        for name in names:
            frappe.db.set_value(
                doctype,
                name,
                {
                    "status": "Resolved",
                    "resolved_by": actor,
                    "resolved_at": now,
                    "resolution_note": _text(resolution_note)[:1000],
                },
                update_modified=False,
            )
            resolved[key] += 1
    return resolved


def _require_domain_capability(domain: str) -> str:
    capability = DOMAIN_CAPABILITY.get(_text(domain))
    if not capability:
        frappe.throw("Unsupported reconciliation domain.", frappe.ValidationError)
    capabilities.require(capability)
    return capability


@frappe.whitelist(methods=["POST"])
def resolve_review(review=None, resolution=None, note=None):
    name = _text(review)
    resolution = _text(resolution).lower()
    if resolution not in {"resolved", "ignored"}:
        frappe.throw("resolution must be resolved or ignored.", frappe.ValidationError)
    if not name or not frappe.db.exists(REVIEW_DOCTYPE, name):
        frappe.throw("Reconciliation review was not found.", frappe.DoesNotExistError)

    frappe.db.get_value(REVIEW_DOCTYPE, name, "name", for_update=True)
    doc = frappe.get_doc(REVIEW_DOCTYPE, name)
    capability = _require_domain_capability(doc.domain)
    security.enforce_rate_limit("staff_mutation")
    if doc.status != "Open":
        return {"review": doc.name, "status": doc.status}

    new_status = "Resolved" if resolution == "resolved" else "Ignored"
    frappe.db.set_value(
        REVIEW_DOCTYPE,
        doc.name,
        {
            "status": new_status,
            "resolved_by": frappe.session.user,
            "resolved_at": now_datetime(),
            "resolution_note": _text(note)[:1000],
        },
        update_modified=False,
    )
    security.audit_event(
        event_type="reconciliation.review_resolved",
        capability=capability,
        target_doctype=REVIEW_DOCTYPE,
        target_name=doc.name,
        old_state="open",
        new_state=new_status.lower(),
        safe_reason=_code(resolution),
    )
    return {"review": doc.name, "status": new_status}


@frappe.whitelist(methods=["POST"])
def resolve_quarantine(quarantine=None, resolution=None, note=None):
    name = _text(quarantine)
    resolution = _text(resolution).lower()
    if resolution not in {"resolved", "ignored", "retrying"}:
        frappe.throw("resolution must be resolved, ignored, or retrying.", frappe.ValidationError)
    if not name or not frappe.db.exists(QUARANTINE_DOCTYPE, name):
        frappe.throw("Technical quarantine record was not found.", frappe.DoesNotExistError)

    frappe.db.get_value(QUARANTINE_DOCTYPE, name, "name", for_update=True)
    doc = frappe.get_doc(QUARANTINE_DOCTYPE, name)
    capability = _require_domain_capability(doc.domain)
    security.enforce_rate_limit("staff_mutation")
    new_status = {"resolved": "Resolved", "ignored": "Ignored", "retrying": "Retrying"}[resolution]
    values = {"status": new_status, "resolution_note": _text(note)[:1000]}
    if new_status in {"Resolved", "Ignored"}:
        values.update({"resolved_by": frappe.session.user, "resolved_at": now_datetime()})
    else:
        values.update({"resolved_by": None, "resolved_at": None})
    frappe.db.set_value(QUARANTINE_DOCTYPE, doc.name, values, update_modified=False)
    security.audit_event(
        event_type="reconciliation.quarantine_updated",
        capability=capability,
        target_doctype=QUARANTINE_DOCTYPE,
        target_name=doc.name,
        old_state=_code(doc.status),
        new_state=_code(new_status),
        safe_reason=_code(resolution),
    )
    return {"quarantine": doc.name, "status": new_status}
