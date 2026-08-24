"""Read-only planning and migration helpers for historical ERP Services.

Historical ERP Service and Task records remain authoritative.
This module must never create replacement ERP Services or Tasks.
"""

from __future__ import annotations

from collections import Counter, defaultdict

import frappe
from frappe.utils import flt


def _text(value) -> str:
    return str(value or "").strip()


def _load_services():
    if not frappe.db.exists("DocType", "Service"):
        return []

    return frappe.get_all(
        "Service",
        fields=[
            "name",
            "customer",
            "service_type",
            "service_amount",
            "discount",
            "net_service_amount",
            "task_created",
            "task_link",
            "date",
            "creation",
        ],
        order_by="creation asc, name asc",
        limit_page_length=0,
    )


def _load_task_types():
    if not frappe.db.exists("DocType", "Task Type"):
        return []

    return frappe.get_all(
        "Task Type",
        fields=[
            "name",
            "service_name",
            "rate",
            "days",
            "description",
        ],
        order_by="name asc",
        limit_page_length=0,
    )


def _load_tasks(task_names):
    names = sorted({_text(name) for name in task_names if _text(name)})
    if not names:
        return {}

    meta = frappe.get_meta("Task")
    optional = [
        "type",
        "status",
        "priority",
        "customer",
        "user_link",
        "exp_end_date",
        "completed_by",
        "completed_on",
        "custom_operation_status",
        "modified",
    ]
    fields = ["name"] + [
        fieldname
        for fieldname in optional
        if meta.get_field(fieldname)
    ]

    rows = frappe.get_all(
        "Task",
        filters={"name": ["in", names]},
        fields=fields,
        limit_page_length=0,
    )
    return {row.name: row for row in rows}



def _resolve_customer_name(raw_customer, customer_names):
    """Resolve one ERP Customer name without guessing identity."""

    raw = _text(raw_customer)

    names = sorted(
        {
            _text(name)
            for name in (customer_names or [])
            if _text(name)
        }
    )

    # Exact authority always wins.
    if raw and raw in names:
        return {
            "customer": raw,
            "valid": True,
            "normalized": False,
            "review_reasons": [],
        }

    # Legacy Link values can differ only by letter case on databases
    # whose collation treats those names as equivalent.
    case_matches = [
        name
        for name in names
        if raw and name.casefold() == raw.casefold()
    ]

    if len(case_matches) == 1:
        return {
            "customer": case_matches[0],
            "valid": True,
            "normalized": True,
            "review_reasons": [
                "customer_name_case_normalized"
            ],
        }

    if len(case_matches) > 1:
        return {
            "customer": "",
            "valid": False,
            "normalized": False,
            "review_reasons": [
                "ambiguous_customer_case_match"
            ],
        }

    return {
        "customer": "",
        "valid": False,
        "normalized": False,
        "review_reasons": [
            "missing_erp_customer"
        ],
    }


def _approved_existing_account_name(
    erp_customer,
    profile_name,
    accounts,
) -> str:
    """Return one existing safe canonical account, otherwise fail closed."""

    customer = _text(erp_customer)
    profile = _text(profile_name)

    if not customer or not profile:
        return ""

    matches = set()

    for account in accounts or []:
        if _text(account.get("erp_customer")) != customer:
            continue

        if (
            _text(account.get("legacy_customer_profile"))
            != profile
        ):
            continue

        if (
            _text(account.get("identity_proof_status"))
            != "Verified"
            or _text(account.get("account_link_status"))
            != "Linked"
            or _text(account.get("service_access_status"))
            != "Approved"
        ):
            continue

        name = _text(account.get("name"))
        if name:
            matches.add(name)

    if len(matches) != 1:
        return ""

    return next(iter(matches))


