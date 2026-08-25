from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import now_datetime

from omc_app.setup.service_catalogue.manifest import (
    ACTIVATION_POLICY,
    AUTHORITATIVE_COMPANY,
    CATEGORIES,
    CURRENCY,
    MANIFEST_VERSION,
    SERVICES,
    category_by_name,
    validate_manifest,
)
from omc_app.setup.service_catalogue.requirements import (
    DOCUMENTS_BY_SERVICE,
    FORM_FIELDS_BY_SERVICE,
    validate_requirements,
)


TERMINAL_REQUEST_STATUSES = {
    "Completed",
    "Cancelled",
    "Historical",
}

NUMERIC_FIELDS = {
    "base_price",
    "service_version",
    "tax_rate",
    "pending_payment_expiry_hours",
    "duplicate_window_hours",
    "allow_parallel_requests",
    "sort_order",
    "is_active",
    "is_required",
    "max_size_mb",
}

PROTECTED_REQUIRED_DOCUMENT_FIELDS = {
    "document_title",
    "document_type",
    "is_required",
    "is_active",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _normalized_document_value(value: Any) -> str:
    return " ".join(_text(value).lower().split())


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same_value(fieldname: str, current: Any, desired: Any) -> bool:
    if fieldname in NUMERIC_FIELDS:
        return _number(current) == _number(desired)

    return _text(current) == _text(desired)


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}

    for fieldname, desired_value in desired.items():
        current_value = current.get(fieldname)

        if _same_value(
            fieldname,
            current_value,
            desired_value,
        ):
            continue

        result[fieldname] = {
            "current": current_value,
            "desired": desired_value,
        }

    return result


def _fee_label(amount: float) -> str:
    value = float(amount or 0)

    if value <= 0:
        return "Contact OMC for pricing"

    if value.is_integer():
        value = int(value)

    return f"{CURRENCY} {value}"


def _desired_category_values(spec) -> dict[str, Any]:
    return {
        "category_name": spec.category_name,
        "title": spec.title,
        "description": spec.description,
        "icon": spec.icon,
        "sort_order": spec.sort_order,
        "is_active": 1,
    }


def _desired_service_values(
    spec,
    current: dict[str, Any] | None = None,
) -> dict[str, Any]:
    current = current or {}
    categories = category_by_name()
    category = categories[spec.category]

    current_service_version = int(
        _number(current.get("service_version"))
        or 1
    )
    current_service_version = max(
        current_service_version,
        1,
    )

    current_tax_policy = (
        _text(current.get("tax_policy"))
        or "No Tax"
    )
    current_tax_rate = _number(
        current.get("tax_rate")
    )

    pending_expiry = int(
        _number(
            current.get(
                "pending_payment_expiry_hours"
            )
        )
        or 72
    )
    duplicate_window = int(
        _number(
            current.get(
                "duplicate_window_hours"
            )
        )
        or 24
    )

    current_parallel = current.get(
        "allow_parallel_requests"
    )
    if current_parallel is None:
        current_parallel = 0

    return {
        "service_id": spec.service_id,
        "title": spec.title,
        "category": spec.category,
        "icon": spec.icon or category.icon,
        "color_family": category.accent_color,
        "base_price": spec.base_price,
        "currency": CURRENCY,
        "company": AUTHORITATIVE_COMPANY,
        "service_version": current_service_version,
        # Existing tax authority is deliberately preserved.
        "tax_policy": current_tax_policy,
        "tax_rate": current_tax_rate,
        "activation_policy": ACTIVATION_POLICY,
        "pending_payment_expiry_hours": (
            pending_expiry
        ),
        "duplicate_window_hours": duplicate_window,
        "fee_label": _fee_label(spec.base_price),
        # No government fee is asserted unless source data
        # explicitly establishes one.
        "government_fee_label": "",
        "estimated_duration": spec.completion_time,
        "completion_time": spec.completion_time,
        # Existing parallel-request policy is authority.
        "allow_parallel_requests": int(
            _number(current_parallel)
        ),
        "sort_order": spec.sort_order,
        "is_active": int(spec.is_active),
        "erp_task_type": spec.erp_task_type,
    }


def _desired_document_values(
    spec,
    *,
    sort_order: int,
) -> dict[str, Any]:
    return {
        "document_key": spec.document_key,
        "document_title": spec.title,
        "document_type": spec.document_type,
        "is_required": int(spec.is_required),
        "instructions": spec.instructions,
        "allowed_extensions": spec.allowed_extensions,
        "max_size_mb": spec.max_size_mb,
        "sort_order": sort_order,
        "is_active": 1,
    }


def _desired_form_field_values(
    spec,
    *,
    sort_order: int,
) -> dict[str, Any]:
    return {
        "fieldname": spec.fieldname,
        "label": spec.label,
        "fieldtype": spec.fieldtype,
        "options": spec.options,
        "placeholder": spec.placeholder,
        "description": spec.description,
        "is_required": int(spec.is_required),
        "default_value": spec.default_value,
        # The current Flutter renderer does not enforce
        # depends_on, so the catalogue does not provision it.
        "depends_on": "",
        "sort_order": sort_order,
        "is_active": 1,
        "catalogue_managed": 1,
    }


