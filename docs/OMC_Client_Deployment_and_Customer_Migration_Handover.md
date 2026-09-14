# OMC App — Client Deployment & Existing-Customer Migration Handover

Source cross-check: **14 September 2026**, branch `main`.

This is the current operator handover for installing or updating the custom `omc_app` on the client's existing **Frappe / ERPNext v14** environment and running the guarded OMC post-install reconciliation safely.

> **Deployment rule:** preserve the existing ERPNext site, install/update only the custom OMC app, take backups before risk boundaries, run the guarded configuration workflow, and do not patch ERPNext/Frappe core.

---

# 1. Source and deployment model

The development source of truth is the repository `main` branch.

The backend app lives under:

```text
backend_omc_app/frappe-bench/apps/omc_app/
```

GitHub Actions publishes that backend subtree automatically to the generated deployment branch:

```text
frappe-app
```

The generated branch contains the Frappe app at repository root and is intended for normal Bench installation/update.

Do not manually edit `frappe-app`; changes belong on `main`.

---

# 2. Preferred fresh-install path

From the client's existing Bench:

```bash
cd /home/frappe/frappe-bench

bench --site <site> backup --with-files

bench get-app --branch frappe-app \
  https://github.com/mshahwaiz-ali/omc_app.git

bench --site <site> install-app omc_app
```

Verify:

```bash
bench --site <site> list-apps
```

`omc_app` must appear in the installed-app list.

For the current client environment, `<site>` may be `erp.omchouse.com`; always confirm the actual production site before running commands.

Do not create a replacement site or database just to install OMC.

---

# 3. Existing installed-app update

If `omc_app` is already installed, do not reinstall it.

Update the generated backend branch in the existing app checkout:

```bash
cd /home/frappe/frappe-bench/apps/omc_app
git pull --ff-only origin frappe-app

cd /home/frappe/frappe-bench
bench --site <site> backup --with-files
bench --site <site> migrate
bench build --app omc_app
bench --site <site> clear-cache
bench restart
```

Use the site's actual production process-manager procedure if `bench restart` is not the correct runtime command for that host.

---

# 4. Guarded post-install configuration

The backend app ships the production post-install helper:

```text
apps/omc_app/scripts/configuration.sh
```

Current script version at this documentation cross-check:

```text
1.3.0
```

Preferred invocation:

```bash
cd /home/frappe/frappe-bench/apps/omc_app
bash scripts/configuration.sh --site <site>
```

The script can auto-detect a Bench/site when safe, but an explicit site is preferred on production systems.

Supported operator options include:

```text
--bench PATH
--site SITE
--legacy-app APP
--skip-legacy-app
--yes
--no-restart
```

Interactive production runs require explicit confirmation:

```text
CONFIGURE <site>
```

The script is designed to be rerunnable and fail closed.

---

# 5. What `configuration.sh` currently performs

The current script performs these guarded phases in order.

## 5.1 Target validation

It verifies:

- valid Frappe Bench;
- target site exists;
- `frappe` is installed;
- `erpnext` is installed;
- `omc_app` is installed.

It refuses to continue on an invalid target.

## 5.2 Backup before configuration

```bash
bench --site <site> backup --with-files
```

Failure to create the backup stops the run.

## 5.3 Schema migration and cache clear

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

This applies OMC schema/patches. It does not by itself perform the historical customer migration or silently publish the service catalogue.

## 5.4 ERP compatibility validation

```bash
bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract
```

OMC validates the ERP integration contract it depends on. Compatibility failure stops the run; the script does not patch ERPNext core to force compatibility.

## 5.5 OMC-owned initialization

```bash
bench --site <site> execute \
  omc_app.setup.operations.initialize_site
```

This reconciles OMC-owned setup such as roles/permissions, Desk metadata, referral workspace integration and branding.

## 5.6 Read-only customer/staff migration preflight

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

The identity strategy uses deterministic ERP evidence and leaves ambiguous identities for review rather than guessing.

The migration must not propose mass customer login-user creation.

The script requires:

```text
user_accounts_to_create = 0
```

## 5.7 Backup before historical-data writes

A second full backup is taken immediately before migration apply.

## 5.8 Idempotent customer/staff/historical migration

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

The migration can reconcile supported:

- existing ERP Customers into OMC customer/account/profile state;
- trusted ERP staff into canonical `OMC Staff Access`;
- supported Employee/persona evidence;
- referral-capable staff records;
- supported historical attribution/projection evidence.

It deliberately does not:

- mass-create customer Frappe Users;
- create shared/default passwords;
- enable disabled Users;
- promote Website Users to System Users;
- override deliberate staff suspension/rejection;
- force-link ambiguous customers;
- fabricate unsupported referral/commission history.

The script verifies after apply that:

```text
user_accounts_created = 0
```

