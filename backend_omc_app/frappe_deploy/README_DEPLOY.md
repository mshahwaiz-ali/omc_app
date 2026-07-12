# Frappe Production Deployment on Ubuntu / EC2

## Recommended EC2 flow

```bash
cp config/production.env.example config/production.env
nano config/production.env
chmod 600 config/production.env

./install.sh --mode production
./site_setup.sh new --mode production --site app.omchouse.com
./deploy.sh setup --site app.omchouse.com
./deploy.sh deploy --site app.omchouse.com
```

Before SSL setup, point the domain A/AAAA record to the EC2 public address and allow ports 80 and 443 in the EC2 security group.

## Normal releases

```bash
./deploy.sh update --site app.omchouse.com
./deploy.sh update --all-sites
```

Every deployment/update performs a backup, enables maintenance mode, installs requirements, builds assets, migrates, clears caches, restarts managed processes, disables maintenance mode, and checks `/api/method/ping` over HTTPS. A shell trap attempts to disable maintenance mode if a later step fails.

## Operations

```bash
./deploy.sh status
./deploy.sh logs
./deploy.sh backup --site app.omchouse.com
./deploy.sh ssl --site app.omchouse.com
```

## Rollback

Code rollback is explicit and deploys the selected known-good commit:

```bash
./deploy.sh rollback --site app.omchouse.com --target <git-commit>
```

Database restore is intentionally separate and destructive:

```bash
./deploy.sh restore --site app.omchouse.com
```

The restore command requires typing `RESTORE <site>` exactly.

## Security and permissions

- Production runtime uses the dedicated `frappe` Linux user by default.
- Nginx owns privileged web ports; Frappe processes do not run as root.
- `.secrets/`, logs, backups, state checkpoints, and real `.env` files are Git-ignored.
- Secret files are created with permissions `600`; directories use `700`.
- MariaDB socket authentication is attempted first. A database administrator password is requested only when socket authentication is unavailable.

## Recovery after interruption

Re-run the same command. Machine installation checkpoints skip completed work, package installation checks existing packages, app/site creation checks current state, and deploy/update creates backups before migrations. Inspect timestamped files in `logs/` before using `--reset-state`.