def _task_projection(
    service,
    task,
    *,
    erp_customer=None,
):
    """Validate and project an existing ERP Task without mutating it."""

    result = {
        "erp_task": "",
        "status": "Historical",
        "closed_on": None,
        "review_reasons": [],
    }

    if not task:
        return result

    reasons = []

    service_customer = (
        _text(erp_customer)
        or _text(service.get("customer"))
    )
    task_customer = _text(task.get("customer"))

    if service_customer:
        if not task_customer:
            reasons.append("task_customer_missing")
        elif task_customer != service_customer:
            reasons.append("task_customer_mismatch")

    service_type = _text(service.get("service_type"))
    task_type = _text(task.get("type"))

    if service_type:
        if not task_type:
            reasons.append("task_type_missing")
        elif task_type != service_type:
            reasons.append("task_type_mismatch")

    task_name = _text(task.get("name"))
    if not task_name:
        reasons.append("task_name_missing")

    if reasons:
        result["review_reasons"] = sorted(set(reasons))
        return result

    from omc_app.api.erp_task_status_sync import (
        historical_customer_status,
    )

    status = historical_customer_status(
        task.get("status"),
        task.get("custom_operation_status"),
    )

    result["erp_task"] = task_name
    result["status"] = status

    if status == "Completed":
        result["closed_on"] = (
            task.get("completed_on")
            or task.get("modified")
            or None
        )
    elif status == "Cancelled":
        result["closed_on"] = (
            task.get("modified")
            or None
        )

    return result


def _historical_evidence(
    service,
    task,
    review_reasons=None,
):
    """Preserve legacy source evidence without deriving financial truth."""

    service_fields = (
        "name",
        "customer",
        "service_type",
        "service_amount",
        "discount",
        "net_service_amount",
        "task_created",
        "task_link",
        "date",
        "creation",
    )

    task_fields = (
        "name",
        "customer",
        "type",
        "status",
        "priority",
        "user_link",
        "exp_end_date",
        "completed_by",
        "completed_on",
        "custom_operation_status",
        "modified",
    )

    return {
        "erp_service": {
            fieldname: service.get(fieldname)
            for fieldname in service_fields
        },
        "erp_task": (
            {
                fieldname: task.get(fieldname)
                for fieldname in task_fields
            }
            if task
            else {}
        ),
        "review_reasons": sorted(
            {
                _text(reason)
                for reason in (review_reasons or [])
                if _text(reason)
            }
        ),
    }


def _service_master_values(task_type):
    """Build inactive legacy catalogue values from one ERP Task Type."""

    task_type_name = _text(task_type.get("name"))
    title = (
        _text(task_type.get("service_name"))
        or task_type_name
    )

    return {
        "doctype": "OMC Service",
        "title": title,
        "description": _text(task_type.get("description")),
        "base_price": flt(task_type.get("rate") or 0, 6),
        "currency": "PKR",
        "erp_task_type": task_type_name,
        "is_active": 0,
    }



def _historical_request_values(
    service,
    mapped_service,
    *,
    profile_name="",
    account_name="",
    task=None,
    erp_customer=None,
    review_reasons=None,
):
    """Build one historical OMC request payload without writing anything."""

    task_result = _task_projection(
        service,
        task,
        erp_customer=erp_customer,
    )

    evidence_reasons = list(review_reasons or [])
    evidence_reasons.extend(
        task_result.get("review_reasons") or []
    )

    task_link = _text(service.get("task_link"))

    if task_link and not task:
        evidence_reasons.append("dangling_task_link")
    elif (
        not task_link
        and int(service.get("task_created") or 0)
    ):
        evidence_reasons.append("task_created_without_link")

    evidence = _historical_evidence(
        service,
        task,
        evidence_reasons,
    )

    return {
        "doctype": "OMC Service Request",
        "service": _text(mapped_service.get("name")),
        "service_title": _text(mapped_service.get("title")),
        "title": _text(mapped_service.get("title")),
        "status": task_result["status"],
        "request_state": "Historical",
        "customer_profile": _text(profile_name),
        "customer_account": _text(account_name),
        "requested_by": "",
        "company_snapshot": "",
        "source_channel": "Imported",
        "submission_mode": "Historical Import",
        "erp_customer": (
            _text(erp_customer)
            or _text(service.get("customer"))
        ),
        "erp_service": _text(service.get("name")),
        "erp_task": task_result["erp_task"],
        "erp_sync_status": "Historical",
        "closed_on": task_result["closed_on"],
        "historical_evidence_json": frappe.as_json(evidence),
    }



