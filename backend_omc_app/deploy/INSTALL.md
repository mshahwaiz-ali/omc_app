# Installation

Run on fresh Ubuntu 24.04 as the deployment user:

```bash
cd backend_omc_app/deploy
cp config/production.env.example config/production.env
nano config/production.env
chmod 600 config/production.env
./install.sh
```

The installer is idempotent: installed packages are skipped individually, a healthy Bench is preserved, and a non-empty unhealthy Bench path causes a hard stop instead of deletion. It installs Python 3.12 support packages, pipx/Bench, Node/Yarn, MariaDB, system Redis, Nginx, Supervisor, wkhtmltopdf dependencies and uv. MariaDB 10.11 is supported by this Frappe-v15 deployment despite Bench warnings.