def _service_rows() -> dict[str, dict[str, Any]]:
    rows = frappe.get_all(
        "OMC Service",
        fields=[
            "name",
            "service_id",
            "title",
            "category",
            "icon",
            "color_family",
            "base_price",
            "currency",
            "company",
            "service_version",
            "pricing_version",
            "tax_policy",
            "tax_rate",
            "activation_policy",
            "pending_payment_expiry_hours",
            "duplicate_window_hours",
            "fee_label",
            "government_fee_label",
            "estimated_duration",
            "completion_time",
            "allow_parallel_requests",
            "sort_order",
            "is_active",
            "erp_task_type",
            "default_assignee",
            "default_assignment_role",
        ],
        limit_page_length=1000,
    )

    return {
        _text(row.service_id): dict(row)
        for row in rows
        if _text(row.service_id)
    }


def _category_rows() -> dict[str, dict[str, Any]]:
    rows = frappe.get_all(
        "OMC Service Category",
        fields=[
            "name",
            "category_name",
            "title",
            "description",
            "icon",
            "sort_order",
            "is_active",
        ],
        limit_page_length=1000,
    )

    return {
        _text(row.category_name): dict(row)
        for row in rows
        if _text(row.category_name)
    }


def _has_in_flight_requests(
    service_name: str,
) -> bool:
    rows = frappe.get_all(
        "OMC Service Request",
        filters={"service": service_name},
        fields=["status"],
        limit_page_length=10000,
    )

    return any(
        _text(row.status)
        not in TERMINAL_REQUEST_STATUSES
        for row in rows
    )


def _document_rows(
    service_name: str,
    *,
    key_column_ready: bool,
) -> list[dict[str, Any]]:
    fields = [
        "name",
        "document_title",
        "document_type",
        "is_required",
        "instructions",
        "allowed_extensions",
        "max_size_mb",
        "sort_order",
        "is_active",
    ]

    if key_column_ready:
        fields.insert(1, "document_key")

    return [
        dict(row)
        for row in frappe.get_all(
            "OMC Service Required Document",
            filters={"service": service_name},
            fields=fields,
            order_by="sort_order asc, creation asc",
            limit_page_length=1000,
        )
    ]


def _form_field_rows(
    service_name: str,
) -> list[dict[str, Any]]:
    fields = [
        "name",
        "fieldname",
        "label",
        "fieldtype",
        "options",
        "placeholder",
        "description",
        "is_required",
        "default_value",
        "depends_on",
        "sort_order",
        "is_active",
    ]

    if frappe.db.has_column(
        "OMC Service Form Field",
        "catalogue_managed",
    ):
        fields.append(
            "catalogue_managed"
        )

    return [
        dict(row)
        for row in frappe.get_all(
            "OMC Service Form Field",
            filters={"service": service_name},
            fields=fields,
            order_by="sort_order asc, creation asc",
            limit_page_length=1000,
        )
    ]


def _form_field_is_catalogue_managed(
    row: dict[str, Any],
) -> bool:
    return bool(
        int(
            _number(
                row.get("catalogue_managed")
            )
        )
    )


def _legacy_document_identity(
    row: dict[str, Any],
) -> tuple[str, str]:
    return (
        _normalized_document_value(
            row.get("document_title")
        ),
        _normalized_document_value(
            row.get("document_type")
        ),
    )


def _find_document_matches(
    rows: list[dict[str, Any]],
    desired: dict[str, Any],
    *,
    key_column_ready: bool,
    used_names: set[str],
) -> list[dict[str, Any]]:
    available = [
        row
        for row in rows
        if _text(row.get("name")) not in used_names
    ]

    desired_key = _normalized_document_value(
        desired.get("document_key")
    )

    if key_column_ready and desired_key:
        keyed = [
            row
            for row in available
            if (
                _normalized_document_value(
                    row.get("document_key")
                )
                == desired_key
            )
        ]

        if keyed:
            return keyed

        # Migration rollout compatibility: a legacy row may
        # still be unkeyed. Match it once by exact normalized
        # title + type and later backfill its stable key.
        available = [
            row
            for row in available
            if not _text(row.get("document_key"))
        ]

    desired_identity = _legacy_document_identity(
        desired
    )

    return [
        row
        for row in available
        if _legacy_document_identity(row)
        == desired_identity
    ]


def _new_bucket() -> dict[str, Any]:
    return {
        "create": [],
        "update": [],
        "deactivate": [],
        "unchanged": [],
        "conflict": [],
        "ignored_unmanaged": [],
    }


def _record_update(
    bucket: dict[str, Any],
    identity: str,
    changes: dict[str, Any],
) -> None:
    bucket["update"].append(
        {
            "id": identity,
            "changes": changes,
        }
    )


def _preview_categories(
    existing: dict[str, dict[str, Any]],
    conflicts: list[dict[str, Any]],
) -> dict[str, Any]:
    bucket = _new_bucket()

    for spec in CATEGORIES:
        identity = spec.category_name
        desired = _desired_category_values(spec)
        current = existing.get(identity)

        if current is None:
            name_collision = frappe.db.exists(
                "OMC Service Category",
                identity,
            )

            if name_collision:
                conflict = {
                    "type": "category_name_collision",
                    "category": identity,
                    "existing_name": name_collision,
                }
                bucket["conflict"].append(identity)
                conflicts.append(conflict)
                continue

            bucket["create"].append(identity)
            continue

        changes = _changes(current, desired)

        if changes:
            _record_update(
                bucket,
                identity,
                changes,
            )
        else:
            bucket["unchanged"].append(identity)

    return bucket


