#!/usr/bin/env bash
set -euo pipefail

# Retire the two broken custom_gst_category metadata definitions without
# dropping business-data columns. Safe to rerun after the fix is applied.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_DIR="${BENCH_DIR:-$REPO_ROOT/backend_omc_app/frappe-bench}"
SITE_NAME="${SITE_NAME:-omc.local}"
MODE="dry-run"

usage() {
  cat <<'EOF'
Usage: scripts/erp_fixes.sh [--dry-run] [--apply] [--site SITE]

  --dry-run    Validate and report the exact changes without writing (default).
  --apply      Back up, apply, migrate, clear cache, and verify the fix.
  --site SITE  Frappe site name (default: omc.local or SITE_NAME).
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --site)
      (($# >= 2)) || fail "--site requires a value"
      SITE_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

PYTHON_BIN="$BENCH_DIR/env/bin/python"
BENCH_BIN="$BENCH_DIR/env/bin/bench"
if [[ ! -x "$BENCH_BIN" ]]; then
  BENCH_BIN="$(command -v bench || true)"
fi
SITES_DIR="$BENCH_DIR/sites"
SUPPLIER_JSON="$BENCH_DIR/apps/erpnext/erpnext/buying/doctype/supplier/supplier.json"
CUSTOMER_JSON="$BENCH_DIR/apps/erpnext/erpnext/selling/custom/customer.json"
RECOVERY_PY="$BENCH_DIR/apps/omc_app/omc_app/maintenance/recover_accidental_erpnext_metadata.py"

[[ -x "$PYTHON_BIN" ]] || fail "Bench Python not found: $PYTHON_BIN"
[[ -n "$BENCH_BIN" && -x "$BENCH_BIN" ]] || fail "bench command not found"
[[ -d "$SITES_DIR/$SITE_NAME" ]] || fail "Site not found: $SITES_DIR/$SITE_NAME"
for required_file in "$SUPPLIER_JSON" "$CUSTOMER_JSON" "$RECOVERY_PY"; do
  [[ -f "$required_file" ]] || fail "Required file not found: $required_file"
done

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$SITES_DIR/$SITE_NAME/private/backups/omc_erp_fixes_${timestamp}_$$"

echo "OMC ERP metadata fix"
echo "  mode:  $MODE"
echo "  site:  $SITE_NAME"
echo "  bench: $BENCH_DIR"

if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$BACKUP_DIR"
  cp -p "$SUPPLIER_JSON" "$BACKUP_DIR/supplier.json"
  cp -p "$CUSTOMER_JSON" "$BACKUP_DIR/customer.json"
  cp -p "$RECOVERY_PY" "$BACKUP_DIR/recover_accidental_erpnext_metadata.py"
  echo "  backup: $BACKUP_DIR"
fi

"$PYTHON_BIN" - "$MODE" "$SUPPLIER_JSON" "$CUSTOMER_JSON" "$RECOVERY_PY" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys

mode, supplier_path, customer_path, recovery_path = sys.argv[1:]
fieldname = "custom_gst_category"


def load(path: str):
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))


