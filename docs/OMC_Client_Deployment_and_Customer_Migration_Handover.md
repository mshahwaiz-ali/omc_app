# OMC App — Client Deployment & Existing-Customer Migration Handover

Source cross-check: **25 August 2026**, branch `main`.

This is the operator handover for deploying the supplied `omc_app` to the client's existing **Frappe / ERPNext v14** environment.

The recommended production path is now deliberately simple:

```text
Copy/register omc_app
    -> install omc_app on the site
    -> run the guarded OMC configuration script
    -> review the final summary and smoke-test the app
```

The configuration script handles the repetitive post-install commands, site selection, backups, migration, OMC setup reconciliation, customer/staff migration, production service-catalogue reconciliation, scheduler enablement, build/restart, and final backend validation.

> The script is intentionally fail-closed. It does not force-link ambiguous customer identities, does not create bulk customer login Users, does not bypass catalogue blockers, and does not automatically delete an arbitrary legacy app.

---

# Part A — Recommended Client Flow

## Step 1 — Open the client's existing Bench

```bash
cd /path/to/frappe-bench

bench list-sites
bench version
```

Confirm that this is the correct existing client **Frappe / ERPNext v14** Bench.

Do not create a replacement site or database for this deployment.

---

## Step 2 — Take a backup before installing the app

```bash
bench --site <site> backup --with-files
```

Keep the backup path recorded.

This is the recovery point before the new OMC app is installed on the site.

---

## Step 3 — Copy/register the supplied OMC app

Place the supplied app folder at:

```text
frappe-bench/apps/omc_app
```

Then:

```bash
cd /path/to/frappe-bench

./env/bin/pip install -e apps/omc_app
./env/bin/python -c "import omc_app; print('OMC App import: OK')"

grep -qxF 'omc_app' sites/apps.txt || echo 'omc_app' >> sites/apps.txt
```

---

## Step 4 — Install OMC App on the site

For a first installation:

```bash
bench --site <site> install-app omc_app
```

Confirm:

```bash
bench --site <site> list-apps
```

`omc_app` must appear.

If `omc_app` is already installed and this is only a code update, do **not** reinstall it.

---

## Step 5 — Run the OMC configuration script

The production script ships **inside the supplied OMC app folder**, so it remains available even when the client receives only `apps/omc_app` rather than the whole development repository.

Run:

```bash
cd /path/to/frappe-bench/apps/omc_app
bash scripts/configuration.sh
```

### Site selection

The script handles the site name itself:

- if the Bench contains exactly **one** site, it selects it automatically;
- if multiple sites exist, it displays a numbered selector;
- an operator may also specify the site explicitly:

```bash
bash scripts/configuration.sh --site your.site.name
```

Before mutation, the interactive script displays the selected Bench/site and requires:

```text
CONFIGURE <site>
```

This prevents a simple wrong-site Enter/typo from configuring the wrong database.

### Optional legacy app removal

After OMC historical migration and catalogue reconciliation, the script lists additional installed apps and can optionally let the operator select the old/legacy app for uninstall.

It **never** treats an unknown third-party app as disposable automatically.

For an already-reviewed exact legacy app name:

```bash
bash scripts/configuration.sh \
  --site your.site.name \
  --legacy-app OLD_APP_NAME
```

Or skip that prompt completely:

```bash
bash scripts/configuration.sh --skip-legacy-app
```

The script intentionally does **not** delete the legacy app source folder from the Bench because another site in the same Bench may still use it.

---

# Part B — What `configuration.sh` Does

The script performs the following sequence on the selected site.

## 1. Verify the target

It verifies that:

- the Bench is structurally valid;
- the target site exists;
- `frappe` is installed;
- `erpnext` is installed;
- `omc_app` is already installed.

If the Bench cannot be auto-detected, it asks for the absolute Bench path.

---

## 2. Take a full post-install backup

The script runs:

```bash
bench --site <site> backup --with-files
```

before the post-install migration/configuration sequence.

---

## 3. Migrate the OMC schema and clear cache

Equivalent manual commands:

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

`bench migrate` applies DocTypes, fields, indexes and registered data/schema patches.

It is **not** the historical customer migration and is **not** the service-catalogue publisher.

---

## 4. Validate the client ERP contract

