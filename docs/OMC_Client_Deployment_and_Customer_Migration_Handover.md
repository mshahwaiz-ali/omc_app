# OMC App — Client Deployment & Existing-Customer Migration Handover

Source cross-check: **25 August 2026**, branch `main`.

This document is the operator handover for installing the supplied `omc_app` on the client's existing **Frappe / ERPNext v14** environment and converting the existing ERP customer/staff data into the OMC application model safely.

The preferred production path is intentionally simple:

```text
Copy/register omc_app
    -> install omc_app on the correct site
    -> run apps/omc_app/scripts/configuration.sh
    -> review the completion summary
    -> perform controlled production smoke tests
```

The configuration script is the executable version of the post-install process described below. It is designed to be rerunnable and fail closed instead of asking the operator to execute a long list of migration commands manually.

---

# Part A — Clean Client Steps

## 1. Open the existing client Bench

```bash
cd /path/to/frappe-bench

bench list-sites
bench version
```

Confirm:

- this is the correct production Bench;
- the intended client site is present;
- the environment is the existing ERPNext v14 installation;
- you are **not** creating a replacement site or database.

---

## 2. Take a full backup before installing OMC

```bash
bench --site <site> backup --with-files
```

Record the generated backup paths. This is the recovery point before the OMC app is installed.

---

## 3. Place and register the supplied OMC app

Place the supplied app folder at:

```text
frappe-bench/apps/omc_app
```

Then from the Bench root:

```bash
./env/bin/pip install -e apps/omc_app
./env/bin/python -c "import omc_app; print('OMC App import: OK')"

grep -qxF 'omc_app' sites/apps.txt || echo 'omc_app' >> sites/apps.txt
```

---

## 4. Install OMC on the site

For a first installation:

```bash
bench --site <site> install-app omc_app
```

Confirm:

```bash
bench --site <site> list-apps
```

`omc_app` must appear in the installed-app list.

If this is only a code update and `omc_app` is already installed, do **not** reinstall it.

---

## 5. Run the guarded OMC configuration script

The production script ships inside the OMC app folder:

```bash
cd /path/to/frappe-bench/apps/omc_app
bash scripts/configuration.sh
```

That is the preferred client command after installation.

### Site selection

The script handles the site name safely:

- one site in the Bench -> selected automatically;
- multiple sites -> numbered site selector;
- explicit site is also supported:

```bash
bash scripts/configuration.sh --site your.site.name
```

Before any configuration write, the script shows the selected Bench/site and requires:

```text
CONFIGURE <site>
```

### Known legacy app

Do **not** remove the old/legacy app before OMC historical migration has finished.

If the exact legacy app name has already been reviewed:

```bash
bash scripts/configuration.sh \
  --site your.site.name \
  --legacy-app OLD_APP_NAME
```

To leave legacy-app retirement for later:

```bash
bash scripts/configuration.sh \
  --site your.site.name \
  --skip-legacy-app
```

The script never treats `frappe`, `erpnext`, or `omc_app` as removable legacy apps.

---

## 6. Review the final script result

Successful completion ends with:

```text
OMC POST-INSTALL CONFIGURATION COMPLETED
```

The script prints two paths:

```text
Log:          .../logs/omc-configuration-<site>-<timestamp>.log
Raw evidence: .../logs/omc-configuration-<site>-<timestamp>-evidence/
```

The **main log is human-readable**. Large machine JSON is not dumped into the operator log anymore.

The **raw evidence directory** retains the actual complete outputs of migration, catalogue and validation commands for audit/debugging. The script creates that directory with restricted permissions.

---

## 7. Perform the production smoke test

After the script succeeds and the runtime has been restarted, verify at minimum:

- ERP/Frappe site opens normally;
- customer login/activation works;
- service catalogue loads;
- service short and detailed descriptions display correctly;
- service support guidance displays correctly;
- service requests can be submitted;
- required-document upload works;
- payment/receipt workflow works;
- accounting settlement gates activation correctly;
- an activated service request can be assigned to an eligible **Employee**;
- staff workspace/case visibility follows Staff Access capabilities;
- support and notification flows work;
- production URL, HTTPS and email/deep links are correct.

---

# Part B — What `configuration.sh` Performs

