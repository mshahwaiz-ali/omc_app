from __future__ import annotations

import hashlib

import frappe
from frappe.utils import cint

from omc_app.api import (
    erp_customer_resolver,
    identity,
    reconciliation_queues,
    reconciliation_runs,
)


JOB_KEY = "customer_account.erp_link"
DOMAIN = "Identity"
CHUNK_SIZE = 25
REVIEW_CODES = {
    "erp_customer_missing",
    "erp_customer_ambiguous",
    "canonical_account_conflict",
}
QUARANTINE_CODES = {"legacy_user_missing", "identity_reconciliation_error"}


def _text(value) -> str:
    return str(value or "").strip()


def _source_version(profile) -> str:
    return hashlib.sha256(
        "|".join(
            (
                _text(profile.name),
                _text(profile.modified),
                _text(profile.user),
                _text(getattr(profile, "linked_app_user", None)),
                _text(profile.email).lower(),
                _text(profile.phone),
                _text(profile.cnic),
                _text(getattr(profile, "ntn", None)),
                _text(profile.customer_status),
                _text(profile.approval_status),
                _text(getattr(profile, "is_active", None)),
                _text(getattr(profile, "linked_erpnext_customer", None)),
            )
        ).encode("utf-8")
    ).hexdigest()


def _account_state(user: str):
    account = identity.get_customer_account(user)
    if not account:
        return None
    return (
        _text(account.erp_customer),
        _text(account.identity_proof_status),
        _text(account.account_link_status),
        _text(account.service_access_status),
        _text(account.mapping_provenance),
        _text(account.mapping_confidence),
        _text(account.source_version),
    )


def _profile_user(profile) -> str:
    user = _text(
        getattr(profile, "linked_app_user", None)
        or getattr(profile, "user", None)
        or getattr(profile, "email", None)
    ).lower()
    return user if user and frappe.db.exists("User", user) else ""


def _account_conflict(account, *, profile_name: str, erp_customer: str) -> str:
    if not account:
        return ""

    existing_customer = _text(getattr(account, "erp_customer", None))
    existing_profile = _text(getattr(account, "legacy_customer_profile", None))

    if existing_customer and existing_customer != erp_customer:
        return "erp_customer_mismatch"
    if existing_profile and existing_profile != profile_name:
        return "legacy_profile_mismatch"
    if not existing_customer:
        return "canonical_account_missing_erp_customer"
    return ""


def _reconcile_profile(profile, *, run_id: str) -> dict[str, int]:
    result = {"changed": 0, "review": 0, "quarantine": 0, "failed": 0}
    version = _source_version(profile)
    user = _profile_user(profile)

    if not user:
        reconciliation_queues.open_technical_quarantine(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            failure_code="legacy_user_missing",
            safe_evidence={"profile": profile.name, "has_email": bool(profile.email)},
            run_id=run_id,
        )
        result["quarantine"] = 1
        return result

    before = _account_state(user)
    profile_doc = frappe.get_doc("OMC Customer Profile", profile.name)

    resolution = erp_customer_resolver.resolve_profile_customer(
        profile_doc,
        create_if_missing=False,
    )
    status = _text(resolution.get("status"))
    erp_customer = _text(resolution.get("customer"))

    if status == "Ambiguous":
        reconciliation_queues.open_human_review(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            reason_code="erp_customer_ambiguous",
            safe_evidence={
                "profile": profile.name,
                "matching_state": "conflict",
            },
            run_id=run_id,
        )
        result["review"] = 1
        return result

    if not erp_customer:
        reconciliation_queues.open_human_review(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            reason_code="erp_customer_missing",
            safe_evidence={
                "profile": profile.name,
                "matching_state": "no_match",
                "resolver_status": status,
            },
            run_id=run_id,
        )
        result["review"] = 1
        return result

    account = identity.get_customer_account(user)
    conflict = _account_conflict(
        account,
        profile_name=profile.name,
        erp_customer=erp_customer,
    )
    if conflict:
        reconciliation_queues.open_human_review(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            reason_code="canonical_account_conflict",
            safe_evidence={
                "profile": profile.name,
                "conflict_kind": conflict,
            },
            run_id=run_id,
        )
        result["review"] = 1
        return result

    if not account:
        account = identity.ensure_customer_account_from_legacy(user)

    if not account:
        reconciliation_queues.open_human_review(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            reason_code="canonical_account_conflict",
            safe_evidence={
                "profile": profile.name,
                "conflict_kind": "canonical_account_not_created",
            },
            run_id=run_id,
        )
        result["review"] = 1
        return result

    after = _account_state(user)
    result["changed"] = int(before != after)

    reconciliation_queues.resolve_source_queues(
        domain=DOMAIN,
        source_doctype="OMC Customer Profile",
        source_name=profile.name,
        review_reason_codes=REVIEW_CODES,
        quarantine_failure_codes=QUARANTINE_CODES,
        resolution_note="Customer identity and ERP Customer mapping reconciled.",
    )
    return result


