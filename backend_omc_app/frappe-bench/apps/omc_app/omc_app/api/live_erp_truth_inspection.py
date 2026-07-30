"""Strictly read-only live ERP inspection for OMC consolidation Batch 1.

Run:
    bench --site omc.local execute omc_app.api.live_erp_truth_inspection.run
"""
from __future__ import annotations

import json
import re
from datetime import date, datetime
from pathlib import Path
from typing import Any

import frappe

DOCTYPES = ("Customer", "Service", "Task", "OMC Customer Profile", "OMC Service Request", "OMC Task")
WORKFLOW_DOCTYPES = ("Service", "Task")
SOURCE_SUFFIXES = {".py", ".js", ".json", ".md", ".txt", ".yaml", ".yml"}
SENSITIVE = ("password", "passwd", "secret", "token", "api_key", "api_secret", "gateway", "private_key")
LINK_WORDS = ("customer", "user", "service", "task", "lead", "consultant", "partner", "associate", "profile", "request")


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


def _sensitive(name: str) -> bool:
    return any(token in name.lower() for token in SENSITIVE)


def _error(exc: Exception) -> str:
    text = str(exc).replace("\n", " ")[:500]
    for token in SENSITIVE:
        text = re.sub(rf"(?i)({re.escape(token)}\s*[=:]\s*)[^,; ]+", r"\1<redacted>", text)
    return text


def _apps() -> list[dict[str, Any]]:
    installed = set(frappe.get_installed_apps())
    all_apps = set(installed)
    try:
        all_apps.update(frappe.get_all_apps(with_internal_apps=True))
    except Exception:
        pass
    versions: dict[str, Any] = {}
    try:
        from frappe.utils.change_log import get_versions
        versions = get_versions() or {}
    except Exception:
        pass
    result = []
    for app in sorted(all_apps):
        path = None
        try:
            path = frappe.get_app_path(app)
        except Exception:
            pass
        version = versions.get(app)
        if isinstance(version, dict):
            version = version.get("branch_version") or version.get("version") or version.get("branch")
        result.append({"app": app, "installed_on_site": app in installed, "version": version, "source_path": path})
    return result


def _field(field: Any) -> dict[str, Any]:
    name = str(getattr(field, "fieldname", "") or "")
    return {
        "fieldname": name,
        "label": getattr(field, "label", None),
        "fieldtype": getattr(field, "fieldtype", None),
        "options": "<redacted>" if _sensitive(name) else getattr(field, "options", None),
        "required": bool(getattr(field, "reqd", 0)),
        "read_only": bool(getattr(field, "read_only", 0)),
        "default": None if _sensitive(name) else getattr(field, "default", None),
        "hidden": bool(getattr(field, "hidden", 0)),
        "in_list_view": bool(getattr(field, "in_list_view", 0)),
        "in_standard_filter": bool(getattr(field, "in_standard_filter", 0)),
        "in_global_search": bool(getattr(field, "in_global_search", 0)),
        "search_index": bool(getattr(field, "search_index", 0)),
        "unique": bool(getattr(field, "unique", 0)),
        "custom": bool(getattr(field, "is_custom_field", 0)),
    }


def _schema(doctype: str) -> dict[str, Any]:
    if not frappe.db.exists("DocType", doctype):
        return {"doctype": doctype, "exists": False}
    meta = frappe.get_meta(doctype)
    app = None
    source_path = None
    try:
        app = (frappe.local.module_app or {}).get(meta.module)
        if app:
            source_path = frappe.get_module_path(app, meta.module)
    except Exception:
        pass
    return {
        "doctype": doctype,
        "exists": True,
        "issingle": bool(meta.issingle),
        "is_submittable": bool(meta.is_submittable),
        "track_changes": bool(meta.track_changes),
        "autoname": meta.autoname,
        "title_field": meta.title_field,
        "search_fields": meta.search_fields,
        "ownership": {"app": app, "module": meta.module, "source_path": source_path},
        "fields": [_field(field) for field in meta.fields],
    }


