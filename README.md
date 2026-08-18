# OMC App

OMC App is the customer and operations platform for **OMC House**. The project combines a Flutter client with a custom Frappe application that integrates with ERPNext while keeping ERPNext source code untouched.

> **Backend-first rule:** Flutter controls presentation and navigation. Frappe/OMC backend code remains authoritative for identity, permissions, ownership, workflow state, assignments, validation, and protected mutations.

---

## Current state

The current architecture has moved away from duplicated OMC records where ERPNext already has a suitable source of truth.

The main model is now:

```text
Customer side
-------------
ERP Customer
    |
    +--> OMC Customer Profile
             |
             +--> Frappe Website User only when app login is activated

Internal side
-------------
Frappe User
    |
    +--> OMC Staff Profile ----> ERP Employee

Lead side
---------
Native ERPNext Lead
    |
    +--> ERP Customer
             |
             +--> OMC Customer Profile

Service execution
-----------------
OMC Service Request
    |
    +--> OMC workflow / document / payment controls
    |
    +--> ERP Service / Project / Task for execution
```

OMC-specific approval, mobile access, referral, and service-workflow rules live in `omc_app`. ERPNext remains the accounting and operational ERP foundation.

### Latest validated snapshot

Validated on the restored client environment after the current staff, migration, and customer-activation changes:

```text
Backend OMC suite:            591 / 591 passed
Customer activation tests:      8 / 8 passed
Flutter analyze:              No issues found
Flutter suite:                326 / 326 passed
Router policy parity suite:    51 / 51 passed
```

These numbers describe the tested repository state, not a guarantee for a different site or a later untested commit.

### Work intentionally not completed yet

- The permanent existing-customer bulk migration has **not** been run.
- A real browser/device end-to-end rehearsal of the new imported-customer activation flow is still required before that migration is released.
- Imported customers without a safe unique email need a future secure phone/SMS or controlled staff-assisted activation path; they are not given a default password.

---

## Source-of-truth boundaries

OMC App deliberately separates ERP records from OMC application state.

| Area | Source of truth | OMC responsibility |
| --- | --- | --- |
| Lead | ERPNext `Lead` | guarded mobile/internal access and OMC workflow integration |
| ERP customer master | ERPNext `Customer` | link to app profile and migration/activation bridge |
| Customer app identity | `OMC Customer Profile` + Frappe `User` when activated | approval, app lifecycle, referral attribution, mobile identity |
| Internal identity | Frappe `User` + ERP `Employee` | `OMC Staff Profile` controls OMC persona and approval |
| Service catalogue | `OMC Service` | customer-safe service configuration and ERP Task Type mapping |
| Customer service workflow | OMC service/request/payment/document records | lifecycle, validation, customer experience, guarded mutations |
| ERP execution | ERP `Service`, `Project`, `Task` | created/synchronised through guarded OMC adapters |
| Accounting | ERPNext finance records | OMC payment/receipt workflow feeds the operational gate; ERP remains finance authority |

**Do not implement OMC features by patching ERPNext source files.** Integration belongs in the custom `omc_app` package through hooks, APIs, permission guards, adapters, fixtures, and migrations.

---

## Customer identity and onboarding

There are two separate customer-entry paths.

### 1. New customer signup

```text
Flutter signup
    -> OMC Pending Registration
    -> email verification
    -> Frappe Website User
    -> OMC Customer Profile
    -> approval-aware app access
```

New signup remains an explicit registration flow. Registration tokens are time-limited and verification is handled by the backend.

### 2. Existing ERP customer activation

Existing ERP customers are migrated **profile-only**. Migration does not create thousands of login accounts or assign shared passwords.

```text
Existing ERP Customer
    -> OMC Customer Profile
       Active + Approved
       customer_origin = Imported
       manual_customer_status = Unregistered
       user = blank
       linked_app_user = blank

Customer opens OMC App
    -> Activate existing account
    -> enters registered email
    -> receives secure activation link
    -> opens /activate-account?token=...
    -> chooses password
    -> Website User is created only now
    -> OMC Customer role is applied
    -> existing profile is linked
    -> normal login is available
```

### Activation security

The imported-customer activation flow is designed to prove control of the registered email before creating a login account.

