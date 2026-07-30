"""Read-only Batch 2 inspection for ERP Service -> Task behaviour.

Run:
    bench --site omc.local execute omc_app.api.service_task_truth_inspection.run
"""
from __future__ import annotations

import inspect
import json
import re
from datetime import date, datetime
from pathlib import Path
from typing import Any

import frappe

TARGET_CALLABLES = (
    "erpnext.service.create_task_from_service",
    "erpnext.service.create_task_from_service_dt",
    "erpnext.service.update_service_status",
    "lead_app.apis.create_service",
)
SEARCH_TOKENS = (
    "create_task_from_service",
    "create_task_from_service_dt",
    "update_service_status",
    "frappe.new_doc('Task')",
    'frappe.new_doc("Task")',
    '"doctype": "Task"',
    "'doctype': 'Task'",
    "add_assignment",
    "assign_to",
    "_assign",
    "ToDo",
    "user_link",
    "sales_person",
    "senior_tax_associates",
    "custom_operation_status",
    "workflow_state",
    "status",
)
TEXT_SUFFIXES = {".py", ".js", ".json", ".md", ".txt", ".yaml", ".yml"}
SENSITIVE = ("password", "secret", "token", "api_key", "api_secret", "private_key")


def _safe(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, dict):
        return {str(k): _safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_safe(v) for v in value]
    return value


def _redact(text: str) -> str:
    result = text
    for token in SENSITIVE:
        result = re.sub(rf"(?i)({re.escape(token)}\s*[=:]\s*)[^,;\s]+", r"\1<redacted>", result)
    return result


def _resolve_callable(dotted_path: str) -> dict[str, Any]:
    module_name, attr = dotted_path.rsplit(".", 1)
    try:
        module = frappe.get_module(module_name)
        fn = getattr(module, attr)
        source_file = inspect.getsourcefile(fn)
        source_lines, start_line = inspect.getsourcelines(fn)
        source = _redact("".join(source_lines))
        return {
            "path": dotted_path,
            "exists": True,
            "source_file": source_file,
            "start_line": start_line,
            "end_line": start_line + len(source_lines) - 1,
            "signature": str(inspect.signature(fn)),
            "source": source,
        }
    except Exception as exc:
        return {"path": dotted_path, "exists": False, "error": _redact(str(exc))[:500]}


def _doctype_fields(doctype: str) -> list[dict[str, Any]]:
    if not frappe.db.exists("DocType", doctype):
        return []
    meta = frappe.get_meta(doctype)
    wanted = {
        "customer", "user_link", "service_type", "task_created", "task_link",
        "subject", "type", "priority", "status", "workflow_state",
        "custom_operation_status", "sales_person", "sale_person",
        "senior_tax_associates", "consultant_id", "reference_business_partner",
        "completed_by", "completed_on", "exp_start_date", "exp_end_date",
    }
    result = []
    for field in meta.fields:
        if field.fieldname in wanted or "assign" in (field.fieldname or "").lower():
            result.append({
                "fieldname": field.fieldname,
                "label": field.label,
                "fieldtype": field.fieldtype,
                "options": field.options,
                "required": bool(field.reqd),
                "read_only": bool(field.read_only),
                "hidden": bool(field.hidden),
                "custom": bool(getattr(field, "is_custom_field", 0)),
                "fetch_from": getattr(field, "fetch_from", None),
            })
    return result


def _property_setters(doctype: str) -> list[dict[str, Any]]:
    if not frappe.db.exists("DocType", "Property Setter"):
        return []
    rows = frappe.get_all(
        "Property Setter",
        filters={"doc_type": doctype},
        fields=["name", "doctype_or_field", "field_name", "property", "property_type", "value"],
        order_by="modified desc",
    )
    relevant = []
    for row in rows:
        text = " ".join(str(row.get(k) or "") for k in ("field_name", "property", "value")).lower()
        if any(token in text for token in ("status", "workflow", "assign", "user_link", "sales_person", "task_link", "task_created", "customer")):
            if any(secret in text for secret in SENSITIVE):
                row["value"] = "<redacted>"
            relevant.append(row)
    return relevant


def _hooks() -> dict[str, Any]:
    result: dict[str, Any] = {}
    for hook_name in ("doc_events", "override_whitelisted_methods", "permission_query_conditions", "has_permission"):
        try:
            result[hook_name] = frappe.get_hooks(hook_name)
        except Exception as exc:
            result[hook_name] = {"inspection_error": _redact(str(exc))[:500]}
    return result


