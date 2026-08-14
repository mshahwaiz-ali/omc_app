from __future__ import annotations

import json
import math
import re
from time import monotonic
from typing import Any

import frappe
from frappe.utils import add_to_date, cint, get_datetime, getdate, now_datetime
from frappe.utils.data import strip_html
from frappe.utils import validate_email_address
from omc_app.api import mobile

OPEN_CASE_STATUSES = ["Open", "In Progress", "Waiting for Customer", "Waiting for Payment"]
FORM_ALIASES = ("form_data", "form_data_json", "service_details", "additional_details")
MAX_JSON_BYTES = 32 * 1024
MAX_KEYS = 100
MAX_KEY_LENGTH = 140
DOCUMENT_GRACE_HOURS = 24
RAPID_WINDOW_MINUTES = 15
RAPID_THRESHOLD = 3
RESCORE_BATCH_SIZE = 50
RESCORE_RUNTIME_SECONDS = 45
JOB_LOCK_TIMEOUT_SECONDS = 55 * 60
CONTROL_CHARACTERS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def _text(value: Any) -> str:
    return str(value or "").strip()


def _canonical_fields(service_name: str):
    return frappe.get_all(
        "OMC Service Form Field",
        filters={"service": service_name, "is_active": 1},
        fields=[
            "fieldname",
            "label",
            "fieldtype",
            "options",
            "is_required",
            "depends_on",
            "sort_order",
        ],
        order_by="sort_order asc, creation asc, name asc",
    )


def _parse_alias(value: Any, alias: str) -> dict[str, Any]:
    if value in (None, ""):
        return {}
    if isinstance(value, str):
        if len(value.encode("utf-8")) > MAX_JSON_BYTES:
            frappe.throw("Submitted form data is too large.", frappe.ValidationError)
        try:
            value = json.loads(value)
        except (TypeError, ValueError):
            frappe.throw(f"{alias} must contain a valid JSON object.", frappe.ValidationError)
    if not isinstance(value, dict):
        frappe.throw(f"{alias} must be an object.", frappe.ValidationError)
    if len(value) > MAX_KEYS:
        frappe.throw("Submitted form data has too many fields.", frappe.ValidationError)
    try:
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError):
        frappe.throw(f"{alias} contains unsupported values.", frappe.ValidationError)
    if len(encoded.encode("utf-8")) > MAX_JSON_BYTES:
        frappe.throw("Submitted form data is too large.", frappe.ValidationError)
    for key, item in value.items():
        if not isinstance(key, str) or not key.strip() or len(key.strip()) > MAX_KEY_LENGTH:
            frappe.throw("Submitted form data contains an invalid field name.", frappe.ValidationError)
        if isinstance(item, (dict, list, tuple, set)):
            frappe.throw("Nested submitted form values are not supported.", frappe.ValidationError)
    return value


def _sanitize_text(value: Any, *, maximum: int) -> str:
    if value is None:
        return ""
    if not isinstance(value, (str, int, float, bool)):
        frappe.throw("Submitted form values must be scalar.", frappe.ValidationError)
    text = CONTROL_CHARACTERS.sub("", strip_html(str(value))).strip()
    if len(text) > maximum:
        frappe.throw(f"Submitted form value must be {maximum} characters or fewer.", frappe.ValidationError)
    return text


def _options(value: Any) -> list[str]:
    return [line.strip() for line in _text(value).replace(",", "\n").splitlines() if line.strip()]


