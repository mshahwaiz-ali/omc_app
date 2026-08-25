#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


WIDTH = 60


def load_payload(path: str) -> dict[str, Any]:
    text = Path(path).read_text(encoding="utf-8", errors="replace").strip()
    for line in reversed([line.strip() for line in text.splitlines() if line.strip()]):
        try:
            value = json.loads(line)
            if isinstance(value, dict):
                return value
        except Exception:
            pass

    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        value = json.loads(text[start : end + 1])
        if isinstance(value, dict):
            return value

    raise SystemExit(f"Could not parse JSON output: {path}")


def number(value: Any) -> str:
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, int):
        return f"{value:,}"
    if isinstance(value, float):
        if value.is_integer():
            return f"{int(value):,}"
        return f"{value:,.2f}".rstrip("0").rstrip(".")
    return str(value)


def compact(value: Any) -> str:
    if value in (None, "", {}, []):
        return "none"
    if isinstance(value, (bool, int, float)):
        return number(value)
    if isinstance(value, dict):
        parts = [f"{key}={number(item)}" for key, item in value.items()]
        return ", ".join(parts) if parts else "none"
    if isinstance(value, list):
        return ", ".join(str(item) for item in value) if value else "none"
    return str(value)


def count_values(value: Any) -> int:
    if not isinstance(value, dict):
        return int(value or 0) if isinstance(value, (int, float)) else 0
    total = 0
    for item in value.values():
        if isinstance(item, (int, float)) and not isinstance(item, bool):
            total += int(item)
    return total


def row(label: str, value: Any) -> None:
    print(f"{label:<34} {compact(value)}")


def heading(title: str) -> None:
    print()
    print("=" * WIDTH)
    print(title)
    print("=" * WIDTH)


def status(text: str) -> None:
    print()
    print(f"STATUS: {text}")


def bucket_row(label: str, bucket: dict[str, Any]) -> None:
    created = bucket.get("create", bucket.get("created", 0))
    updated = bucket.get("update", bucket.get("updated", 0))
    deactivated = bucket.get("deactivate", bucket.get("deactivated", 0))
    unchanged = bucket.get("unchanged", 0)
    conflicts = bucket.get("conflict", bucket.get("conflicts", 0))
    print(
        f"{label:<22} "
        f"create {number(created):>6}  "
        f"update {number(updated):>6}  "
        f"deactivate {number(deactivated):>6}  "
        f"unchanged {number(unchanged):>6}  "
        f"conflicts {number(conflicts):>4}"
    )


def erp_contract(data: dict[str, Any]) -> None:
    heading("ERP contract validation")
    row("Compatible", data.get("compatible"))
    row("Required app", data.get("required_app"))
    row("Validated fields", data.get("validated_fields"))
    row("Required doctypes", len(data.get("doctypes") or []))
    row("Warnings", len(data.get("warnings") or []))
    status("VALID" if data.get("compatible") else "REVIEW REQUIRED")


def initialize(data: dict[str, Any]) -> None:
    heading("OMC site initialization")
    row("Status", data.get("ok"))
    row("Permissions", data.get("permissions"))
    row("Desk metadata", data.get("desk_metadata"))
    branding = data.get("branding") or {}
    row("Brand", branding.get("brand_name"))
    contract = data.get("erp_contract") or {}
    row("ERP compatible", contract.get("compatible"))
    row("ERP warnings", len(contract.get("warnings") or []))


def migration_preflight(data: dict[str, Any]) -> None:
    heading("Customer migration preflight")
    row("Customers found", data.get("total_customers"))
    row("Safely identifiable", data.get("safely_identifiable"))
    row("Activation-ready", data.get("activation_ready_import"))
    row("Deferred until signup", data.get("deferred_claim_on_signup"))
    row("Identity review required", data.get("identity_review"))
    row("Profiles to create", data.get("create_customer_profile"))
    row("Profiles to reuse", data.get("reuse_customer_profile"))
    row("Customer Users to create", data.get("user_accounts_to_create"))
    row("Blocking/review identities", count_values(data.get("blocker_counts") or {}))
    row("Warnings", count_values(data.get("warning_counts") or {}))

    historical = data.get("historical_service_migration") or {}
    task_types = historical.get("task_types") or {}
    services = historical.get("historical_services") or {}
    heading("Historical service preflight")
    row("Task Types total", task_types.get("total"))
    row("Task Types already mapped", task_types.get("already_mapped"))
    row("Task Types to create", task_types.get("to_create"))
    row("Mapping conflicts", task_types.get("mapping_conflicts"))
    row("Historical services", services.get("total"))
    row("Already projected", services.get("already_projected"))
    row("Safe projection candidates", services.get("safe_projection_candidates"))
    row("Projection conflicts", services.get("projection_conflicts"))
    row("Missing ERP customer", services.get("missing_customer"))
    row("Review reasons", count_values(historical.get("review_reason_counts") or {}))

    safe = int(data.get("user_accounts_to_create") or 0) == 0
    status("SAFE TO CONTINUE" if safe else "STOP - CUSTOMER USER CREATION DETECTED")