def _scan_sources() -> dict[str, Any]:
    roots: dict[str, Path] = {}
    for app in ("erpnext", "lead_app", "omc_app"):
        try:
            roots[app] = Path(frappe.get_app_path(app))
        except Exception:
            continue
    ignored = {".git", "node_modules", "__pycache__", ".venv", "env", "sites", "logs", "private", "public/dist"}
    matches = []
    for app, root in roots.items():
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
                continue
            relative = path.relative_to(root)
            if any(part in ignored for part in relative.parts):
                continue
            try:
                if path.stat().st_size > 1_000_000:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            hit_lines = []
            for index, line in enumerate(text.splitlines(), start=1):
                if any(token in line for token in SEARCH_TOKENS):
                    hit_lines.append({"line": index, "text": _redact(line.strip())[:300]})
            if hit_lines:
                matches.append({"app": app, "path": str(relative), "matches": hit_lines[:100]})
    matches.sort(key=lambda row: (row["app"], row["path"]))
    return {"roots": {app: str(path) for app, path in roots.items()}, "files": matches}


def _assignment_model() -> dict[str, Any]:
    task_fields = {row["fieldname"]: row for row in _doctype_fields("Task")}
    return {
        "task_user_link": task_fields.get("user_link"),
        "explicit_assigned_fields": [row for row in task_fields.values() if "assign" in row["fieldname"].lower()],
        "frappe_assignment_note": (
            "Frappe document assignment is normally represented by Assignment/ToDo and the internal _assign value. "
            "This report only identifies whether project code actively uses those mechanisms."
        ),
    }


def _markdown(report: dict[str, Any]) -> str:
    lines = [
        "# OMC Batch 2 — Service and Task Truth Inspection",
        "",
        f"Generated: `{report['generated_at']}`",
        f"Site: `{report['site']}`",
        "",
        "> Read-only controller, metadata, hook, and source inspection.",
        "",
        "## Resolved callables",
        "",
    ]
    for item in report["callables"]:
        if item.get("exists"):
            lines.append(f"- `{item['path']}{item['signature']}` — `{item['source_file']}:{item['start_line']}-{item['end_line']}`")
        else:
            lines.append(f"- `{item['path']}` — not resolved: {item.get('error')}")
    lines += ["", "## Key metadata", ""]
    for doctype, fields in report["doctype_fields"].items():
        lines.append(f"### {doctype}")
        for field in fields:
            lines.append(
                f"- `{field['fieldname']}` — {field['fieldtype']} → `{field.get('options') or ''}`; "
                f"required={field['required']}; read_only={field['read_only']}; fetch_from=`{field.get('fetch_from') or ''}`"
            )
    lines += ["", "## Relevant source references", ""]
    for file in report["source_scan"]["files"]:
        lines.append(f"### `{file['app']}:{file['path']}`")
        for hit in file["matches"]:
            lines.append(f"- L{hit['line']}: `{hit['text']}`")
    lines += [
        "",
        "## Safety",
        "",
        "- No records are inserted, updated, deleted, submitted, cancelled, or committed.",
        "- No migrations or schema changes are executed.",
        "- ERP, lead_app, OMC, and Flutter source files are only read.",
        "- Only the generated JSON and Markdown report files are written.",
        "",
    ]
    return "\n".join(lines)


def run(output_dir: str | None = None) -> dict[str, Any]:
    """Generate a read-only Batch 2 report for Service/Task creation and assignment."""
    report = _safe({
        "report_version": 1,
        "generated_at": frappe.utils.now_datetime(),
        "site": frappe.local.site,
        "read_only": True,
        "callables": [_resolve_callable(path) for path in TARGET_CALLABLES],
        "doctype_fields": {
            "Customer": _doctype_fields("Customer"),
            "Service": _doctype_fields("Service"),
            "Task": _doctype_fields("Task"),
            "OMC Service Request": _doctype_fields("OMC Service Request"),
        },
        "property_setters": {
            "Customer": _property_setters("Customer"),
            "Service": _property_setters("Service"),
            "Task": _property_setters("Task"),
        },
        "hooks": _hooks(),
        "assignment_model": _assignment_model(),
        "source_scan": _scan_sources(),
    })
    destination = Path(output_dir).expanduser().resolve() if output_dir else Path(frappe.get_site_path("private", "files")).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    stamp = frappe.utils.now_datetime().strftime("%Y%m%d_%H%M%S")
    json_path = destination / f"omc_service_task_truth_{stamp}.json"
    markdown_path = destination / f"omc_service_task_truth_{stamp}.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True, default=str), encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    return {
        "status": "report_generated_not_validated",
        "site": frappe.local.site,
        "json_report": str(json_path),
        "markdown_report": str(markdown_path),
        "read_only": True,
    }