def _ensure_service_master(task_type):
    """Create or reuse exactly one inactive OMC Service for a Task Type."""

    task_type_name = _text(task_type.get("name"))
    if not task_type_name:
        return {
            "action": "conflict",
            "service": "",
            "title": "",
            "review_reasons": ["missing_task_type_name"],
            "omc_services": [],
        }

    existing = frappe.get_all(
        "OMC Service",
        filters={"erp_task_type": task_type_name},
        fields=[
            "name",
            "title",
            "erp_task_type",
            "is_active",
        ],
        order_by="name asc",
        limit_page_length=0,
    )

    if len(existing) == 1:
        return {
            "action": "reused",
            "service": _text(existing[0].get("name")),
            "title": _text(existing[0].get("title")),
            "review_reasons": [],
            "omc_services": [
                _text(existing[0].get("name"))
            ],
        }

    if len(existing) > 1:
        names = sorted(
            {
                _text(row.get("name"))
                for row in existing
                if _text(row.get("name"))
            }
        )

        return {
            "action": "conflict",
            "service": "",
            "title": "",
            "review_reasons": [
                "multiple_omc_service_mappings"
            ],
            "omc_services": names,
        }

    values = _service_master_values(task_type)
    doc = frappe.get_doc(values)
    doc.insert(ignore_permissions=True)

    return {
        "action": "created",
        "service": _text(doc.name),
        "title": _text(values.get("title")),
        "review_reasons": [],
        "omc_services": [_text(doc.name)],
    }



def _projection_compatibility_reasons(
    row,
    service,
    mapped_service,
    *,
    task=None,
    erp_customer=None,
):
    """Return fail-closed reasons for reusing one existing projection."""

    expected_customer = (
        _text(erp_customer)
        or _text(service.get("customer"))
    )
    expected_service = _text(mapped_service.get("name"))
    expected_task = _text(
        _task_projection(
            service,
            task,
            erp_customer=expected_customer,
        ).get("erp_task")
    )

    reasons = []

    if _text(row.get("request_state")) != "Historical":
        reasons.append(
            "existing_projection_not_historical"
        )

    if _text(row.get("source_channel")) != "Imported":
        reasons.append(
            "existing_projection_not_imported"
        )

    if _text(row.get("service")) != expected_service:
        reasons.append(
            "existing_projection_service_mismatch"
        )

    if _text(row.get("erp_customer")) != expected_customer:
        reasons.append(
            "existing_projection_customer_mismatch"
        )

    if _text(row.get("erp_task")) != expected_task:
        reasons.append(
            "existing_projection_task_mismatch"
        )

    return sorted(set(reasons))


def _ensure_historical_request(
    service,
    mapped_service,
    *,
    profile_name="",
    account_name="",
    task=None,
    erp_customer=None,
    review_reasons=None,
):
    """Create, safely reuse, or repair one historical ERP Service projection."""

    erp_service = _text(service.get("name"))

    if not erp_service:
        return {
            "action": "conflict",
            "request": "",
            "review_reasons": ["missing_erp_service_name"],
            "omc_requests": [],
        }

    existing = frappe.get_all(
        "OMC Service Request",
        filters={"erp_service": erp_service},
        fields=[
            "name",
            "service",
            "erp_service",
            "erp_customer",
            "erp_task",
            "source_channel",
            "request_state",
            "historical_evidence_json",
        ],
        order_by="name asc",
        limit_page_length=0,
    )

    if len(existing) > 1:
        names = sorted(
            {
                _text(row.get("name"))
                for row in existing
                if _text(row.get("name"))
            }
        )

        return {
            "action": "conflict",
            "request": "",
            "review_reasons": [
                "multiple_omc_projections"
            ],
            "omc_requests": names,
        }

    if len(existing) == 1:
        row = existing[0]
        request_name = _text(row.get("name"))

        expected_customer = (
            _text(erp_customer)
            or _text(service.get("customer"))
        )

        compatibility_reasons = (
            _projection_compatibility_reasons(
                row,
                service,
                mapped_service,
                task=task,
                erp_customer=expected_customer,
            )
        )

        if compatibility_reasons:
            return {
                "action": "conflict",
                "request": "",
                "review_reasons": compatibility_reasons,
                "omc_requests": [request_name],
            }

        expected_values = _historical_request_values(
            service,
            mapped_service,
            profile_name=profile_name,
            account_name=account_name,
            task=task,
            erp_customer=expected_customer,
            review_reasons=review_reasons,
        )

        expected_evidence = _text(
            expected_values.get(
                "historical_evidence_json"
            )
        )
        existing_evidence = _text(
            row.get("historical_evidence_json")
        )

        repaired_fields = []

        if existing_evidence != expected_evidence:
            frappe.db.set_value(
                "OMC Service Request",
                request_name,
                "historical_evidence_json",
                expected_evidence,
                update_modified=False,
            )
            repaired_fields.append(
                "historical_evidence_json"
            )

        return {
            "action": "reused",
            "request": request_name,
            "review_reasons": [],
            "omc_requests": [request_name],
            "changed": bool(repaired_fields),
            "repaired_fields": repaired_fields,
        }

    values = _historical_request_values(
        service,
        mapped_service,
        profile_name=profile_name,
        account_name=account_name,
        task=task,
        erp_customer=erp_customer,
        review_reasons=review_reasons,
    )

    doc = frappe.get_doc(values)
    doc.insert(ignore_permissions=True)

    return {
        "action": "created",
        "request": _text(doc.name),
        "review_reasons": [],
        "omc_requests": [_text(doc.name)],
    }