def save(path: str, data):
    pathlib.Path(path).write_text(
        json.dumps(data, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )


supplier = load(supplier_path)
supplier_fields = [
    field for field in supplier.get("fields", []) if field.get("fieldname") == fieldname
]
supplier_order_count = supplier.get("field_order", []).count(fieldname)
if len(supplier_fields) > 1 or supplier_order_count > 1:
    raise SystemExit("Supplier contains duplicate custom_gst_category metadata; refusing to guess.")
if supplier_fields:
    expected = {"fieldtype": "Link", "options": "GST Category"}
    if any(supplier_fields[0].get(key) != value for key, value in expected.items()):
        raise SystemExit("Supplier custom_gst_category differs from the expected broken Link field.")

customer = load(customer_path)
customer_fields = [
    field for field in customer.get("custom_fields", []) if field.get("fieldname") == fieldname
]
if len(customer_fields) > 1:
    raise SystemExit("Customer contains duplicate custom_gst_category definitions; refusing to guess.")
if customer_fields and customer_fields[0].get("fieldtype") != "Data":
    raise SystemExit("Customer custom_gst_category differs from the expected Data field.")

property_setters = customer.get("property_setters", [])
customer_order_references = 0
for setter in property_setters:
    if setter.get("property") != "field_order":
        continue
    try:
        order = json.loads(setter.get("value") or "[]")
    except (TypeError, ValueError) as error:
        raise SystemExit(f"Customer field_order property setter is invalid JSON: {error}")
    customer_order_references += order.count(fieldname)
if customer_order_references > 1:
    raise SystemExit("Customer field_order contains duplicate GST references; refusing to guess.")

recovery = pathlib.Path(recovery_path).read_text(encoding="utf-8")
column_line = '    ("Customer", "custom_gst_category"),\n'
column_count = recovery.count(column_line)
marker = '"name": "Customer-custom_gst_category"'
marker_count = recovery.count(marker)
if column_count > 1 or marker_count > 1:
    raise SystemExit("OMC recovery metadata contains duplicate GST definitions; refusing to guess.")

changes = {
    "supplier_field": bool(supplier_fields),
    "supplier_field_order": bool(supplier_order_count),
    "customer_custom_field": bool(customer_fields),
    "customer_field_order": bool(customer_order_references),
    "omc_recovery_column": bool(column_count),
    "omc_recovery_definition": bool(marker_count),
}
print("Source preflight:", json.dumps(changes, sort_keys=True))

if mode != "apply":
    raise SystemExit(0)

supplier["fields"] = [
    field for field in supplier.get("fields", []) if field.get("fieldname") != fieldname
]
supplier["field_order"] = [
    item for item in supplier.get("field_order", []) if item != fieldname
]

customer["custom_fields"] = [
    field for field in customer.get("custom_fields", []) if field.get("fieldname") != fieldname
]
for setter in property_setters:
    if setter.get("property") != "field_order":
        continue
    order = json.loads(setter.get("value") or "[]")
    setter["value"] = json.dumps([item for item in order if item != fieldname])

if column_count:
    recovery = recovery.replace(column_line, "", 1)
if marker_count:
    marker_index = recovery.index(marker)
    block_start = recovery.rfind("    {\n", 0, marker_index)
    if block_start < 0:
        raise SystemExit("Could not locate the Customer recovery definition start.")
    cursor = block_start
    depth = 0
    block_end = None
    while cursor < len(recovery):
        if recovery[cursor] == "{":
            depth += 1
        elif recovery[cursor] == "}":
            depth -= 1
            if depth == 0:
                block_end = cursor + 1
                while block_end < len(recovery) and recovery[block_end] in ",\n":
                    block_end += 1
                break
        cursor += 1
    if block_end is None:
        raise SystemExit("Could not locate the Customer recovery definition end.")
    recovery = recovery[:block_start] + recovery[block_end:]

save(supplier_path, supplier)
save(customer_path, customer)
pathlib.Path(recovery_path).write_text(recovery, encoding="utf-8")
print("Source metadata updated.")
PY

export OMC_ERP_FIX_SITE="$SITE_NAME"
export OMC_ERP_FIX_MODE="$MODE"
export OMC_ERP_FIX_BACKUP_DIR="$BACKUP_DIR"
(
  cd "$SITES_DIR"
  "$PYTHON_BIN" <<'PY'
from __future__ import annotations

import json
import os
import pathlib

import frappe

site = os.environ["OMC_ERP_FIX_SITE"]
mode = os.environ["OMC_ERP_FIX_MODE"]
backup_dir = pathlib.Path(os.environ["OMC_ERP_FIX_BACKUP_DIR"])
fieldname = "custom_gst_category"

frappe.init(site=site)
frappe.connect()
try:
    custom_fields = frappe.get_all(
        "Custom Field",
        filters={"dt": ["in", ["Customer", "Supplier"]], "fieldname": fieldname},
        fields=["name", "dt", "fieldname", "fieldtype", "options", "insert_after"],
    )
    docfields = frappe.get_all(
        "DocField",
        filters={"parent": "Supplier", "fieldname": fieldname},
        fields=["name", "parent", "fieldname", "fieldtype", "options", "idx"],
    )
    setter = frappe.db.get_value(
        "Property Setter",
        {"doc_type": "Customer", "property": "field_order"},
        ["name", "value"],
        as_dict=True,
    )
    setter_references = 0
    if setter:
        setter_references = json.loads(setter.value or "[]").count(fieldname)
    state = {
        "custom_fields": custom_fields,
        "supplier_docfields": docfields,
        "customer_field_order_references": setter_references,
    }
    print("Database preflight:", json.dumps(state, default=str, sort_keys=True))
    if mode != "apply":
        raise SystemExit(0)

    backup_dir.mkdir(parents=True, exist_ok=True)
    (backup_dir / "database_metadata.json").write_text(
        json.dumps(state, default=str, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    frappe.db.delete(
        "Custom Field",
        {"dt": ["in", ["Customer", "Supplier"]], "fieldname": fieldname},
    )
    frappe.db.delete(
        "DocField",
        {"parent": "Supplier", "fieldname": fieldname},
    )
    if setter and setter_references:
        order = json.loads(setter.value or "[]")
        frappe.db.set_value(
            "Property Setter",
            setter.name,
            "value",
            json.dumps([item for item in order if item != fieldname]),
            update_modified=False,
        )
    frappe.db.commit()
    frappe.clear_cache(doctype="Customer")
    frappe.clear_cache(doctype="Supplier")
    print("Database metadata updated; data columns were not dropped.")
finally:
    frappe.destroy()
PY
)

if [[ "$MODE" != "apply" ]]; then
  echo "Dry-run complete. Run with --apply to perform these exact changes."
  exit 0
fi

(
  cd "$BENCH_DIR"
  "$BENCH_BIN" --site "$SITE_NAME" migrate
  "$BENCH_BIN" --site "$SITE_NAME" clear-cache
)

(
  cd "$SITES_DIR"
  "$PYTHON_BIN" <<'PY'
import json
import os

import frappe

site = os.environ["OMC_ERP_FIX_SITE"]
fieldname = "custom_gst_category"
frappe.init(site=site)
frappe.connect()
try:
    result = {
        "customer_custom_field": bool(
            frappe.db.exists("Custom Field", {"dt": "Customer", "fieldname": fieldname})
        ),
        "supplier_custom_field": bool(
            frappe.db.exists("Custom Field", {"dt": "Supplier", "fieldname": fieldname})
        ),
        "supplier_docfield": bool(
            frappe.db.exists("DocField", {"parent": "Supplier", "fieldname": fieldname})
        ),
        "customer_meta_field": bool(frappe.get_meta("Customer").has_field(fieldname)),
        "supplier_meta_field": bool(frappe.get_meta("Supplier").has_field(fieldname)),
    }
    print("Post-fix verification:", json.dumps(result, sort_keys=True))
    if any(result.values()):
        raise SystemExit("GST metadata verification failed; inspect the backup before retrying.")
finally:
    frappe.destroy()
PY
)

echo "ERP GST metadata fix completed successfully."
echo "Backup retained at: $BACKUP_DIR"
