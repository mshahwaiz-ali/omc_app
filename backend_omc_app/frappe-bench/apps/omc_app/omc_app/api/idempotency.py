from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass

import frappe
from frappe.utils import add_to_date, now_datetime


IDEMPOTENCY_HEADER = "X-Idempotency-Key"
KEY_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{15,139}$")
DEFAULT_TTL_HOURS = 48


@dataclass(frozen=True)
class IdempotencyClaim:
    name: str
    replay: dict | None = None


def _text(value) -> str:
    return str(value or "").strip()


def request_key(kwargs: dict | None = None) -> str:
    body_key = _text((kwargs or {}).get("idempotency_key"))
    if body_key:
        return body_key
    try:
        return _text(frappe.get_request_header(IDEMPOTENCY_HEADER))
    except Exception:
        return ""


def _request_hash(payload: dict) -> str:
    filtered = {
        str(key): value
        for key, value in (payload or {}).items()
        if str(key) != "idempotency_key"
    }
    encoded = json.dumps(
        filtered,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _record_name(actor: str, operation: str, key: str) -> str:
    raw = f"{actor.strip().lower()}|{operation.strip()}|{key}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def begin(*, operation: str, actor: str, payload: dict) -> IdempotencyClaim | None:
    key = request_key(payload)
    if not key:
        return None
    if not KEY_PATTERN.fullmatch(key):
        frappe.throw(
            "Invalid idempotency key.",
            frappe.ValidationError,
        )

    request_hash = _request_hash(payload)
    name = _record_name(actor, operation, key)
    existing = frappe.db.get_value(
        "OMC Idempotency Record",
        name,
        ["request_hash", "state", "response_json"],
        as_dict=True,
    )
    if existing:
        if existing.request_hash != request_hash:
            frappe.throw(
                "This idempotency key was already used with different data.",
                frappe.ValidationError,
            )
        if existing.state == "Completed" and existing.response_json:
            replay = json.loads(existing.response_json)
            if isinstance(replay, dict):
                replay["idempotent_replay"] = True
                return IdempotencyClaim(name=name, replay=replay)
        if existing.state == "Failed":
            frappe.db.set_value(
                "OMC Idempotency Record",
                name,
                {
                    "state": "Processing",
                    "response_json": "",
                    "expires_on": add_to_date(
                        now_datetime(), hours=DEFAULT_TTL_HOURS
                    ),
                },
                update_modified=False,
            )
            return IdempotencyClaim(name=name)
        frappe.throw(
            "This request is already being processed. Refresh before retrying.",
            frappe.ValidationError,
        )

    doc = frappe.new_doc("OMC Idempotency Record")
    doc.dedupe_key = name
    doc.operation = operation
    doc.actor = actor
    doc.request_hash = request_hash
    doc.state = "Processing"
    doc.expires_on = add_to_date(now_datetime(), hours=DEFAULT_TTL_HOURS)
    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        return begin(operation=operation, actor=actor, payload=payload)
    return IdempotencyClaim(name=doc.name)


def complete(
    claim: IdempotencyClaim | None,
    response: dict,
    *,
    reference_doctype: str = "",
    reference_name: str = "",
    stored_response: dict | None = None,
) -> dict:
    if claim is None:
        return response
    safe_response = json.dumps(
        stored_response if stored_response is not None else response,
        sort_keys=True,
        default=str,
    )
    frappe.db.set_value(
        "OMC Idempotency Record",
        claim.name,
        {
            "state": "Completed",
            "reference_doctype": reference_doctype,
            "reference_name": reference_name,
            "response_json": safe_response,
        },
        update_modified=False,
    )
    response["idempotency_key"] = claim.name
    response["idempotent_replay"] = False
    return response


def fail(claim: IdempotencyClaim | None) -> None:
    if claim is None:
        return
    if frappe.db.exists("OMC Idempotency Record", claim.name):
        frappe.db.set_value(
            "OMC Idempotency Record",
            claim.name,
            "state",
            "Failed",
            update_modified=False,
        )


def cleanup_expired_records() -> None:
    frappe.db.delete(
        "OMC Idempotency Record",
        {"expires_on": ["<", now_datetime()]},
    )