def _preview_services(
    existing: dict[str, dict[str, Any]],
    conflicts: list[dict[str, Any]],
) -> dict[str, Any]:
    bucket = _new_bucket()

    for spec in SERVICES:
        identity = spec.service_id
        current = existing.get(identity)

        if current is None:
            name_collision = frappe.db.exists(
                "OMC Service",
                identity,
            )

            if name_collision:
                conflict = {
                    "type": "service_name_collision",
                    "service": identity,
                    "existing_name": name_collision,
                }
                bucket["conflict"].append(identity)
                conflicts.append(conflict)
                continue

            bucket["create"].append(identity)
            continue

        desired = _desired_service_values(
            spec,
            current,
        )
        changes = _changes(current, desired)

        if changes:
            _record_update(
                bucket,
                identity,
                changes,
            )
        else:
            bucket["unchanged"].append(identity)

    return bucket


def _preview_documents_for_service(
    service_id: str,
    service_name: str | None,
    *,
    key_column_ready: bool,
    effective_from_ready: bool,
    has_in_flight: bool,
    conflicts: list[dict[str, Any]],
) -> dict[str, Any]:
    bucket = _new_bucket()
    bucket["key_backfill_pending"] = []

    desired_specs = DOCUMENTS_BY_SERVICE[
        service_id
    ]

    if not service_name:
        bucket["create"] = [
            f"{service_id}:{spec.document_key}"
            for spec in desired_specs
        ]
        return bucket

    rows = _document_rows(
        service_name,
        key_column_ready=key_column_ready,
    )
    used_names: set[str] = set()

    for index, spec in enumerate(
        desired_specs,
        start=1,
    ):
        identity = (
            f"{service_id}:{spec.document_key}"
        )
        desired = _desired_document_values(
            spec,
            sort_order=index,
        )

        matches = _find_document_matches(
            rows,
            desired,
            key_column_ready=key_column_ready,
            used_names=used_names,
        )

        if len(matches) > 1:
            conflict = {
                "type": "ambiguous_document_template",
                "service": service_id,
                "document_key": spec.document_key,
                "matches": [
                    row.get("name")
                    for row in matches
                ],
            }
            bucket["conflict"].append(identity)
            conflicts.append(conflict)
            continue

        if not matches:
            if (
                spec.is_required
                and has_in_flight
                and not effective_from_ready
            ):
                conflict = {
                    "type": (
                        "required_document_create_"
                        "blocked_in_flight"
                    ),
                    "service": service_id,
                    "document_key": spec.document_key,
                }
                bucket["conflict"].append(identity)
                conflicts.append(conflict)
                continue

            bucket["create"].append(identity)
            continue

        current = matches[0]
        used_names.add(
            _text(current.get("name"))
        )

        compare_desired = dict(desired)

        if not key_column_ready:
            compare_desired.pop(
                "document_key",
                None,
            )
            bucket[
                "key_backfill_pending"
            ].append(identity)
        elif not _text(
            current.get("document_key")
        ):
            # Safe identity-only migration of a matching
            # legacy row.
            pass

        changes = _changes(
            current,
            compare_desired,
        )

        if (
            has_in_flight
            and any(
                fieldname
                in PROTECTED_REQUIRED_DOCUMENT_FIELDS
                for fieldname in changes
            )
        ):
            conflict = {
                "type": (
                    "required_document_change_"
                    "blocked_in_flight"
                ),
                "service": service_id,
                "document_key": spec.document_key,
                "changes": changes,
            }
            bucket["conflict"].append(identity)
            conflicts.append(conflict)
            continue

        if changes:
            _record_update(
                bucket,
                identity,
                changes,
            )
        else:
            bucket["unchanged"].append(identity)

    # Only stable-key rows can be conclusively identified as
    # stale managed templates. Unknown active legacy rows fail
    # closed rather than being silently deactivated.
    for row in rows:
        row_name = _text(row.get("name"))
        if row_name in used_names:
            continue

        if not int(_number(row.get("is_active"))):
            continue

        row_key = (
            _text(row.get("document_key"))
            if key_column_ready
            else ""
        )

        if not row_key:
            conflict = {
                "type": "unmanaged_legacy_document",
                "service": service_id,
                "row": row_name,
                "title": row.get(
                    "document_title"
                ),
                "document_type": row.get(
                    "document_type"
                ),
            }
            bucket["conflict"].append(
                f"{service_id}:{row_name}"
            )
            conflicts.append(conflict)
            continue

        if (
            has_in_flight
            and int(
                _number(row.get("is_required"))
            )
        ):
            conflict = {
                "type": (
                    "required_document_deactivate_"
                    "blocked_in_flight"
                ),
                "service": service_id,
                "document_key": row_key,
                "row": row_name,
            }
            bucket["conflict"].append(
                f"{service_id}:{row_key}"
            )
            conflicts.append(conflict)
            continue

        bucket["deactivate"].append(
            f"{service_id}:{row_key}"
        )

    return bucket