def migration_apply(data: dict[str, Any]) -> None:
    heading("Customer migration apply")
    row("Total ERP customers", data.get("total_customers"))
    row("Safe rows migrated", data.get("safe_rows_migrated"))
    row("Profiles created", data.get("profiles_created"))
    row("Profiles reused", data.get("profiles_reused"))
    row("Customer Users created", data.get("user_accounts_created"))
    row("Deferred until signup", data.get("deferred_claim_on_signup_skipped"))
    row("Identity review skipped", data.get("identity_review_skipped"))

    staff = data.get("staff_sync") or {}
    heading("Staff reconciliation")
    row("Candidate users", staff.get("candidate_users"))
    row("Eligible users", staff.get("eligible_users"))
    row("Staff synchronized", staff.get("synced_users"))
    row("Staff skipped", staff.get("skipped_users"))
    row("Skip reasons", count_values(staff.get("skip_reasons") or {}))

    heading("Historical referrals")
    row("Linked now", data.get("historical_referrals_linked"))
    row("Already linked", data.get("historical_referrals_already_linked"))
    row("Left for review", data.get("historical_referral_review"))
    row("Review reasons", count_values(data.get("historical_referral_review_counts") or {}))

    historical = data.get("historical_service_migration") or {}
    task_types = historical.get("task_types") or {}
    services = historical.get("historical_services") or {}
    heading("Historical service migration")
    row("Task Types created", task_types.get("created"))
    row("Task Types reused", task_types.get("reused"))
    row("Task Type conflicts", task_types.get("conflicts"))
    row("Services created", services.get("created"))
    row("Services reused", services.get("reused"))
    row("Services skipped", services.get("skipped"))
    row("Service conflicts", services.get("conflicts"))
    row("Review reasons", count_values(historical.get("review_reason_counts") or {}))

    safe = int(data.get("user_accounts_created") or 0) == 0
    status("APPLIED SAFELY" if safe else "STOP - CUSTOMER USERS WERE CREATED")


def catalogue_preview(data: dict[str, Any]) -> None:
    heading("Production service catalogue preview")
    row("Ready to sync", data.get("ready_to_sync"))
    pre = data.get("preconditions") or {}
    company = pre.get("company") or {}
    tasks = pre.get("task_types") or {}
    schema = pre.get("schema") or {}
    row("Company", company.get("name"))
    row("Company exists", company.get("exists"))
    row("Task Types found", tasks.get("found"))
    row("Task Types expected", tasks.get("expected"))
    row("Missing Task Types", len(tasks.get("missing") or []))
    row("Schema ready", schema.get("ready"))

    summary = data.get("summary") or {}
    print()
    bucket_row("Categories", summary.get("categories") or {})
    bucket_row("Services", summary.get("services") or {})
    bucket_row("Required documents", summary.get("required_documents") or {})
    bucket_row("Form fields", summary.get("form_fields") or {})

    totals = summary.get("totals") or {}
    print()
    row("Total objects to create", totals.get("created"))
    row("Total objects to update", totals.get("updated"))
    row("Total objects to deactivate", totals.get("deactivated"))
    row("Total objects unchanged", totals.get("unchanged"))
    row("Conflicts", totals.get("conflicts"))
    row("Blockers", totals.get("blockers"))
    row("Key backfill pending", totals.get("key_backfill_pending"))

    presentation = data.get("presentation") or {}
    heading("Service descriptions & assignment preview")
    row("Services requiring copy update", presentation.get("updated"))
    row("Services already current", presentation.get("unchanged"))
    row("Managed services missing", len(presentation.get("missing_services") or []))
    row("Default assignment role", presentation.get("assignment_role"))
    row("Source errors", len(presentation.get("errors") or []))

    ready = bool(data.get("ready_to_sync")) and bool(presentation.get("ok", True))
    status("SAFE TO SYNC" if ready else "REVIEW REQUIRED")


