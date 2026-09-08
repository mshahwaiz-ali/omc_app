# Deployment Installer

Source cross-check: **25 August 2026**.

`install.sh` prepares the server dependencies and Frappe Bench runtime used by the checked-in OMC deployment toolkit.

Current defaults enforced by the script:

```text
FRAPPE_BRANCH=version-14
PYTHON_VERSION=3.10
NODE_MAJOR=18
Yarn=1.22.x
minimum requested swap=2048 MiB
```

The app package itself declares Python `>=3.10`.

---

## Run

From the repository:

```bash
cd backend_omc_app/deploy
cp config/production.env.example config/production.env
# review/edit deployment-specific values
chmod 600 config/production.env
./install.sh
```

The script requires sudo/root access for OS package/service setup.

---

## What it installs/checks

The installer handles or validates dependencies including:

- Git/curl/build tooling;
- MariaDB server/client;
- Redis server;
- nginx;
- Supervisor;
- Python build/runtime packages;
- Node.js 18;
- Yarn 1.22;
- `uv`;
- `frappe-bench` through pipx;
- image/PDF-related native libraries used by the Frappe stack.

It enables/starts MariaDB, Redis, nginx and Supervisor at the OS level.

---

## Bench behavior

A Bench is considered healthy only when the expected Frappe app, sites directory, Python environment and `sites/apps.txt` exist.

If the configured Bench is already healthy, it is preserved and validated.

If it is not healthy, the script can remove the incomplete configured Bench path and initialise a fresh Frappe v14 Bench. If an OMC app source directory exists in the expected location, it is staged/restored around that fresh Bench initialisation.

**Do not point `BENCH_DIR` at a client production Bench unless you have reviewed this behavior and intentionally want the installer to manage that runtime.** For an already-working client site, use the client handover/update runbook instead of rebuilding the Bench.

The script does not create a site or database.

---

## App package

If `apps/omc_app` exists after Bench preparation, the installer:

```text
validates the app source
installs it editable into the Bench Python environment
verifies Frappe import/version
verifies omc_app import
```

Site installation still requires the explicit site workflow.

---

## Final checks

The script verifies:

- Bench Python matches the requested 3.10 runtime;
- Frappe reports version 14.x;
- OMC app import succeeds when app source is present;
- MariaDB, Redis, nginx and Supervisor services are active.

Successful installer completion means the runtime Bench/dependencies are ready. It does **not** mean a client site has been created, migrated, customer-migrated, catalogue-synchronised or smoke-tested.

See [`SITE_SETUP.md`](SITE_SETUP.md) and the client handover runbook for those steps.