def _apply_projection():
    """Project historical catalogue and Service history without committing."""

    task_types = _load_task_types()
    services = _load_services()

    task_types_by_name = {
        _text(row.get("name")): row
        for row in task_types
        if _text(row.get("name"))
    }

    tasks = _load_tasks(
        [
            row.get("task_link")
            for row in services
            if _text(row.get("task_link"))
        ]
    )

    customer_names = set(
        frappe.get_all(
            "Customer",
            pluck="name",
            limit_page_length=0,
        )
    )

    profiles_by_customer = defaultdict(list)
    for row in frappe.get_all(
        "OMC Customer Profile",
        fields=[
            "name",
            "linked_erpnext_customer",
        ],
        limit_page_length=0,
    ):
        customer = _text(
            row.get("linked_erpnext_customer")
        )
        if customer:
            profiles_by_customer[customer].append(row)

    accounts_by_customer = defaultdict(list)
    for row in frappe.get_all(
        "OMC Customer Account",
        fields=[
            "name",
            "erp_customer",
            "legacy_customer_profile",
            "identity_proof_status",
            "account_link_status",
            "service_access_status",
        ],
        limit_page_length=0,
    ):
        customer = _text(row.get("erp_customer"))
        if customer:
            accounts_by_customer[customer].append(row)

    result = {
        "task_types": {
            "total": len(task_types),
            "created": 0,
            "reused": 0,
            "conflicts": 0,
        },
        "historical_services": {
            "total": len(services),
            "created": 0,
            "reused": 0,
            "conflicts": 0,
            "skipped": 0,
            "customer_case_normalized": 0,
        },
        "review_reason_counts": Counter(),
        "review_samples": [],
        "changed": False,
    }

    masters_by_task_type = {}

    # Phase 5: Task Type -> inactive OMC Service master.
    for task_type in task_types:
        task_type_name = _text(task_type.get("name"))
        master_result = _ensure_service_master(task_type)
        action = _text(master_result.get("action"))

        if action == "created":
            result["task_types"]["created"] += 1
            result["changed"] = True
        elif action == "reused":
            result["task_types"]["reused"] += 1
        else:
            result["task_types"]["conflicts"] += 1

        masters_by_task_type[task_type_name] = master_result

    # Phases 6-8: ERP Service -> Historical request, safe Task link,
    # and explicit review metadata.
    for service in services:
        reasons = []

        service_name = _text(service.get("name"))
        raw_customer = _text(service.get("customer"))
        service_type = _text(service.get("service_type"))
        task_name = _text(service.get("task_link"))

        customer_resolution = _resolve_customer_name(
            raw_customer,
            customer_names,
        )
        customer = _text(
            customer_resolution.get("customer")
        )

        reasons.extend(
            customer_resolution.get("review_reasons")
            or []
        )

        blocked = not bool(
            customer_resolution.get("valid")
        )

        if customer_resolution.get("normalized"):
            result[
                "historical_services"
            ]["customer_case_normalized"] += 1

        task_type = task_types_by_name.get(service_type)
        if not service_type or not task_type:
            reasons.append("missing_task_type")
            blocked = True

        master_result = masters_by_task_type.get(
            service_type,
            {},
        )

        if task_type and (
            _text(master_result.get("action")) == "conflict"
            or not _text(master_result.get("service"))
        ):
            reasons.extend(
                master_result.get("review_reasons") or [
                    "omc_service_mapping_unavailable"
                ]
            )
            blocked = True

        profile_name = ""
        account_name = ""

        profiles = profiles_by_customer.get(customer, [])

        if len(profiles) == 1:
            profile_name = _text(profiles[0].get("name"))

            account_name = _approved_existing_account_name(
                customer,
                profile_name,
                accounts_by_customer.get(customer, []),
            )
        elif len(profiles) > 1:
            reasons.append("multiple_customer_profiles")

        task = tasks.get(task_name) if task_name else None

        if task_name:
            if task:
                reasons.extend(
                    _task_projection(
                        service,
                        task,
                        erp_customer=customer,
                    ).get("review_reasons") or []
                )
            else:
                reasons.append("dangling_task_link")
        elif int(service.get("task_created") or 0):
            reasons.append("task_created_without_link")

        if blocked:
            result["historical_services"]["skipped"] += 1
        else:
            mapped_service = frappe._dict({
                "name": _text(master_result.get("service")),
                "title": (
                    _text(master_result.get("title"))
                    or _text(task_type.get("service_name"))
                    or service_type
                ),
                "erp_task_type": service_type,
                "is_active": 0,
            })

            request_result = _ensure_historical_request(
                service,
                mapped_service,
                profile_name=profile_name,
                account_name=account_name,
                task=task,
                erp_customer=customer,
                review_reasons=reasons,
            )

            request_action = _text(
                request_result.get("action")
            )

            if request_action == "created":
                result["historical_services"]["created"] += 1
                result["changed"] = True

            elif request_action == "reused":
                result["historical_services"]["reused"] += 1

                if request_result.get("changed"):
                    result["changed"] = True

            else:
                result["historical_services"]["conflicts"] += 1
                result["historical_services"]["skipped"] += 1
                reasons.extend(
                    request_result.get("review_reasons")
                    or ["historical_projection_conflict"]
                )

        unique_reasons = sorted(
            {
                _text(reason)
                for reason in reasons
                if _text(reason)
            }
        )

        for reason in unique_reasons:
            result["review_reason_counts"][reason] += 1

        if unique_reasons and len(
            result["review_samples"]
        ) < 25:
            result["review_samples"].append({
                "erp_service": service_name,
                "customer": raw_customer,
                "canonical_customer": customer,
                "service_type": service_type,
                "task": task_name,
                "reasons": unique_reasons,
            })

    result["review_reason_counts"] = dict(
        sorted(result["review_reason_counts"].items())
    )

    return result