def _batch(cursor: str, batch_size: int):
    filters = {}
    if cursor:
        filters["name"] = [">", cursor]
    return frappe.get_all(
        "OMC Customer Profile",
        filters=filters,
        fields=[
            "name",
            "user",
            "linked_app_user",
            "email",
            "phone",
            "cnic",
            "ntn",
            "customer_status",
            "approval_status",
            "is_active",
            "linked_erpnext_customer",
            "modified",
        ],
        order_by="name asc",
        limit_page_length=batch_size + 1,
    )


def run_customer_account_reconciliation(batch_size: int = 200) -> dict:
    batch_size = max(1, min(cint(batch_size or 200), 500))
    run, checkpoint = reconciliation_runs.start_run(
        job_key=JOB_KEY,
        domain=DOMAIN,
        batch_size=batch_size,
    )
    counters = {"scanned": 0, "changed": 0, "review": 0, "quarantine": 0, "failed": 0}
    cursor = _text(checkpoint.cursor_value)

    try:
        rows = _batch(cursor, batch_size)
        has_more = len(rows) > batch_size
        rows = rows[:batch_size]

        for index, row in enumerate(rows, start=1):
            savepoint = f"omc_identity_reconcile_{index}"
            frappe.db.savepoint(savepoint)
            counters["scanned"] += 1
            try:
                result = _reconcile_profile(row, run_id=run.run_id)
            except Exception as exc:
                frappe.db.rollback(save_point=savepoint)
                reconciliation_queues.open_technical_quarantine(
                    domain=DOMAIN,
                    source_doctype="OMC Customer Profile",
                    source_name=row.name,
                    source_version=_source_version(row),
                    failure_code="identity_reconciliation_error",
                    safe_evidence={
                        "profile": row.name,
                        "exception_type": type(exc).__name__,
                    },
                    run_id=run.run_id,
                )
                frappe.log_error(
                    frappe.get_traceback(),
                    "OMC customer reconciliation failure",
                )
                counters["quarantine"] += 1
                counters["failed"] += 1
            else:
                for key in ("changed", "review", "quarantine", "failed"):
                    counters[key] += cint(result.get(key))

            cursor = row.name
            if index % CHUNK_SIZE == 0:
                reconciliation_runs.checkpoint_progress(
                    run,
                    checkpoint,
                    cursor=cursor,
                    counters=counters,
                    source_version=_source_version(row),
                )

        cycle_completed = not has_more
        source_version = _source_version(rows[-1]) if rows else _text(checkpoint.source_version)
        return reconciliation_runs.complete_run(
            run,
            checkpoint,
            counters=counters,
            cursor=cursor,
            cycle_completed=cycle_completed,
            source_version=source_version,
        )
    except Exception as exc:
        frappe.log_error(frappe.get_traceback(), "OMC customer reconciliation job failed")
        return reconciliation_runs.fail_run(
            run,
            error_code=type(exc).__name__,
            counters=counters,
        )
