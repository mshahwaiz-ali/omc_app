#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_BENCH_DIR="$(cd "$APP_ROOT/../.." 2>/dev/null && pwd || true)"

BENCH_DIR="${BENCH_DIR:-}"
SITE="${SITE_NAME:-}"
LEGACY_APP=""
ERP_CUSTOMER_GROUP="${ERP_CUSTOMER_GROUP:-}"
ERP_TERRITORY="${ERP_TERRITORY:-}"
ASSUME_YES=0
SKIP_LEGACY_APP=0
NO_RESTART=0
CURRENT_STEP="startup"
LOG_FILE=""
TEMP_DIR=""
BENCH_CMD=""
BENCH_PYTHON=""
INSTALLED_APPS=()
SELECTED_OPTION=""

usage() {
    cat <<'USAGE'
OMC production post-install configuration

Usage:
  ./scripts/configuration.sh [options]

Options:
  --bench PATH              Frappe Bench directory. Auto-detected when possible.
  --site SITE               Target site. Auto-selected when only one site exists.
  --customer-group NAME     Existing ERP Customer Group for new OMC customers.
  --territory NAME          Existing ERP Territory for new OMC customers.
  --legacy-app APP          Explicit legacy app to uninstall after OMC migration.
  --skip-legacy-app         Do not prompt for legacy app removal.
  --yes                     Skip the initial "CONFIGURE <site>" confirmation.
  --no-restart              Skip Bench restart after build/configuration.
  -h, --help                Show this help.

Environment alternatives:
  BENCH_DIR=/path/to/frappe-bench
  SITE_NAME=your.site.name
  ERP_CUSTOMER_GROUP="Individual"
  ERP_TERRITORY="Pakistan"

Existing Selling Settings values are preserved. If either ERP Customer default
is missing, interactive runs offer only values that already exist in ERPNext.
Non-interactive runs must provide missing defaults explicitly.

The script is safe to rerun. It uses OMC's idempotent migration/catalogue
operations and stops on failed compatibility or catalogue validation.
USAGE
}

info() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf '\nWARNING: %s\n' "$*" >&2
}

fail() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
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
    printf 'Fix the reported issue, then rerun the script.\n' >&2
    printf 'Do not bypass failed ERP/catalogue safety checks.\n' >&2
    printf '============================================================\n' >&2
    exit "$rc"
}

