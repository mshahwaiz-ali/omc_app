# OMC App — Client Deployment & Existing-Customer Migration Handover

Source cross-check: **25 August 2026**, branch `main`.

This runbook is for installing/updating the supplied `omc_app` on the client's existing **Frappe / ERPNext v14** site, then performing the controlled OMC data migration and service-catalogue reconciliation.

> Replace `<site>` and `/path/to/frappe-bench` with the client's real values. Do not guess site names, app names, or paths.

---

## 1. Confirm the target environment

```bash
cd /path/to/frappe-bench
bench list-sites
bench --site <site> list-apps
bench version
```

Before continuing, confirm:

- the correct client site;
- Frappe/ERPNext v14 compatibility;
- the existing ERP site is healthy;
- the old/legacy app name, if one is still installed;
- the supplied OMC app folder is the intended release.

---

## 2. Take a full backup

Before installing, removing, or migrating applications:

```bash
bench --site <site> backup --with-files
```

Do not continue unless the backup succeeds and its location is known.

---

## 3. Place/register the OMC app

Copy the supplied app folder to:

```text
frappe-bench/apps/omc_app
```

Then register/install the Python package in the existing Bench environment:

```bash
cd /path/to/frappe-bench
./env/bin/pip install -e apps/omc_app
./env/bin/python -c "import omc_app; print('OMC App import: OK')"
```

If the app is not present in `sites/apps.txt`, add exactly one line:

```bash
grep -qxF 'omc_app' sites/apps.txt || echo 'omc_app' >> sites/apps.txt
```

Do not overwrite unrelated apps or reset the client's Bench.

---

## 4. Install OMC App on the site

For first installation:

```bash
bench --site <site> install-app omc_app
```

Confirm:

```bash
bench --site <site> list-apps
```

`omc_app` must appear in the installed-app list.

If this is an update to an already-installed OMC app, do not reinstall it; deploy the updated code and continue with migration.

---

## 5. Run Frappe migration

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

`bench migrate` applies OMC DocTypes, fields, indexes, patches, and schema metadata required by the installed code.

Important boundary:

> **`bench migrate` does not publish the production service catalogue and does not perform the existing-customer business migration.**

The current OMC lifecycle deliberately keeps normal migrate validation-only for OMC setup operations that would otherwise rewrite roles, branding, Desk metadata, or catalogue content.

---

## 6. Remove the old Lead/legacy app only if applicable

First identify the exact installed app name:

```bash
bench --site <site> list-apps
```

Take another full backup before removal:

```bash
bench --site <site> backup --with-files
```

Then use the exact legacy app name:

```bash
bench --site <site> uninstall-app OLD_APP_NAME --yes
```

After successful uninstall:

```bash
bench --site <site> migrate
bench --site <site> clear-cache
```

Do not guess `OLD_APP_NAME`. Do not delete ERPNext/Frappe source. If legacy metadata is still required by the client site, stop and investigate before deleting its app folder.

---

# Existing-customer migration

## 7. Run read-only migration preflight

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

Review the complete output before applying anything.

The current migration classifies ERP Customer identity using this deterministic priority:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The tax-ID/NTN rule is the final fallback; ambiguous records are not force-linked.

Review especially:

- total customer count;
- safely identifiable/migratable count;
- identity-review count and reasons;
- create vs reuse profile/account actions;
- activation-ready vs deferred claim cases;
- staff/referral reconciliation counts;
- blockers and warnings;
- any reported login-user creation count.

The migration must not bulk-create customer login users or shared/default passwords.

---

## 8. Take the final pre-migration backup

Immediately before the write migration:

```bash
bench --site <site> backup --with-files
```

Record the backup path/time with the migration evidence.

---

## 9. Apply the controlled OMC data migration

Use the current explicit-confirmation command:

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

The migration is designed to reconcile supported phases such as:

- eligible ERP staff into OMC staff/profile/access state;
- canonical `OMC Staff Access` capability rows;
- referral codes for eligible referral-capable staff;
- safe OMC Customer Profile/account relationships;
- historical referral/acquisition attribution where evidence exists;
- review/quarantine paths for ambiguous data.

It must not:

- bulk-create customer Frappe Users;
- generate shared/default passwords;
- enable disabled users;
- silently convert Website Users into System Users;
- overwrite explicit suspended/rejected staff authority;
- force-link ambiguous customers;
- guess historical referrers or commission provenance.

