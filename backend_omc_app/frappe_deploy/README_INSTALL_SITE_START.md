# Frappe Installation, Site Setup, and Local Runtime

This toolkit keeps machine provisioning, site provisioning, and development runtime separate. Run scripts from this directory.

## 1. Configure

```bash
cp config/local.env.example config/local.env
nano config/local.env
chmod 600 config/local.env
```

`config/local.env` is ignored by Git. Generated credentials are stored under `.secrets/` with mode `600`.

## 2. Install machine prerequisites

```bash
chmod +x install.sh site_setup.sh start.sh deploy.sh
./install.sh --mode local
```

The installer is idempotent. Installed packages and completed checkpoints are skipped. To deliberately replay checkpoints:

```bash
./install.sh --mode local --reset-state
```

A partial Bench directory is moved to `frappe-bench.partial.<timestamp>` before a clean retry; it is not silently deleted.

## 3. Create and manage sites

```bash
./site_setup.sh new --mode local --site omc.local
./site_setup.sh list --mode local
./site_setup.sh update --mode local --site omc.local
./site_setup.sh restore --mode local --site omc.local
./site_setup.sh delete --mode local --site omc.local
```

For generated credentials, the script creates:

- `.secrets/sites/<site>.env`: persistent Frappe/site secret record.
- `.secrets/credentials-<site>.txt`: readable handoff note scheduled for deletion after 24 hours when user systemd timers are available.

Record credentials in a password manager and delete the handoff note immediately afterward.

## 4. Start local development

```bash
./start.sh --site omc.local
./start.sh --background --site omc.local
./start.sh --status
./start.sh --restart --site omc.local
./start.sh --logs
./start.sh --stop
```

`start.sh` is development-only and uses `bench start`. Never use it as the production process manager.
