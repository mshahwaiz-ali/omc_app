# Backend Operations

Source cross-check: **25 August 2026**.

Routine commands for an already-prepared OMC Frappe/ERPNext v14 deployment.

---

## Service status

```bash
sudo supervisorctl status
sudo systemctl is-active nginx
sudo nginx -t
```

Bench Redis queue/cache processes are managed with the Frappe production process set. A healthy system Redis service on port 6379 is not a substitute for the Bench Redis instances used by the Bench configuration.

Useful port check:

```bash
ss -ltnp | grep -E ':11000|:13000'
```

---

## Runtime restart

For the checked-in runtime-only helper:

```bash
cd backend_omc_app/deploy
./production.sh
```

`production.sh`:

- validates the existing Bench path;
- starts Supervisor if needed;
- rereads/updates Supervisor config;
- starts/restarts production processes;
- validates nginx;
- starts/reloads nginx;
- checks Redis when `redis-cli` is available.

It does **not** install packages, create a site, run migrations, build assets, install the app, or rewrite nginx/Supervisor config.

Manual equivalent checks/restarts may include:

```bash
sudo supervisorctl status
sudo supervisorctl restart all
sudo nginx -t
sudo systemctl reload nginx
```

---

## Application update

For an already-installed OMC app after updated code has been deployed:

```bash
cd backend_omc_app/frappe-bench

./env/bin/pip install -e apps/omc_app
bench --site <site> migrate
bench --site <site> clear-cache
bench build --app omc_app
bench restart
```

If the deployment uses system Supervisor/nginx, validate/reload those services after the Bench restart as appropriate.

Do not recreate the client Bench/site for an ordinary app update.

---

## OMC setup boundaries

Normal `bench migrate` does not explicitly publish the source-controlled service catalogue or deliberately rewrite all OMC setup data.

When needed, use the explicit operations:

```bash
bench --site <site> execute omc_app.setup.operations.validate_site
bench --site <site> execute omc_app.setup.operations.repair_permissions
bench --site <site> execute omc_app.setup.operations.sync_desk_configuration
bench --site <site> execute omc_app.setup.operations.apply_site_branding
```

Run only the operation required by the reviewed change.

---

## Service catalogue operations

Read-only preview:

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

Read-only validation:

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Explicit sync:

```bash
bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

Do not bypass preview blockers/conflicts. Catalogue sync protects exact ERP Task Type mappings, in-flight request requirements and historical pricing.

---

## Existing-customer migration

Use the dedicated client handover runbook rather than ad-hoc data edits:

[`../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md)

At minimum, always preflight before apply and back up before the write migration.

---

## Validation

Backend suite:

```bash
cd backend_omc_app/frappe-bench
bench --site <site> run-tests --app omc_app --skip-test-records
```

Catalogue:

```bash
bench --site <site> execute omc_app.setup.operations.validate_service_catalogue
```

Deployment helper:

```bash
cd backend_omc_app/deploy
./verify.sh <site>
```

**Note:** current `verify.sh` runs `bench --site <site> migrate` as one of its checks. It is therefore not a purely read-only command.

---

## Logs

Common Bench logs:

```bash
tail -f \
  backend_omc_app/frappe-bench/logs/web.error.log \
  backend_omc_app/frappe-bench/logs/worker.error.log
```

Also inspect scheduler/worker/nginx/Supervisor logs when a failure belongs to those layers.

Never commit production logs, dumps, backups, credentials, private files, site config secrets, or generated runtime state.