def _preview_form_fields_for_service(
    service_id: str,
    service_name: str | None,
    *,
    conflicts: list[dict[str, Any]],
) -> dict[str, Any]:
    bucket = _new_bucket()

    desired_specs = FORM_FIELDS_BY_SERVICE[
        service_id
    ]

    if not service_name:
        bucket["create"] = [
            f"{service_id}:{spec.fieldname}"
            for spec in desired_specs
        ]
        return bucket

    rows = _form_field_rows(service_name)
    by_fieldname: dict[
        str,
        list[dict[str, Any]],
    ] = {}

    for row in rows:
        fieldname = _text(
            row.get("fieldname")
        )
        by_fieldname.setdefault(
            fieldname,
            [],
        ).append(row)

    desired_fieldnames: set[str] = set()

    for index, spec in enumerate(
        desired_specs,
        start=1,
    ):
        desired_fieldnames.add(
            spec.fieldname
        )

        identity = (
            f"{service_id}:{spec.fieldname}"
        )

        matches = by_fieldname.get(
            spec.fieldname,
            [],
        )

        if len(matches) > 1:
            conflict = {
                "type": "ambiguous_form_field",
                "service": service_id,
                "fieldname": spec.fieldname,
                "matches": [
                    row.get("name")
                    for row in matches
                ],
            }
            bucket["conflict"].append(
                identity
            )
            conflicts.append(
                conflict
            )
            continue

        if not matches:
            bucket["create"].append(
                identity
            )
            continue

        current = matches[0]

        desired = (
            _desired_form_field_values(
                spec,
                sort_order=index,
            )
        )

        changes = _changes(
            current,
            desired,
        )

        if changes:
            _record_update(
                bucket,
                identity,
                changes,
            )
        else:
            bucket["unchanged"].append(
                identity
            )

    for row in rows:
        if not int(
            _number(
                row.get("is_active")
            )
        ):
            continue

        fieldname = _text(
            row.get("fieldname")
        )

        if fieldname in desired_fieldnames:
            continue

        if not _form_field_is_catalogue_managed(
            row
        ):
            bucket[
                "ignored_unmanaged"
            ].append(
                f"{service_id}:{fieldname}"
            )
            continue

        bucket["deactivate"].append(
            f"{service_id}:{fieldname}"
        )

    return bucket


def _merge_buckets(
    destination: dict[str, Any],
    source: dict[str, Any],
) -> None:
    for action in (
        "create",
        "update",
        "deactivate",
        "unchanged",
        "conflict",
        "ignored_unmanaged",
    ):
        destination[action].extend(
            source.get(
                action,
                [],
            )
        )

    destination.setdefault(
        "key_backfill_pending",
        [],
    )
    destination[
        "key_backfill_pending"
    ].extend(
        source.get(
            "key_backfill_pending",
            [],
        )
    )


def _bucket_counts(
    bucket: dict[str, Any],
) -> dict[str, int]:
    return {
        action: len(
            bucket.get(
                action,
                [],
            )
        )
        for action in (
            "create",
            "update",
            "deactivate",
            "unchanged",
            "conflict",
            "key_backfill_pending",
            "ignored_unmanaged",
        )
    }




PRICE_CHANGE_TERMINAL_STATUSES = {
    "Completed",
    "Cancelled",
    "Historical",
}


def _request_is_historical_projection(
    row: dict[str, Any],
) -> bool:
    """Recognize only canonical imported historical ERP projections.

    Historical migration deliberately preserves ERP history without deriving
    new financial truth. Such rows are never part of the customer payment
    lifecycle and therefore do not require pricing snapshot backfill before
    catalogue master prices change.
    """
    return bool(
        _text(
            row.get("request_state")
        )
        == "Historical"
        and _text(
            row.get("source_channel")
        )
        == "Imported"
        and _text(
            row.get("submission_mode")
        )
        == "Historical Import"
        and _text(
            row.get("erp_sync_status")
        )
        == "Historical"
    )


def _request_pricing_snapshot_is_safe(
    row: dict[str, Any],
    *,
    has_active_payment: bool = False,
) -> bool:
    """Return whether an old request is insulated from service price changes."""
    if has_active_payment:
        return True

    policy = _text(
        row.get("payment_policy_snapshot")
    )

    payable_amount = _number(
        row.get("payable_amount")
    )
    final_price = _number(
        row.get("final_price")
    )

    if policy == "No Charge":
        return (
            payable_amount == 0
            and final_price == 0
        )

    snapshot_identity_ready = bool(
        _text(
            row.get(
                "pricing_version_snapshot"
            )
        )
        and _text(
            row.get(
                "pricing_currency"
            )
        )
        and int(
            _number(
                row.get(
                    "service_version_snapshot"
                )
            )
        )
        > 0
    )

    if not snapshot_identity_ready:
        return False

    original_price = _number(
        row.get("original_price")
    )
    proposed_final_price = _number(
        row.get("proposed_final_price")
    )
    discount_status = _text(
        row.get("discount_status")
    )

    if discount_status == "Pending Approval":
        return (
            original_price > 0
            and proposed_final_price >= 0
        )

    return bool(
        payable_amount > 0
        or final_price > 0
        or original_price > 0
    )


