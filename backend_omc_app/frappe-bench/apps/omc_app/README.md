# OMC App Frappe Backend

> Custom Frappe backend app for the OMC House mobile/web customer service platform.

This folder contains the repo-tracked Frappe app package named `omc_app`. It powers the Flutter frontend through mobile-friendly APIs and stores OMC-owned business data such as customer profiles, service requests, documents, payments, support tickets, notifications, leads, and tasks.

---

## Quick Index

| Section | Purpose |
|---|---|
| [Backend Role](#backend-role) | What this backend does |
| [Folder Map](#folder-map) | Where files live |
| [Architecture](#architecture) | How frontend, Frappe, APIs, and DocTypes connect |
| [Local Development](#local-development) | Run backend locally with `bench start` |
| [Site Setup](#site-setup) | Create site and install app |
| [Production Setup](#production-setup) | Supervisor/nginx production notes |
| [Start / Stop / Restart](#start--stop--restart) | Dev and production commands |
| [Deployment Workflow](#deployment-workflow) | Pull, migrate, build, restart |
| [API Surface](#api-surface) | Main mobile backend APIs |
| [DocTypes](#main-doctypes) | Main OMC DocTypes |
| [Smoke Tests](#smoke-tests) | Commands to verify backend health |
| [Troubleshooting](#troubleshooting) | Common issues and fixes |

---

## Backend Role

The backend is responsible for:

- Customer signup and profile creation
- Pending-review / approved-customer access state
- Role and capability checks
- Backend-driven service catalogue
- Service request creation and tracking
- Required documents and customer uploads
- Payment due / receipt tracking
- Support tickets and replies
- Customer notifications and push tokens
- Customer settings/preferences
- Tax calculator API
- Expense tracker API
- Internal workspace data for OMC staff
- Leads, customers, tasks, and operational queues

The Flutter app calls this backend through Frappe method APIs. Protected actions are enforced server-side, not only hidden in UI.

---

## Folder Map

Repo-tracked backend app:

```text
backend_omc_app/apps/omc_app/
  README.md
  pyproject.toml
  omc_app/
    __init__.py
    hooks.py
    api/
      mobile.py
      secured_mobile.py
      guest_session.py
      expense.py
      service_templates.py
    omc_app/
      doctype/
        omc_customer_profile/
        omc_customer_preference/
        omc_service/
        omc_service_request/
        omc_service_document/
        omc_service_payment/
        omc_notification/
        omc_support_ticket/
        omc_lead/
        omc_task/
        ...
    fixtures/
    public/
```

Local Frappe bench runtime usually lives here:

```text
backend_omc_app/frappe-bench/
  apps/
    frappe/
    omc_app/
  sites/
  config/
  logs/
```

Important distinction:

| Path | Meaning |
|---|---|
| `backend_omc_app/apps/omc_app` | Repo-tracked backend app source |
| `backend_omc_app/frappe-bench/apps/omc_app` | Local bench runtime app source |
| `backend_omc_app/frappe-bench/sites` | Site configs, private files, logs, database mapping |

---

## Architecture

```text
Flutter App
  |
  | HTTPS / Frappe REST
  v
Frappe Site, e.g. omc.local or erp.omchouse.com
  |
  | /api/method/omc_app.api.*
  v
Custom Frappe App: omc_app
  |
  | Controllers / APIs / Permission checks
  v
OMC-owned DocTypes
  |
  | Optional future mappings
  v
ERPNext / external systems / reports / integrations
```

Core rule:

```text
UI can hide features, but backend must still block unauthorized API actions.
```

---

## Requirements

Typical stack for this project:

| Layer | Expected |
|---|---|
| Frappe | Version 15 style bench/app structure |
| Python | `>=3.10` according to `pyproject.toml` |
| Database | MariaDB/MySQL supported by Frappe |
| Cache/Queue | Redis via bench |
| Web server | nginx for production |
| Process manager | supervisor for production |
| Local runner | `bench start` |

The app package name is:

```text
omc_app
```

---

## Local Development

### 1. Go to bench folder

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
```

Use your actual bench path if different.

### 2. Confirm site exists

```bash
bench list-sites
```

Expected local site for this project is commonly:

```text
omc.local
```

### 3. Confirm app is available

```bash
bench list-apps
```

Expected:

```text
frappe
omc_app
```

### 4. Start development server

```bash
bench start
```

Default local backend URL:

```text
http://127.0.0.1:8000
```

Flutter local app should point to:

```bash
--dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

---

## Site Setup

### Create a new site

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench new-site omc.local
```

You will be asked for administrator and database passwords depending on your local setup.

### Install OMC backend app on site

```bash
bench --site omc.local install-app omc_app
bench --site omc.local migrate
bench --site omc.local clear-cache
```

### Verify installed apps

```bash
bench --site omc.local list-apps
```

Expected:

```text
frappe
omc_app
```

---

## App Installation Notes

If the app exists in bench but is not installed on the site:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local install-app omc_app
bench --site omc.local migrate
```

If Python package import fails:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench/apps/omc_app
../../../env/bin/pip install -e .
cd ../..
bench --site omc.local clear-cache
bench restart
```

If using the repo-tracked app source, make sure bench runtime app and repo app are synced according to your local workflow.

---

## Production Setup

### Production model

For production, Frappe normally runs behind:

```text
nginx -> gunicorn/frappe web workers -> Redis queues -> MariaDB
```

Production process management is usually handled by:

```text
supervisor
```

Production web routing/static proxy is usually handled by:

```text
nginx
```

### One-command production setup

From bench folder:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
sudo bench setup production $(whoami)
```

If your bench command expects no username argument, use:

```bash
sudo bench setup production
```

This generates and links production configs for supervisor and nginx on many bench setups.

### Manual production setup

Generate supervisor config:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench setup supervisor
```

Link supervisor config:

```bash
sudo ln -s $(pwd)/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
sudo supervisorctl reread
sudo supervisorctl update
```

Generate nginx config:

```bash
bench setup nginx
```

Link nginx config:

```bash
sudo ln -s $(pwd)/config/nginx.conf /etc/nginx/conf.d/frappe-bench.conf
sudo nginx -t
sudo systemctl reload nginx
```

If nginx fails because another default site already uses port 80, disable the default site first:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### HTTPS

Production mobile apps should use HTTPS only.

Recommended production backend URL:

```text
https://erp.omchouse.com
```

After DNS points to the server, configure SSL with your preferred method. For bench-managed Let's Encrypt setups, use the relevant bench SSL command supported by your bench version.

---

## Start / Stop / Restart

### Development mode

Start:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench start
```

Stop:

```text
Ctrl + C
```

### Production mode

Check services:

```bash
sudo supervisorctl status
systemctl status nginx --no-pager
```

Restart Frappe bench processes:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench restart
```

Or directly with supervisor:

```bash
sudo supervisorctl restart all
```

Reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Full production restart:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench restart
sudo nginx -t
sudo systemctl reload nginx
```

---

## Deployment Workflow

Use this when code has been pulled or backend app files changed.

### 1. Go to repo root

```bash
cd ~/data_drive/app_omc
```

### 2. Pull latest code

```bash
git pull
```

### 3. Sync app into bench if your local workflow needs it

If your bench runtime app is separate from repo-tracked app source, copy/sync the updated app into:

```text
backend_omc_app/frappe-bench/apps/omc_app
```

If your workflow has a sync script, run it from its documented location.

### 4. Install/update Python package

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench/apps/omc_app
../../../env/bin/pip install -e .
```

### 5. Run migration

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local migrate
```

### 6. Clear cache

```bash
bench --site omc.local clear-cache
bench --site omc.local clear-website-cache
```

### 7. Build assets if public/static assets changed

```bash
bench build --app omc_app
```

### 8. Restart backend

Development:

```bash
bench start
```

Production:

```bash
bench restart
sudo nginx -t
sudo systemctl reload nginx
```

---

## Backend API Surface

Main app API methods are configured in the Flutter app under `ApiConfig` and implemented in backend modules.

### Auth / Session

```text
login
logout
omc_app.api.mobile.sign_up
omc_app.api.mobile.google_mobile_login
omc_app.api.mobile.get_session_user
```

### Guest

```text
omc_app.api.guest_session.create_guest_session
omc_app.api.guest_session.update_guest_activity
```

### Profile / Settings

```text
omc_app.api.mobile.get_profile
omc_app.api.mobile.update_profile
omc_app.api.mobile.update_contact_info
omc_app.api.mobile.get_settings_preferences
omc_app.api.mobile.update_settings_preferences
```

### Services

```text
omc_app.api.mobile.get_service_catalogue
omc_app.api.mobile.get_service_detail
omc_app.api.service_templates.get_service_template
omc_app.api.mobile.create_service
```

### Service Cases

```text
omc_app.api.mobile.get_service_cases
omc_app.api.mobile.get_service_case
omc_app.api.secured_mobile.get_service_cases
omc_app.api.secured_mobile.get_service_case
omc_app.api.secured_mobile.update_service_case_status
```

### Documents

```text
omc_app.api.mobile.get_documents
omc_app.api.mobile.get_document
omc_app.api.mobile.upload_service_document
omc_app.api.secured_mobile.update_service_document_status
```

### Payments

```text
omc_app.api.mobile.get_payments
omc_app.api.mobile.get_payment
omc_app.api.mobile.upload_payment_receipt
omc_app.api.mobile.review_payment_receipt
```

### Knowledge / Banners / FAQs

```text
omc_app.api.mobile.get_knowledge
omc_app.api.mobile.get_knowledge_article
omc_app.api.mobile.get_app_banners
omc_app.api.mobile.get_faqs
```

### Notifications

```text
omc_app.api.mobile.get_notifications
omc_app.api.mobile.get_notification_detail
omc_app.api.mobile.mark_notification_read
omc_app.api.mobile.mark_all_notifications_read
omc_app.api.mobile.register_push_token
omc_app.api.mobile.unregister_push_token
```

### Support

```text
omc_app.api.mobile.get_support_config
omc_app.api.mobile.create_support_ticket
omc_app.api.mobile.get_support_tickets
omc_app.api.mobile.get_support_ticket
omc_app.api.mobile.add_support_ticket_reply
omc_app.api.mobile.update_support_ticket_status
```

### Expense Tracker

```text
omc_app.api.expense.get_expense_categories
omc_app.api.expense.get_expense_entries
omc_app.api.expense.create_expense_entry
omc_app.api.expense.update_expense_entry
omc_app.api.expense.delete_expense_entry
omc_app.api.expense.get_expense_summary
```

### Internal Workspace

```text
omc_app.api.mobile.get_internal_workspace_summary
omc_app.api.mobile.get_leads
omc_app.api.mobile.get_lead
omc_app.api.mobile.get_customers
omc_app.api.mobile.get_customer
omc_app.api.mobile.get_tasks
omc_app.api.mobile.get_task
```

---

## Main DocTypes

| DocType | Use |
|---|---|
| OMC Customer Profile | User/customer/applicant profile and approval state |
| OMC Customer Preference | Notification/theme/language preferences |
| OMC Service | Service catalogue master |
| OMC Service Category | Service grouping |
| OMC Service Required Document | Service-wise document requirements |
| OMC Service Request | Customer service case |
| OMC Service Timeline | Case progress/activity timeline |
| OMC Service Document | Uploaded/requested customer documents |
| OMC Service Payment | Payment due and receipt status tracking |
| OMC Notification | Customer/internal notification records |
| OMC Push Token | Mobile push tokens |
| OMC Support Ticket | Customer support issue |
| OMC Support Reply | Support conversation replies |
| OMC Support Channel | WhatsApp/phone/email support config |
| OMC Support Topic | Support categories |
| OMC Lead | Internal lead/CRM record |
| OMC Task | Internal task/follow-up |
| OMC Expense Entry | Customer expense tracker entry |

---

## Access and Permission Model

### Guest

Allowed:

- Public service catalogue
- Service detail
- Knowledge/public content
- Tax calculator
- Support/contact config

Blocked:

- Service request creation
- Document upload
- Payments
- Customer dashboard
- Support ticket creation
- Internal workspace

### Pending User

Signup creates a pending profile:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending users can log in but protected customer features remain blocked.

### Approved Customer

Approved profile:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can create requests, upload documents, track cases, view payments, upload receipts when enabled, create support tickets, and use customer modules.

### Internal Staff

Internal permissions are role-based. Current role groups include:

- System Manager
- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Consultant
- OMC Business Partner
- OMC Tax Associate

---

## Smoke Tests

Run these after setup, migration, or deployment.

### Basic import check

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
```

### Session/capability check

```bash
bench --site omc.local execute omc_app.api.mobile.get_session_user
```

### Service catalogue

```bash
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
```

### Public support config

```bash
bench --site omc.local execute omc_app.api.mobile.get_support_config
```

### Migration check

```bash
bench --site omc.local migrate
```

### App list check

```bash
bench --site omc.local list-apps
```

### HTTP check

```bash
curl -I http://127.0.0.1:8000
```

For production:

```bash
curl -I https://erp.omchouse.com
```

---

## Mobile Backend URL

Local Flutter run:

```bash
flutter run \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

Production Flutter run/build:

```bash
flutter build apk --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com
```

---

## CORS / Local Mobile-Web Development

If Flutter web or another local frontend calls Frappe from a different origin, configure CORS from bench/site config as needed.

Example local development origin:

```text
http://localhost:5000
```

Typical local check:

```bash
curl -i -X OPTIONS http://127.0.0.1:8000/api/method/login \
  -H "Origin: http://localhost:5000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type"
```

Expected result should be a clean response without server crash.

---

## Backups Before Production Changes

Before migration or risky deployment:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local backup --with-files
```

Backup files are created under the site backup folder.

Do not run destructive commands such as `drop-site`, `reinstall`, or database reset unless intentionally rebuilding that site.

---

## Developer Workflow

### After editing backend app in bench

If you edit runtime app under:

```text
backend_omc_app/frappe-bench/apps/omc_app
```

sync changes back to repo-tracked app before committing.

### After editing repo-tracked app

If you edit repo-tracked app under:

```text
backend_omc_app/apps/omc_app
```

sync/copy it into bench runtime app before running bench commands, then install editable package if needed:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench/apps/omc_app
../../../env/bin/pip install -e .
```

### Commit flow

```bash
cd ~/data_drive/app_omc
git status
git add -A
git commit -m "Update Frappe backend documentation"
git push
```

---

## Troubleshooting

### App not listed in site

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local list-apps
bench --site omc.local install-app omc_app
bench --site omc.local migrate
```

### `No module named omc_app`

Run editable install from bench app folder:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench/apps/omc_app
../../../env/bin/pip install -e .
```

Then:

```bash
cd ../..
bench --site omc.local clear-cache
bench restart
```

### Doctype changes not visible

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local clear-cache
bench restart
```

### API gives permission error

Check user access state:

```bash
bench --site omc.local execute omc_app.api.mobile.get_session_user
```

Common causes:

- User is Guest
- User profile is Pending Review
- Customer is not approved
- Required internal role is missing
- API is correctly blocked by backend permission guard

### Internal workspace not visible

Check roles and capabilities:

```bash
bench --site omc.local execute omc_app.api.mobile.get_session_user
```

Internal access requires one of the allowed OMC/internal roles.

### Service request creation blocked

Check customer profile status:

```text
customer_status = Active
approval_status = Approved
```

Only approved customers should create service requests.

### nginx reload fails

Test config:

```bash
sudo nginx -t
```

If default nginx site conflicts with bench config:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### supervisor processes not running

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status
```

Restart all:

```bash
sudo supervisorctl restart all
```

---

## Production Checklist

Before marking backend production-ready:

- [ ] Site exists and app is installed
- [ ] `bench --site omc.local migrate` passes
- [ ] `bench --site omc.local list-apps` shows `omc_app`
- [ ] Service catalogue API works
- [ ] Signup creates pending profile
- [ ] Pending user is blocked from protected actions
- [ ] Approved customer can create service request
- [ ] Document upload works and files are private where required
- [ ] Payment receipt tracking works if enabled
- [ ] Support ticket flow works
- [ ] Notifications list/detail works
- [ ] Internal workspace is blocked for customers
- [ ] Internal workspace works for authorized staff
- [ ] nginx config passes
- [ ] supervisor services are running
- [ ] HTTPS is configured
- [ ] Backup exists before migration/release

---

## License

MIT