def preflight():
    """Return a strictly read-only historical Service/Task migration plan."""

    services = _load_services()
    task_types = _load_task_types()

    task_type_names = {
        _text(row.get("name"))
        for row in task_types
        if _text(row.get("name"))
    }

    customer_names = set(
        frappe.get_all(
            "Customer",
            pluck="name",
            limit_page_length=0,
        )
    )

    task_links = [
        row.get("task_link")
        for row in services
        if _text(row.get("task_link"))
    ]
    tasks = _load_tasks(task_links)

    profiles_by_customer = defaultdict(list)
    for row in frappe.get_all(
        "OMC Customer Profile",
        fields=["name", "linked_erpnext_customer"],
        limit_page_length=0,
    ):
        customer = _text(row.get("linked_erpnext_customer"))
        if customer:
            profiles_by_customer[customer].append(row.name)

    accounts_by_customer = defaultdict(list)
    for row in frappe.get_all(
        "OMC Customer Account",
        fields=[
            "name",
            "erp_customer",
            "legacy_customer_profile",
            "identity_proof_status",
            "account_link_status",
            "service_access_status",
        ],
        limit_page_length=0,
    ):
        customer = _text(row.get("erp_customer"))
        if customer:
            accounts_by_customer[customer].append(row)

    omc_services = frappe.get_all(
        "OMC Service",
        fields=[
            "name",
            "title",
            "erp_task_type",
            "is_active",
            "company",
        ],
        limit_page_length=0,
    )

    omc_by_task_type = defaultdict(list)
    for row in omc_services:
        task_type = _text(row.get("erp_task_type"))
        if task_type:
            omc_by_task_type[task_type].append(row.name)

    projections_by_service = defaultdict(list)
    for row in frappe.get_all(
        "OMC Service Request",
        filters={"erp_service": ["is", "set"]},
        fields=[
            "name",
            "service",
            "erp_service",
            "erp_customer",
            "erp_task",
            "source_channel",
            "request_state",
        ],
        limit_page_length=0,
    ):
        erp_service = _text(row.get("erp_service"))
        if erp_service:
            projections_by_service[erp_service].append(row)

    result = {
        "read_only": True,
        "task_types": {
            "total": len(task_types),
            "already_mapped": 0,
            "to_create": 0,
            "mapping_conflicts": 0,
            "mapping_conflict_samples": [],
        },
        "historical_services": {
            "total": len(services),
            "valid_customer": 0,
            "missing_customer": 0,
            "customer_case_normalized": 0,
            "valid_task_type": 0,
            "missing_task_type": 0,
            "profile_available": 0,
            "profile_missing": 0,
            "multiple_profiles": 0,
            "account_available": 0,
            "task_link_present": 0,
            "task_link_valid": 0,
            "task_link_missing": 0,
            "task_link_dangling": 0,
            "task_created_without_link": 0,
            "task_customer_mismatch": 0,
            "task_type_mismatch": 0,
            "already_projected": 0,
            "projection_conflicts": 0,
            "safe_projection_candidates": 0,
        },
        "review_reason_counts": Counter(),
        "review_samples": [],
    }

    for task_type in task_types:
        name = _text(task_type.get("name"))
        mapped = omc_by_task_type.get(name, [])

        if len(mapped) == 1:
            result["task_types"]["already_mapped"] += 1
        elif len(mapped) > 1:
            result["task_types"]["mapping_conflicts"] += 1
            if len(
                result["task_types"]["mapping_conflict_samples"]
            ) < 20:
                result["task_types"]["mapping_conflict_samples"].append({
                    "task_type": name,
                    "omc_services": sorted(mapped),
                })
        else:
            result["task_types"]["to_create"] += 1

    for service in services:
        reasons = []

        service_name = _text(service.get("name"))
        raw_customer = _text(service.get("customer"))
        service_type = _text(service.get("service_type"))
        task_name = _text(service.get("task_link"))

        customer_resolution = _resolve_customer_name(
            raw_customer,
            customer_names,
        )
        customer = _text(
            customer_resolution.get("customer")
        )
        customer_valid = bool(
            customer_resolution.get("valid")
        )
        task_type_valid = bool(
            service_type and service_type in task_type_names
        )

        reasons.extend(
            customer_resolution.get("review_reasons")
            or []
        )

        if customer_valid:
            result["historical_services"]["valid_customer"] += 1

            if customer_resolution.get("normalized"):
                result[
                    "historical_services"
                ]["customer_case_normalized"] += 1
        else:
            result["historical_services"]["missing_customer"] += 1

        if task_type_valid:
            result["historical_services"]["valid_task_type"] += 1
        else:
            result["historical_services"]["missing_task_type"] += 1
            reasons.append("missing_task_type")

        profile_count = len(profiles_by_customer.get(customer, []))
        if profile_count == 1:
            result["historical_services"]["profile_available"] += 1
        elif profile_count == 0:
            result["historical_services"]["profile_missing"] += 1
        else:
            result["historical_services"]["multiple_profiles"] += 1
            reasons.append("multiple_customer_profiles")

        if profile_count == 1:
            profile_name = _text(
                profiles_by_customer.get(customer, [])[0]
            )

            account_name = _approved_existing_account_name(
                customer,
                profile_name,
                accounts_by_customer.get(customer, []),
            )

            if account_name:
                result[
                    "historical_services"
                ]["account_available"] += 1

        task = tasks.get(task_name) if task_name else None

        if task_name:
            result["historical_services"]["task_link_present"] += 1

            if task:
                result["historical_services"]["task_link_valid"] += 1

                task_customer = _text(task.get("customer"))
                if (
                    task_customer
                    and customer
                    and task_customer != customer
                ):
                    result[
                        "historical_services"
                    ]["task_customer_mismatch"] += 1
                    reasons.append("task_customer_mismatch")

                task_type = _text(task.get("type"))
                if (
                    task_type
                    and service_type
                    and task_type != service_type
                ):
                    result[
                        "historical_services"
                    ]["task_type_mismatch"] += 1
                    reasons.append("task_type_mismatch")
            else:
                result[
                    "historical_services"
                ]["task_link_dangling"] += 1
                reasons.append("dangling_task_link")
        else:
            result["historical_services"]["task_link_missing"] += 1
            if int(service.get("task_created") or 0):
                result[
                    "historical_services"
                ]["task_created_without_link"] += 1
                reasons.append("task_created_without_link")

        mapped_services = omc_by_task_type.get(
            service_type,
            [],
        )
        service_mapping_conflict = (
            task_type_valid
            and len(mapped_services) > 1
        )

        if service_mapping_conflict:
            reasons.append(
                "multiple_omc_service_mappings"
            )

        existing = projections_by_service.get(
            service_name,
            [],
        )
        projection_compatible = True

        if len(existing) == 1:
            # A reusable existing projection can only be proven when there
            # is exactly one canonical OMC Service mapping for the Task Type.
            if (
                customer_valid
                and task_type_valid
                and len(mapped_services) == 1
            ):
                mapped_service = frappe._dict({
                    "name": mapped_services[0],
                })
                compatibility_reasons = (
                    _projection_compatibility_reasons(
                        existing[0],
                        service,
                        mapped_service,
                        task=task,
                        erp_customer=customer,
                    )
                )

                if compatibility_reasons:
                    projection_compatible = False
                    result[
                        "historical_services"
                    ]["projection_conflicts"] += 1
                    reasons.extend(
                        compatibility_reasons
                    )
                else:
                    result[
                        "historical_services"
                    ]["already_projected"] += 1
            elif (
                customer_valid
                and task_type_valid
                and len(mapped_services) == 0
            ):
                # Apply would create the canonical service master first.
                # An existing request cannot already prove linkage to that
                # not-yet-existing mapping, so fail closed in preflight too.
                projection_compatible = False
                result[
                    "historical_services"
                ]["projection_conflicts"] += 1
                reasons.append(
                    "existing_projection_service_mismatch"
                )
            else:
                projection_compatible = False

        elif len(existing) > 1:
            projection_compatible = False
            result[
                "historical_services"
            ]["projection_conflicts"] += 1
            reasons.append(
                "multiple_omc_projections"
            )

        # Service history itself is safe to project when the authoritative
        # ERP Customer and Task Type are valid, the service-master mapping
        # is unambiguous, and any existing projection is compatible with
        # the exact same reuse rules enforced by apply().
        if (
            customer_valid
            and task_type_valid
            and not service_mapping_conflict
            and projection_compatible
            and len(existing) <= 1
        ):
            result[
                "historical_services"
            ]["safe_projection_candidates"] += 1

        for reason in sorted(set(reasons)):
            result["review_reason_counts"][reason] += 1

        if reasons and len(result["review_samples"]) < 25:
            result["review_samples"].append({
                "erp_service": service_name,
                "customer": raw_customer,
                "canonical_customer": customer,
                "service_type": service_type,
                "task": task_name,
                "reasons": sorted(set(reasons)),
            })

    result["review_reason_counts"] = dict(
        sorted(result["review_reason_counts"].items())
    )

    return result