def _customizations(doctype: str) -> dict[str, Any]:
    fields = frappe.get_all("Custom Field", filters={"dt": doctype}, fields=["name", "fieldname", "label", "fieldtype", "options", "insert_after", "reqd", "read_only", "hidden"], order_by="idx asc") if frappe.db.exists("DocType", "Custom Field") else []
    setters = frappe.get_all("Property Setter", filters={"doc_type": doctype}, fields=["name", "doctype_or_field", "field_name", "property", "property_type", "value"], order_by="modified desc") if frappe.db.exists("DocType", "Property Setter") else []
    for row in fields:
        if _sensitive(str(row.get("fieldname") or "")):
            row["options"] = "<redacted>"
    for row in setters:
        if _sensitive(str(row.get("field_name") or "")) or _sensitive(str(row.get("property") or "")):
            row["value"] = "<redacted>"
    return {"custom_fields": fields, "property_setters": setters}


def _workflows(doctype: str) -> list[dict[str, Any]]:
    if not frappe.db.exists("DocType", "Workflow"):
        return []
    result = []
    for row in frappe.get_all("Workflow", filters={"document_type": doctype}, fields=["name"], order_by="modified desc"):
        doc = frappe.get_doc("Workflow", row.name)
        result.append({
            "name": doc.name,
            "active": bool(doc.is_active),
            "workflow_state_field": doc.workflow_state_field,
            "states": [{"state": x.state, "doc_status": x.doc_status, "allow_edit": x.allow_edit, "update_field": getattr(x, "update_field", None), "update_value": getattr(x, "update_value", None)} for x in doc.states],
            "transitions": [{"state": x.state, "action": x.action, "next_state": x.next_state, "allowed": x.allowed, "condition": getattr(x, "condition", None), "allow_self_approval": bool(getattr(x, "allow_self_approval", 0))} for x in doc.transitions],
        })
    return result


def _stats(doctype: str, schema: dict[str, Any]) -> dict[str, Any]:
    if not schema.get("exists") or schema.get("issingle"):
        return {"total": 0, "grouped_by": None, "states": []}
    names = {f["fieldname"] for f in schema["fields"]}
    group = next((x for x in ("workflow_state", "status", "docstatus") if x in names), None)
    states = []
    if group:
        rows = frappe.get_all(doctype, fields=[group, "count(name) as count"], group_by=group, order_by="count desc")
        states = [{"state": row.get(group), "count": row.get("count")} for row in rows]
    return {"total": frappe.db.count(doctype), "grouped_by": group, "states": states}


def _sample(doctype: str, schema: dict[str, Any]) -> dict[str, Any] | None:
    if not schema.get("exists") or schema.get("issingle"):
        return None
    available = {f["fieldname"] for f in schema["fields"]}
    fields = [x for x in ("name", "status", "workflow_state", "docstatus", "disabled", "is_active", "creation", "modified") if x == "name" or x in available]
    rows = frappe.get_all(doctype, fields=fields, limit_page_length=1, order_by="modified desc")
    if not rows:
        return None
    row = rows[0]
    result = {k: row.get(k) for k in fields if k != "name"}
    identifier = str(row.get("name") or "")
    result["name"] = {"present": bool(identifier), "length": len(identifier), "masked_prefix": re.sub(r"[A-Za-z0-9]", "X", identifier[:8])}
    return result