The following is the exact post-install workflow automated by the script.

## 1. Target validation

The script verifies:

- a valid Frappe Bench was found;
- the target site exists;
- `frappe` is installed;
- `erpnext` is installed;
- `omc_app` is installed.

It then requires the explicit `CONFIGURE <site>` confirmation unless the operator deliberately uses `--yes`.

---

## 2. Full post-install backup

Before the post-install mutation sequence:

```bash
bench --site <site> backup --with-files
```

Failure to create this backup stops the run.

---

## 3. Schema migration and cache clear

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

This applies OMC DocTypes/schema/registered patches. It is **not** the historical customer migration and does **not** by itself publish the production service catalogue.

---

## 4. ERP compatibility contract

The script executes:

```bash
bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract
```

OMC validates the ERP integration points it relies on, including Customer, Service, Task, Task Type, Sales Invoice and Payment Entry contracts.

A compatibility failure stops the run. OMC does not patch ERPNext source to force compatibility.

Warnings are shown in the formatted report and should be reviewed; they are not silently converted into unrelated ERP business-setting changes by the deployment script.

---

## 5. OMC-owned site initialization

```bash
bench --site <site> execute \
  omc_app.setup.operations.initialize_site
```

This idempotently reconciles OMC-owned:

- canonical roles and DocPerm configuration;
- Desk/workspace metadata;
- referral workspace links;
- branding;
- ERP compatibility validation.

The operation is safe to rerun and does not seed unrelated tax/business data.

---

## 6. Customer/staff migration preflight

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

This stage is read-only.

The identity strategy is designed to use deterministic ERP evidence and leave ambiguous records for review rather than guessing.

Current identity priority:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The configuration script requires:

```text
user_accounts_to_create = 0
```

Historical customer migration does not mass-create customer login Users or shared/default passwords.

The formatted console report shows the important totals only, including:

- total ERP customers;
- safely identifiable customers;
- activation-ready imports;
- claim-on-signup deferrals;
- identity-review rows;
- profile create/reuse counts;
- blocker/warning counts;
- historical Service/Task projection status.

Full samples/details remain available in the raw evidence file.

---

## 7. Second backup before historical-data writes

Immediately before migration apply:

```bash
bench --site <site> backup --with-files
```

This provides a clean recovery boundary between site setup and bulk historical reconciliation.

---

## 8. Unified customer/staff/historical migration

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

The migration can safely reconcile:

- existing ERP customers into OMC customer profile/account structures where identity is deterministic;
- supported ERP staff into canonical `OMC Staff Access`;
- Employee persona from supported ERP evidence;
- referral-capable staff registries;
- proven historical referral attribution;
- supported historical ERP Service/Task projections.

It deliberately does **not**:

- bulk-create customer Frappe Users;
- create common/default passwords;
- enable disabled Users;
- promote Website Users to System Users;
- override deliberate staff suspension/rejection;
- force-link ambiguous customers;
- fabricate referral or commission history.

After apply, the script requires:

```text
user_accounts_created = 0
```

---

## 9. Post-migration read-only verification

The same migration preflight runs again after apply.

This captures the converged state and confirms that the safe migration is rerunnable/idempotent.

---

## 10. Production service-catalogue preview

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

Current source-controlled catalogue baseline:

```text
9 categories
31 exact ERP Task Type mapped services
17 active
14 inactive / review-required
93 required-document templates
62 service form fields
195 managed catalogue objects
currency: PKR
company: Omc House
default activation policy: Full Settlement
```

The script refuses to synchronize unless:

```text
ready_to_sync = true
```

No fuzzy Task Type matching or silent Task Type creation is used.

---

## 11. Atomic service catalogue + customer-facing service setup

The script runs:

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

This operation now treats a production service as more than just its price/title mapping.

For all 31 source-controlled OMC services it also reconciles:

- a service-specific **short description**;
- a service-specific **detailed description**;
- a service-specific **support message**;
- `default_assignment_role = Employee`.

The descriptions are written as clear customer-facing sales/service copy: they explain the practical value of using OMC, reduce uncertainty and highlight the benefit of organized professional handling without promising a guaranteed legal/tax outcome or inventing an unsupported deadline.

### Why Employee is the default assignment role