## 5.9 Post-migration read-only verification

The migration preflight runs again to confirm the reconciled state remains safe and rerunnable.

## 5.10 Service-catalogue preview

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

The source-controlled catalogue currently contains:

```text
9 categories
31 services
```

Use preview output as the authority for exact active/inactive and managed-row counts on the target release/site.

The script requires:

```text
ready_to_sync = true
```

No fuzzy ERP Task Type matching or silent Task Type creation is allowed.

## 5.11 Atomic service-catalogue synchronization

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

The managed service layer includes service configuration plus customer-facing presentation/assignment data managed by the current catalogue code.

Catalogue publishing is explicit. Normal `bench migrate` is not the catalogue publisher.

## 5.12 Catalogue validation

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

The run stops unless the catalogue converges to a valid state.

## 5.13 Service presentation validation

```bash
bench --site <site> execute \
  omc_app.setup.service_catalogue.presentation.validate_service_presentation
```

The managed customer-facing presentation and assignment defaults must validate.

## 5.14 App-ready defaults preview

The current configuration script also manages source-controlled app-ready defaults:

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_app_defaults
```

Preview must report safe synchronization before any write is allowed.

App-ready defaults cover source-controlled application configuration such as supported mobile content/workflow/default data managed by the current setup layer.

Client/runtime-owned secrets, users, payment/bank details and transaction records are intentionally outside this ownership boundary.

## 5.15 App-ready defaults synchronization

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_app_defaults
```

The synchronization must validate successfully.

## 5.16 App-ready defaults validation

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_app_defaults
```

The run stops if managed defaults do not converge.

## 5.17 Optional legacy-app retirement

Legacy app retirement is optional and occurs only after OMC migration/catalogue/default reconciliation.

Protected apps are never valid retirement targets:

```text
frappe
erpnext
omc_app
```

If a legacy app is explicitly selected, the script takes another backup before uninstalling it from the target site.

The legacy source folder is not deleted automatically because another Bench site may still depend on it.

## 5.18 Scheduler

```bash
bench --site <site> enable-scheduler
```

## 5.19 Asset build and cache clear

```bash
bench build --app omc_app
bench --site <site> clear-cache
```

## 5.20 Runtime restart

If Supervisor production configuration is detected, the script can run:

```bash
bench restart
```

Otherwise it warns the operator to restart using the client's actual process manager.

`--no-restart` is for controlled rehearsal only; production traffic must not continue indefinitely on stale runtime processes.

## 5.21 Final verification

The script performs final application/site validation and preserves command evidence for audit/debugging.

---

# 6. Logging and evidence

The script writes a human-readable main log:

```text
frappe-bench/logs/omc-configuration-<site>-<timestamp>.log
```

It also creates a restricted raw evidence directory:

```text
frappe-bench/logs/omc-configuration-<site>-<timestamp>-evidence/
```

The raw evidence contains complete command outputs used for migration/catalogue/default validation.

Treat this directory as operationally sensitive because migration evidence can contain customer/staff identifiers.

---

# 7. Current customer/service architecture to verify after deployment

## Customer identity

ERPNext `Customer` remains the ERP business customer master.

OMC uses its own canonical authentication bridge/account/profile records for mobile access without replacing ERP Customer authority.

Historical migration is not a recurring synchronization command that must be rerun whenever the linked customer later receives a new Service Request, document, payment or Task.

Once canonical relationships exist, normal runtime workflows continue using those relationships.

## Service execution

The intended production contract is:

```text
One OMC Service Request
        -> payment/accounting eligibility
        -> durable activation bridge
        -> ERP Service
        -> exactly one authoritative ERP Task
```

The OMC Service Request is customer-facing lifecycle state.

The ERP Task is internal operational work and must not be exposed to customers as their service record.

## Payment authority

For a positive-price Full Settlement service:

```text
required-document eligibility
        -> payment/receipt workflow
        -> ERP accounting evidence
        -> settlement reconciliation
        -> activation eligibility
