# OMC App — Client Deployment & Existing-Customer Migration Handover

Source cross-check: **25 August 2026**, branch `main`.

This document is the operator handover for deploying the supplied `omc_app` to the client's existing **Frappe / ERPNext v14** environment, migrating supported existing ERP customers/staff into OMC application state, reconciling the production service catalogue, and safely retiring the old Lead/legacy app if applicable.

> Replace `<site>` and `/path/to/frappe-bench` with the client's real values. Never guess a site name, legacy app name, path, or production credential.

---

# Part A — Clean Deployment Steps

This section is the short execution sequence. Detailed reasoning for every stage is in **Part B**.

## Step 1 — Open the correct Bench and identify the site

```bash
cd /path/to/frappe-bench

bench list-sites
bench --site <site> list-apps
bench version
```

Confirm:

- correct client site;
- Frappe/ERPNext v14;
- existing site is healthy;
- exact old/legacy app name if one is installed;
- correct OMC release folder is available.

---

## Step 2 — Take the first full backup

```bash
bench --site <site> backup --with-files
```

Record the backup location before continuing.

---

## Step 3 — Copy/register the new OMC app

Place the supplied folder at:

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

### First installation only

```bash
bench --site <site> install-app omc_app
```

### If OMC App is already installed

Do **not** reinstall it. Continue with the updated source.

Confirm:

```bash
bench --site <site> list-apps
```

`omc_app` must appear.

---

## Step 5 — Run Frappe migration and validate the ERP contract

```bash
bench --site <site> migrate
bench --site <site> clear-cache

bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract
```

Do not continue if the ERP contract validation fails.

---

## Step 6 — Run the existing-customer/staff migration preflight

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

Review the output fully. Do not apply until identity-review/blocker counts are understood.

---

## Step 7 — Take the final pre-data-migration backup

```bash
bench --site <site> backup --with-files
```

Record this backup separately. This is the recovery point immediately before the OMC historical-data write.

---

## Step 8 — Apply the controlled OMC data migration

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

Do not manually force-link records that migration leaves for review.

---

## Step 9 — Re-run the migration preflight

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

Confirm that successfully migrated records now reconcile/reuse correctly and remaining review cases are expected.

---

## Step 10 — Preview the production service catalogue

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

Expected catalogue baseline:

```text
9 categories
31 services
17 active
14 inactive/review-required
PKR
Omc House
Full Settlement default activation policy
```

Do not sync if preview reports unexpected blockers/conflicts, missing/ambiguous Task Types, unsafe price changes, or unsafe in-flight requirement changes.

---

## Step 11 — Sync and validate the service catalogue

After a reviewed clean preview:

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

A fully reconciled site should have no unexpected pending mutations, conflicts, or blockers.

---

## Step 12 — Retire/remove the old Lead/legacy app only after OMC migration

**Do not remove the legacy app before the OMC historical-data migration unless its data ownership has been explicitly reviewed.**

First confirm the exact app name:

```bash
bench --site <site> list-apps
```

Take another full backup:

```bash
bench --site <site> backup --with-files
```

Then uninstall using the exact name:

```bash
bench --site <site> uninstall-app OLD_APP_NAME --yes
```

After uninstall:

```bash
bench --site <site> migrate
bench --site <site> clear-cache

bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Only delete the old app folder from `apps/` after successful uninstall and post-removal validation.

If the ERP contract fails after uninstall, **stop**. Do not improvise or patch ERPNext source manually.

---

## Step 13 — Run any specifically approved OMC setup reconciliation

Normal `bench migrate` does not intentionally rewrite all OMC Desk/permission/branding configuration.

Only when required by the deployment plan, run explicit operations such as:

```bash
bench --site <site> execute omc_app.setup.operations.repair_permissions
bench --site <site> execute omc_app.setup.operations.sync_desk_configuration
bench --site <site> execute omc_app.setup.operations.apply_site_branding
```

Do not run extra mutation operations merely because they exist.

---

## Step 14 — Build, clear cache and restart/reload services

```bash
bench build --app omc_app
bench --site <site> clear-cache
bench restart
```

For Supervisor/nginx production environments also verify:

```bash
sudo supervisorctl status
sudo nginx -t
sudo systemctl reload nginx
```

---

## Step 15 — Final verification

```bash
bench --site <site> list-apps
bench --site <site> doctor

bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Then perform controlled application smoke tests:

