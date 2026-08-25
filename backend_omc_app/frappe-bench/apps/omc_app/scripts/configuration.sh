#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SCRIPT_VERSION="1.2.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_BENCH_DIR="$(cd "$APP_ROOT/../.." 2>/dev/null && pwd || true)"
REPORTER="$SCRIPT_DIR/configuration_report.py"

BENCH_DIR="${BENCH_DIR:-}"
SITE="${SITE_NAME:-}"
LEGACY_APP=""
ASSUME_YES=0
SKIP_LEGACY_APP=0
NO_RESTART=0
CURRENT_STEP="startup"
LOG_FILE=""
EVIDENCE_DIR=""
BENCH_CMD=""
BENCH_PYTHON=""
INSTALLED_APPS=()

usage() {
    cat <<'USAGE'
OMC production post-install configuration

Usage:
  ./scripts/configuration.sh [options]

Options:
  --bench PATH          Frappe Bench directory. Auto-detected when possible.
  --site SITE           Target site. Auto-selected when only one site exists.
  --legacy-app APP      Explicit legacy app to uninstall after OMC migration.
  --skip-legacy-app     Do not prompt for legacy app removal.
  --yes                 Skip the initial "CONFIGURE <site>" confirmation.
  --no-restart          Skip Bench restart after build/configuration.
  -h, --help            Show this help.

Environment alternatives:
  BENCH_DIR=/path/to/frappe-bench
  SITE_NAME=your.site.name

The script is safe to rerun. It uses OMC's idempotent migration/catalogue
operations and stops on failed compatibility, migration, catalogue or service
presentation validation.

Service catalogue synchronization atomically applies the managed service rows,
customer-facing short/long descriptions, support copy and Employee assignment
role in one database transaction.

Human-readable summaries are written to the main log. Full raw JSON command
outputs are preserved separately in a timestamped evidence directory.
USAGE
}

warn() {
    printf '\nWARNING: %s\n' "$*" >&2
}

fail() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

on_error() {
    local rc=$?
    printf '\n============================================================\n' >&2
    printf 'OMC CONFIGURATION STOPPED\n' >&2
    printf 'Step: %s\n' "$CURRENT_STEP" >&2
    printf 'Exit code: %s\n' "$rc" >&2
    if [[ -n "$LOG_FILE" ]]; then
        printf 'Log: %s\n' "$LOG_FILE" >&2
    fi
    if [[ -n "$EVIDENCE_DIR" ]]; then
        printf 'Raw evidence: %s\n' "$EVIDENCE_DIR" >&2
    fi
    printf 'Fix the reported issue, then rerun the script.\n' >&2
    printf 'Do not bypass failed ERP/catalogue safety checks.\n' >&2
    printf '============================================================\n' >&2
    exit "$rc"
}

trap on_error ERR