def _price_change_snapshot_blocker(
    service_actions: dict[str, Any],
    existing_services: dict[
        str,
        dict[str, Any],
    ],
) -> dict[str, Any] | None:
    """Fail closed when a price change can affect an unsnapshotted request."""
    price_updates = []

    for action in service_actions.get(
        "update",
        [],
    ):
        changes = action.get(
            "changes",
            {},
        )

        if "base_price" not in changes:
            continue

        price_updates.append(
            {
                "service_id": (
                    action.get("id")
                    or ""
                ),
                "price_change": (
                    changes["base_price"]
                ),
            }
        )

    if not price_updates:
        return None

    request_meta = frappe.get_meta(
        "OMC Service Request"
    )

    fields = [
        "name",
        "service",
        "status",
        "creation",
    ]

    optional_fields = [
        "request_state",
        "source_channel",
        "submission_mode",
        "erp_sync_status",
        "original_price",
        "proposed_final_price",
        "final_price",
        "payable_amount",
        "pricing_currency",
        "pricing_version_snapshot",
        "service_version_snapshot",
        "payment_policy_snapshot",
        "discount_status",
    ]

    for fieldname in optional_fields:
        if request_meta.has_field(
            fieldname
        ):
            fields.append(
                fieldname
            )

    payment_doctype_exists = bool(
        frappe.db.exists(
            "DocType",
            "OMC Service Payment",
        )
    )

    unsafe = []

    for price_update in price_updates:
        service_id = price_update[
            "service_id"
        ]

        current = (
            existing_services.get(
                service_id
            )
            or {}
        )

        service_name = (
            current.get("name")
            or service_id
        )

        rows = frappe.get_all(
            "OMC Service Request",
            filters={
                "service": service_name,
            },
            fields=fields,
            order_by="creation asc",
            limit_page_length=10000,
        )

        for raw_row in rows:
            row = dict(raw_row)

            status = _text(
                row.get("status")
            )

            if (
                status
                in PRICE_CHANGE_TERMINAL_STATUSES
            ):
                continue

            if _request_is_historical_projection(
                row
            ):
                continue

            has_active_payment = False

            if payment_doctype_exists:
                has_active_payment = bool(
                    frappe.db.exists(
                        "OMC Service Payment",
                        {
                            "service_request": (
                                row.get("name")
                            ),
                            "status": [
                                "!=",
                                "Cancelled",
                            ],
                        },
                    )
                )

            if _request_pricing_snapshot_is_safe(
                row,
                has_active_payment=(
                    has_active_payment
                ),
            ):
                continue

            unsafe.append(
                {
                    "request": (
                        row.get("name")
                        or ""
                    ),
                    "service_id": service_id,
                    "status": status,
                    "creation": str(
                        row.get(
                            "creation"
                        )
                        or ""
                    ),
                    "price_change": (
                        price_update[
                            "price_change"
                        ]
                    ),
                    "original_price": (
                        row.get(
                            "original_price"
                        )
                        or 0
                    ),
                    "final_price": (
                        row.get(
                            "final_price"
                        )
                        or 0
                    ),
                    "payable_amount": (
                        row.get(
                            "payable_amount"
                        )
                        or 0
                    ),
                    "pricing_currency": (
                        row.get(
                            "pricing_currency"
                        )
                        or ""
                    ),
                    "pricing_version_snapshot": (
                        row.get(
                            "pricing_version_snapshot"
                        )
                        or ""
                    ),
                    "service_version_snapshot": (
                        row.get(
                            "service_version_snapshot"
                        )
                        or 0
                    ),
                    "has_active_payment": (
                        has_active_payment
                    ),
                }
            )

    if not unsafe:
        return None

    return {
        "type": (
            "in_flight_price_snapshot_missing"
        ),
        "message": (
            "Service price changes are blocked because "
            "non-terminal requests do not have an "
            "authoritative frozen pricing snapshot."
        ),
        "count": len(
            unsafe
        ),
        "requests": unsafe,
    }