- ERP/Frappe site opens normally;
- customer login/session works;
- existing-customer activation works where applicable;
- service catalogue loads;
- required-document flow works;
- payment/receipt flow works;
- accounting/activation gate behaves correctly;
- protected internal workspace requires valid Staff Access/capability;
- support/notifications work;
- background workers/scheduler are healthy;
- logs contain no unresolved migration/schema/bridge failures.

---

# Part B — Why These Steps Are in This Order

## 1. Why confirm the environment first?

The client already has a working ERP site. This deployment must modify the intended existing site, not create a replacement site or new database.

`bench list-sites`, `list-apps`, and `bench version` establish:

- which site is being changed;
- which apps are currently installed;
- whether the runtime matches the supported v14 deployment;
- whether a legacy app still needs controlled retirement.

A wrong site name or wrong Bench is a deployment error, not something the migration should try to recover from.

---

## 2. Why take backups more than once?

There are separate risk boundaries:

1. before application installation/schema migration;
2. immediately before historical OMC data migration;
3. before legacy-app removal.

Each backup corresponds to a different recovery point.

A backup taken before installation does not replace the value of a backup taken immediately before a bulk data reconciliation.

---

## 3. What copying the OMC folder actually does

Copying:

```text
omc_app -> frappe-bench/apps/omc_app
```

only places application source on the server.

It does **not** automatically:

- install the app on a site;
- create OMC database tables;
- execute patches;
- migrate historical customers;
- publish the service catalogue;
- remove the legacy app.

The editable Python install makes the package importable by the Bench environment, and `sites/apps.txt` registers the app with the Bench.

---

## 4. Why `install-app` and `bench migrate` are separate

For a first installation:

```text
source copied
    -> Python package registered
    -> install-app
    -> bench migrate
```

`install-app` installs the custom Frappe app on the selected site.

`bench migrate` then brings the site's schema/metadata/patch state in line with the installed code.

It applies things such as:

- OMC DocTypes;
- fields/schema changes;
- indexes;
- registered patches;
- Frappe metadata migrations.

Important:

> `bench migrate` is **not** the historical customer migration and is **not** the production service-catalogue publisher.

Those are deliberate separate operations.

---

## 5. Why validate the ERP contract after migrate

OMC integrates with an existing client ERP schema instead of rewriting ERPNext source.

The read-only ERP contract validation confirms required ERP business structures exist, including required Customer, Service, Task, Task Type, Sales Invoice and Payment Entry integration points and the specific required client fields/types.

If that contract is incomplete, OMC deliberately fails rather than silently modifying ERPNext metadata.

This is why the deployment should stop on contract failure.

---

## 6. Why the old app should normally remain until after historical OMC migration

The current migration/reconciliation code can use existing ERP/legacy evidence to resolve historical identity and staff persona information.

Examples include:

- linked Lead information used for customer CNIC/phone identity fallback;
- existing ERP User persona information used for staff reconciliation;
- existing Customer relationships used for historical attribution.

An app uninstall can remove app-owned metadata/custom fields depending on how that legacy app was built.

Therefore the safe sequence is:

```text
install OMC
    -> migrate OMC schema
    -> validate ERP contract
    -> read/migrate historical evidence
    -> reconcile catalogue
    -> only then retire legacy app
    -> validate ERP contract again
```

This preserves evidence until OMC has completed the migration that may need it.

If the client has independently proven that the old app owns no required migration/ERP-contract metadata, its removal can be evaluated separately. Do not assume that without evidence.

---

# Part C — Existing-Customer & Staff Migration Explained

## 1. Purpose

The client may have thousands of existing ERP customers. Manually recreating them as app customers is neither practical nor safe.

The migration therefore reconciles existing ERP business identities into OMC application state without bulk-generating customer login accounts.

## 2. Customer identity order

The current migration resolves identity in this priority:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The backend uses deterministic uniqueness checks rather than fuzzy matching.

If a value is duplicated/ambiguous, migration does not guess.

## 3. Why NTN/tax ID is last

Customer tax identity can be useful, but established unique email/CNIC/phone evidence has higher priority in the current migration contract.

A supported unique tax ID/NTN is therefore a deterministic fallback only.

## 4. What migration may reconcile

Depending on the data present, the migration can reconcile areas such as:

- eligible existing ERP staff;
- Staff Profile compatibility state;
- canonical `OMC Staff Access`;
- staff capabilities/persona evidence;
- referral codes for eligible referral owners;
- OMC Customer Profiles for safely identifiable ERP Customers;
- canonical customer-account relationships where appropriate;
- historical referral/acquisition attribution where evidence exists;
- explicit review/quarantine state for unsafe/ambiguous cases.