OMC staff reconciliation already supports the canonical ERP persona:

```text
Employee
```

An eligible Employee must still be:

- an enabled System User;
- represented by approved/current `OMC Staff Access`;
- valid under the canonical staff reconciliation model.

Assignment chooses from the eligible Employee pool using least-loaded assignment. If no eligible Employee exists, the existing controlled Manager fallback remains available instead of assigning to an invalid user.

Legacy assignment-role values remain readable for compatibility, but source-controlled services converge to `Employee`.

### Transaction boundary

Catalogue writes and service presentation/assignment writes are committed as **one transaction** through the OMC setup operation.

If the description/support/assignment layer cannot validate, the combined sync is rolled back rather than leaving newly created services only partially configured.

---

## 12. Catalogue and presentation validation

The script validates the base catalogue:

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

and the managed customer-facing service layer:

```bash
bench --site <site> execute \
  omc_app.setup.service_catalogue.presentation.validate_service_presentation
```

The run stops unless both converge cleanly.

For the presentation layer, final validation requires all managed services to have the source-controlled descriptions/support copy and the Employee assignment default.

---

## 13. Optional legacy app retirement

Legacy app retirement occurs only **after** historical migration and catalogue reconciliation.

That order is intentional because old ERP/legacy data may contain identity or attribution evidence required during migration.

If an operator explicitly selects a legacy app, the script:

1. refuses protected apps (`frappe`, `erpnext`, `omc_app`);
2. takes another full backup;
3. uninstalls only the selected app from the target site;
4. runs `bench migrate` and clears cache;
5. validates the ERP contract again;
6. reruns OMC initialization;
7. validates catalogue and service presentation again.

The legacy app **source folder is not deleted automatically**. A Bench can host multiple sites, so another site may still depend on that source.

---

## 14. Scheduler

```bash
bench --site <site> enable-scheduler
```

OMC uses scheduled/background operations for operational recovery and processing.

---

## 15. Asset build and cache clear

```bash
bench build --app omc_app
bench --site <site> clear-cache
```

---

## 16. Production process restart

When Supervisor production configuration is detected, the script runs:

```bash
bench restart
```

If Supervisor is not detected, the script does not guess a custom process-manager command; it warns that the runtime must be restarted using the client's actual production process manager.

For controlled rehearsal only:

```bash
bash scripts/configuration.sh --no-restart
```

Do not use `--no-restart` as an excuse to serve production traffic without restarting the runtime afterward.

---

## 17. Final verification

The final automated checks include:

- installed-app listing;
- ERP contract validation;
- catalogue validation;
- service descriptions/support/Employee assignment validation;
- `bench --site <site> doctor`.

The script then prints the human log and raw-evidence paths.

---

# Part C — Logging and Evidence

## Human-readable main log

Path pattern:

```text
frappe-bench/logs/omc-configuration-<site>-<timestamp>.log
```

Large migration JSON is summarized into sections such as:

```text
Migration preflight
-------------------
  Total ERP customers             ...
  Safely identifiable             ...
  Activation-ready imports        ...
  Deferred claim-on-signup        ...
  Identity review                 ...
  Customer Users to create        0
  Blockers                        ...
  Warnings                        ...
```

Catalogue output is summarized in the same style, including the count of services whose descriptions/support/Employee assignment were updated.

## Raw command evidence

Path pattern:

```text
frappe-bench/logs/omc-configuration-<site>-<timestamp>-evidence/
```

This directory contains the full raw outputs used by the script for validation, including migration samples and catalogue details.

It exists so the main operator log remains readable **without losing the actual command evidence** needed for troubleshooting or audit.

Because migration output can contain customer/staff identifiers, the evidence directory is created with restricted permissions and should be handled as operationally sensitive data.

---

# Part D — Manual Fallback Sequence

Use this only if `configuration.sh` cannot be used.

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

bench --site "$SITE" execute \
  omc_app.setup.service_catalogue.presentation.validate_service_presentation

bench --site "$SITE" enable-scheduler
bench build --app omc_app
bench --site "$SITE" clear-cache
bench restart

bench --site "$SITE" execute \
  omc_app.setup.erp_contract.validate_client_erp_contract