def _links(schemas: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    result = []
    for doctype, schema in schemas.items():
        for field in schema.get("fields", []):
            haystack = " ".join(str(field.get(x) or "") for x in ("fieldname", "label", "options")).lower()
            if field.get("fieldtype") in {"Link", "Dynamic Link", "Table", "Table MultiSelect"} or any(word in haystack for word in LINK_WORDS):
                result.append({"source_doctype": doctype, "fieldname": field["fieldname"], "label": field.get("label"), "fieldtype": field.get("fieldtype"), "target_or_options": field.get("options"), "custom": field.get("custom")})
    return result


def _source_scan(apps: list[dict[str, Any]]) -> dict[str, Any]:
    roots = {row["app"]: Path(row["source_path"]) for row in apps if row.get("source_path") and row["app"] in {"omc_app", "lead_app", "erpnext"}}
    output = {"scan_roots": {k: str(v) for k, v in roots.items()}, "omc_task_dependencies": [], "lead_app_dependencies": [], "service_task_evidence": []}
    ignored = {".git", "node_modules", "__pycache__", ".venv", "env", "sites", "logs", "private"}
    for app, root in roots.items():
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in SOURCE_SUFFIXES or set(path.parts) & ignored:
                continue
            try:
                if path.stat().st_size > 1_500_000:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            rel = str(path.relative_to(root))
            lines = text.splitlines()
            if app == "omc_app" and "OMC Task" in text:
                categories = []
                lowered = text.lower()
                for category, words in {"query": ("get_all", "get_list", "get_doc", "get_value"), "create": ("new_doc", '"doctype": "OMC Task"', "'doctype': 'OMC Task'"), "serialize": ("serialize", "to_dict"), "permission": ("permission", "task_query", "task_has_permission"), "dashboard": ("dashboard", "count"), "test_workspace_scheduler_notification": ("test", "workspace", "scheduler", "notification")}.items():
                    if any(word.lower() in lowered for word in words):
                        categories.append(category)
                output["omc_task_dependencies"].append({"path": rel, "categories": categories, "line_numbers": [i + 1 for i, line in enumerate(lines) if "OMC Task" in line][:30]})
            if "lead_app" in text or (app == "lead_app" and any(x in text for x in ("Customer", "Service", "Task"))):
                output["lead_app_dependencies"].append({"app": app, "path": rel, "line_numbers": [i + 1 for i, line in enumerate(lines) if "lead_app" in line or "OMC Task" in line][:30]})
            if app in {"lead_app", "erpnext"} and "Service" in text and "Task" in text and re.search(r"(?:Service.{0,180}Task|Task.{0,180}Service|create.{0,80}task)", text, re.I | re.S):
                output["service_task_evidence"].append({"app": app, "path": rel, "line_numbers": [i + 1 for i, line in enumerate(lines) if "Service" in line or "Task" in line][:40]})
    for key in ("omc_task_dependencies", "lead_app_dependencies", "service_task_evidence"):
        output[key] = sorted(output[key], key=lambda x: (x.get("app", ""), x["path"]))
    return output


def _markdown(report: dict[str, Any]) -> str:
    lines = ["# OMC Live ERP Truth Inspection", "", f"Generated: `{report['generated_at']}`", f"Site: `{report['site']}`", "", "> Read-only inspection. Samples contain masked identifiers and state indicators only.", "", "## Installed applications", "", "| App | Installed | Version | Source path |", "|---|---:|---|---|"]
    for app in report["installed_apps"]:
        lines.append(f"| `{app['app']}` | {'Yes' if app['installed_on_site'] else 'No'} | `{app.get('version') or ''}` | `{app.get('source_path') or ''}` |")
    lines += ["", "## Production-safe counts", "", "| DocType | Total | Grouped by | States |", "|---|---:|---|---|"]
    for dt, data in report["statistics"].items():
        states = ", ".join(f"{x.get('state')}: {x.get('count')}" for x in data.get("states", []))
        lines.append(f"| `{dt}` | {data.get('total')} | `{data.get('grouped_by') or ''}` | {states} |")
    for dt, schema in report["schemas"].items():
        lines += ["", f"## {dt}", ""]
        if not schema.get("exists"):
            lines.append("Not present or inspection failed.")
            continue
        lines += ["| Field | Label | Type | Options | Required | Read only | Hidden | Custom |", "|---|---|---|---|---:|---:|---:|---:|"]
        for f in schema["fields"]:
            lines.append(f"| `{f['fieldname']}` | {f.get('label') or ''} | `{f.get('fieldtype') or ''}` | `{f.get('options') or ''}` | {'Yes' if f['required'] else 'No'} | {'Yes' if f['read_only'] else 'No'} | {'Yes' if f['hidden'] else 'No'} | {'Yes' if f['custom'] else 'No'} |")
        lines += ["", "Sanitized sample:", "", "```json", json.dumps(report["sanitized_samples"].get(dt), indent=2, default=str), "```"]
    lines += ["", "## Workflows", ""]
    for dt, workflows in report["workflows"].items():
        lines.append(f"### {dt}")
        if not workflows:
            lines.append("No Workflow document found.")
        for wf in workflows:
            lines.append(f"- `{wf['name']}` — {'active' if wf['active'] else 'inactive'}; state field `{wf.get('workflow_state_field')}`")
            lines.append("  - States: " + ", ".join(f"{x['state']} (docstatus {x['doc_status']})" for x in wf["states"]))
            lines.append("  - Transitions: " + "; ".join(f"{x['state']} → {x['action']} → {x['next_state']} [{x['allowed']}]" for x in wf["transitions"]))
    lines += ["", "## Relevant links", "", "| Source | Field | Type | Target/options |", "|---|---|---|---|"]
    for link in report["links"]:
        lines.append(f"| `{link['source_doctype']}` | `{link['fieldname']}` | `{link['fieldtype']}` | `{link.get('target_or_options') or ''}` |")
    for title, key in (("OMC Task backend dependencies", "omc_task_dependencies"), ("lead_app dependencies", "lead_app_dependencies"), ("Service ↔ Task source evidence", "service_task_evidence")):
        lines += ["", f"## {title}", ""]
        for item in report["source_scan"][key]:
            lines.append(f"- `{item.get('app', 'omc_app')}:{item['path']}`; lines {item['line_numbers']}; categories {item.get('categories', [])}")
    lines += ["", "## Safety", "", "- No inserts, updates, deletes, submits, cancels, migrations, schema changes, or ERP source changes are performed.", "- Only metadata reads, SELECT-style aggregate reads, source file reads, and report file writes are used.", "- Full customer data, secrets, credentials, private file contents, notes, documents, and financial values are excluded.", ""]
    return "\n".join(lines)


def run(output_dir: str | None = None) -> dict[str, Any]:
    """Generate sanitized JSON and Markdown reports; never mutate DocTypes or records."""
    schemas: dict[str, dict[str, Any]] = {}
    customizations: dict[str, dict[str, Any]] = {}
    statistics: dict[str, dict[str, Any]] = {}
    samples: dict[str, dict[str, Any] | None] = {}
    errors: list[dict[str, str]] = []
    apps = _apps()
    for doctype in DOCTYPES:
        try:
            schemas[doctype] = _schema(doctype)
            customizations[doctype] = _customizations(doctype) if schemas[doctype].get("exists") else {"custom_fields": [], "property_setters": []}
            statistics[doctype] = _stats(doctype, schemas[doctype])
            samples[doctype] = _sample(doctype, schemas[doctype])
        except Exception as exc:
            message = _error(exc)
            schemas[doctype] = {"doctype": doctype, "exists": None, "inspection_error": message}
            customizations[doctype] = {"custom_fields": [], "property_setters": []}
            statistics[doctype] = {"total": None, "grouped_by": None, "states": [], "inspection_error": message}
            samples[doctype] = None
            errors.append({"scope": f"doctype:{doctype}", "error": message})
    workflows = {}
    for doctype in WORKFLOW_DOCTYPES:
        try:
            workflows[doctype] = _workflows(doctype)
        except Exception as exc:
            workflows[doctype] = []
            errors.append({"scope": f"workflow:{doctype}", "error": _error(exc)})
    try:
        source_scan = _source_scan(apps)
    except Exception as exc:
        source_scan = {"scan_roots": {}, "omc_task_dependencies": [], "lead_app_dependencies": [], "service_task_evidence": []}
        errors.append({"scope": "source_scan", "error": _error(exc)})
    report = _safe({"report_version": 1, "generated_at": frappe.utils.now_datetime(), "site": frappe.local.site, "read_only": True, "installed_apps": apps, "schemas": schemas, "customizations": customizations, "workflows": workflows, "links": _links(schemas), "statistics": statistics, "sanitized_samples": samples, "source_scan": source_scan, "inspection_errors": errors})
    destination = Path(output_dir).expanduser().resolve() if output_dir else Path(frappe.get_site_path("private", "files")).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    stamp = frappe.utils.now_datetime().strftime("%Y%m%d_%H%M%S")
    json_path = destination / f"omc_live_erp_truth_{stamp}.json"
    markdown_path = destination / f"omc_live_erp_truth_{stamp}.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True, default=str), encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    return {"status": "report_generated_not_validated", "site": frappe.local.site, "json_report": str(json_path), "markdown_report": str(markdown_path), "inspection_errors": len(errors), "read_only": True}