## 5. What migration intentionally does not do

It must not:

- create thousands of customer Frappe Users in advance;
- create shared/default passwords;
- guess duplicate identities;
- automatically enable disabled users;
- promote Website Users to System Users;
- overwrite suspended/rejected Staff Access merely because sync runs again;
- invent historical referrers;
- invent commission provenance;
- force-link an ambiguous ERP Customer.

## 6. Why preflight is required

The preflight is the review point before writes.

Review:

- total customers;
- safely identifiable count;
- identity-review count;
- reasons for review;
- create/reuse actions;
- staff reconciliation state;
- referral/history reconciliation;
- blockers/warnings;
- unexpected login-user creation behaviour.

A materially unexpected preflight result means **stop**, not “apply and see what happens”.

## 7. Why rerun preflight after apply

The post-apply preflight verifies idempotent reconciliation.

Successfully migrated records should now appear as existing/reusable/current rather than as new uncontrolled writes.

Remaining identity-review cases should remain explicit review cases until separately resolved.

---

# Part D — Service Catalogue Explained

## 1. Why catalogue sync is separate from `bench migrate`

The production service catalogue is business data, not merely database schema.

It contains:

```text
9 categories
31 services
17 active
14 inactive/review-required
```

It also contains pricing, service identity, required documents, form fields and exact ERP Task Type mapping.

Automatically rewriting that business data during every schema migration would be unsafe.

Therefore catalogue publishing is explicit:

```text
preview -> review -> sync -> validate
```

## 2. Exact ERP Task Type rule

OMC does not fuzzy-match or create ERP Task Types.

A service maps to the exact existing client ERP Task Type identity.

This prevents a similar-looking Task Type from silently receiving the wrong OMC service configuration.

## 3. Why inactive services remain in the manifest

A service can remain inactive when its commercial facts are not sufficiently verified, for example:

- incomplete pricing;
- unclear recurring fee structure;
- incomplete scope;
- uncertain completion timing;
- incomplete requirements.

Inactive does not mean deleted. It means not safe to publish as an active customer service yet.

## 4. Catalogue protection for live customer requests

The provisioner protects existing/in-flight requests from unsafe changes such as:

- newly imposed required documents;
- unsafe price changes;
- ambiguous stable document keys;
- destructive removal of managed requirements.

New required-document definitions can use `effective_from` so older requests keep the contract they started with.

## 5. Idempotency

Once a site matches the source-controlled catalogue, repeating the sync should produce no new business mutations.

A clean validation should show no unexpected:

- creates;
- updates;
- deactivations;
- conflicts;
- blockers.

---

# Part E — Legacy App Retirement Explained

## 1. Never guess the app name

Use:

```bash
bench --site <site> list-apps
```

The uninstall command must use the exact installed app name.

## 2. Why backup immediately before uninstall

Frappe app uninstall can remove app-owned site metadata/data.

A fresh backup creates a recovery point specifically for legacy-app retirement.

## 3. Why ERP contract validation must run again afterward

The OMC backend depends on a defined client ERP integration contract.

If legacy-app uninstall removes any required field/metadata, the contract validation will expose it immediately.

Do not hide that failure by manually patching ERPNext source.

## 4. When to remove the old source folder

Only after:

```text
uninstall-app succeeded
+ bench migrate succeeded
+ ERP contract validation succeeded
+ OMC catalogue validation succeeded
+ site remained healthy
```

Then the obsolete app source folder can be removed if the client no longer needs it.

---

# Part F — Payment, Accounting and ERP Activation Checks

The current production architecture is payment/accounting-first.

For a normal full-settlement service:

```text
Service Request
    -> required documents
    -> payment/receipt
    -> ERP accounting settlement
    -> Ready for Activation
    -> durable bridge
    -> ERP Service + ERP Task
```

A receipt upload alone is not accounting settlement.

During smoke testing, verify that a paid service does not create/activate ERP operational records before the backend considers the request financially eligible.

The durable bridge uses `OMC Bridge Operation` and is designed to safely retry without duplicating the business effect.

---

# Part G — Optional Setup Operations

Normal migrate intentionally does not silently rewrite every OMC site setting.

Explicit setup commands may exist for:

- permission repair;
- Desk/workspace configuration;
- branding;
- tax defaults;
- catalogue reconciliation.

Only run a mutation when it is part of the approved deployment plan.

For example:

```bash
bench --site <site> execute omc_app.setup.operations.repair_permissions
bench --site <site> execute omc_app.setup.operations.sync_desk_configuration
bench --site <site> execute omc_app.setup.operations.apply_site_branding
```