- activation request responses are enumeration-safe;
- the generated token is cryptographically random;
- only a SHA-256 token digest is stored in `OMC Customer Activation`;
- plaintext activation tokens are not stored in the DocType;
- token lifetime is 30 minutes;
- resend cooldown is 60 seconds;
- a newer request supersedes an older pending token;
- tokens are one-time use;
- password minimum is eight characters;
- the customer chooses their own password;
- no default or shared password is generated;
- an existing Frappe User collision is never automatically merged into the customer identity;
- identity collisions move to review rather than bypassing verification.

Flutter routes for this flow are:

```text
/activate-existing-account
/activate-account?token=...
/app/activate-account?token=...   -> canonical activation route
```

---

## Existing ERP customer migration

`omc_app.api.customer_migration` classifies existing ERP customers before any permanent apply operation.

Identity resolution priority is:

```text
1. safe unique Customer email
2. unique linked-Lead CNIC
3. safe unique resolved phone with no Customer/Lead conflict
4. identity review
```

The restored client-data rehearsal produced this snapshot:

```text
Total ERP Customers:                 4,886
Profile-only auto-migratable:        4,530
Identity review:                       356

Unique-email activation candidates:  3,245
CNIC fallback profiles:              1,004
Safe-phone fallback profiles:          281

Frappe Users created by migration:       0
```

The migration is designed to be idempotent and preserve existing profile identity/lifecycle fields. Unique-email profiles can use the first self-service email activation path. CNIC- or phone-resolved profiles can still be migrated as business profiles, but their login activation remains intentionally blocked until a secure verification channel exists.

**The 4,530-profile permanent migration is currently on hold until the real activation E2E rehearsal is green.**

---

## Staff identity, approval, and capabilities

Internal users are not modelled as customers.

```text
Frappe User
    -> OMC Staff Profile
       -> linked ERP Employee
       -> staff_role
       -> staff_status
       -> approval_status
       -> is_active
```

A newly recognised staff member is not automatically authorised merely because their ERP Employee is active.

Default OMC staff lifecycle:

```text
staff_status = Pending
approval_status = Pending Review
is_active = 0
```

After explicit OMC approval:

```text
staff_status = Active
approval_status = Approved
is_active = 1
```

Supported OMC staff personas are:

- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Consultant
- OMC Tax Associate
- OMC Business Partner

Frappe/ERP Role Profiles are not the OMC business-persona source of truth. The application calculates effective OMC staff roles from the Staff Profile plus valid OMC User roles, then derives capabilities from that effective persona and approval state.

This avoids rewriting shared client Role Profiles such as Operations while still allowing OMC-specific permissions.

See [`ROLE.md`](ROLE.md) and [`docs/app_role.md`](docs/app_role.md) for the detailed role/capability model. These files are maintained separately from the high-level README.

---

## Referral model

Referral ownership belongs to approved referral-capable staff, not customers.

Current referral-owner personas are:

```text
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

The ownership model is:

```text
Approved referral-capable Staff Profile
    -> OMC Referral
       -> owns referral code

Referred Customer
    -> OMC Customer Profile
       referred_by
       referral_record
       referral_code_used
       referral_assistance_consent
```

A customer profile does not own its own referral code.

---

## Service and ERP workflow

`OMC Service` is the customer-facing service configuration. It maps to an existing ERP `Task Type` through `erp_task_type`; OMC does not own or replace ERP Task Type records.

The operational flow is broadly:

```text
Service request created
    -> assignment / case workflow
    -> required documents
    -> document review
    -> payment required where configured
    -> receipt submission and finance review
    -> verified/paid activation gate
    -> ERP Service / Project / Task execution
    -> progress and completion
