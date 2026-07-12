# Troubleshooting

- **App not in apps.txt / `frappeomc_app`:** run `site_setup.sh install-app`; the registration function rewrites one app per line, removes duplicates and guarantees a trailing newline.
- **Redis cache not running:** inspect `supervisorctl status` and ports 11000/13000. Starting `redis-server` alone is insufficient.
- **Nginx unknown log format `main`:** `site_setup.sh production` replaces the incompatible access-log directive, then runs `nginx -t`.
- **Raw HTML or missing CSS/JS:** run `bench build`, clear site cache, restart Supervisor and reload Nginx; confirm `sites/assets/frappe/dist` exists.
- **MariaDB root socket authentication:** deployment uses `frappe_admin@localhost`, not interactive root authentication.
- **Empty `FRAPPE_DB_ADMIN_PASSWORD`:** remove only the empty local secret assignment and rerun `install.sh` to generate it.
- **Partial site failure:** inspect the site folder/database first. Cleanup requires explicit `CLEANUP <site>` confirmation and supports `--no-backup` for disposable tests.
- **IP routing:** set the IP as `SITE_NAME`, run `bench use <IP>`, and send traffic through the generated Nginx configuration.