def catalogue_sync(data: dict[str, Any]) -> None:
    heading("Production service catalogue synchronization")
    row("Status", data.get("ok"))
    row("Committed", data.get("committed"))
    sections = data.get("sections") or {}
    for name, label in (
        ("categories", "Categories"),
        ("services", "Services"),
        ("required_documents", "Required documents"),
        ("form_fields", "Form fields"),
    ):
        if name in sections:
            bucket_row(label, sections.get(name) or {})

    totals = data.get("totals") or {}
    print()
    row("Created", totals.get("created"))
    row("Updated", totals.get("updated"))
    row("Deactivated", totals.get("deactivated"))
    row("Unchanged", totals.get("unchanged"))
    row("Deleted", totals.get("deleted"))
    row("Conflicts", totals.get("conflicts"))
    validation = data.get("validation") or {}
    row("Catalogue rows valid", validation.get("valid"))

    presentation = data.get("presentation") or {}
    heading("Service descriptions & Employee assignment")
    row("Services updated", presentation.get("updated"))
    row("Services unchanged", presentation.get("unchanged"))
    row("Default assignment role", presentation.get("assignment_role"))
    presentation_validation = presentation.get("validation") or {}
    row("Presentation valid", presentation_validation.get("valid"))

    valid = bool(validation.get("valid")) and bool(presentation_validation.get("valid"))
    status("VALID" if valid else "REVIEW REQUIRED")


def catalogue_validate(data: dict[str, Any]) -> None:
    heading("Production service catalogue validation")
    row("Valid", data.get("valid"))
    row("Ready to sync", data.get("ready_to_sync"))
    pending = data.get("pending") or {}
    row("Pending creates", pending.get("created"))
    row("Pending updates", pending.get("updated"))
    row("Pending deactivations", pending.get("deactivated"))
    row("Conflicts", pending.get("conflicts"))
    row("Blockers", pending.get("blockers"))
    totals = ((data.get("summary") or {}).get("totals") or {})
    row("Managed objects unchanged", totals.get("unchanged"))
    row("Key backfill pending", totals.get("key_backfill_pending"))

    presentation = data.get("presentation") or {}
    if presentation:
        heading("Service descriptions & assignment validation")
        row("Valid", presentation.get("valid"))
        row("Services requiring update", presentation.get("updated"))
        row("Services unchanged", presentation.get("unchanged"))
        row("Missing managed services", len(presentation.get("missing_services") or []))
        row("Default assignment role", presentation.get("assignment_role"))
        row("Source errors", len(presentation.get("errors") or []))

    status("VALID" if data.get("valid") else "REVIEW REQUIRED")


def presentation_sync(data: dict[str, Any]) -> None:
    heading("Service descriptions & assignment")
    row("Status", data.get("ok"))
    row("Committed", data.get("committed"))
    row("Services updated", data.get("updated"))
    row("Services unchanged", data.get("unchanged"))
    row("Default assignment role", data.get("assignment_role"))
    validation = data.get("validation") or {}
    row("Presentation valid", validation.get("valid"))


def presentation_validate(data: dict[str, Any]) -> None:
    heading("Service presentation validation")
    row("Valid", data.get("valid"))
    row("Services requiring update", data.get("updated"))
    row("Services unchanged", data.get("unchanged"))
    row("Missing managed services", len(data.get("missing_services") or []))
    row("Default assignment role", data.get("assignment_role"))
    row("Source errors", len(data.get("errors") or []))


REPORTERS = {
    "erp_contract": erp_contract,
    "initialize": initialize,
    "migration_preflight": migration_preflight,
    "migration_apply": migration_apply,
    "catalogue_preview": catalogue_preview,
    "catalogue_sync": catalogue_sync,
    "catalogue_validate": catalogue_validate,
    "presentation_sync": presentation_sync,
    "presentation_validate": presentation_validate,
}


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[1] not in REPORTERS:
        valid = ", ".join(sorted(REPORTERS))
        raise SystemExit(f"Usage: {Path(sys.argv[0]).name} <{valid}> <raw-output-file>")
    kind, path = sys.argv[1], sys.argv[2]
    REPORTERS[kind](load_payload(path))


if __name__ == "__main__":
    main()
