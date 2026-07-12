# Site Setup

```bash
./site_setup.sh new --site 13.63.113.213
./site_setup.sh install-app --site 13.63.113.213
./site_setup.sh migrate --site 13.63.113.213
./site_setup.sh production --site 13.63.113.213
./site_setup.sh status --site 13.63.113.213
./site_setup.sh cleanup --site 13.63.113.213
./site_setup.sh cleanup --site 13.63.113.213 --no-backup
```

`bench new-site` creates the site database, database user and configuration. The script does not pre-create them. The dedicated `frappe_admin@localhost` credential is generated once in `.secrets/production.env` and reused without being printed.