trap cleanup EXIT
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
        --customer-group)
            [[ $# -ge 2 ]] || fail "--customer-group requires an existing Customer Group name"
            ERP_CUSTOMER_GROUP="$2"
            shift 2
            ;;
        --territory)
            [[ $# -ge 2 ]] || fail "--territory requires an existing Territory name"
            ERP_TERRITORY="$2"
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
}

select_site() {
    local configs=()
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
        configs+=("$config")
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
    mkdir -p "$BENCH_DIR/logs"
    LOG_FILE="$BENCH_DIR/logs/omc-configuration-${SITE}-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

step() {
    CURRENT_STEP="$1"
    printf '\n============================================================\n'
    printf '%s\n' "$CURRENT_STEP"
    printf '============================================================\n'
}

capture_json() {
    local output_file="$1"
    shift
    "$@" | tee "$output_file"
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
        value = json.loads(line)
        break
    except Exception:
        pass

if value is None:
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            value = json.loads(text[start:end + 1])
        except Exception:
            value = None

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

json_array_lines() {
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
        value = json.loads(line)
        break
    except Exception:
        pass

if value is None:
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        value = json.loads(text[start:end + 1])

for part in path.split(".") if path else []:
    value = value[part]

if not isinstance(value, list):
    raise SystemExit(f"JSON path is not a list: {path}")

for item in value:
    print(str(item))
PY
}

option_exists() {
    local wanted="$1"
    shift
    local option=""
    for option in "$@"; do
        [[ "$option" == "$wanted" ]] && return 0
    done
    return 1
}

choose_existing_option() {
    local label="$1"
    local current="$2"
    local explicit="$3"
    local json_file="$4"
    local json_path="$5"
    local preferred="$6"
    local options=()
    local option=""
    local choice=""
    local index=1

    SELECTED_OPTION=""
    mapfile -t options < <(json_array_lines "$json_file" "$json_path")
    ((${#options[@]} > 0)) || fail "No existing ERP $label records are available."

    if [[ -n "$explicit" ]]; then
        option_exists "$explicit" "${options[@]}" ||
            fail "$label does not exist in ERPNext: $explicit"
        SELECTED_OPTION="$explicit"
        return 0
    fi

    if [[ -n "$current" ]]; then
        option_exists "$current" "${options[@]}" ||
            fail "Current Selling Settings $label does not exist: $current"
        SELECTED_OPTION="$current"
        return 0
    fi

    [[ -t 0 ]] ||
        fail "Selling Settings $label is empty. Provide the corresponding command-line option."

    printf '\nSelling Settings %s is empty.\n' "$label"

    if ((${#options[@]} <= 20)); then
        printf 'Existing ERP %s options:\n' "$label"
        for option in "${options[@]}"; do
            printf '  %d) %s\n' "$index" "$option"
            index=$((index + 1))
        done

        while true; do
            printf 'Choose %s [1-%d]: ' "$label" "${#options[@]}"
            read -r choice
            if [[ "$choice" =~ ^[0-9]+$ ]] &&
                ((choice >= 1 && choice <= ${#options[@]})); then
                SELECTED_OPTION="${options[$((choice - 1))]}"
                return 0
            fi
            printf 'Please enter a valid number.\n'
        done
    fi

    printf '%d existing ERP %s records are available.\n' "${#options[@]}" "$label"
    if [[ -n "$preferred" ]] && option_exists "$preferred" "${options[@]}"; then
        printf 'Broad existing option available: %s\n' "$preferred"
    fi
    printf 'Enter an exact existing name, or type LIST to display all values.\n'

    while true; do
        printf '%s: ' "$label"
        read -r choice
        if [[ "$choice" == "LIST" ]]; then
            for option in "${options[@]}"; do
                printf '  - %s\n' "$option"
            done
            continue
        fi
        if option_exists "$choice" "${options[@]}"; then
            SELECTED_OPTION="$choice"
            return 0
        fi
        printf 'That value does not exist. Enter an exact existing name or LIST.\n'
    done
}

backup_site() {
    local label="$1"
    step "Backup: $label"
    "$BENCH_CMD" --site "$SITE" backup --with-files
}

configure_customer_defaults_if_needed() {
    local inspect_file="$TEMP_DIR/erp-customer-defaults-before.json"
    local after_file="$TEMP_DIR/erp-customer-defaults-after.json"
    local current_group=""
    local current_territory=""
    local target_group=""
    local target_territory=""
    local kwargs=""

    capture_json "$inspect_file" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.inspect_erp_customer_defaults

    current_group="$(json_value "$inspect_file" "customer_group")"
    current_territory="$(json_value "$inspect_file" "territory")"

    choose_existing_option \
        "customer_group" \
        "$current_group" \
        "$ERP_CUSTOMER_GROUP" \
        "$inspect_file" \
        "customer_group_options" \
        "Individual"
    target_group="$SELECTED_OPTION"

    choose_existing_option \
        "territory" \
        "$current_territory" \
        "$ERP_TERRITORY" \
        "$inspect_file" \
        "territory_options" \
        "Pakistan"
    target_territory="$SELECTED_OPTION"

    if [[ "$target_group" != "$current_group" || "$target_territory" != "$current_territory" ]]; then
        kwargs="$($BENCH_PYTHON - "$target_group" "$target_territory" <<'PY'
import json
import sys
print(json.dumps({"customer_group": sys.argv[1], "territory": sys.argv[2]}))
PY
)"
        "$BENCH_CMD" --site "$SITE" execute \
            omc_app.setup.operations.configure_erp_customer_defaults \
            --kwargs "$kwargs"
    else
        printf 'Existing ERP Customer defaults preserved: %s / %s\n' \
            "$target_group" "$target_territory"
    fi

    capture_json "$after_file" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.inspect_erp_customer_defaults

    [[ "$(json_value "$after_file" "ok")" == "true" ]] ||
        fail "ERP Customer defaults are still incomplete after configuration."

    printf 'ERP Customer defaults ready:\n'
    printf '  Customer Group: %s\n' "$(json_value "$after_file" "customer_group")"
    printf '  Territory:      %s\n' "$(json_value "$after_file" "territory")"
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

TEMP_DIR="$(mktemp -d)"
start_log

printf 'Log:   %s\n' "$LOG_FILE"

backup_site "before OMC post-install configuration"

step "Migrate OMC schema and clear cache"
"$BENCH_CMD" --site "$SITE" migrate
"$BENCH_CMD" --site "$SITE" clear-cache

step "Validate client ERP contract"
"$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.erp_contract.validate_client_erp_contract

step "Verify ERP Customer creation defaults"
configure_customer_defaults_if_needed

step "Revalidate client ERP contract after ERP Customer defaults"
"$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.erp_contract.validate_client_erp_contract

step "Reconcile OMC-owned roles, Desk metadata, referral workspace and branding"
"$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.initialize_site

step "Read-only customer/staff migration preflight"
PRE_MIGRATION="$TEMP_DIR/customer-preflight-before.json"
capture_json "$PRE_MIGRATION" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.preflight

USER_ACCOUNTS_TO_CREATE="$(json_value "$PRE_MIGRATION" "user_accounts_to_create")"
[[ "$USER_ACCOUNTS_TO_CREATE" == "0" ]] ||
    fail "Migration preflight proposed customer User creation: $USER_ACCOUNTS_TO_CREATE"

printf '\nMigration preflight summary:\n'
printf '  activation-ready imports: %s\n' "$(json_value "$PRE_MIGRATION" "activation_ready_import")"
printf '  deferred claim-on-signup:  %s\n' "$(json_value "$PRE_MIGRATION" "deferred_claim_on_signup")"
printf '  identity review:           %s\n' "$(json_value "$PRE_MIGRATION" "identity_review")"
printf '  blocker counts:            %s\n' "$(json_value "$PRE_MIGRATION" "blocker_counts")"
printf '  warning counts:            %s\n' "$(json_value "$PRE_MIGRATION" "warning_counts")"

backup_site "immediately before OMC historical-data migration"

step "Apply idempotent customer/staff/historical migration"
MIGRATION_APPLY="$TEMP_DIR/customer-apply.json"
capture_json "$MIGRATION_APPLY" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.apply \
    --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'

USER_ACCOUNTS_CREATED="$(json_value "$MIGRATION_APPLY" "user_accounts_created")"
[[ "$USER_ACCOUNTS_CREATED" == "0" ]] ||
    fail "Migration unexpectedly created customer Users: $USER_ACCOUNTS_CREATED"

step "Post-migration read-only verification"
POST_MIGRATION="$TEMP_DIR/customer-preflight-after.json"
capture_json "$POST_MIGRATION" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.api.customer_migration.preflight

POST_USER_ACCOUNTS="$(json_value "$POST_MIGRATION" "user_accounts_to_create")"
[[ "$POST_USER_ACCOUNTS" == "0" ]] ||
    fail "Post-migration preflight reports unexpected User creation: $POST_USER_ACCOUNTS"

step "Preview production service catalogue"
CATALOGUE_PREVIEW="$TEMP_DIR/catalogue-preview.json"
capture_json "$CATALOGUE_PREVIEW" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.preview_service_catalogue

READY_TO_SYNC="$(json_value "$CATALOGUE_PREVIEW" "ready_to_sync")"
[[ "$READY_TO_SYNC" == "true" ]] ||
    fail "Catalogue preview is not safe to sync. Review the preview blockers/conflicts above."

step "Synchronize production service catalogue"
"$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.sync_service_catalogue

step "Validate production service catalogue"
CATALOGUE_VALIDATE="$TEMP_DIR/catalogue-validate.json"
capture_json "$CATALOGUE_VALIDATE" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.validate_service_catalogue

CATALOGUE_VALID="$(json_value "$CATALOGUE_VALIDATE" "valid")"
[[ "$CATALOGUE_VALID" == "true" ]] ||
    fail "Catalogue validation did not converge to a valid state."

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
    "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.erp_contract.validate_client_erp_contract

    step "Reconcile OMC-owned configuration after legacy app removal"
    "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.initialize_site

    step "Revalidate catalogue after legacy app removal"
    POST_LEGACY_VALIDATE="$TEMP_DIR/catalogue-after-legacy.json"
    capture_json "$POST_LEGACY_VALIDATE" \
        "$BENCH_CMD" --site "$SITE" execute \
        omc_app.setup.operations.validate_service_catalogue

    POST_LEGACY_VALID="$(json_value "$POST_LEGACY_VALIDATE" "valid")"
    [[ "$POST_LEGACY_VALID" == "true" ]] ||
        fail "Catalogue became invalid after legacy app removal."

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
"$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.erp_contract.validate_client_erp_contract

FINAL_DEFAULTS="$TEMP_DIR/erp-customer-defaults-final.json"
capture_json "$FINAL_DEFAULTS" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.inspect_erp_customer_defaults
[[ "$(json_value "$FINAL_DEFAULTS" "ok")" == "true" ]] ||
    fail "Final ERP Customer defaults validation failed."

FINAL_CATALOGUE="$TEMP_DIR/catalogue-final.json"
capture_json "$FINAL_CATALOGUE" \
    "$BENCH_CMD" --site "$SITE" execute \
    omc_app.setup.operations.validate_service_catalogue

FINAL_VALID="$(json_value "$FINAL_CATALOGUE" "valid")"
[[ "$FINAL_VALID" == "true" ]] || fail "Final catalogue validation failed."

"$BENCH_CMD" --site "$SITE" doctor

printf '\n============================================================\n'
printf 'OMC POST-INSTALL CONFIGURATION COMPLETED\n'
printf 'Site: %s\n' "$SITE"
printf 'Log:  %s\n' "$LOG_FILE"
printf '============================================================\n'
printf '\nStill required outside this script:\n'
printf '  - controlled app/browser/device smoke test\n'
printf '  - review any identity/blocker cases intentionally left for manual review\n'
printf '  - verify production URL, HTTPS, email/deep links and external integrations\n'
printf '\nFull automated backend test suites are intentionally NOT run on the production client site.\n'