```

For payment-required services, ERP activation is blocked until the linked OMC payment reaches an accepted verified/paid state. The ERP Service and ERP Task use the same validated Task Type mapping.

Documents and payment receipts are not silently auto-approved. Protected mutations pass through backend ownership, capability, and workflow checks.

---

## Main product areas

### Customer-facing Flutter app

- onboarding, login, signup, verification, password recovery, and existing-account activation;
- backend-driven home/dashboard content;
- service catalogue, service detail, request creation, and tracking;
- customer documents and required-document upload/replacement;
- payment instructions, receipt upload, and payment status;
- notifications;
- support tickets and support chat;
- knowledge/articles and public information;
- tax calculator;
- expense tracking and budgets;
- profile/settings and notification preferences;
- referral-related customer attribution where applicable.

### Internal operations

Capability-gated staff workflows include:

- internal workspace and operational queues;
- service-case work and assignment;
- document review;
- payment review;
- lead/customer/task access according to scope;
- support operations;
- registration/customer review;
- staff management for authorised roles;
- ERP synchronisation/recovery operations;
- business/configuration operations where the persona permits them.

Flutter visibility is convenience only; the backend re-checks authority for protected reads and mutations.

---

## Security principles

The project follows these non-negotiable rules:

- backend authorization is authoritative;
- unknown/unsupported access is fail-closed;
- customer reads and writes are ownership-scoped;
- internal operations require explicit capabilities and, normally, an approved active Staff Profile;
- shared ERP Role Profiles are not mutated to force OMC personas;
- existing Frappe identities are not silently merged during imported-customer activation;
- customer activation uses one-time expiring tokens rather than default passwords;
- sensitive files, credentials, runtime state, dumps, logs, and secrets must not be committed;
- ERPNext source code remains untouched by OMC customisation;
- installation/migration logic should be repeatable and non-destructive.

---

## Repository structure

```text
.
├── README.md
├── ROLE.md
├── OMC_APP_FEATURES.md
├── omc_detailed_explanation.md
├── docs/
│   ├── app_role.md
│   ├── merge_plan.md
│   ├── mobile_release_hardening.md
│   ├── association_files/
│   └── test_reports/
├── omc_app/                         # Flutter application
│   ├── lib/
│   └── test/
└── backend_omc_app/
    ├── deploy/                      # deployment/support tooling
    └── frappe-bench/
        └── apps/
            └── omc_app/             # custom Frappe application
```

The checked-in product backend is the custom `omc_app`. A developer's local Bench may contain other installed client apps, but those are not part of the OMC backend package unless intentionally tracked as project source.

---

## Local development

### Flutter

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
flutter test
```

Development endpoint example:

```bash
flutter run -d chrome --web-port=8085 \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=OMC_LINK_BASE_URL=http://localhost:8085
```

Use an endpoint appropriate to the target device. Production builds must use the intended production HTTPS origin and link configuration.

### Existing Frappe site

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench list-sites
bench --site omc.local list-apps
bench start
```

Normal development/update work must not recreate or destroy an existing site, database, Bench, or client data.

---

## Installation and updates

The custom backend is intended to be deployable as the `omc_app` Frappe application without ERPNext source patches.

For a first installation after the app is present in the Bench:

```bash
bench --site <site> install-app omc_app
```

For an existing installation after deploying updated app code:

```bash
bench --site <site> migrate
bench build
bench --site <site> clear-cache
```

Production service restarts/reloads depend on the client's actual Supervisor/nginx deployment.

Before any client deployment:

- take/verify backups;
- confirm the target Frappe/ERPNext environment;
- preserve existing client apps and data;
- never reset or overwrite unrelated application working trees;
- run the OMC validation suite and post-deployment smoke checks.

---

## Validation commands

### Flutter

```bash
cd ~/data_drive/app_omc/omc_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

### Frappe backend

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local run-tests --app omc_app --skip-test-records
```

`--skip-test-records` is used for the populated restored client site so unrelated global ERP fixture generation is not confused with the isolated OMC application suite.

Validation results should always come from actual command output for the exact commit/environment being released.

---

## Release gates still relevant to the current customer-activation work

Before running the permanent existing-customer migration:

1. complete the isolated real Flutter/browser activation E2E using a test imported profile;
2. verify activation email/deep-link delivery against the intended environment;
3. confirm lazy Website User creation, `OMC Customer` role assignment, profile linking, and real password login;
4. rerun backend and Flutter regression suites after any resulting code change;
5. run migration preflight on the target database and review all identity-review counts before apply;
6. execute a controlled migration with backup, counts, and post-verification rather than an unreviewed bulk mutation.

---

## Documentation

- [`README.md`](README.md) — high-level current architecture and operating boundaries;
- [`ROLE.md`](ROLE.md) — OMC role/persona model;
- [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — detailed business and workflow explanation;
- [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md) — feature catalogue;
- [`docs/app_role.md`](docs/app_role.md) — detailed capability/access documentation;
- [`docs/test_reports/`](docs/test_reports/) — dated validation evidence;
- [`backend_omc_app/frappe-bench/apps/omc_app/README.md`](backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend-specific notes.

The root documents and `docs/` directory should describe implemented code, not superseded design plans. Historical plans/audits should be clearly labelled or removed when they no longer represent the current architecture.

---

## Ownership

This repository contains OMC House application code and project documentation. Distribution and reuse are subject to the project owner's authorisation and applicable licence terms.