def preview_service_catalogue() -> dict[str, Any]:
    """Read-only preview of the source-controlled service catalogue.

    No inserts, updates, deletes, commits, migrations, Task Type creation,
    or ERP master-data mutation occur here.
    """
    validate_manifest()
    validate_requirements()

    blockers: list[dict[str, Any]] = []
    conflicts: list[dict[str, Any]] = []

    company_exists = bool(
        frappe.db.exists(
            "Company",
            AUTHORITATIVE_COMPANY,
        )
    )

    if not company_exists:
        blockers.append(
            {
                "type": "missing_company",
                "company": AUTHORITATIVE_COMPANY,
            }
        )

    missing_task_types = [
        spec.erp_task_type
        for spec in SERVICES
        if not frappe.db.exists(
            "Task Type",
            spec.erp_task_type,
        )
    ]

    if missing_task_types:
        blockers.append(
            {
                "type": "missing_task_types",
                "task_types": missing_task_types,
            }
        )

    required_document_key_ready = (
        frappe.db.has_column(
            "OMC Service Required Document",
            "document_key",
        )
    )
    service_document_key_ready = (
        frappe.db.has_column(
            "OMC Service Document",
            "document_key",
        )
    )
    required_document_effective_from_ready = (
        frappe.db.has_column(
            "OMC Service Required Document",
            "effective_from",
        )
    )
    form_field_catalogue_managed_ready = (
        frappe.db.has_column(
            "OMC Service Form Field",
            "catalogue_managed",
        )
    )

    missing_schema_columns = []

    if not required_document_key_ready:
        missing_schema_columns.append(
            "OMC Service Required Document.document_key"
        )

    if not service_document_key_ready:
        missing_schema_columns.append(
            "OMC Service Document.document_key"
        )

    if not required_document_effective_from_ready:
        missing_schema_columns.append(
            "OMC Service Required Document.effective_from"
        )

    if not form_field_catalogue_managed_ready:
        missing_schema_columns.append(
            "OMC Service Form Field.catalogue_managed"
        )

    if missing_schema_columns:
        blockers.append(
            {
                "type": "schema_migration_required",
                "missing_columns": (
                    missing_schema_columns
                ),
            }
        )

    existing_categories = _category_rows()
    existing_services = _service_rows()

    category_actions = _preview_categories(
        existing_categories,
        conflicts,
    )
    service_actions = _preview_services(
        existing_services,
        conflicts,
    )

    price_snapshot_blocker = (
        _price_change_snapshot_blocker(
            service_actions,
            existing_services,
        )
    )

    if price_snapshot_blocker:
        blockers.append(
            price_snapshot_blocker
        )

    document_actions = _new_bucket()
    document_actions[
        "key_backfill_pending"
    ] = []

    form_actions = _new_bucket()

    for spec in SERVICES:
        current = existing_services.get(
            spec.service_id
        )
        service_name = (
            _text(current.get("name"))
            if current
            else None
        )

        has_in_flight = (
            _has_in_flight_requests(
                service_name
            )
            if service_name
            else False
        )

        service_document_preview = (
            _preview_documents_for_service(
                spec.service_id,
                service_name,
                key_column_ready=(
                    required_document_key_ready
                ),
                effective_from_ready=(
                    required_document_effective_from_ready
                ),
                has_in_flight=has_in_flight,
                conflicts=conflicts,
            )
        )

        _merge_buckets(
            document_actions,
            service_document_preview,
        )

        service_form_preview = (
            _preview_form_fields_for_service(
                spec.service_id,
                service_name,
                conflicts=conflicts,
            )
        )

        _merge_buckets(
            form_actions,
            service_form_preview,
        )

    category_counts = _bucket_counts(
        category_actions
    )
    service_counts = _bucket_counts(
        service_actions
    )
    document_counts = _bucket_counts(
        document_actions
    )
    form_counts = _bucket_counts(
        form_actions
    )

    created = (
        category_counts["create"]
        + service_counts["create"]
        + document_counts["create"]
        + form_counts["create"]
    )
    updated = (
        category_counts["update"]
        + service_counts["update"]
        + document_counts["update"]
        + form_counts["update"]
    )
    deactivated = (
        category_counts["deactivate"]
        + service_counts["deactivate"]
        + document_counts["deactivate"]
        + form_counts["deactivate"]
    )
    unchanged = (
        category_counts["unchanged"]
        + service_counts["unchanged"]
        + document_counts["unchanged"]
        + form_counts["unchanged"]
    )

    ready_to_sync = (
        not blockers
        and not conflicts
    )

    return {
        "ok": True,
        "read_only": True,
        "operation": (
            "preview_service_catalogue"
        ),
        "manifest_version": MANIFEST_VERSION,
        "ready_to_sync": ready_to_sync,
        "preconditions": {
            "company": {
                "name": AUTHORITATIVE_COMPANY,
                "exists": company_exists,
            },
            "task_types": {
                "expected": len(SERVICES),
                "found": (
                    len(SERVICES)
                    - len(missing_task_types)
                ),
                "missing": missing_task_types,
            },
            "schema": {
                "ready": not missing_schema_columns,
                "missing_columns": (
                    missing_schema_columns
                ),
            },
        },
        "summary": {
            "categories": category_counts,
            "services": service_counts,
            "required_documents": (
                document_counts
            ),
            "form_fields": form_counts,
            "totals": {
                "created": created,
                "updated": updated,
                "deactivated": deactivated,
                "unchanged": unchanged,
                "conflicts": len(conflicts),
                "blockers": len(blockers),
                "key_backfill_pending": (
                    document_counts[
                        "key_backfill_pending"
                    ]
                ),
            },
        },
        "actions": {
            "categories": category_actions,
            "services": service_actions,
            "required_documents": (
                document_actions
            ),
            "form_fields": form_actions,
        },
        "blockers": blockers,
        "conflicts": conflicts,
        "ownership": {
            "creates_task_types": False,
            "owns_default_assignee": False,
            "owns_default_assignment_role": False,
            "owns_pricing_version": False,
            "preserves_existing_tax_policy": True,
            "preserves_existing_tax_rate": True,
            "preserves_existing_service_version": True,
            "preserves_existing_parallel_policy": True,
            "grandfathers_new_requirements_by_effective_from": True,
            "preserves_unmanaged_form_fields": True,
            "stale_keyed_documents": (
                "deactivate_not_delete"
            ),
            "unknown_legacy_documents": (
                "conflict_not_delete"
            ),
        },
    }


# ==================================================================
# MUTATING RECONCILIATION
# ==================================================================


def _empty_write_counts() -> dict[str, int]:
    return {
        "created": 0,
        "updated": 0,
        "deactivated": 0,
        "unchanged": 0,
    }


def _set_doc_values(
    doc,
    values: dict[str, Any],
) -> None:
    for fieldname, value in values.items():
        setattr(doc, fieldname, value)


def _insert_required_document(
    service_name: str,
    desired: dict[str, Any],
    effective_from,
):
    doc = frappe.new_doc(
        "OMC Service Required Document"
    )
    doc.service = service_name

    _set_doc_values(
        doc,
        desired,
    )

    # All requirements created by one catalogue sync share one
    # effective boundary. Existing legacy templates remain NULL.
    doc.effective_from = effective_from

    doc.insert(
        ignore_permissions=True,
    )
    return doc


def _sync_categories() -> dict[str, int]:
    counts = _empty_write_counts()
    existing = _category_rows()

    for spec in CATEGORIES:
        desired = _desired_category_values(spec)
        current = existing.get(
            spec.category_name
        )

        if current is None:
            doc = frappe.new_doc(
                "OMC Service Category"
            )
            _set_doc_values(
                doc,
                desired,
            )
            doc.insert(
                ignore_permissions=True,
            )
            counts["created"] += 1
            continue

        changes = _changes(
            current,
            desired,
        )

        if not changes:
            counts["unchanged"] += 1
            continue

        doc = frappe.get_doc(
            "OMC Service Category",
            current["name"],
        )
        _set_doc_values(
            doc,
            desired,
        )
        doc.save(
            ignore_permissions=True,
        )
        counts["updated"] += 1

    return counts


