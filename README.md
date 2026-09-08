# OMC App — Frappe Backend

This directory is the authoritative custom Frappe application `omc_app` used by the OMC House mobile/customer platform.

Current client target:

```text
Frappe / ERPNext: v14
Python:           >=3.10
App name:         omc_app
```

OMC business logic belongs in this custom app. ERPNext/Frappe core source must not be patched for OMC behavior.

## Direct client installation from this repository

The development repository keeps Flutter and backend source together on `main`. A GitHub workflow publishes **this directory only** to the generated `frappe-app` branch, with this Frappe app at the branch root.

Do not edit `frappe-app` manually. Changes must be made here on `main`; the deployment branch is generated from this directory.

### First installation

From the client's existing Frappe Bench:

```bash
cd /home/frappe/frappe-bench

bench get-app --branch frappe-app \
  https://github.com/mshahwaiz-ali/omc_app.git

bench --site <site> install-app omc_app
```

For the current client Bench, replace `<site>` with the actual site name, for example `erp.omchouse.com`.

`bench get-app` owns the app placement and Python editable installation. Manual ZIP extraction, nested-folder copying, manual `pip install -e`, and manual edits to `sites/apps.txt` should not be required for a normal fresh fetch.

### Existing installed app update

```bash
cd /home/frappe/frappe-bench/apps/omc_app
git pull --ff-only origin frappe-app

cd /home/frappe/frappe-bench
bench --site <site> migrate
bench build --app omc_app
bench --site <site> clear-cache
bench restart
```

Always take the site's normal production backup before a production update.

### Explicit OMC post-install configuration

The app ships its guarded configuration/migration helper inside the app itself:

```bash
cd /home/frappe/frappe-bench/apps/omc_app
bash scripts/configuration.sh --site <site>
```

This is separate from `bench get-app`/`install-app`. Use it when the reviewed client handover requires OMC customer/staff migration, catalogue reconciliation, or other explicit setup operations. Routine future code updates normally use the migration/update flow above rather than rerunning historical setup blindly.

## Backend responsibilities

The app provides:

- customer onboarding, login and activation support;
- canonical customer mapping through `OMC Customer Account`;
- canonical internal authority through `OMC Staff Access`;
- capability, ownership and break-glass checks;
- service catalogue and service templates;
- payment-first service-request lifecycle;
- stable document requirements and uploads;
- payment/receipt workflow and ERP accounting reconciliation;
- durable ERP Service/Task activation;
- assignment and workflow automation;
- referrals and commission lifecycle;
- support, notifications, push delivery and customer settings;
- tax/expense tools;
- customer/staff migration and reconciliation;
- audit/security evidence;
- APIs consumed by Flutter.

## Canonical authority

Customer:

```text
Frappe Website User
        -> OMC Customer Account
              -> ERP Customer
              -> OMC Customer Profile compatibility link
```

Staff:

```text
Frappe System User
        -> OMC Staff Access
              -> explicit capabilities
              -> approval/reconciliation state
              -> optional scoped break-glass grants
```

`System Manager` is not implicit OMC business authority.

## Main package map

```text
omc_app/
├── api/                         # guarded APIs/workflows
├── omc_app/doctype/             # OMC DocTypes
├── patches/                     # controlled schema/data patches
├── setup/                       # lifecycle, permissions, catalogue, reconciliation
├── fixtures/
├── public/
├── hooks.py
└── README.md
```

The source-controlled service catalogue lives under:

```text
omc_app/setup/service_catalogue/
```

## Install and migrate lifecycle

Current hooks:

```text
before_install -> validate_site
after_install  -> initialize_site(commit=False)
after_migrate  -> validate_site only
```

Routine migration deliberately does not republish all business configuration or silently rewrite the service catalogue.

Explicit operator operations remain available through `omc_app.setup.operations`, including validation, permission repair, Desk synchronization, branding, tax seeds, task-type mappings, and service-catalogue preview/validate/sync.

## Service catalogue

Current source-controlled production manifest:

```text
9 categories
31 services
PKR
Omc House
Full Settlement default activation policy
```

Read-only preview and validation:

```bash
bench --site <site> execute omc_app.setup.operations.preview_service_catalogue
bench --site <site> execute omc_app.setup.operations.validate_service_catalogue
```

Explicit reconciliation:

```bash
bench --site <site> execute omc_app.setup.operations.sync_service_catalogue
```

## Validation

Backend regression suite:

```bash
cd /home/frappe/frappe-bench
bench --site <site> run-tests --app omc_app --skip-test-records
```

Latest locally verified complete OMC backend regression checkpoint on 8 September 2026:

```text
Ran 1028 tests
OK
```

## Security boundaries

- backend authorization is authoritative;
- unknown access fails closed;
- customers are ownership-scoped;
- staff actions require canonical capabilities/scopes;
- System Manager does not silently gain OMC authority;
- break-glass grants are explicit, temporary and scoped;
- sensitive mutations use guarded APIs;
- payment/accounting eligibility is rechecked before ERP activation;
- document identity cannot be bypassed by display labels;
- push tokens/bindings are account/device scoped;
- ERPNext/Frappe core remains untouched.

## Source and deployment relationship

```text
main
  backend_omc_app/frappe-bench/apps/omc_app/
                    |
                    | automatic publish
                    v
frappe-app branch (generated)
  pyproject.toml
  README.md
  omc_app/
  scripts/
  ...
                    |
                    v
client Bench get-app / install-app
```

This keeps one development source of truth and removes manual backend-folder copying.

## Related documentation

- repository overview: `../../../../README.md` on `main`;
- roles/capabilities: `../../../../docs/ROLE.md` on `main`;
- product feature guide: `../../../../docs/OMC_APP_FEATURES.md` on `main`;
- archived backend/deployment notes: `../../../docs/README.md` on `main`.
