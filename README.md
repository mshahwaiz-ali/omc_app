# OMC App

A production-oriented digital service platform for **OMC House**, combining a Flutter application with a custom Frappe backend.

OMC App gives guests, customers, and authorised staff one connected system for service discovery, onboarding, case processing, documents, payments, support, notifications, referrals, tax utilities, expense tracking, and internal operations.

> **Authority principle:** Flutter controls presentation and navigation. Frappe remains the source of truth for identity, permissions, ownership, assignments, workflow state, and protected mutations.

---

## Current status

The application is functionally implemented across the OMC-owned Flutter and Frappe boundary. The latest recorded full audit on 3 August 2026 reported:

- isolated OMC backend suite: **556/556 passed** with `--skip-test-records`;
- Flutter suite: **303/303 passed**;
- Flutter static analysis: **no issues found**;
- Linux workflow integration contract: **1/1 passed**;
- Android debug APK build: passed;
- focused live public, protected, and admin-operation HTTP checks: passed.

These are recorded audit results, not a promise that an untested later commit or a different environment has the same result. See [`inspection.md`](inspection.md) and the [dated E2E report](docs/test_reports/omc_e2e_workflow_report_2026-08-02.md) for commands, evidence boundaries, and limitations.

Current documentation-refresh verification at `main` commit `5e599a92`:

- `flutter analyze`: passed, no issues;
- `flutter test`: **303/303 passed**;
- backend suite: **557 ran, 1 failed**. The failure is `test_web_link_uses_frappe_origin_by_default`, whose assertion still expects the retired `/verify-email` web page while current code intentionally generates the `verify_registration_web` API endpoint. The suite is therefore not represented as currently all-green until that contract test is reconciled.

Remaining release gates are environment- or hardware-specific:

- build the signed Android release artefact against the production HTTPS endpoint;
- install and exercise it on a physical device, including device lock;
- complete production API, role-denial, upload, scheduler, and worker smoke tests;
- perform iOS archive, signing, Face ID, and App Store validation on macOS/Xcode when required;
- have the client ERP owner resolve the retained empty `HS Code` Link metadata if those ERP fields will be used.
- reconcile and rerun the current verification-web-link backend contract test.

Validation results must always be taken from actual command output and must never be assumed.

---

## Product overview

OMC App connects two experiences to the same Frappe records.

### Customer experience

Customers can:

- browse active OMC services and requirements;
- create an account through a structured four-step signup flow;
- verify their email and wait for approval where required;
- manage profile, contact, business, and notification preferences;
- submit service requests;
- upload and replace required documents;
- track case status, progress, timelines, and next actions;
- review payment instructions and receipt-review status;
- submit payment receipts through protected upload flows;
- receive in-app and push-ready notifications;
- create and follow support tickets;
- use the tax calculator;
- track expenses, budgets, summaries, and receipts;
- access FAQs, knowledge content, announcements, and contact details.

### Internal operations

Authorised OMC staff can:

- review customer onboarding and approval state;
- work from role-specific operational queues;
- create assisted service requests for eligible customers;
- manage assigned service cases;
- review customer documents;
- review payment receipts;
- manage support tickets and leads;
- manage operational tasks;
- work with referrals and partner-managed cases;
- publish customer-facing content;
- receive workflow notifications and escalations;
- access only the records and actions allowed by their capabilities and assignment scope.

For a business-facing feature guide, see [`omc_detailed_explanation.md`](omc_detailed_explanation.md).

---

## Platform architecture

```text
+-----------------------------------------------------------+
|                       Flutter App                         |
|                                                           |
| Guest | Pending Customer | Approved Customer | Staff      |
| Riverpod state | GoRouter policy | secure local storage   |
+-------------------------------+---------------------------+
                                |
                                | HTTPS / Frappe APIs
                                v
+-----------------------------------------------------------+
|                       Frappe Site                         |
|                                                           |
| Session auth | CSRF | permissions | file handling         |
| whitelisted methods | scheduler | background workers      |
+-------------------------------+---------------------------+
                                |
                                v
+-----------------------------------------------------------+
|                    Custom OMC Backend                     |
|                                                           |
| route guards | capability checks | ownership checks       |
| workflow services | DocTypes | permission hooks | tests   |
+-------------------------------+---------------------------+
                                |
                                v
+-----------------------------------------------------------+
|                    Operational Records                    |
|                                                           |
| customers | services | requests | documents | payments    |
| support | leads | tasks | referrals | notifications       |
+-----------------------------------------------------------+
```

