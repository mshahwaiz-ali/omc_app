# OMC Frappe Deployment Toolkit

Source cross-check: **25 August 2026**, branch `main`.

This directory contains deployment helpers for the OMC backend runtime.

The checked-in installer currently targets the client-compatible stack:

```text
Frappe branch: version-14
Python:        3.10
Node.js:       18.x
Yarn:          1.22.x
ERPNext:       existing/client v14 deployment context
```

Do not describe this toolkit as a Frappe v15 installer unless the scripts themselves are deliberately migrated and revalidated.

---

## Toolkit boundaries

`install.sh` prepares/validates the server dependencies and Frappe v14 Bench runtime. It deliberately does **not** create a site/database.

`site_setup.sh` performs explicit site actions such as creating a site, installing an app, migrating, configuring production, showing status, or confirmed cleanup.

`production.sh` is runtime-only: it refreshes Supervisor/nginx runtime state for an already-prepared deployment and does not install packages, migrate the site, build assets, create sites, or rewrite production configuration.

`verify.sh` validates a deployed site/runtime and currently runs `bench migrate` as part of its checks, so treat it as an active verification command rather than a purely read-only probe.

---

## Typical fresh-server flow

```bash
cd backend_omc_app/deploy

cp config/production.env.example config/production.env
# edit deployment-specific values
chmod 600 config/production.env

./install.sh
./site_setup.sh new --site <site> --app omc_app
./verify.sh <site>
```

Review the scripts and environment file before running them on a client production server.

---

## Existing client site

For an existing ERPNext v14 client site, do **not** recreate the Bench/site merely because these helper scripts exist.

Use the controlled handover runbook instead:

[`../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md)

That runbook covers app placement, backup, install/update, migrate, customer/staff migration, explicit service-catalogue reconciliation, validation and smoke testing.

---

## Safety

- use absolute paths in deployment configuration where required;
- keep secrets, logs, backups and generated runtime files outside Git;
- confirm the correct Bench/site before destructive actions;
- `site_setup.sh cleanup` requires explicit confirmation and normally takes a backup;
- do not use `--no-backup` on a client production site;
- do not overwrite a healthy client Bench/app tree without a reviewed deployment plan;
- do not patch ERPNext source for OMC behavior.

---

## Documentation

- [`INSTALL.md`](INSTALL.md) — installer behavior and prerequisites;
- [`SITE_SETUP.md`](SITE_SETUP.md) — site actions;
- [`OPERATIONS.md`](OPERATIONS.md) — routine operations;
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — common deployment failures;
- [`../../README.md`](../../README.md) — current OMC architecture.