bench --site "$SITE" execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site "$SITE" execute \
  omc_app.setup.service_catalogue.presentation.validate_service_presentation

bench --site "$SITE" doctor
```

Legacy-app uninstall remains conditional and belongs after migration/catalogue convergence with a fresh pre-removal backup.

---

# Part E — Recovery and Rollback Model

`configuration.sh` is **fail closed**, but it does not blindly restore a production database automatically.

Automatic restore is intentionally avoided because a restore rewinds database/files state and should remain an explicit operator decision.

Recovery points are created before the main risk boundaries:

```text
1. before OMC installation              -> manual pre-install backup
2. before post-install configuration    -> script backup
3. before historical migration writes   -> script backup
4. before legacy app uninstall           -> script backup, if retirement is selected
```

If a stage fails:

1. stop at the failure;
2. retain the main log and raw-evidence directory;
3. identify whether the failed operation is safely rerunnable;
4. prefer correcting the blocker and rerunning idempotent OMC reconciliation when appropriate;
5. use the relevant recorded backup only when an explicit rollback is required.

Do not bypass a failed safety check with direct database edits or ERPNext source patches.

---

# Part F — What the Script Intentionally Does Not Do

The production configuration script does **not** automatically:

- run the full backend regression suite against the live customer database;
- seed optional tax-calculator or business/rental tax schedules;
- invent missing prices, tax rates or regulatory rules;
- force-link ambiguous customer identities;
- create bulk customer login Users/passwords;
- enable disabled users;
- change arbitrary ERPNext business settings merely to silence a warning;
- execute an unknown external fix script;
- remove a legacy app source folder with `rm -rf`;
- modify ERPNext source code.

These boundaries are deliberate.

---

# Part G — Stop Conditions

Stop and investigate if any of the following occurs:

- wrong Bench or site is selected;
- `omc_app` is not installed;
- any required backup fails;
- `bench migrate` fails;
- ERP compatibility fails;
- migration proposes customer User creation;
- migration unexpectedly creates customer Users;
- migration command exits unexpectedly;
- catalogue preview returns `ready_to_sync = false`;
- catalogue synchronization fails;
- catalogue validation returns `valid = false`;
- service presentation validation fails;
- a managed service is missing during description/assignment reconciliation;
- an unexpected legacy app is selected;
- post-legacy-removal ERP/catalogue validation fails;
- asset build or runtime restart fails;
- `bench doctor` reports an unresolved production problem;
- the ERP site stops loading correctly.

---

# Part H — Final Production Checklist

After a successful script run:

- [ ] correct client site was selected;
- [ ] pre-install backup exists;
- [ ] script backups completed;
- [ ] `omc_app` is installed;
- [ ] ERP contract is compatible;
- [ ] OMC roles/permissions/Desk/branding reconciled;
- [ ] customer/staff migration completed or left only understood review cases;
- [ ] no bulk customer login Users were created;
- [ ] historical referral/service evidence was preserved or explicitly left for review;
- [ ] 31-service catalogue reconciled safely;
- [ ] managed services have short descriptions;
- [ ] managed services have detailed descriptions;
- [ ] managed services have service-specific support messages;
- [ ] managed services default to `Employee` assignment;
- [ ] eligible Employee assignment works with Manager fallback if necessary;
- [ ] required-document templates and form fields are valid;
- [ ] scheduler is enabled;
- [ ] OMC assets were built;
- [ ] production runtime was restarted/reloaded;
- [ ] final catalogue and service-presentation validations are clean;
- [ ] `bench doctor` is healthy;
- [ ] human-readable configuration log is retained;
- [ ] raw evidence directory is retained securely;
- [ ] customer login/activation smoke test works;
- [ ] service catalogue/detail UI shows the new copy correctly;
- [ ] service request/document/payment flow works;
- [ ] staff assignment/task visibility works;
- [ ] support/notification flow works;
- [ ] production URL, HTTPS, email and deep links are verified.

---

# Final Deployment Rule

The client-facing operational rule is:

```text
Install OMC
    -> run configuration.sh
    -> allow the guarded migration/catalogue process to finish
    -> review the readable result and raw evidence
    -> smoke-test production
```

Do not replace that flow with ad-hoc manual database edits or a shortened sequence that skips backups, preflight or validation.