def _normalize_value(field, value: Any):
    fieldtype = _text(field.fieldtype) or "Data"
    if fieldtype == "Attach":
        if value not in (None, ""):
            frappe.throw(f"{field.label or field.fieldname} must be uploaded after request creation.", frappe.ValidationError)
        return ""
    limits = {"Data": 140, "Phone": 40, "Email": 254, "Small Text": 500, "Text": 5000}
    if fieldtype in limits:
        text = _sanitize_text(value, maximum=limits[fieldtype])
        if fieldtype == "Email" and text and not validate_email_address(text, throw=False):
            frappe.throw(f"{field.label or field.fieldname} must be a valid email address.", frappe.ValidationError)
        return text
    if fieldtype == "Select":
        text = _sanitize_text(value, maximum=500)
        allowed = _options(field.options)
        if text and text not in allowed:
            frappe.throw(f"{field.label or field.fieldname} has an unsupported value.", frappe.ValidationError)
        return text
    if fieldtype == "Check":
        if isinstance(value, bool):
            return 1 if value else 0
        text = _text(value).lower()
        if text in {"1", "true", "yes", "on"}:
            return 1
        if text in {"", "0", "false", "no", "off"}:
            return 0
        frappe.throw(f"{field.label or field.fieldname} must be a checkbox value.", frappe.ValidationError)
    if fieldtype == "Date":
        try:
            return str(getdate(value)) if value not in (None, "") else ""
        except Exception:
            frappe.throw(f"{field.label or field.fieldname} must be a valid date.", frappe.ValidationError)
    if fieldtype == "Datetime":
        try:
            return str(get_datetime(value)) if value not in (None, "") else ""
        except Exception:
            frappe.throw(f"{field.label or field.fieldname} must be a valid date and time.", frappe.ValidationError)
    if fieldtype == "Int":
        text = _sanitize_text(value, maximum=100)
        if not re.fullmatch(r"[+-]?\d+", text):
            frappe.throw(f"{field.label or field.fieldname} must be a whole number.", frappe.ValidationError)
        return int(text)
    if fieldtype in {"Float", "Currency"}:
        text = _sanitize_text(value, maximum=100)
        try:
            number = float(text)
        except (TypeError, ValueError):
            frappe.throw(f"{field.label or field.fieldname} must be numeric.", frappe.ValidationError)
        if not math.isfinite(number):
            frappe.throw(f"{field.label or field.fieldname} must be finite.", frappe.ValidationError)
        return number
    frappe.throw(f"Unsupported configured field type: {fieldtype}.", frappe.ValidationError)