def _sync_services() -> dict[str, int]:
    counts = _empty_write_counts()
    existing = _service_rows()

    for spec in SERVICES:
        current = existing.get(
            spec.service_id
        )

        desired = _desired_service_values(
            spec,
            current or {},
        )

        if current is None:
            doc = frappe.new_doc(
                "OMC Service"
            )
            _set_doc_values(
                doc,
                desired,
            )
            doc.insert(
                ignore_permissions=True,
            )
            counts["created"] += 1
            continue

        changes = _changes(
            current,
            desired,
        )

        if not changes:
            counts["unchanged"] += 1
            continue

        doc = frappe.get_doc(
            "OMC Service",
            current["name"],
        )

        # pricing_version is deliberately not supplied here.
        # OMC Service.before_save regenerates it from the
        # authoritative pricing fields.
        _set_doc_values(
            doc,
            desired,
        )

        doc.save(
            ignore_permissions=True,
        )
        counts["updated"] += 1

    return counts


def _sync_required_documents(
    effective_from,
) -> dict[str, int]:
    counts = _empty_write_counts()

    services = _service_rows()

    for service_spec in SERVICES:
        service_row = services.get(
            service_spec.service_id
        )

        if not service_row:
            frappe.throw(
                (
                    "Catalogue reconciliation could not resolve "
                    f"service {service_spec.service_id}."
                ),
                frappe.ValidationError,
            )

        service_name = _text(
            service_row.get("name")
        )

        rows = _document_rows(
            service_name,
            key_column_ready=True,
        )

        used_names: set[str] = set()
        has_in_flight = (
            _has_in_flight_requests(
                service_name
            )
        )

        desired_specs = (
            DOCUMENTS_BY_SERVICE[
                service_spec.service_id
            ]
        )

        for index, document_spec in enumerate(
            desired_specs,
            start=1,
        ):
            desired = (
                _desired_document_values(
                    document_spec,
                    sort_order=index,
                )
            )

            matches = _find_document_matches(
                rows,
                desired,
                key_column_ready=True,
                used_names=used_names,
            )

            if len(matches) > 1:
                frappe.throw(
                    (
                        "Ambiguous required-document template "
                        f"for {service_spec.service_id}:"
                        f"{document_spec.document_key}"
                    ),
                    frappe.ValidationError,
                )

            if not matches:
                _insert_required_document(
                    service_name,
                    desired,
                    effective_from,
                )
                counts["created"] += 1
                continue

            current = matches[0]
            current_name = _text(
                current.get("name")
            )
            used_names.add(
                current_name
            )

            changes = _changes(
                current,
                desired,
            )

            if not changes:
                counts["unchanged"] += 1
                continue

            if (
                has_in_flight
                and any(
                    fieldname
                    in PROTECTED_REQUIRED_DOCUMENT_FIELDS
                    for fieldname in changes
                )
            ):
                frappe.throw(
                    (
                        "Unsafe required-document change is "
                        "blocked while service requests are "
                        "in flight: "
                        f"{service_spec.service_id}:"
                        f"{document_spec.document_key}"
                    ),
                    frappe.ValidationError,
                )

            doc = frappe.get_doc(
                "OMC Service Required Document",
                current_name,
            )

            # effective_from is intentionally NOT overwritten.
            # Existing legacy requirements continue to apply
            # universally, while previously provisioned rows
            # retain their original effective boundary.
            _set_doc_values(
                doc,
                desired,
            )

            doc.save(
                ignore_permissions=True,
            )
            counts["updated"] += 1

        # Deactivate stale source-controlled keyed requirements.
        # Never hard-delete them.
        for row in rows:
            row_name = _text(
                row.get("name")
            )

            if row_name in used_names:
                continue

            if not int(
                _number(
                    row.get("is_active")
                )
            ):
                continue

            row_key = _text(
                row.get("document_key")
            )

            if not row_key:
                frappe.throw(
                    (
                        "Unmanaged active legacy document "
                        "requires review before reconciliation: "
                        f"{service_spec.service_id}:"
                        f"{row_name}"
                    ),
                    frappe.ValidationError,
                )

            if (
                has_in_flight
                and int(
                    _number(
                        row.get("is_required")
                    )
                )
            ):
                frappe.throw(
                    (
                        "Required-document deactivation is "
                        "blocked while service requests are "
                        "in flight: "
                        f"{service_spec.service_id}:"
                        f"{row_key}"
                    ),
                    frappe.ValidationError,
                )

            doc = frappe.get_doc(
                "OMC Service Required Document",
                row_name,
            )
            doc.is_active = 0
            doc.save(
                ignore_permissions=True,
            )
            counts["deactivated"] += 1

    return counts