The script runs the read-only compatibility check:

```bash
bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract
```

OMC depends on specific existing ERP Customer, Service, Task, Task Type, Sales Invoice and Payment Entry integration points.

If the contract fails, configuration stops. The script does not patch ERPNext source to make the check pass.

---

## 5. Reconcile OMC-owned site configuration

The script deliberately runs:

```bash
bench --site <site> execute \
  omc_app.setup.operations.initialize_site
```

This idempotently reconciles OMC-owned:

- canonical roles / DocPerm configuration;
- Desk/workspace metadata;
- referral workspace links;
- OMC branding;
- ERP compatibility validation.

A first `install-app omc_app` already invokes the same initialization through `after_install`, but running the explicit idempotent operation here makes the production configuration script safe for both fresh installations and updates/repairs.

---

## 6. Run customer/staff migration preflight

The script runs:

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

The current identity priority is:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The script verifies that:

```text
user_accounts_to_create = 0
```

Bulk historical customer migration is profile/account reconciliation only. Login User creation belongs to secure activation/claim flows.

Identity-review and row-level blockers are displayed and retained for review instead of being force-fixed.

---

## 7. Take another backup immediately before historical-data writes

The script takes a second full backup immediately before customer/staff/historical migration.

This is intentionally separate from the earlier installation/configuration backup.

---

## 8. Apply the idempotent OMC historical migration

Equivalent manual command:

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

The unified migration can reconcile:

- supported ERP staff into canonical `OMC Staff Access`;
- referral-capable staff registries;
- safely resolvable imported customer profiles;
- proven historical referral/acquisition attribution;
- supported historical ERP Service/Task projections.

It deliberately does **not**:

- bulk-create customer Frappe Users;
- create shared/default passwords;
- enable disabled Users;
- promote Website Users to System Users;
- overwrite explicit suspended/rejected staff authority;
- force-link ambiguous customer identities;
- fabricate historical referral/commission provenance.

The script checks again that:

```text
user_accounts_created = 0
```

---

## 9. Re-run migration preflight

The script repeats the read-only migration preflight after apply so the run log contains the post-migration reconciliation state.

The migration is designed to be idempotent; safe existing records are reused on rerun.

---

## 10. Preview the source-controlled service catalogue

The script runs:

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

Current production manifest:

```text
9 categories
31 services
17 active
14 inactive / review-required
currency: PKR
company: Omc House
default activation policy: Full Settlement
```

The script refuses to sync unless:

```text
ready_to_sync = true
```

Therefore missing/ambiguous exact ERP Task Types, unsafe price changes, in-flight requirement conflicts, or other catalogue blockers stop the automated path.

---

## 11. Sync and validate the catalogue

When the preview is safe, the script runs:

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

It requires final catalogue validation to report:

```text
valid = true
```

The catalogue provisioner is designed to be atomic and idempotent, preserve non-owned service configuration, protect in-flight requests and historical pricing, and map only exact existing ERP Task Types.

---

## 12. Optionally uninstall the old/legacy app

The script reaches this stage **only after** OMC historical migration and catalogue reconciliation.

That ordering is intentional because historical migration may use old ERP/legacy evidence such as referenced Lead identity fields or existing staff persona data.

If the operator selects a legacy app, the script:

1. refuses to remove `frappe`, `erpnext`, or `omc_app`;
2. takes another full backup;
3. uninstalls only the explicitly selected app from the target site;
4. runs `bench migrate` and cache clear;
5. validates the ERP contract again;
6. reruns OMC site initialization;
7. validates the service catalogue again.

If post-removal validation fails, the script stops and the pre-removal backup is the recovery point.

### Why the source folder is not deleted automatically

A Bench can host multiple sites. Another site may still depend on that app source.

Therefore `configuration.sh` handles **site uninstall**, but source-folder deletion remains a separate operator decision after confirming that no Bench site needs the old app.

---

## 13. Enable the scheduler

The script runs:

```bash
bench --site <site> enable-scheduler
```

OMC uses scheduled jobs for background operational processing, including bridge/outbox work and scheduled maintenance.

---

## 14. Build assets and clear cache

Equivalent commands:

```bash
bench build --app omc_app
bench --site <site> clear-cache
```