def validate_submission(service_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    fields = _canonical_fields(service_name)
    conditional = [field for field in fields if _text(field.depends_on)]
    if conditional:
        frappe.throw(
            "This service has unsupported conditional form configuration. Please contact OMC support.",
            frappe.ValidationError,
        )

    supplied = []
    for alias in FORM_ALIASES:
        if payload.get(alias) not in (None, ""):
            supplied.append((alias, _parse_alias(payload.get(alias), alias)))
    raw = supplied[0][1] if supplied else {}
    canonical_compare = json.dumps(raw, sort_keys=True, ensure_ascii=False, default=str)
    for alias, candidate in supplied[1:]:
        if json.dumps(candidate, sort_keys=True, ensure_ascii=False, default=str) != canonical_compare:
            frappe.throw(f"{alias} conflicts with another submitted form payload.", frappe.ValidationError)

    by_name = {_text(field.fieldname): field for field in fields if _text(field.fieldname)}
    unknown = sorted(set(_text(key) for key in raw) - set(by_name))
    if unknown:
        frappe.throw(f"Unsupported submitted form field: {unknown[0]}.", frappe.ValidationError)

    clean = {}
    for fieldname, field in by_name.items():
        present = fieldname in raw and raw[fieldname] not in (None, "")
        if cint(field.is_required) and field.fieldtype != "Attach" and not present:
            frappe.throw(f"{field.label or fieldname} is required.", frappe.ValidationError)
        if present or fieldname in raw:
            clean[fieldname] = _normalize_value(field, raw.get(fieldname))
    encoded = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return {"data": clean, "json": encoded, "fields": fields}


def sanitize_description(value: Any) -> str:
    return _sanitize_text(value, maximum=5000)


def _escalate_unsupported_conditions() -> int:
    rows = frappe.get_all(
        "OMC Service Form Field",
        filters={"is_active": 1, "depends_on": ["is", "set"]},
        fields=["name", "service"],
        order_by="service asc, name asc",
        limit_page_length=100,
    )
    if not rows:
        return 0
    role_users = frappe.get_all(
        "Has Role",
        filters={"role": ["in", ["OMC Admin", "OMC Manager"]], "parenttype": "User"},
        pluck="parent",
    )
    if not role_users:
        return 0
    active = frappe.get_all(
        "User",
        filters={
            "name": ["in", sorted(set(role_users))],
            "enabled": 1,
            "user_type": "System User",
        },
        pluck="name",
    )
    if not active:
        return 0
    recipient = sorted(set(active))[0]
    created = 0
    for row in rows:
        title = "Unsupported service form condition"
        if frappe.db.exists(
            "OMC Notification",
            {
                "recipient_user": recipient,
                "title": title,
                "reference_doctype": "OMC Service",
                "reference_name": row.service,
                "creation": [">=", add_to_date(now_datetime(), hours=-24)],
            },
        ):
            continue
        created += int(
            bool(
                mobile._create_customer_notification(
                    recipient_user=recipient,
                    title=title,
                    message=f"Service {row.service} contains unsupported depends_on configuration.",
                    notification_type="Service",
                    reference_doctype="OMC Service",
                    reference_name=row.service,
                )
            )
        )
    return created


def _identity_filters(request) -> list[dict[str, Any]]:
    profile = _text(getattr(request, "customer_profile", None))
    requested_for = _text(getattr(request, "requested_for_customer", None))
    manual = _text(getattr(request, "manual_customer", None))
    if profile:
        return [{"customer_profile": profile}]
    if requested_for:
        return [{"requested_for_customer": requested_for}]
    if not manual or not frappe.db.exists("OMC Manual Customer", manual):
        return []
    row = frappe.db.get_value("OMC Manual Customer", manual, ["cnic", "email", "mobile"], as_dict=True) or {}
    if _text(row.get("cnic")):
        matches = frappe.get_all("OMC Manual Customer", filters={"cnic": _text(row.get("cnic"))}, pluck="name")
    elif _text(row.get("email")):
        target = _text(row.get("email")).lower()
        matches = [
            item.name
            for item in frappe.get_all("OMC Manual Customer", fields=["name", "email"])
            if _text(item.email).lower() == target
        ]
    elif _text(row.get("mobile")):
        target = re.sub(r"\D", "", _text(row.get("mobile")))
        matches = [
            item.name
            for item in frappe.get_all("OMC Manual Customer", fields=["name", "mobile"])
            if re.sub(r"\D", "", _text(item.mobile)) == target
        ]
    else:
        matches = [manual]
    return [{"manual_customer": ["in", sorted(set(matches))]}] if matches else []


def _potential_duplicate(request):
    for identity_filter in _identity_filters(request):
        filters = {
            **identity_filter,
            "service": request.service,
            "status": ["in", OPEN_CASE_STATUSES],
            "name": ["!=", request.name],
        }
        rows = frappe.get_all("OMC Service Request", filters=filters, pluck="name", order_by="creation asc, name asc", limit=1)
        if rows:
            return rows[0]
    return None


def _rapid_submission(request) -> bool:
    since = add_to_date(getattr(request, "creation", None) or now_datetime(), minutes=-RAPID_WINDOW_MINUTES)
    for identity_filter in _identity_filters(request):
        count = frappe.db.count("OMC Service Request", filters={**identity_filter, "creation": [">=", since]})
        if count >= RAPID_THRESHOLD:
            return True
    return False


def _missing_required_documents(request) -> list[str]:
    templates = frappe.get_all(
        "OMC Service Required Document",
        filters={"service": request.service, "is_active": 1, "is_required": 1},
        fields=["document_title", "document_type"],
    )
    documents = frappe.get_all(
        "OMC Service Document",
        filters={"service_request": request.name, "status": ["in", ["Uploaded", "Approved"]]},
        fields=["document_title", "document_type"],
    )
    present = {
        (_text(doc.document_title).lower(), _text(doc.document_type).lower())
        for doc in documents
    }
    return [
        template.document_title or template.document_type
        for template in templates
        if (_text(template.document_title).lower(), _text(template.document_type).lower()) not in present
    ]


def _structured_form_findings(request) -> tuple[list[dict[str, Any]], int, bool]:
    """Evaluate stored canonical data without trying to reconstruct legacy prose."""
    fields = _canonical_fields(request.service)
    by_name = {_text(field.fieldname): field for field in fields if _text(field.fieldname)}
    raw_value = getattr(request, "submission_data_json", None)
    raw = {}
    reasons: list[dict[str, Any]] = []
    invalid_fields = 0
    missing_fields = 0
    unknown_fields = 0

    if raw_value not in (None, ""):
        try:
            raw = json.loads(raw_value) if isinstance(raw_value, str) else raw_value
        except (TypeError, ValueError):
            raw = None
        if not isinstance(raw, dict):
            reasons.append({"code": "invalid_form_data"})
            invalid_fields += 1
            raw = {}

    for key in sorted(set(_text(key) for key in raw) - set(by_name)):
        reasons.append({"code": "unknown_legacy_key", "field": key})
        unknown_fields += 1

    for fieldname, field in by_name.items():
        if _text(field.depends_on):
            reasons.append({"code": "unsupported_condition", "field": fieldname})
            invalid_fields += 1
            continue
        present = fieldname in raw and raw[fieldname] not in (None, "")
        if cint(field.is_required) and field.fieldtype != "Attach" and not present:
            reasons.append({"code": "missing_required_form_value", "field": fieldname})
            missing_fields += 1
            continue
        if present or fieldname in raw:
            try:
                _normalize_value(field, raw.get(fieldname))
            except frappe.ValidationError:
                reasons.append({"code": "invalid_form_value", "field": fieldname})
                invalid_fields += 1

    score = min(50, missing_fields * 25)
    score += min(40, invalid_fields * 20)
    score += min(20, unknown_fields * 10)
    return reasons, score, bool(missing_fields or invalid_fields or unknown_fields)


def evaluate_request(request, *, persist: bool = True) -> dict[str, Any]:
    reasons, score, incomplete = _structured_form_findings(request)
    duplicate = _potential_duplicate(request)
    if duplicate:
        reasons.append({"code": "potential_duplicate", "request": duplicate})
        score += 30
    if _rapid_submission(request):
        reasons.append({"code": "rapid_repeated_submission"})
        score += 20

    identity_present = bool(_identity_filters(request))
    contact_present = bool(_text(getattr(request, "contact_email", None)) or _text(getattr(request, "contact_phone", None)))
    if not identity_present or not contact_present:
        reasons.append({"code": "missing_contact_identity"})
        score += 30
        incomplete = True

    due_at = getattr(request, "submission_documents_due_at", None) or add_to_date(
        getattr(request, "creation", None) or now_datetime(), hours=DOCUMENT_GRACE_HOURS
    )
    if get_datetime(due_at) <= now_datetime():
        missing = _missing_required_documents(request)
        if missing:
            reasons.extend({"code": "required_document_outstanding", "document": name} for name in missing)
            score += min(45, len(missing) * 15)
            incomplete = True

    status = "Incomplete" if incomplete else ("Needs Review" if reasons else "Clear")
    result = {
        "status": status,
        "score": min(100, score),
        "reasons": reasons,
        "potential_duplicate_of": duplicate,
        "documents_due_at": due_at,
    }
    if persist:
        values = {
            "submission_integrity_status": status,
            "submission_integrity_score": result["score"],
            "submission_integrity_reasons_json": json.dumps(reasons, ensure_ascii=False, separators=(",", ":"))[:4000],
            "submission_integrity_checked_at": now_datetime(),
            "submission_documents_due_at": due_at,
            "potential_duplicate_of": duplicate,
        }
        frappe.db.set_value("OMC Service Request", request.name, values, update_modified=False)
        if status != "Clear":
            frappe.db.set_value(
                "ToDo",
                {
                    "reference_type": "OMC Service Request",
                    "reference_name": request.name,
                    "status": ["not in", ["Closed", "Cancelled"]],
                },
                "priority",
                "High",
                update_modified=False,
            )
    return result


def run_integrity_rescore() -> dict[str, Any]:
    started = monotonic()
    site = getattr(frappe.local, "site", "site")
    lock = frappe.cache().lock(
        f"omc_app:{site}:submission_integrity_rescore",
        timeout=JOB_LOCK_TIMEOUT_SECONDS,
        blocking_timeout=0,
    )
    if not lock.acquire(blocking=False):
        return {
            "scanned": 0,
            "rescored": 0,
            "failed": 0,
            "runtime_budget_stopped": 0,
            "status": "skipped_locked",
        }
    try:
        configuration_escalations = _escalate_unsupported_conditions()
        rows = frappe.get_all(
            "OMC Service Request",
            filters={"status": ["in", OPEN_CASE_STATUSES]},
            pluck="name",
            order_by="submission_integrity_checked_at asc, creation asc, name asc",
            limit_page_length=RESCORE_BATCH_SIZE,
        )
        summary = {
            "scanned": len(rows),
            "rescored": 0,
            "failed": 0,
            "runtime_budget_stopped": 0,
            "configuration_escalations": configuration_escalations,
        }
        for index, name in enumerate(rows):
            if monotonic() - started >= RESCORE_RUNTIME_SECONDS:
                summary["runtime_budget_stopped"] = len(rows) - index
                break
            savepoint = f"integrity_{index}"
            frappe.db.savepoint(savepoint)
            try:
                locked = frappe.db.get_value(
                    "OMC Service Request", name, "name", for_update=True, wait=False
                )
                if not locked:
                    continue
                evaluate_request(frappe.get_doc("OMC Service Request", name))
                summary["rescored"] += 1
            except Exception as error:
                frappe.db.rollback(save_point=savepoint)
                summary["failed"] += 1
                frappe.log_error(
                    title=f"OMC integrity rescore failed: {name}",
                    message=f"{error.__class__.__name__}: {_text(error)}"[:1000],
                )
        return {**summary, "status": "completed"}
    finally:
        try:
            lock.release()
        except Exception:
            pass