The migration is intended to be idempotent: a correct rerun should reuse/reconcile existing state rather than duplicate it.

---

## 10. Re-run migration preflight

After apply:

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight
```

Confirm that completed records are now reported as reusable/current and that remaining review/blocker cases are expected exceptions.

If supported by the installed release, use the migration's blocker/review detail command for unresolved identities rather than manually editing links.

---

# Production service catalogue

## 11. Preview the catalogue reconciliation

The catalogue is source controlled and currently expects:

```text
9 categories
31 services
17 active
14 inactive/review-required
PKR
Omc House
Full Settlement default activation policy
```

Run the read-only preview:

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

Stop if there are unexpected missing/ambiguous ERP Task Types, conflicts, unsafe price changes, or in-flight requirement blockers.

OMC maps only to exact existing ERP Task Types; it must not create or fuzzy-match Task Types.

---

## 12. Apply catalogue sync explicitly

Only after a clean/reviewed preview:

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

The sync is designed to be atomic, rollback on failure, protect in-flight/historical contracts, and be idempotent.

Then validate:

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

For an already-reconciled production site, the desired validation state is no pending creates/updates/deactivations, no conflicts, and no blockers.

---

## 13. Optional deliberate OMC setup reconciliation

Normal `bench migrate` does not silently rewrite OMC roles, Desk/workspace metadata, branding, or catalogue.

If the deployment specifically requires current source-controlled OMC setup to be reconciled, use deliberate operator commands such as:

```bash
bench --site <site> execute omc_app.setup.operations.repair_permissions
bench --site <site> execute omc_app.setup.operations.sync_desk_configuration
bench --site <site> execute omc_app.setup.operations.apply_site_branding
```

Run only the operations actually required by the deployment plan.

---

## 14. Clear cache, build, restart

```bash
bench --site <site> clear-cache
bench build --app omc_app
bench restart
```

If production uses Supervisor/nginx, validate/reload according to the client's deployment:

```bash
sudo supervisorctl status
sudo nginx -t
sudo systemctl reload nginx
```

---

## 15. Verification

At minimum verify:

```bash
bench --site <site> list-apps
bench --site <site> doctor
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Then smoke-test the actual environment:

- ERP/Frappe site loads;
- login/session works;
- OMC customer access resolves correctly;
- service catalogue loads;
- a controlled test request can reach the expected document/payment state;
- required-document upload works;
- payment/receipt workflow behaves correctly;
- protected internal workspace requires valid staff capability;
- email/deep-link activation works if part of the release;
- logs show no migration/bridge/schema errors.

For release confidence, run the OMC backend regression suite in the target test/restored environment before or after deployment as appropriate.

---

# Stop conditions

Stop and investigate if any of the following occurs:

- app import or install fails;
- `bench migrate` fails;
- the ERP site stops loading;
- migration preflight differs materially from the reviewed expectation;
- migration proposes unsafe identity linking or unexpected login-user creation;
- staff reconciliation reports unexpected conflicts;
- catalogue preview reports missing/ambiguous Task Types, unsafe in-flight changes, price conflicts, or blockers;
- catalogue validation is not clean after a successful intended sync;
- old-app removal breaks required client metadata;
- ERP Service/Task activation begins before the expected payment/accounting gate;
- production services/logs show unresolved failures.

Do not manually force-link ambiguous identities or bypass catalogue/settlement safety checks.

---

# Final checklist

- [ ] Correct ERPNext v14 site confirmed
- [ ] Full backup completed
- [ ] Correct `omc_app` release copied/registered
- [ ] OMC App installed or updated
- [ ] `bench migrate` completed
- [ ] Legacy app removed only if explicitly required
- [ ] Migration preflight reviewed
- [ ] Final pre-migration backup completed
- [ ] OMC data migration applied with explicit confirmation
- [ ] Post-migration preflight reviewed
- [ ] Catalogue preview reviewed
- [ ] Catalogue sync applied if required
- [ ] Catalogue validation clean
- [ ] Cache cleared/assets built
- [ ] Services restarted/reloaded
- [ ] ERP site healthy
- [ ] OMC smoke tests completed
- [ ] Remaining identity/catalogue review cases recorded rather than force-fixed