```

Receipt review alone must not manually force final Paid/settled state.

ERP accounting reconciliation remains authoritative.

## Reusable documents

The current document engine supports policy-driven reuse of approved prior documents.

Current reuse is restricted by backend rules including:

- same canonical customer;
- same service;
- matching stable document requirement;
- approved source evidence;
- configured reuse policy;
- validity period where applicable;
- eligible replacement/archive state.

Supported policies are:

```text
Always New
Reusable Until Replaced
Reusable for N Days
```

`Always New` remains the safe default.

At the current source baseline, catalogue provisioning does not itself assign `reuse_policy` or `reuse_validity_days`; deployment should therefore verify the actual configured required-document policies if reuse is expected for a service.

Reusable evidence satisfies document eligibility only. It does not bypass payment or settlement.

---

# 8. Production smoke test

After configuration and runtime restart, verify at minimum:

- ERP/Frappe site opens normally;
- `omc_app` remains installed;
- customer login/activation works;
- service catalogue loads correctly;
- service detail/presentation content is correct;
- customer can create a Service Request;
- required-document upload works;
- qualifying configured reusable evidence appears as already satisfied/on file;
- reused evidence can be replaced with a fresh upload where supported;
- payment/receipt workflow works;
- receipt review alone does not falsely settle payment;
- ERP accounting reconciliation gates activation correctly;
- activation creates/resolves exactly one authoritative ERP Task for the request;
- customer tracking uses Service Request state and does not expose internal ERP Task details;
- eligible staff assignment/task visibility follows Staff Access capability/scope;
- support/notification flows work;
- production URL, HTTPS, email and deep links are correct.

---

# 9. Manual fallback sequence

Use this only when `configuration.sh` cannot be used and the operator understands each guarded step.

```bash
cd /home/frappe/frappe-bench
SITE="your.site.name"

bench --site "$SITE" backup --with-files
bench --site "$SITE" migrate
bench --site "$SITE" clear-cache

bench --site "$SITE" execute \
  omc_app.setup.erp_contract.validate_client_erp_contract

bench --site "$SITE" execute \
  omc_app.setup.operations.initialize_site

bench --site "$SITE" execute \
  omc_app.api.customer_migration.preflight

bench --site "$SITE" backup --with-files

bench --site "$SITE" execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'

bench --site "$SITE" execute \
  omc_app.api.customer_migration.preflight

bench --site "$SITE" execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site "$SITE" execute \
  omc_app.setup.operations.sync_service_catalogue

bench --site "$SITE" execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site "$SITE" execute \
  omc_app.setup.service_catalogue.presentation.validate_service_presentation

bench --site "$SITE" execute \
  omc_app.setup.operations.preview_app_defaults

bench --site "$SITE" execute \
  omc_app.setup.operations.sync_app_defaults

bench --site "$SITE" execute \
  omc_app.setup.operations.validate_app_defaults

bench --site "$SITE" enable-scheduler
bench build --app omc_app
bench --site "$SITE" clear-cache
```

Restart the production runtime using the correct process-manager procedure for the host.

Do not use manual fallback to bypass a blocker reported by the guarded script.

---

# 10. Recovery model

The configuration workflow fails closed but does not automatically restore production data.

Backups are created around the main risk boundaries so rollback remains an explicit operator decision.

If a stage fails:

1. stop at the failure;
2. retain the main log and evidence directory;
3. identify the actual blocker;
4. prefer correcting the blocker and rerunning idempotent OMC reconciliation when safe;
5. restore from the relevant recorded backup only when explicit rollback is required.

Do not bypass failed checks using direct database edits or ERPNext source patches.

---

# 11. Stop conditions

Stop and investigate if any of the following occurs:

- wrong Bench or site selected;
- `omc_app` missing from installed apps;
- backup failure;
- migration failure;
- ERP compatibility failure;
- customer migration proposes/creates unexpected login Users;
- catalogue preview is not safe to sync;
- catalogue sync/validation failure;
- presentation validation failure;
- app-default preview is unsafe;
- app-default sync/validation failure;
- unexpected legacy app selected;
- build/restart failure;
- final site/runtime health problem;
- ERP site stops loading normally.

---

# 12. Final production checklist

- [ ] correct Bench/site confirmed;
- [ ] pre-install/update backup exists;
- [ ] `omc_app` installed from the correct deployment source;
- [ ] ERP contract validates;
- [ ] OMC initialization completes;
- [ ] customer/staff migration converges without bulk login-user creation;
- [ ] service catalogue preview/sync/validation succeeds;
- [ ] service presentation validation succeeds;
- [ ] app-ready defaults preview/sync/validation succeeds;
- [ ] scheduler enabled;
- [ ] assets built;
- [ ] production runtime restarted/reloaded;
- [ ] configuration log retained;
- [ ] raw evidence retained securely;
- [ ] customer login/activation smoke test works;
- [ ] service request/document/payment flow works;
- [ ] configured reusable-document behavior works;
- [ ] ERP settlement gating works;
- [ ] one-request/one-Task activation contract works;
- [ ] customers do not see internal ERP Task records;
- [ ] staff scope/assignment works;
- [ ] support/notification flow works;
- [ ] production URL/HTTPS/email/deep links verified.

---

# Final deployment rule

```text
Backup
  -> install/update omc_app
  -> run configuration.sh
  -> review guarded migration/catalogue/app-default results
  -> restart runtime
  -> smoke-test production
```

Do not replace this with ad-hoc database edits, ERPNext core changes, or a shortened sequence that skips backups, preflight or validation.
