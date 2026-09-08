# Site Setup Toolkit

Source cross-check: **25 August 2026**.

`site_setup.sh` performs explicit site-level actions against the configured Bench. It is not a general migration script for an already-running client environment unless the operator deliberately chooses the relevant action.

Current actions:

```text
menu
new
status
install-app
migrate
production
cleanup   (alias: drop)
```

---

## Examples

```bash
cd backend_omc_app/deploy

./site_setup.sh new --site <site> --app omc_app
./site_setup.sh status
./site_setup.sh install-app --site <site> --app omc_app
./site_setup.sh migrate --site <site>
./site_setup.sh production --site <site>
./site_setup.sh cleanup --site <site>
```

For a disposable test site only, cleanup supports:

```bash
./site_setup.sh cleanup --site <site> --no-backup
```

Do not use `--no-backup` on client production data.

---

## `new`

`new`:

1. validates the requested site name;
2. optionally selects an app from the Bench;
3. refuses to create a site that already exists;
4. runs `bench new-site`;
5. optionally installs the selected app during site creation;
6. runs post-setup operations including migrate, clear-cache, scheduler enable, `bench use`, asset build and production config generation.

The site/database are created by Frappe/Bench. Do not pre-create a replacement client database as part of normal use.

---

## `install-app`

```bash
./site_setup.sh install-app --site <site> --app omc_app
```

This calls the normal Bench site app installation. Use it only when the app is not already installed.

For an already-installed OMC app update, deploy the code then run the appropriate migrate/validation workflow instead of reinstalling the app.

---

## `migrate`

```bash
./site_setup.sh migrate --site <site>
```

This runs normal Frappe migration only.

Important OMC boundary:

> Normal migrate does not explicitly publish the source-controlled service catalogue.

Catalogue preview/validate/sync remains a separate operator workflow.

---

## `production`

The production action regenerates Bench Supervisor/nginx configuration, links the generated config into system locations, validates nginx, refreshes Supervisor, and reloads nginx.

Use this only when the deployment is intended to let Bench manage those production configs.

For runtime-only service restart/reload, use `production.sh` instead.

---

## `status`

`status` enumerates existing site directories with `site_config.json`, prints installed apps for each, and reports the relevant system-service state.

It is the safest first action when you are unsure which sites already exist.

---

## `cleanup`

Cleanup is destructive.

It:

- requires the exact site;
- requires typed confirmation `CLEANUP <site>`;
- takes `bench backup --with-files` unless `--no-backup` was explicitly provided;
- drops the site through Bench.

Never use cleanup to “fix” an existing client site unless site removal is the reviewed objective.

---

## Existing client deployment

For an already-running ERPNext v14 client site, prefer the controlled handover runbook:

[`../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md)

That workflow preserves the existing Bench/site and adds the OMC app, migration, data reconciliation, catalogue reconciliation and validation deliberately.
