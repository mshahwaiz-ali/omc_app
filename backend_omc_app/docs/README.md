# OMC Backend Documentation Archive

This directory preserves the backend and deployment documentation that previously lived directly under `backend_omc_app/` and `backend_omc_app/deploy/`.

The old `backend_omc_app/deploy/` runtime toolkit was removed from the active repository layout on 8 September 2026 because client installation is now published as a normal Frappe app from the same repository.

Preserved documents:

- `backend_readme.md` — historical backend master guide;
- `DEPLOY_README.md` — historical deployment-toolkit overview;
- `INSTALL.md` — historical runtime installer notes;
- `OPERATIONS.md` — historical operations notes;
- `SITE_SETUP.md` — historical site-toolkit notes;
- `TROUBLESHOOTING.md` — historical troubleshooting notes.

Some commands and relative links inside these preserved documents reference the removed `deploy/` toolkit and are therefore historical rather than current executable instructions.

## Current backend source

The authoritative custom Frappe application remains:

```text
backend_omc_app/frappe-bench/apps/omc_app/
```

The repository publishes that directory automatically to the generated `frappe-app` branch, where it becomes the repository root for Bench installation.

Client installation therefore uses the same GitHub repository without copying folders manually:

```bash
cd /home/frappe/frappe-bench
bench get-app --branch frappe-app https://github.com/mshahwaiz-ali/omc_app.git
bench --site <site> install-app omc_app
```

The `frappe-app` branch is generated deployment output. Development continues on `main`; do not edit `frappe-app` manually.

`backend_omc_app/local_setup/` is retained separately because it contains local helper scripts, not documentation files.