The backend is authoritative even when the Flutter interface hides, disables, or redirects a route.

---

## Access model

### Guest

A guest can use public and guest-safe areas such as:

- public home content;
- active service catalogue and service details;
- approved FAQs and knowledge content;
- contact information;
- tax calculator;
- login, signup, verification, and recovery flows.

Guests cannot access customer cases, documents, payments, private notifications, support history, expense records, or internal operations.

### Pending customer

A pending customer has registered but has not completed OMC approval.

Typical state:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending customers can sign in, view their profile and approval state, maintain allowed preferences, and continue using guest-safe functionality. Approved-only service workflows remain locked.

### Approved customer

Typical state:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can access customer workflows, but every read and mutation remains ownership-scoped to their own OMC customer profile.

### Internal staff

Internal access is capability-driven rather than based on one broad staff flag.

Supported OMC roles include:

- **OMC Admin** — full application administration and operational authority;
- **OMC Manager** — broad operations without normal Admin-only configuration authority;
- **OMC Support Agent** — support, leads, and relevant customer communication;
- **OMC Document Reviewer** — document queues, attachments, and review decisions;
- **OMC Finance Reviewer** — payment queues, receipts, and finance decisions;
- **OMC Consultant** — assigned service requests and tasks;
- **OMC Tax Associate** — assigned tax-related service work;
- **OMC Business Partner** — assigned partner-managed work;
- **OMC Customer** — customer identity, still governed by approval and ownership.

See [`docs/app_role.md`](docs/app_role.md) for the canonical role and capability model.

---

## Main capabilities

### Authentication and onboarding

- role-aware signup for Customer, Consultant, Business Partner, and Tax Associate requests;
- username suggestion and availability validation;
- validated email, phone, WhatsApp, CNIC, address, and password fields;
- optional referral capture and assistance consent;
- email-verification success state with resend cooldown;
- login identity resolution;
- password-reset and pending-secret lifecycle hardening;
- approval-aware post-login routing;
- secure logout and session cleanup;
- email verification through app/browser links with resend cooldown and invalid-token handling;
- optional post-login device lock using fingerprint, Face ID, or the configured device credential;
- automatic re-lock when the signed-in app is backgrounded and resumed.

### Profile and settings

- self-service profile editing through guarded backend endpoints;
- personal, contact, and business profile fields;
- protected account email authority;
- notification preference controls;
- service, document, payment, and tax notification categories;
- account deletion request through support workflow;
- legal policy and application information shortcuts;
- role-aware visibility and editability.

### Service catalogue

- backend-managed categories and services;
- active/inactive visibility;
- public customer-safe service data;
- service descriptions, requirements, pricing context, and required documents;
- internal configuration excluded from public responses;
- protected service-request initiation.

### Service requests and cases

- approved-customer request creation;
- assisted request creation by authorised staff;
- active request detection and resume/start-new handling;
- customer and internal case tracking;
- status, priority, progress, timeline, and next-action presentation;
- explicit, referral, service-default, role-based, and manager-fallback assignment;
- least-loaded eligible assignee selection;
- duplicate-safe Frappe ToDo creation;
- completion safeguards and operational audit entries.

### Documents

- multipart document uploads;
- request ownership validation;
- prevention of cross-request file reuse;
- customer document list and replacement flows;
- reviewer-specific queues and attachment access;
- approval and rejection decisions;
- rejected documents return the request to customer action;
- final required-document approval triggers payment eligibility evaluation;
- delayed-review reminders and escalation support.

### Payments

- payment records linked to service requests;
- automatic payment creation only after required documents are approved;
- service-controlled amount and currency;
- rejection of zero or missing payable amounts;
- duplicate active-payment prevention;
- protected receipt uploads;
- finance review queues and decisions;
- `Paid`, `Rejected`, and `Under Review` workflow transitions;
- customer and internal notifications;
- role-specific payment and receipt visibility.

### Support, leads, referrals, and tasks

- customer support ticket creation and replies;
- internal support queues and read-state handling;
- lead creation and management;
- referral summaries and detail views;
- guarded referral ownership and assistance rules;
- assignment-scoped tasks;
- enabled System User validation for task assignment;
- guarded task assignment/reassignment, planning updates, and operational-status transitions;
- transaction-safe `Submitted by QC` completion for the exact ERP Task and linked ToDos;
- internal operational dashboard and work queues.

