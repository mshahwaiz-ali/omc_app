# OMC App

OMC App is a full-stack customer-service platform for OMC House.

It combines a Flutter mobile/web application with a custom Frappe backend. Guests can browse public content, customers can request and track services, and OMC staff can process work through role-based internal workflows.

## What the platform does

- Public service catalogue and service details
- Customer signup, login, approval, and profile management
- Service request creation and tracking
- Required-document upload and review
- Payment due, receipt, and review tracking
- Notifications and push-token registration
- Support tickets, replies, and lead handling
- Customer expense tracker and tax calculator
- Internal workspace for OMC operations
- Capability-based frontend and backend access control

## Architecture

```text
Flutter App
  |
  | HTTPS / Frappe REST and method APIs
  v
Frappe Site
  |
  | omc_app.api.*
  v
Custom Frappe App
  |
  | APIs, controllers, permissions, DocTypes
  v
OMC-owned business data
```

Security rule:

> Flutter may hide or lock a feature, but every protected action must also be enforced by the backend.

## Repository layout

```text
omc_app/
  Flutter frontend
  lib/
    app/
    core/
    features/

backend_omc_app/
  frappe-bench/
    apps/omc_app/
      Repo-tracked custom Frappe app used by the local bench
    sites/
    config/
    logs/

ROLE.md
  Canonical role and access guide

docs/
  Supporting plans and project documentation
```

Primary working paths used by this project:

```text
Repository root: ~/data_drive/app_omc
Flutter app:     ~/data_drive/app_omc/omc_app
Frappe bench:    ~/data_drive/app_omc/backend_omc_app/frappe-bench
Backend app:     ~/data_drive/app_omc/backend_omc_app/frappe-bench/apps/omc_app
Local site:      omc.local
```

## Technology

### Frontend

- Flutter and Dart
- Riverpod
- GoRouter
- Dio
- Flutter Secure Storage
- Shared Preferences
- File Picker and Image Picker
- Cached Network Image
- FL Chart

The current Flutter package version is `1.0.0+1` and the Dart SDK constraint is `^3.12.2`.

### Backend

- Frappe Framework
- Python
- MariaDB/MySQL through Frappe
- Redis queues and workers
- Custom OMC DocTypes
- Frappe whitelisted APIs
- nginx and supervisor for production hosting

## Main user states

### Guest

Guests may use explicitly public routes such as service browsing, public content, login, signup, and approved utilities. Protected customer data and all internal operations are blocked.

### Pending customer

Signup creates or links a Frappe User and OMC Customer Profile. A pending customer can sign in but approved-only functionality remains locked.

Typical initial state:

```text
customer_status = Pending
approval_status = Pending Review
```

### Approved customer

Typical approved state:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can access their own profile, service requests, documents, payments where exposed, notifications, support, and customer tools. Every record is ownership-scoped.

### Internal staff

Internal access is capability-driven and record-scoped. Active OMC staff roles are:

- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Consultant
- OMC Tax Associate
- OMC Business Partner

See [`ROLE.md`](ROLE.md) for the complete role matrix, assignment rules, blocked areas, and smoke-test expectations.

## Important access behavior

- Unknown authenticated routes are denied by default.
- Flutter navigation and route guards use canonical backend capabilities.
- Customers can access only their own records.
- Consultants, Tax Associates, and Business Partners are normally assignment-scoped.
- Document Reviewer and Finance Reviewer operate in separate functional domains.
- Support Agent receives support and lead access, not general review access.
- Manager has broad operational access but no normal delete/share rights and no Admin-only configuration access.
- A file attached to one service request cannot be reused for another request.
- Notifications require an exact customer-profile or recipient-user match.
- Internal tasks can be assigned only to enabled System Users.

## Main Flutter modules

```text
omc_app/lib/features/
  auth/
  home/
  service_catalogue/
  service_requests/
  documents/
  payments/
  dashboard/
  leads/
  customers/
  tasks/
  notifications/
  support/
  profile/
  settings/
  tax_calculator/
  expense_tracker/
  internal_workspace/
```

Shared routing, networking, storage, configuration, theming, and widgets live under `omc_app/lib/app` and `omc_app/lib/core`.

## Main backend areas

The custom backend app contains:

- mobile and secured APIs;
- access and capability helpers;
- role provisioning and permission synchronization;
- query and record-level permission rules;
- OMC DocTypes for customers, services, requests, documents, payments, notifications, support, leads, tasks, tax data, and configuration;
- tests for access boundaries and core behavior.

Important backend files include:

```text
omc_app/api/mobile.py
omc_app/api/document_upload.py
omc_app/permissions.py
omc_app/setup/roles.py
omc_app/api/test_permissions.py
```

All paths above are relative to:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/
```

## Local backend setup

### Start an existing bench

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench list-sites
bench --site omc.local list-apps
bench start
```

Expected installed apps include:

```text
frappe
omc_app
```

### Install on a new site

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench new-site omc.local
bench --site omc.local install-app omc_app
bench --site omc.local migrate
bench --site omc.local clear-cache
```

Do not commit site configuration, databases, logs, private files, or secrets.

## Run the Flutter app

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter run --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

For an Android emulator, the host machine may need to be addressed as `10.0.2.2` instead of `127.0.0.1`.

Example:

```bash
flutter run --dart-define=OMC_API_BASE_URL=http://10.0.2.2:8000
```

Use HTTPS for real devices and production environments.

## Validation

### Backend

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local run-tests --app omc_app
```

Focused permission suite:

```bash
bench --site omc.local run-tests \
  --app omc_app \
  --module omc_app.api.test_permissions
```

### Flutter

```bash
cd ~/data_drive/app_omc/omc_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

### Repository hygiene

```bash
cd ~/data_drive/app_omc
git diff --check
git status --short
```

Never report validation as passed unless the actual command output has been reviewed.

## Production deployment outline

A normal backend deployment should include:

```bash
cd /path/to/app_omc
git pull --rebase origin main

cd backend_omc_app/frappe-bench
bench --site <site> migrate
bench build
bench --site <site> clear-cache
sudo supervisorctl restart all
sudo systemctl reload nginx
```

Production requirements:

- TLS/HTTPS
- restricted secrets and site configuration
- MariaDB and Redis health
- supervisor-managed Frappe processes
- nginx reverse proxy and asset serving
- database and private-file backups
- tested restore procedure
- real-account role smoke tests

## Contribution workflow

This repository currently uses `main` as the working branch.

Before editing:

```bash
cd ~/data_drive/app_omc
git pull --rebase origin main
git status --short
```

After validation:

```bash
git add <changed-files>
git commit -m "<clear message>"
git pull --rebase origin main
git push origin main
```

Do not commit runtime bench data, secrets, generated build output, logs, local databases, or backup files.

## Current project state

The capability and access-control architecture is implemented and covered by focused backend and Flutter tests. The remaining production gate is real-environment end-to-end smoke testing with Guest, Pending Customer, Approved Customer, and every internal OMC role.

## Documentation

- [`ROLE.md`](ROLE.md) — canonical roles, capabilities, ownership, assignment, and smoke-test matrix
- [`backend_omc_app/frappe-bench/apps/omc_app/README.md`](backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend-specific setup and operations
- [`docs/`](docs/) — supporting plans and project notes

---

OMC App is designed around one central principle: the frontend should be easy to use, while authorization remains explicit, consistent, and enforced by the backend.