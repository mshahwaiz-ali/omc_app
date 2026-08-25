# Deployment Troubleshooting

Source cross-check: **25 August 2026**.

Use this guide for the checked-in Frappe/ERPNext v14 deployment toolkit. Investigate before deleting or recreating client runtime/data.

---

## Wrong runtime version

The current installer expects:

```text
Frappe 14.x
Python 3.10
Node 18.x
Yarn 1.22.x
```

If documentation or an old environment says v15/Python 3.12, do not mix those assumptions with the current deployment scripts. Confirm the intended client environment first.

---

## Bench/app import failure

Check:

```bash
cd backend_omc_app/frappe-bench
./env/bin/python --version
./env/bin/python -c "import frappe; print(frappe.__version__)"
./env/bin/python -c "import omc_app; print('OMC App import: OK')"
./env/bin/pip show omc_app
```

If app source exists but is not installed editable:

```bash
./env/bin/pip install -e apps/omc_app
```

Do not reinstall/recreate the whole Bench solely for an editable-package problem.

---

## App missing from `sites/apps.txt`

The file must contain one `omc_app` entry on its own line.

Check:

```bash
grep -n '^omc_app$' sites/apps.txt
```

Then verify site installation separately:

```bash
bench --site <site> list-apps
```

Being present in `sites/apps.txt` does not automatically mean the app is installed on a specific site.

---

## Migration failure

Stop on a failed migration. Inspect the actual traceback/logs before retrying.

```bash
bench --site <site> migrate
```

Do not run customer migration or catalogue sync until schema migration is healthy.

Normal migrate is not the catalogue publisher.

---

## Catalogue preview/validation blockers

Use:

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Investigate blockers such as:

- missing/ambiguous ERP Task Type;
- unsafe in-flight required-document change;
- unsafe historical/in-flight price change;
- stable-key conflict;
- unexpected managed-state drift.

Do not force the catalogue by editing around a blocker.

---

## Customer migration identity review

Ambiguous email/CNIC/phone/NTN identities are intentionally review cases.

Run migration preflight and inspect blocker/review reasons. Do not manually force-link customers merely to reduce the review count.

The migration should not bulk-create customer login users or shared/default passwords.

---

## Staff access conflict

Canonical staff authority is `OMC Staff Access`.

If reconciliation reports Conflict, check the ERP persona evidence and any deliberately reviewed persona before changing it. A reviewed persona mismatch must not be silently overwritten.

Suspended/Rejected access is also protected from routine reconciliation.

---

## Redis/worker problems

System Redis alone is insufficient if the Bench queue/cache processes are down.

Check:

```bash
sudo supervisorctl status
ss -ltnp | grep -E ':11000|:13000'
```

Then inspect Bench worker/Redis logs.

---

## Nginx failure

Always validate config before reload:

```bash
sudo nginx -t
```

If the generated Bench config is intended to be active, regenerate/link it only through the reviewed production setup workflow.

For runtime-only restart/reload of an already-configured deployment:

```bash
./production.sh
```

---

## Missing CSS/JS or raw HTML

Check/build assets:

```bash
cd backend_omc_app/frappe-bench
bench build --app omc_app
bench --site <site> clear-cache
bench restart
sudo nginx -t
sudo systemctl reload nginx
```

Confirm the expected Frappe asset directories exist under `sites/assets`.

---

## `verify.sh` changes the site

Current `verify.sh` includes:

```text
bench --site <site> migrate
```

So it is not a strictly read-only health command. On production, understand that behavior and ensure a backup/deployment window as appropriate before using it.

---

## Partial site failure

Do not immediately run cleanup/drop-site.

First inspect:

- `sites/<site>/site_config.json`;
- database availability;
- installed apps;
- migration traceback;
- Supervisor state;
- nginx config/logs;
- Bench web/worker/scheduler logs.

`site_setup.sh cleanup` is destructive and requires typed confirmation. It normally backs up first. `--no-backup` is for disposable test environments, not client production.

---

## ERP activation stuck/failed

OMC ERP activation is handled through durable `OMC Bridge Operation` state.

Do not manually create duplicate ERP Service/Task records to “fix” a failed activation.

Check:

- request lifecycle state;
- accounting settlement eligibility;
- bridge operation state/attempts;
- safe error category;
- existing ERP Service/Task links;
- worker logs.

Use the authorised bridge recovery path/capability when a terminal failed operation is eligible for recovery.

---

## Document requirement mismatch

New requirements use stable `document_key` identity. A wrong keyed upload must not be forced to match by changing only the title/type.

For historical unkeyed records, the backend contains controlled compatibility logic. Investigate the request's applicable requirement set and effective date before editing data.

---

## IP/site routing

For an IP-based test site, site routing still depends on Bench/Nginx configuration and the selected default site. Use `bench use <site>` only when that routing behavior is intentional.

For production, prefer the reviewed hostname/DNS/HTTPS deployment rather than relying on an IP-only setup.

---

## Recovery rule

When a deployment/migration result differs materially from the reviewed plan:

1. stop further writes;
2. capture the error/output;
3. verify the latest backup;
4. diagnose the exact layer;
5. fix forward only when safe, otherwise restore through the established Frappe/DB recovery procedure.

Do not “repair” production by deleting unrelated app trees or modifying ERPNext source.
