# OMC Frappe Deployment Toolkit

Ubuntu 24.04 / Frappe v15 deployment tooling. Frappe framework installation and custom `omc_app` deployment are deliberately separate. The app source is validated before copying, and an existing Bench app is never silently overwritten.

1. Copy `config/production.env.example` to `config/production.env` and set absolute paths.
2. Run `./install.sh`.
3. Run `./site_setup.sh new --site <site-or-ip>`.
4. Run `./verify.sh <site-or-ip>`.

Secrets, logs and backups remain local and Git-ignored.