---

# Part H — Optional Separate Compatibility/Fix Script

If the handover package includes a **separately supplied, approved compatibility/fix script**, treat it as a separate reviewed deployment action.

Before running it:

1. confirm the exact script filename;
2. read its path assumptions;
3. adjust only documented path variables if the client's Bench layout differs;
4. take a backup if it mutates site data/metadata;
5. run it from the directory required by that script;
6. re-run `bench migrate`, ERP-contract validation and relevant tests/checks afterward if the script changes metadata.

This runbook intentionally does not invent a script filename/path that is not present in the repository.

---

# Part I — Stop Conditions

Stop and investigate if any of these occurs:

- wrong site/Bench/runtime detected;
- backup fails;
- OMC Python import fails;
- `install-app` fails;
- `bench migrate` fails;
- ERP contract validation fails;
- migration preflight differs materially from the reviewed expectation;
- migration proposes unexpected login-user creation;
- identity ambiguity is being force-resolved;
- staff reconciliation reports unexpected security conflicts;
- catalogue preview reports missing/ambiguous ERP Task Types;
- catalogue reports unsafe price/document changes;
- catalogue validation remains conflicted/blocked after intended sync;
- legacy-app uninstall removes required ERP integration metadata;
- ERP site stops loading;
- payment/accounting gate is bypassed;
- ERP Service/Task duplication appears;
- Supervisor/workers/scheduler are unhealthy;
- logs show unresolved migration, schema, accounting or bridge failures.

Do not continue simply to finish the checklist. Resolve the stop condition or restore the appropriate backup.

---

# Part J — Final Evidence Checklist

## Environment

- [ ] Correct Bench confirmed
- [ ] Correct client site confirmed
- [ ] Frappe/ERPNext v14 confirmed
- [ ] Exact old app name recorded if applicable

## Safety

- [ ] Initial full backup completed
- [ ] Final pre-data-migration backup completed
- [ ] Pre-legacy-removal backup completed if applicable

## OMC code/schema

- [ ] Correct `omc_app` source copied
- [ ] Python import works
- [ ] App registered in Bench
- [ ] `omc_app` installed on the correct site
- [ ] `bench migrate` completed
- [ ] ERP contract validation passed

## Historical data

- [ ] Migration preflight reviewed
- [ ] Identity-review cases understood
- [ ] OMC migration applied with explicit confirmation
- [ ] Post-apply preflight reviewed
- [ ] No ambiguous records force-linked

## Catalogue

- [ ] Catalogue preview reviewed
- [ ] Exact ERP Task Type mappings accepted
- [ ] Catalogue sync run if required
- [ ] Catalogue validation clean

## Legacy app

- [ ] Legacy app removed only if explicitly approved
- [ ] Post-removal migrate completed
- [ ] ERP contract validation still passes
- [ ] Catalogue validation still passes

## Runtime

- [ ] OMC assets built
- [ ] Cache cleared
- [ ] Production processes restarted/reloaded
- [ ] Scheduler/workers healthy
- [ ] Nginx configuration valid

## Functional smoke checks

- [ ] ERP site opens normally
- [ ] Customer login works
- [ ] Existing-customer activation works where applicable
- [ ] Service catalogue works
- [ ] Required-document upload works
- [ ] Payment/receipt workflow works
- [ ] Accounting settlement gate works
- [ ] ERP activation happens only when eligible
- [ ] Staff internal workspace is capability-gated
- [ ] Support/notifications work
- [ ] No critical errors remain in logs

---

# Final Deployment Flow

```text
Existing healthy ERPNext v14 site
        |
        v
Confirm site/apps/runtime
        |
        v
Full backup
        |
        v
Copy/register omc_app
        |
        v
install-app (first install only)
        |
        v
bench migrate
        |
        v
Validate client ERP contract
        |
        v
Customer/staff migration preflight
        |
        v
Final pre-migration backup
        |
        v
Apply OMC historical-data migration
        |
        v
Post-migration preflight
        |
        v
Catalogue preview
        |
        v
Catalogue sync + validation
        |
        v
Backup + retire legacy app if approved
        |
        v
Migrate + revalidate ERP contract/catalogue
        |
        v
Optional explicit OMC setup operations
        |
        v
Build + clear cache + restart
        |
        v
Final technical + functional verification
```

The essential deployment rule is:

> **Preserve the working ERP site, migrate/reconcile OMC data deliberately, retain historical evidence until migration has consumed it, and validate every destructive boundary before proceeding.**