while (($#)); do
    case "$1" in
        --bench)
            [[ $# -ge 2 ]] || fail "--bench requires a path"
            BENCH_DIR="$2"
            shift 2
            ;;
        --site)
            [[ $# -ge 2 ]] || fail "--site requires a site name"
            SITE="$2"
            shift 2
            ;;
        --legacy-app)
            [[ $# -ge 2 ]] || fail "--legacy-app requires an app name"
            LEGACY_APP="$2"
            shift 2
            ;;
        --skip-legacy-app)
            SKIP_LEGACY_APP=1
            shift
            ;;
        --yes)
            ASSUME_YES=1
            shift
            ;;
        --no-restart)
            NO_RESTART=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

valid_bench() {
    local path="$1"
    [[ -d "$path/apps" ]] &&
        [[ -d "$path/sites" ]] &&
        [[ -f "$path/sites/apps.txt" ]] &&
        [[ -x "$path/env/bin/python" ]]
}

resolve_bench() {
    local candidate=""

    if [[ -n "$BENCH_DIR" ]]; then
        candidate="$BENCH_DIR"
    elif [[ -n "$DEFAULT_BENCH_DIR" ]] && valid_bench "$DEFAULT_BENCH_DIR"; then
        candidate="$DEFAULT_BENCH_DIR"
    elif valid_bench "$PWD"; then
        candidate="$PWD"
    fi

    while [[ -z "$candidate" ]] || ! valid_bench "$candidate"; do
        [[ -t 0 ]] || fail "Bench could not be auto-detected. Pass --bench /path/to/frappe-bench."
        printf 'Enter absolute Frappe Bench path: '
        read -r candidate
        [[ -n "$candidate" ]] || candidate=""
    done

    BENCH_DIR="$(cd "$candidate" && pwd)"
    BENCH_PYTHON="$BENCH_DIR/env/bin/python"

    if command -v bench >/dev/null 2>&1; then
        BENCH_CMD="$(command -v bench)"
    elif [[ -x "$HOME/.local/bin/bench" ]]; then
        BENCH_CMD="$HOME/.local/bin/bench"
    else
        fail "bench command is not available on PATH or at $HOME/.local/bin/bench"
    fi

    [[ -f "$REPORTER" ]] || fail "Configuration report helper is missing: $REPORTER"
}

select_site() {
    local sites=()
    local config=""
    local choice=""
    local index=1

    if [[ -n "$SITE" ]]; then
        [[ -f "$BENCH_DIR/sites/$SITE/site_config.json" ]] ||
            fail "Site does not exist in this Bench: $SITE"
        return 0
    fi

    while IFS= read -r config; do
        [[ -n "$config" ]] || continue
        sites+=("$(basename "$(dirname "$config")")")
    done < <(
        find "$BENCH_DIR/sites" \
            -mindepth 2 -maxdepth 2 \
            -type f -name site_config.json \
            -print | sort
    )

    ((${#sites[@]} > 0)) || fail "No Frappe sites were found in $BENCH_DIR/sites"

    if ((${#sites[@]} == 1)); then
        SITE="${sites[0]}"
        printf 'Detected site: %s\n' "$SITE"
        return 0
    fi

    [[ -t 0 ]] || fail "Multiple sites found. Pass --site <site>."

    printf '\nAvailable sites:\n'
    for config in "${sites[@]}"; do
        printf '  %d) %s\n' "$index" "$config"
        index=$((index + 1))
    done

    while true; do
        printf 'Choose target site [1-%d]: ' "${#sites[@]}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] &&
            ((choice >= 1 && choice <= ${#sites[@]})); then
            SITE="${sites[$((choice - 1))]}"
            return 0
        fi
        printf 'Please enter a valid number.\n'
    done
}

refresh_installed_apps() {
    local output=""

    output="$($BENCH_CMD --site "$SITE" list-apps)"
    printf '%s\n' "$output"

    INSTALLED_APPS=()
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        INSTALLED_APPS+=("${line%%[[:space:]]*}")
    done <<< "$output"
}

app_is_installed() {
    local wanted="$1"
    local app=""

    for app in "${INSTALLED_APPS[@]}"; do
        [[ "$app" == "$wanted" ]] && return 0
    done
    return 1
}

start_log() {
    local stamp=""
    stamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BENCH_DIR/logs"
    LOG_FILE="$BENCH_DIR/logs/omc-configuration-${SITE}-${stamp}.log"
    EVIDENCE_DIR="$BENCH_DIR/logs/omc-configuration-${SITE}-${stamp}-evidence"
    mkdir -p "$EVIDENCE_DIR"
    chmod 700 "$EVIDENCE_DIR"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

step() {
    CURRENT_STEP="$1"
    printf '\n============================================================\n'
    printf '%s\n' "$CURRENT_STEP"
    printf '============================================================\n'
}

capture_json() {
    local key="$1"
    local report_kind="$2"
    shift 2
    local output_file="$EVIDENCE_DIR/${key}.json"

    "$@" >"$output_file"
    "$BENCH_PYTHON" "$REPORTER" "$report_kind" "$output_file"
}

json_value() {
    local file="$1"
    local path="$2"

    "$BENCH_PYTHON" - "$file" "$path" <<'PY'
import json
import sys

filename, path = sys.argv[1], sys.argv[2]
text = open(filename, "r", encoding="utf-8", errors="replace").read().strip()

value = None
for line in reversed([line.strip() for line in text.splitlines() if line.strip()]):
    try:
        parsed = json.loads(line)
        if isinstance(parsed, dict):
            value = parsed
            break
    except Exception:
        pass

if value is None:
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        parsed = json.loads(text[start:end + 1])
        if isinstance(parsed, dict):
            value = parsed

if value is None:
    print("Could not parse bench execute JSON output.", file=sys.stderr)
    sys.exit(3)

for part in path.split(".") if path else []:
    if not isinstance(value, dict) or part not in value:
        print(f"Missing JSON path: {path}", file=sys.stderr)
        sys.exit(4)
    value = value[part]

if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))
else:
    print(value)
PY
}

backup_site() {
    local label="$1"
    step "Backup: $label"
    "$BENCH_CMD" --site "$SITE" backup --with-files
}

resolve_legacy_app() {
    local candidates=()
    local app=""
    local answer=""
    local choice=""
    local index=1

    if [[ -n "$LEGACY_APP" ]]; then
        case "$LEGACY_APP" in
            frappe|erpnext|omc_app)
                fail "Refusing to uninstall protected app: $LEGACY_APP"
                ;;
        esac
        app_is_installed "$LEGACY_APP" ||
            fail "Requested legacy app is not installed on $SITE: $LEGACY_APP"
        return 0
    fi

    ((SKIP_LEGACY_APP == 0)) || return 0

    for app in "${INSTALLED_APPS[@]}"; do
        case "$app" in
            frappe|erpnext|omc_app) ;;
            *) candidates+=("$app") ;;
        esac
    done

    ((${#candidates[@]} > 0)) || return 0

    if [[ ! -t 0 ]]; then
        warn "Additional apps exist but no --legacy-app was provided; no app will be removed."
        return 0
    fi

    printf '\nAdditional installed apps detected:\n'
    for app in "${candidates[@]}"; do
        printf '  %d) %s\n' "$index" "$app"
        index=$((index + 1))
    done

    printf 'Is one of these the old/legacy app that should be uninstalled from this site now? [y/N]: '
    read -r answer
    case "${answer,,}" in
        y|yes) ;;
        *) return 0 ;;
    esac

    while true; do
        printf 'Choose legacy app [1-%d]: ' "${#candidates[@]}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] &&
            ((choice >= 1 && choice <= ${#candidates[@]})); then
            LEGACY_APP="${candidates[$((choice - 1))]}"
            break
        fi
        printf 'Please enter a valid number.\n'
    done

    printf 'Type REMOVE %s to confirm uninstall: ' "$LEGACY_APP"
    read -r answer
    [[ "$answer" == "REMOVE $LEGACY_APP" ]] || {
        warn "Legacy app removal cancelled."
        LEGACY_APP=""
    }
}

resolve_bench
select_site
cd "$BENCH_DIR"

printf '\nOMC Configuration Script v%s\n' "$SCRIPT_VERSION"
printf 'Bench: %s\n' "$BENCH_DIR"
printf 'Site:  %s\n' "$SITE"
printf '\nInstalled apps:\n'
refresh_installed_apps

app_is_installed frappe || fail "frappe is not installed on $SITE"
app_is_installed erpnext || fail "erpnext is not installed on $SITE"
app_is_installed omc_app || fail "omc_app is not installed on $SITE. Install it first."

if ((ASSUME_YES == 0)); then
    [[ -t 0 ]] || fail "Non-interactive run requires --yes."
    printf '\nThis will back up and configure the existing site.\n'
    printf 'Type CONFIGURE %s to continue: ' "$SITE"
    read -r confirmation
    [[ "$confirmation" == "CONFIGURE $SITE" ]] || {
        printf 'Cancelled. No configuration changes were made by this script.\n'
        exit 0
    }
fi

start_log
printf 'Log:          %s\n' "$LOG_FILE"
printf 'Raw evidence: %s\n' "$EVIDENCE_DIR"

backup_site "before OMC post-install configuration"

step "Migrate OMC schema and clear cache"
"$BENCH_CMD" --site "$SITE" migrate
"$BENCH_CMD" --site "$SITE" clear-cache

step "Validate client ERP contract"
capture_json "01-erp-contract" "erp_contract" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.erp_contract.validate_client_erp_contract

step "Reconcile OMC-owned roles, Desk metadata, referral workspace and branding"
capture_json "02-initialize-site" "initialize" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.initialize_site

step "Read-only customer/staff migration preflight"
PRE_MIGRATION="$EVIDENCE_DIR/03-customer-preflight-before.json"
capture_json "03-customer-preflight-before" "migration_preflight" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.preflight

USER_ACCOUNTS_TO_CREATE="$(json_value "$PRE_MIGRATION" "user_accounts_to_create")"
[[ "$USER_ACCOUNTS_TO_CREATE" == "0" ]] ||
    fail "Migration preflight proposed customer User creation: $USER_ACCOUNTS_TO_CREATE"

backup_site "immediately before OMC historical-data migration"

step "Apply idempotent customer/staff/historical migration"
MIGRATION_APPLY="$EVIDENCE_DIR/04-customer-migration-apply.json"
capture_json "04-customer-migration-apply" "migration_apply" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.apply \
    --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'

USER_ACCOUNTS_CREATED="$(json_value "$MIGRATION_APPLY" "user_accounts_created")"
[[ "$USER_ACCOUNTS_CREATED" == "0" ]] ||
    fail "Migration unexpectedly created customer Users: $USER_ACCOUNTS_CREATED"

step "Post-migration read-only verification"
POST_MIGRATION="$EVIDENCE_DIR/05-customer-preflight-after.json"
capture_json "05-customer-preflight-after" "migration_preflight" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.preflight

POST_USER_ACCOUNTS="$(json_value "$POST_MIGRATION" "user_accounts_to_create")"
[[ "$POST_USER_ACCOUNTS" == "0" ]] ||
    fail "Post-migration preflight reports unexpected User creation: $POST_USER_ACCOUNTS"

step "Preview production service catalogue"
CATALOGUE_PREVIEW="$EVIDENCE_DIR/06-catalogue-preview.json"
capture_json "06-catalogue-preview" "catalogue_preview" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.preview_service_catalogue

READY_TO_SYNC="$(json_value "$CATALOGUE_PREVIEW" "ready_to_sync")"
[[ "$READY_TO_SYNC" == "true" ]] ||
    fail "Catalogue preview is not safe to sync. Review the preview blockers/conflicts in raw evidence."

step "Synchronize services, descriptions, support copy and Employee assignment"
CATALOGUE_SYNC="$EVIDENCE_DIR/07-catalogue-sync.json"
capture_json "07-catalogue-sync" "catalogue_sync" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.sync_service_catalogue

[[ "$(json_value "$CATALOGUE_SYNC" "presentation.validation.valid")" == "true" ]] ||
    fail "Service description/assignment synchronization did not validate."

step "Validate production service catalogue"
CATALOGUE_VALIDATE="$EVIDENCE_DIR/08-catalogue-validate.json"
capture_json "08-catalogue-validate" "catalogue_validate" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.validate_service_catalogue

CATALOGUE_VALID="$(json_value "$CATALOGUE_VALIDATE" "valid")"
[[ "$CATALOGUE_VALID" == "true" ]] ||
    fail "Catalogue validation did not converge to a valid state."

step "Validate service descriptions and assignment defaults"
PRESENTATION_VALIDATE="$EVIDENCE_DIR/09-service-presentation-validate.json"
capture_json "09-service-presentation-validate" "presentation_validate" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.service_catalogue.presentation.validate_service_presentation

[[ "$(json_value "$PRESENTATION_VALIDATE" "valid")" == "true" ]] ||
    fail "Service presentation validation failed."

step "Optional legacy app retirement selection"
refresh_installed_apps
resolve_legacy_app

if [[ -n "$LEGACY_APP" ]]; then
    backup_site "before uninstalling legacy app $LEGACY_APP"

    step "Uninstall legacy app from target site: $LEGACY_APP"
    "$BENCH_CMD" --site "$SITE" uninstall-app "$LEGACY_APP" --yes

    step "Migrate after legacy app removal"
    "$BENCH_CMD" --site "$SITE" migrate
    "$BENCH_CMD" --site "$SITE" clear-cache

    step "Revalidate ERP contract after legacy app removal"
    capture_json "10-post-legacy-erp-contract" "erp_contract" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.erp_contract.validate_client_erp_contract

    step "Reconcile OMC-owned configuration after legacy app removal"
    capture_json "11-post-legacy-initialize" "initialize" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.initialize_site

    step "Revalidate catalogue after legacy app removal"
    POST_LEGACY_VALIDATE="$EVIDENCE_DIR/12-catalogue-after-legacy.json"
    capture_json "12-catalogue-after-legacy" "catalogue_validate" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.validate_service_catalogue

    [[ "$(json_value "$POST_LEGACY_VALIDATE" "valid")" == "true" ]] ||
        fail "Catalogue became invalid after legacy app removal."

    step "Revalidate service presentation after legacy app removal"
    POST_LEGACY_PRESENTATION="$EVIDENCE_DIR/13-presentation-after-legacy.json"
    capture_json "13-presentation-after-legacy" "presentation_validate" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.service_catalogue.presentation.validate_service_presentation

    [[ "$(json_value "$POST_LEGACY_PRESENTATION" "valid")" == "true" ]] ||
        fail "Service presentation became invalid after legacy app removal."

    warn "Legacy app source folder was intentionally retained. Remove it only after confirming no other Bench site uses it."
fi

step "Enable scheduler"
"$BENCH_CMD" --site "$SITE" enable-scheduler

step "Build OMC assets and clear cache"
"$BENCH_CMD" build --app omc_app
"$BENCH_CMD" --site "$SITE" clear-cache

if ((NO_RESTART)); then
    warn "Bench restart skipped by --no-restart. Restart the production runtime before serving traffic."
elif [[ -f "$BENCH_DIR/config/supervisor.conf" ]] || command -v supervisorctl >/dev/null 2>&1; then
    step "Restart Bench production processes"
    "$BENCH_CMD" restart
else
    warn "Supervisor production configuration was not detected. Restart the runtime using the client's process manager before serving traffic."
fi

step "Final application and site verification"
refresh_installed_apps
capture_json "14-final-erp-contract" "erp_contract" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.erp_contract.validate_client_erp_contract

FINAL_CATALOGUE="$EVIDENCE_DIR/15-final-catalogue.json"
capture_json "15-final-catalogue" "catalogue_validate" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.validate_service_catalogue

[[ "$(json_value "$FINAL_CATALOGUE" "valid")" == "true" ]] ||
    fail "Final catalogue validation failed."

FINAL_PRESENTATION="$EVIDENCE_DIR/16-final-service-presentation.json"
capture_json "16-final-service-presentation" "presentation_validate" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.service_catalogue.presentation.validate_service_presentation

[[ "$(json_value "$FINAL_PRESENTATION" "valid")" == "true" ]] ||
    fail "Final service presentation validation failed."

"$BENCH_CMD" --site "$SITE" doctor

printf '\n============================================================\n'
printf 'OMC POST-INSTALL CONFIGURATION COMPLETED\n'
printf 'Site:         %s\n' "$SITE"
printf 'Log:          %s\n' "$LOG_FILE"
printf 'Raw evidence: %s\n' "$EVIDENCE_DIR"
printf '============================================================\n'
printf '\nStill required outside this script:\n'
printf '  - controlled app/browser/device smoke test\n'
printf '  - review any identity/blocker cases intentionally left for manual review\n'
printf '  - verify production URL, HTTPS, email/deep links and external integrations\n'
printf '\nFull automated backend test suites are intentionally NOT run on the production client site.\n'