### Administration and recovery

- registration approval and rejection;
- staff invitation, supported-role editing, and account enable/disable;
- guarded business settings;
- service-case reassignment with eligible assignee selection and recorded reason;
- exhausted ERP synchronisation inspection and retry;
- pending-discount inspection, approval, and reason-required rejection;
- searchable, paginated, capability-specific operation queues.

### Notifications

- ownership-safe notification reads;
- exact recipient-user and customer-profile matching;
- unread/read state and pagination;
- notification preference gating;
- push-token registration and integrity controls;
- backend-authored workflow notifications;
- scheduler-driven reminders and escalation notices;
- customer-facing fallback content controlled by the backend.

### Tax calculator

- guest-safe and authenticated access;
- backend-managed tax slabs;
- supported tax years, income modes, filer states, and income types;
- bounded and validated numeric input;
- finite and non-negative monetary values;
- canonical backend calculation authority.

### Expense tracker

- customer-owned expense records;
- categories, dates, descriptions, and positive finite amounts;
- summary and budget views;
- budget thresholds and variance monitoring;
- receipt upload support;
- bounded bulk synchronisation;
- cloud/local sync integrity controls;
- rejection of direct receipt URL injection.

### Dashboard and content

- customer and internal dashboards;
- service-aware recent activity presentation;
- guarded dashboard reads;
- backend-driven announcements, FAQs, knowledge articles, onboarding, branding, and contact content;
- public, customer, and internal data separation.

### Resilience and fallbacks

- consistent offline, timeout, permission, validation, configuration, server, and malformed-response messages;
- retryable loading/error states and duplicate-action guards;
- fail-closed route and capability handling;
- packaged fallback branding, legal content, support configuration, onboarding slides, and quick actions;
- base-service preservation if optional template enrichment fails;
- explicit development-only service preview/catalogue fallback, never fake production catalogue data;
- guest/pending local expense mode and approved-customer guarded cloud mode;
- partial-dashboard unavailable indicators instead of false zeroes;
- local device-lock failure or cancellation keeps the app locked and offers another unlock attempt.

---

## Automated service lifecycle

```text
Request created
    |
    +--> authorised assignment resolved
    +--> duplicate-safe ToDo created
    +--> assignee and customer notifications created
    |
Customer uploads required documents
    |
Reviewer decision
    |
    +--> Rejected
    |       -> Waiting for Customer
    |       -> customer notified
    |
    +--> All required documents approved
            -> payable service configuration validated
            -> one Pending payment created
            -> Waiting for Payment
            -> customer notified

Customer submits receipt
    |
    +--> finance and operational reviewers notified
    +--> delayed-review reminders enabled
    |
Finance decision
    |
    +--> Paid
    |       -> request moves forward
    |       -> customer and assignee notified
    |
    +--> Rejected
            -> Waiting for Customer
            -> replacement receipt required

Completion requested
    |
    +--> required documents must be approved
    +--> active payments must be Paid
    +--> unresolved rejected items block completion
    +--> open ToDos are closed
    +--> completion timestamp and timeline are recorded
    +--> customer is notified
```

Documents and payment receipts are never automatically approved. Automation begins after an authorised human decision.

---

## Security model

OMC App uses defence in depth.

### Backend-first authorisation

Protected methods enforce:

- authentication;
- customer approval state;
- canonical capabilities;
- customer ownership;
- internal assignment scope;
- document and payment relationships;
- supported workflow transitions;
- validated request payloads.

### Fail-closed routing and endpoint authority

- unknown authenticated routes are denied by default;
- unknown or blank access levels are denied;
- sensitive legacy methods route through guarded wrappers;
- public catalogue endpoints expose active customer-safe data only;
- customer and internal reads pass through ownership or capability guards;
- sensitive mutations require guarded endpoints;
- route-to-authority mappings are covered by tests.

### Input and file safety

- public and authenticated write payloads are bounded;
- numeric values are validated for type, range, and finiteness;
- uploaded files are tied to the correct customer and operational record;
- protected receipt and document flows reject user-controlled URL injection;
- secrets, private files, databases, logs, backups, and runtime state are excluded from source control.

---

## Technology stack

### Flutter application

- Flutter and Dart;
- Riverpod;
- GoRouter;
- Dio;
- Flutter Secure Storage;
- Shared Preferences;
- File Picker and Image Picker;
- Cached Network Image;
- FL Chart;
- Local Auth.

### Frappe backend