def _sync_form_fields() -> dict[str, int]:
    counts = _empty_write_counts()
    services = _service_rows()

    for service_spec in SERVICES:
        service_row = services.get(
            service_spec.service_id
        )

        if not service_row:
            frappe.throw(
                (
                    "Catalogue reconciliation could not resolve "
                    f"service {service_spec.service_id}."
                ),
                frappe.ValidationError,
            )

        service_name = _text(
            service_row.get("name")
        )

        rows = _form_field_rows(
            service_name
        )

        by_fieldname: dict[
            str,
            list[dict[str, Any]],
        ] = {}

        for row in rows:
            fieldname = _text(
                row.get("fieldname")
            )

            by_fieldname.setdefault(
                fieldname,
                [],
            ).append(row)

        desired_fieldnames: set[str] = set()

        desired_specs = (
            FORM_FIELDS_BY_SERVICE[
                service_spec.service_id
            ]
        )

        for index, field_spec in enumerate(
            desired_specs,
            start=1,
        ):
            desired_fieldnames.add(
                field_spec.fieldname
            )

            desired = (
                _desired_form_field_values(
                    field_spec,
                    sort_order=index,
                )
            )

            matches = by_fieldname.get(
                field_spec.fieldname,
                [],
            )

            if len(matches) > 1:
                frappe.throw(
                    (
                        "Ambiguous catalogue form field: "
                        f"{service_spec.service_id}:"
                        f"{field_spec.fieldname}"
                    ),
                    frappe.ValidationError,
                )

            if not matches:
                doc = frappe.new_doc(
                    "OMC Service Form Field"
                )
                doc.service = service_name

                _set_doc_values(
                    doc,
                    desired,
                )

                doc.insert(
                    ignore_permissions=True,
                )
                counts["created"] += 1
                continue

            current = matches[0]

            changes = _changes(
                current,
                desired,
            )

            if not changes:
                counts["unchanged"] += 1
                continue

            doc = frappe.get_doc(
                "OMC Service Form Field",
                current["name"],
            )

            _set_doc_values(
                doc,
                desired,
            )

            doc.save(
                ignore_permissions=True,
            )
            counts["updated"] += 1

        # Only fields previously marked as catalogue-owned may
        # be deactivated by catalogue reconciliation.
        for row in rows:
            if not int(
                _number(
                    row.get("is_active")
                )
            ):
                continue

            fieldname = _text(
                row.get("fieldname")
            )

            if fieldname in desired_fieldnames:
                continue

            if not _form_field_is_catalogue_managed(
                row
            ):
                continue

            doc = frappe.get_doc(
                "OMC Service Form Field",
                row["name"],
            )

            doc.is_active = 0

            doc.save(
                ignore_permissions=True,
            )
            counts["deactivated"] += 1

    return counts


def _validation_from_preview(
    preview: dict[str, Any],
) -> dict[str, Any]:
    totals = (
        preview.get("summary", {})
        .get("totals", {})
    )

    pending = {
        "created": int(
            totals.get("created", 0)
            or 0
        ),
        "updated": int(
            totals.get("updated", 0)
            or 0
        ),
        "deactivated": int(
            totals.get("deactivated", 0)
            or 0
        ),
        "conflicts": int(
            totals.get("conflicts", 0)
            or 0
        ),
        "blockers": int(
            totals.get("blockers", 0)
            or 0
        ),
    }

    valid = (
        bool(
            preview.get("ready_to_sync")
        )
        and all(
            value == 0
            for value in pending.values()
        )
    )

    return {
        "ok": True,
        "read_only": True,
        "operation": (
            "validate_service_catalogue"
        ),
        "valid": valid,
        "ready_to_sync": bool(
            preview.get("ready_to_sync")
        ),
        "pending": pending,
        "summary": preview.get(
            "summary",
            {},
        ),
        "blockers": preview.get(
            "blockers",
            [],
        ),
        "conflicts": preview.get(
            "conflicts",
            [],
        ),
    }


def validate_service_catalogue() -> dict[str, Any]:
    """Read-only exact-state catalogue validation."""
    return _validation_from_preview(
        preview_service_catalogue()
    )


def _aggregate_write_counts(
    sections: dict[str, dict[str, int]],
) -> dict[str, int]:
    return {
        action: sum(
            int(
                section.get(
                    action,
                    0,
                )
                or 0
            )
            for section in sections.values()
        )
        for action in (
            "created",
            "updated",
            "deactivated",
            "unchanged",
        )
    }


def sync_service_catalogue(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    """Atomically reconcile the source-controlled OMC service catalogue.

    Preconditions and the complete prospective plan are validated before
    the first write. All catalogue mutations share one transaction savepoint.
    The resulting database state is re-previewed and must be exact before the
    single final commit is allowed.
    """
    preflight = preview_service_catalogue()

    if not preflight.get(
        "ready_to_sync"
    ):
        frappe.throw(
            (
                "Service catalogue is not safe to synchronize. "
                "Run preview_service_catalogue and resolve all "
                "blockers/conflicts first."
            ),
            frappe.ValidationError,
        )

    effective_from = now_datetime()
    savepoint = (
        "omc_service_catalogue_sync"
    )

    frappe.db.savepoint(
        savepoint
    )

    try:
        sections = {
            "categories": (
                _sync_categories()
            ),
            "services": (
                _sync_services()
            ),
            "required_documents": (
                _sync_required_documents(
                    effective_from
                )
            ),
            "form_fields": (
                _sync_form_fields()
            ),
        }

        # Mandatory post-write validation happens BEFORE commit.
        post_preview = (
            preview_service_catalogue()
        )
        validation = (
            _validation_from_preview(
                post_preview
            )
        )

        if not validation["valid"]:
            frappe.throw(
                (
                    "Post-sync catalogue validation failed. "
                    "The catalogue transaction has been rolled back."
                ),
                frappe.ValidationError,
            )

        totals = _aggregate_write_counts(
            sections
        )

        result = {
            "ok": True,
            "operation": (
                "sync_service_catalogue"
            ),
            "manifest_version": (
                MANIFEST_VERSION
            ),
            "effective_from": str(
                effective_from
            ),
            "committed": bool(commit),
            "sections": sections,
            "totals": {
                **totals,
                "deleted": 0,
                "conflicts": 0,
            },
            "validation": validation,
        }

        # Exactly one explicit commit, and only after the
        # complete catalogue validates cleanly.
        if commit:
            frappe.db.commit()

        return result

    except Exception:
        frappe.db.rollback(
            save_point=savepoint
        )
        raise

