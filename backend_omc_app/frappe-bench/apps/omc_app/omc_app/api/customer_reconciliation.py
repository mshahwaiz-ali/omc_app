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


def _profile_user_reference(profile) -> str:
    """Return only an explicit application identity link.

    Profile email is business/contact data and must never silently become app
    activation evidence.
    """

    return _text(
        getattr(profile, "linked_app_user", None)
        or getattr(profile, "user", None)
    ).lower()


def _profile_user(profile) -> str:
    user = _profile_user_reference(profile)
    return (
        user
        if user and frappe.db.exists("User", user)
        else ""
    )


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

    user_reference = _profile_user_reference(profile)
    user = _profile_user(profile)

    # An explicit User link that no longer resolves is still a technical
    # identity problem. A Profile with no User link at all is now a valid
    # business-only customer state and must not be quarantined.
    if user_reference and not user:
        reconciliation_queues.open_technical_quarantine(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            source_version=version,
            failure_code="legacy_user_missing",
            safe_evidence={
                "profile": profile.name,
                "has_email": bool(profile.email),
            },
            run_id=run_id,
        )
        result["quarantine"] = 1
        return result

    before = _account_state(user) if user else None
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

    # ERP Customer + OMC Profile is a complete business-customer identity.
    # No User or Customer Account is required until app activation.
    if not user:
        reconciliation_queues.resolve_source_queues(
            domain=DOMAIN,
            source_doctype="OMC Customer Profile",
            source_name=profile.name,
            review_reason_codes=REVIEW_CODES,
            quarantine_failure_codes=QUARANTINE_CODES,
            resolution_note=(
                "Business customer ERP Customer/Profile mapping is valid; "
                "app activation is not required."
            ),
        )
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



def get_customer_account_reconciliation_status() -> dict:
    """Return read-only operational status for production convergence gates."""

    checkpoint = frappe.db.get_value(
        "OMC Reconciliation Checkpoint",
        {
            "job_key": JOB_KEY,
            "domain": DOMAIN,
        },
        [
            "cursor_value",
            "cycle_count",
            "last_run_id",
        ],
        as_dict=True,
    ) or {}

    review_rows = frappe.get_all(
        "OMC Reconciliation Review",
        filters={
            "domain": DOMAIN,
            "status": "Open",
        },
        fields=["reason_code"],
        limit_page_length=0,
    )

    quarantine_rows = frappe.get_all(
        "OMC Technical Quarantine",
        filters={
            "domain": DOMAIN,
            "status": [
                "in",
                ["Open", "Retrying"],
            ],
        },
        fields=["failure_code"],
        limit_page_length=0,
    )

    review_counts = {}
    for row in review_rows:
        code = _text(row.get("reason_code"))
        review_counts[code] = review_counts.get(code, 0) + 1

    quarantine_counts = {}
    for row in quarantine_rows:
        code = _text(row.get("failure_code"))
        quarantine_counts[code] = (
            quarantine_counts.get(code, 0) + 1
        )

    unexpected_reviews = {
        code: count
        for code, count in review_counts.items()
        if code not in REVIEW_CODES
    }

    return {
        "job_key": JOB_KEY,
        "domain": DOMAIN,
        "checkpoint": {
            "cursor_value": _text(
                checkpoint.get("cursor_value")
            ),
            "cycle_count": cint(
                checkpoint.get("cycle_count")
            ),
            "last_run_id": _text(
                checkpoint.get("last_run_id")
            ),
        },
        "customer_profiles": frappe.db.count(
            "OMC Customer Profile"
        ),
        "users": frappe.db.count("User"),
        "customer_accounts": frappe.db.count(
            "OMC Customer Account"
        ),
        "open_reviews": len(review_rows),
        "open_review_reason_counts": review_counts,
        "expected_review_reason_codes": sorted(
            REVIEW_CODES
        ),
        "unexpected_open_review_reason_counts":
            unexpected_reviews,
        "open_identity_quarantines":
            len(quarantine_rows),
        "open_quarantine_failure_counts":
            quarantine_counts,
        "legacy_user_missing_open":
            quarantine_counts.get(
                "legacy_user_missing",
                0,
            ),
    }


def _run_customer_account_reconciliation_unlocked(batch_size: int = 200) -> dict:
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

def run_customer_account_reconciliation(
    batch_size: int = 200,
    lock_timeout: int = 0,
) -> dict:
    """Run one checkpointed batch with exclusive job ownership."""

    timeout = max(
        0,
        min(cint(lock_timeout or 0), 60),
    )

    acquired = reconciliation_runs.acquire_job_lock(
        job_key=JOB_KEY,
        domain=DOMAIN,
        timeout=timeout,
    )

    if not acquired:
        return {
            "run_id": "",
            "status": "SkippedLocked",
            "safe_error_code":
                "reconciliation_already_running",
            "cursor_start": "",
            "cursor_end": "",
            "next_cursor": "",
            "cycle_completed": False,
            "scanned": 0,
            "changed": 0,
            "review": 0,
            "quarantine": 0,
            "failed": 0,
        }

    try:
        return _run_customer_account_reconciliation_unlocked(
            batch_size=batch_size,
        )
    finally:
        reconciliation_runs.release_job_lock(
            job_key=JOB_KEY,
            domain=DOMAIN,
        )