- Frappe Framework 14 (`frappe` 14.101.1 and `erpnext` 14.87.0 in the checked-in Bench);
- Python;
- MariaDB/MySQL;
- Redis queues and workers;
- custom OMC DocTypes;
- whitelisted method APIs;
- permission query conditions and record-level hooks;
- scheduler jobs;
- nginx and Supervisor in production.

---

## Repository structure

```text
.
├── README.md
├── OMC_APP_FEATURES.md
├── omc_detailed_explanation.md
├── inspection.md
├── docs/
│   ├── app_role.md
│   └── test_reports/
├── omc_app/
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   └── features/
│   ├── test/
│   ├── docs/backend_api_contract.md
│   └── pubspec.yaml
└── backend_omc_app/
    ├── deploy/
    └── frappe-bench/
        └── apps/omc_app/
            ├── omc_app/
            │   ├── api/
            │   ├── setup/
            │   ├── permissions.py
            │   ├── hooks.py
            │   └── omc_app/doctype/
            ├── README.md
            └── pyproject.toml
```

---

## Local development

The examples assume the repository is available at `~/data_drive/app_omc`.

### Flutter

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

Android emulators normally reach the host through `10.0.2.2`:

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

Do not recreate an existing site, database, Bench, or production deployment during a normal update.

---

## Configuration

Supply the API endpoint at run or build time:

```bash
--dart-define=OMC_API_BASE_URL=https://example.com
```

Never commit credentials, `site_config.json`, private files, database dumps, logs, generated builds, or Bench runtime state.

Deployment assets are under [`backend_omc_app/deploy/`](backend_omc_app/deploy/).

---

## Validation

### Flutter

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Latest recorded full-audit result:

```text
Flutter analyze: No issues found
Flutter tests: 303 passed
Linux workflow contract: 1 passed
Android debug APK: built successfully
```

Current refresh result on commit `5e599a92`: analysis passed and Flutter tests remain 303/303.

### Frappe backend

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local run-tests --app omc_app --skip-test-records
```

Latest confirmed result:

```text
OMC backend tests: 556 passed
```

`--skip-test-records` is intentional for the populated OMC site. Ordinary global ERP fixture bootstrap is a different boundary and must not be represented as part of this recorded OMC result.

The current rerun after later verification-link commits executed 557 tests and reported one assertion failure in `test_web_link_uses_frappe_origin_by_default`: the test expects the former `/verify-email` URL, while `auth_links.py` now uses the working `pending_registration.verify_registration_web` endpoint. This is a current test-contract blocker, not part of the earlier 556/556 evidence.

### Repository hygiene

```bash
cd ~/data_drive/app_omc
git diff --check
git status --short
```

### Required manual smoke coverage

Production verification should cover both allowed actions and expected denials for:

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

---

## Production deployment

`main` is the repository source of truth.

A routine update should preserve the deployed Bench, site, database, configuration, private files, nginx, Supervisor, and Redis setup.

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

Only run commands appropriate for the actual server layout.

Production readiness also requires:

- HTTPS;
- protected secrets and site configuration;
- healthy MariaDB and Redis services;
- enabled scheduler and workers;
- scheduled backups and a tested restore procedure;
- post-deployment login, API, upload, assignment, payment, notification, scheduler, and role smoke tests;
- Android release build and device verification against the production endpoint.

---

## Documentation

- [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — complete business and feature guide;
- [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md) — source-backed feature-by-feature catalogue;
- [`inspection.md`](inspection.md) — endpoint-to-provider-to-screen parity and production-readiness audit;
- [`docs/test_reports/omc_e2e_workflow_report_2026-08-02.md`](docs/test_reports/omc_e2e_workflow_report_2026-08-02.md) — dated validation evidence and limitations;
- [`docs/app_role.md`](docs/app_role.md) — role, capability, assignment, and access architecture;
- [`omc_app/docs/backend_api_contract.md`](omc_app/docs/backend_api_contract.md) — Flutter/backend API contract;
- [`backend_omc_app/frappe-bench/apps/omc_app/README.md`](backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend development and operations;
- [`backend_omc_app/deploy/`](backend_omc_app/deploy/) — deployment templates and verification assets.

---

## Licence and ownership

This repository contains proprietary OMC House application code and operational documentation. Distribution and reuse must follow the project owner's authorisation and applicable licence terms.

---

**OMC App connects a simple customer experience to a controlled, auditable, backend-enforced operating platform.**