---

## 15. Restart the production runtime when Supervisor is detected

When the Bench/Supervisor production configuration is detected, the script runs:

```bash
bench restart
```

If the client uses another process manager, the script warns rather than guessing how that environment should be restarted.

For controlled cases, restart can be suppressed with:

```bash
bash scripts/configuration.sh --no-restart
```

but the runtime must then be restarted manually before production traffic is considered ready.

---

## 16. Final backend validation

The script finishes with:

- installed-app listing;
- ERP contract validation;
- service-catalogue validation;
- `bench --site <site> doctor`.

A timestamped log is stored under:

```text
frappe-bench/logs/omc-configuration-<site>-<timestamp>.log
```

The script prints the log path at completion or on failure.

---

# Part C — What Is Intentionally Not Automated

## Full backend test suite on the live production site

The production configuration script does **not** run:

```bash
bench --site <site> run-tests --app omc_app --skip-test-records
```

The full regression suite belongs on the development/restored/test environment, not as an automatic mutation-heavy step on the live client production database.

The latest directly observed development validation before this handover refresh was:

```text
Backend OMC suite: 932 / 932 passed
```

Production still requires smoke testing against the deployed environment.

---

## Tax calculator business-data seeds

Optional tax-calculator/business-rental seed operations are **not** executed automatically.

Tax configuration is business/regulatory data and should only be installed when the intended tax-year/slab configuration has been deliberately reviewed.

---

## Arbitrary fix scripts

`configuration.sh` does not execute an unknown external fix script automatically.

If a release requires a specifically reviewed repair script, its exact file, arguments, path assumptions, idempotency and rollback behavior must be reviewed for that release before it is added to the deployment sequence.

---

## Legacy app source-folder deletion

The script does not `rm -rf apps/<legacy_app>`.

Site uninstall and Bench source deletion are separate decisions because a Bench may host more than one site.

---

# Part D — Manual Fallback Commands

If the configuration script cannot be used, the equivalent core sequence is:

```bash
cd /path/to/frappe-bench
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

bench --site "$SITE" enable-scheduler
bench build --app omc_app
bench --site "$SITE" clear-cache
bench restart

bench --site "$SITE" execute \
  omc_app.setup.erp_contract.validate_client_erp_contract

bench --site "$SITE" execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site "$SITE" doctor
```

Legacy-app uninstall remains conditional and should be performed only after the exact old app has been identified and a pre-removal backup exists.

---

# Part E — Stop Conditions

Stop and investigate if any of these occurs:

- the wrong Bench/site appears selected;
- `omc_app` is not installed;
- a backup fails;
- `bench migrate` fails;
- ERP contract validation fails;
- migration proposes or reports customer User creation;
- customer migration exits unexpectedly;
- catalogue preview reports `ready_to_sync = false`;
- catalogue validation reports `valid = false`;
- an unexpected app is selected for uninstall;
- ERP contract/catalogue validation fails after legacy-app removal;
- scheduler/doctor reports unresolved production problems;
- build/restart fails;
- the ERP site stops loading.

Do not bypass these failures with manual database edits or ERPNext source patches.

---

# Part F — Final Production Checklist

After `configuration.sh` completes, verify:

- [ ] correct client site was selected;
- [ ] all script backups completed;
- [ ] `omc_app` remains installed;
- [ ] ERP contract validation is clean;
- [ ] customer/staff migration completed or left only understood review cases;
- [ ] no bulk customer login Users were created;
- [ ] service catalogue is valid;
- [ ] scheduler is enabled;
- [ ] assets were built;
- [ ] production processes were restarted/reloaded;
- [ ] `bench doctor` is healthy;
- [ ] ERP/Frappe site opens normally;
- [ ] customer login / existing-customer activation works;
- [ ] service catalogue loads;
- [ ] required-document upload works;
- [ ] payment/receipt workflow works;
- [ ] accounting settlement gates ERP activation correctly;
- [ ] protected internal workspace requires valid OMC Staff Access/capability;
- [ ] support/notification flows work;
- [ ] production URL and HTTPS are correct;
- [ ] email / activation deep links work;
- [ ] remaining manual identity-review cases are recorded rather than force-linked.

At that point the OMC backend configuration is ready for controlled production use.