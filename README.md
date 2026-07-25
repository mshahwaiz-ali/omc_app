# OMC App

A full-stack digital service platform for **OMC House**, combining a Flutter customer and staff application with a custom Frappe backend.

OMC App brings service discovery, customer onboarding, case management, document collection, payment review, support, notifications, tax utilities, expense tracking, and internal operations into one role-aware system.

> **Core principle:** the interface should stay simple, but every protected action must be authorised and enforced by the backend.

---

## Table of contents

- [Product overview](#product-overview)
- [Platform architecture](#platform-architecture)
- [User access model](#user-access-model)
- [Main capabilities](#main-capabilities)
- [Security model](#security-model)
- [Technology stack](#technology-stack)
- [Repository structure](#repository-structure)
- [Local development](#local-development)
- [Configuration](#configuration)
- [Validation](#validation)
- [Production deployment](#production-deployment)
- [Documentation](#documentation)
- [Current project status](#current-project-status)

---

## Product overview

OMC App has two connected experiences built on the same business data.

### Customer experience

Customers can:

- browse active OMC services;
- view service details and requirements;
- create an account and complete onboarding;
- wait for OMC approval where required;
- submit service requests;
- upload required documents;
- track case progress and next actions;
- review payment instructions and receipt status;
- receive notifications;
- create and follow support tickets;
- manage their profile and preferences;
- use the tax calculator;
- record and review personal expenses;
- access FAQs, knowledge content, announcements, and contact information.

### Internal operations

Authorised OMC staff can:

- review and approve customer profiles;
- manage service catalogue content;
- process customer service requests;
- review uploaded documents;
- review payment receipts;
- manage leads and support tickets;
- assign and complete operational tasks;
- publish customer-facing content;
- work through capability-based internal queues;
- access only the records and actions allowed by their assigned role.

The intended workflow is:

```text
Customer uses the Flutter app
        |
        | HTTPS / Frappe APIs
        v
Custom OMC Frappe backend
        |
        | DocTypes, permissions, workflows, audit data
        v
OMC staff manage operations through Frappe Desk and internal app modules
```

---

## Platform architecture

```text
+------------------------------------------------------+
|                    Flutter App                       |
|                                                      |
|  Guest     Pending Customer     Approved Customer    |
|  Internal staff modules shown by capability          |
+---------------------------+--------------------------+
                            |
                            | HTTPS
                            | REST resources and whitelisted methods
                            v
+------------------------------------------------------+
|                     Frappe Site                      |
|                                                      |
|  Session auth | CSRF | permissions | file handling   |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
|                 Custom OMC Frappe App                |
|                                                      |
|  APIs | guards | capabilities | permissions          |
|  controllers | DocTypes | workflows | tests          |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
|             OMC-owned operational records            |
|                                                      |
|  Customers | services | cases | documents | payments |
|  support | leads | tasks | notifications | tax data  |
+------------------------------------------------------+
```

The Flutter app does not define authority. It consumes canonical state and capability information from the backend and uses it to shape navigation and user experience. The backend remains the final enforcement layer.

---

## User access model

### Guest

A guest is not signed in.

Typical allowed access:

- active public service catalogue;
- public service details;
- approved public content;
- FAQs and knowledge articles;
- tax calculator;
- login and signup;
- guest-safe onboarding and contact information.

Guests cannot access customer records, service cases, documents, payments, notifications, support history, or internal operations.

### Pending customer

A pending customer has registered but is not yet approved.

Typical state:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending customers can sign in, view their own profile and approval status, and continue using guest-safe features. Approved-only workflows remain locked.

### Approved customer

Typical approved state:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can access their own service requests, documents, payment records where enabled, notifications, support tickets, profile, expense data, and other customer tools.

Customer access is always ownership-scoped:

> An approved customer may only read or modify records belonging to their own customer profile.

### Internal staff

The internal workspace uses role-based capabilities rather than a single broad staff permission.

Active OMC roles include:

- **OMC Admin** — full OMC application administration and operations;
- **OMC Manager** — broad operational management without normal Admin-only configuration authority;
- **OMC Support Agent** — support, lead, and relevant customer communication workflows;
- **OMC Document Reviewer** — document queues, attachments, and document decisions;
- **OMC Finance Reviewer** — payment queues, receipts, and payment decisions;
- **OMC Consultant** — assigned service cases and tasks;
- **OMC Tax Associate** — assigned tax-related service work;
- **OMC Business Partner** — assigned partner-managed work;
- **OMC Customer** — customer portal identity, still subject to profile approval state.

Opening the internal workspace does not grant every internal action. Sensitive reads and mutations require specific capabilities and record scope.

See [`docs/app_role.md`](docs/app_role.md) for the complete role architecture, capability matrix, assignment rules, and validation requirements.

---

## Main capabilities

### Service catalogue

- backend-managed categories and services;
- active/inactive visibility;
- customer-visible details and instructions;
- required-document configuration;
- public endpoints restricted to active customer-safe data;
- internal configuration kept out of public responses.

### Customer onboarding

- bounded signup fields;
- validated email and password input;
- customer profile creation;
- pending-review and approved states;
- protected profile updates;
- account email cannot be changed through profile-edit endpoints.

### Service requests and case tracking

- approved-customer request creation;
- active-service validation;
- bounded title, description, phone, email, and priority values;
- ownership-scoped customer views;
- internal assignment and status workflows;
- customer-visible progress and action requirements.

### Documents

- multipart upload flow;
- service-request ownership validation;
- prevention of cross-request file reuse;
- document review queues;
- reviewer-specific capabilities and attachment access.

### Payments

- payment and receipt tracking;
- finance review workflow;
- role-specific receipt visibility;
- protected payment mutations and review actions.

### Support, leads, and tasks

- customer support tickets and replies;
- internal support queues;
- lead management;
- assignment-scoped task access;
- enabled System User validation for internal task assignment.

### Tax calculator

Public tax requests are validated before the canonical calculator runs:

- maximum request size;
- bounded advanced inputs;
- supported income types, filer statuses, and income modes;
- finite and non-negative monetary values;
- protection against nested or malformed numeric payloads.

### Expense tracker

- customer-owned expense records;
- validated positive finite amounts;
- bounded text and identifiers;
- bounded bulk synchronisation;
- validated budget thresholds;
- receipt uploads through multipart file handling;
- direct receipt URL injection rejected.

### Notifications and content

- ownership-safe customer notifications;
- exact profile or recipient-user matching;
- backend-driven FAQs, knowledge, announcements, and onboarding content;
- public content separated from authenticated and internal data.

---

## Security model

OMC App follows a defence-in-depth model.

### Backend-first authorisation

Flutter route guards improve user experience, but they are not treated as security boundaries. Protected backend methods enforce authentication, approval state, capabilities, ownership, assignment, and document relationships.

### Fail-closed behaviour

- unknown authenticated routes are denied by default;
- unknown or blank quick-action access levels are denied;
- inactive services cannot be requested through guarded creation endpoints;
- public service endpoints expose active customer-safe data only;
- sensitive write endpoints are routed through validation guards;
- direct user-controlled file URLs are not accepted for protected receipt uploads.

### Record scope

- customers see only their own records;
- consultants, Tax Associates, and Business Partners are assignment-scoped by default;
- Document Reviewers and Finance Reviewers operate in separate domains;
- Support Agents receive only the customer and service context required for support work;
- Managers receive broad operational access without normal Admin-only configuration rights.

### Input and file safety

- public and authenticated write payloads are bounded;
- numeric values are checked for finite range and supported limits;
- bulk operations have count and payload-size limits;
- uploaded files are tied to the correct customer and service request;
- secrets, site configuration, private files, databases, logs, and backups are excluded from version control.

---

## Technology stack

### Frontend

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio
- Flutter Secure Storage
- Shared Preferences
- File Picker and Image Picker
- Cached Network Image
- FL Chart

### Backend

- Frappe Framework 15
- Python
- MariaDB/MySQL through Frappe
- Redis queues and workers
- custom OMC DocTypes
- Frappe whitelisted method APIs
- Frappe permission query conditions and record-level permission hooks
- nginx and Supervisor in production

---

## Repository structure

```text
.
├── README.md
├── omc_detailed_explanation.md
├── docs/
│   └── app_role.md
├── omc_app/
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   └── features/
│   ├── test/
│   └── pubspec.yaml
└── backend_omc_app/
    ├── deploy/
    └── frappe-bench/
        └── apps/
            └── omc_app/
                ├── omc_app/
                │   ├── api/
                │   ├── setup/
                │   ├── permissions.py
                │   ├── hooks.py
                │   └── omc_app/doctype/
                ├── README.md
                └── pyproject.toml
```

### Main Flutter feature areas

```text
omc_app/lib/features/
├── auth/
├── home/
├── service_catalogue/
├── service_requests/
├── documents/
├── payments/
├── dashboard/
├── leads/
├── customers/
├── tasks/
├── notifications/
├── support/
├── profile/
├── settings/
├── tax_calculator/
├── expense_tracker/
└── internal_workspace/
```

### Important backend areas

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/
├── api/
│   ├── access.py
│   ├── branding_config.py
│   ├── expense_guard.py
│   ├── expense_write_guard.py
│   ├── profile_guard.py
│   ├── public_catalogue.py
│   ├── quick_actions.py
│   ├── secured_mobile.py
│   ├── service_request_guard.py
│   ├── service_templates.py
│   ├── tax_calculator.py
│   └── tax_calculator_guard.py
├── setup/roles.py
├── permissions.py
└── hooks.py
```

---

## Local development

The commands below assume the repository is checked out at:

```text
~/data_drive/app_omc
```

Use equivalent paths for a different checkout location.

### Prerequisites

- Flutter stable with a Dart version compatible with `pubspec.yaml`;
- Python and a supported Frappe Bench environment;
- Frappe Framework 15;
- MariaDB or MySQL;
- Redis;
- Node.js and package tooling required by Frappe assets;
- Android Studio or an Android SDK for Android development.

### Flutter setup

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
flutter test
```

Run against a local backend:

```bash
flutter run \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

Android emulators normally reach the host machine through `10.0.2.2`:

```bash
flutter run \
  --dart-define=OMC_API_BASE_URL=http://10.0.2.2:8000
```

Use HTTPS for physical devices and production builds.

### Existing Frappe site

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench list-sites
bench --site omc.local list-apps
bench start
```

Expected installed applications:

```text
frappe
omc_app
```

### New Frappe site

Use this only when intentionally creating a new development site:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench new-site omc.local
bench --site omc.local install-app omc_app
bench --site omc.local migrate
bench --site omc.local clear-cache
```

Do not recreate an existing production site or database as part of a normal application update.

---

## Configuration

The Flutter API base URL is supplied at build or run time:

```bash
--dart-define=OMC_API_BASE_URL=https://example.com
```

Production secrets belong in protected environment and site configuration, never in tracked source files.

Do not commit:

- `.env` files containing credentials;
- `site_config.json`;
- database passwords;
- API secrets;
- private files;
- database dumps;
- logs;
- generated assets and build output;
- Bench runtime state.

Deployment templates and scripts live under [`backend_omc_app/deploy/`](backend_omc_app/deploy/).

---

## Validation

Never report a validation step as passed without reviewing its actual command output.

### Flutter

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

### Backend syntax

```bash
cd ~/data_drive/app_omc
python3 -m compileall -q \
  backend_omc_app/frappe-bench/apps/omc_app/omc_app
```

### Frappe tests

Run inside a configured OMC Bench with a working test site and database:

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

### Repository hygiene

```bash
cd ~/data_drive/app_omc
git diff --check
git status --short
```

### Required access smoke tests

Production readiness requires real-environment verification for:

- Guest;
- Pending Customer;
- Approved Customer;
- OMC Admin;
- OMC Manager;
- OMC Support Agent;
- OMC Document Reviewer;
- OMC Finance Reviewer;
- OMC Consultant;
- OMC Tax Associate;
- OMC Business Partner.

Each role should be tested for both allowed actions and expected denials.

---

## Production deployment

`main` is the source-of-truth branch for this repository.

A normal production update should preserve the existing Bench, site, database, configuration, private files, and process setup.

### Safe update outline

```bash
cd /path/to/app_omc
git fetch origin main
git pull --ff-only origin main

cd backend_omc_app/frappe-bench
bench --site <site> migrate
bench build
bench --site <site> clear-cache
sudo supervisorctl restart all
sudo systemctl reload nginx
```

Run only the commands appropriate for the actual server layout. Do not recreate the site, database, Bench, or deployment during a routine application update.

### Production requirements

- TLS/HTTPS;
- restricted site configuration and secrets;
- healthy MariaDB and Redis services;
- Supervisor-managed Frappe processes;
- nginx reverse proxy and asset serving;
- scheduled database and private-file backups;
- a tested restore procedure;
- post-deployment API, login, upload, and role smoke tests;
- Android build verification against the production API endpoint.

---

## Documentation

- [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — product, client workflow, and feature-by-feature explanation;
- [`docs/app_role.md`](docs/app_role.md) — canonical role and capability architecture;
- [`backend_omc_app/frappe-bench/apps/omc_app/README.md`](backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend-specific development and operations;
- [`omc_app/docs/backend_api_contract.md`](omc_app/docs/backend_api_contract.md) — frontend/backend API contract;
- [`backend_omc_app/deploy/`](backend_omc_app/deploy/) — deployment templates and verification scripts.

---

## Current project status

The platform currently includes:

- implemented Flutter customer and internal modules;
- capability-driven navigation and backend authorisation;
- customer ownership and internal assignment boundaries;
- hardened public catalogue, signup, profile, service-request, expense, receipt-upload, quick-action, and tax-calculator entry points;
- focused backend access tests;
- Flutter unit and route-access tests;
- production deployment assets and verification scripts.

Local static validation, guarded-input checks, Flutter tests, Flutter analysis, hook imports, and repository secret-tracking checks have been completed against the current codebase.

The remaining release workflow is environment-specific:

1. pull the validated source onto the production OMC server;
2. run the required Frappe migration and asset steps;
3. restart services safely;
4. run real API and role smoke tests;
5. build and test the Android application against the production endpoint.

---

## Licence and ownership

This repository contains proprietary OMC House application code and operational documentation. Distribution and reuse should follow the project owner's authorisation and any licence terms supplied with the deployment.

---

**OMC App connects a simple customer experience to a controlled, auditable, backend-enforced operations platform.**
