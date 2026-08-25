# OMC App

OMC App is the customer and operations platform for **OMC House**. The repository combines a Flutter application with a custom Frappe app that integrates with ERPNext while keeping ERPNext source code untouched.

> **Backend-first rule:** Flutter controls presentation and navigation. The OMC/Frappe backend remains authoritative for identity, access, ownership, capabilities, pricing, workflow state, documents, payments, assignment, ERP activation, and protected mutations.

---

## Current state

Source cross-check: **25 August 2026**, branch `main`.

Latest implementation commit before this documentation refresh:

```text
f668f779 feat: productionize service catalogue and document identity
```

Latest directly observed validation for that implementation:

```text
Backend OMC suite:                 932 / 932 passed
Flutter case-detail contract:        4 / 4 passed
Flutter analyze:                  No issues found

Production catalogue validation:
  categories:                         9 unchanged
  services:                          31 unchanged
  required documents:               93 unchanged
  form fields:                       62 unchanged
  total managed objects:            195 unchanged
  pending creates:                    0
  pending updates:                    0
  pending deactivations:              0
  conflicts:                          0
  blockers:                           0
```

These numbers describe the exact tested repository/site state. A later code change or different site must be validated again.

---

## Architecture

OMC deliberately separates ERP business records from OMC application authority.

### Customer identity

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +------> ERP Customer
        |
        +------> OMC Customer Profile
                 legacy/business-profile compatibility link
```

`OMC Customer Account` is the canonical application-access link for an authenticated customer. Customer access requires a valid linked account whose identity and service-access state are approved.

`OMC Customer Profile` remains important for business/profile data and legacy compatibility, but it is no longer the sole authority for authenticated customer access.

### Internal staff authority

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +------> explicit capability rows
        +------> reconciliation / approval state
        +------> optional scoped break-glass grants
```

`OMC Staff Access` is the canonical internal OMC access record. Normal Frappe roles do not silently grant OMC business authority. Protected operations are capability-driven.

### Service execution

```text
Source-controlled service catalogue
        |
        v
OMC Service
        |
        +------> exact existing ERP Task Type
        |
        v
OMC Service Request
        |
        +------> pricing snapshot
        +------> required-document contract
        +------> payment/accounting gate
        |
        v
Ready for Activation
        |
        v
Durable OMC Bridge Operation
        |
        +------> ERP Service
        +------> ERP Task
        |
        v
Assignment + operational execution
```

ERP Service and Task creation happens only after the OMC request becomes activation-eligible.

---

## Source-of-truth boundaries

| Area | Canonical authority |
| --- | --- |
| Lead | ERPNext `Lead` |
| ERP customer master | ERPNext `Customer` |
| Authenticated customer mapping | `OMC Customer Account` |
| Customer business/profile compatibility | `OMC Customer Profile` |
| Internal OMC access | `OMC Staff Access` |
| Internal permissions | canonical OMC capabilities |
| Emergency temporary access | scoped `OMC Break Glass Grant` |
| Service catalogue | source-controlled catalogue manifest + `OMC Service` |
| ERP service mapping | exact existing ERP `Task Type` |
| Customer service lifecycle | `OMC Service Request` |
| Required-document contract | `OMC Service Required Document` |
| Submitted service documents | `OMC Service Document` |
| Payment workflow | `OMC Service Payment` |
| Accounting settlement link | `OMC Accounting Link` |
| ERP activation/retry state | `OMC Bridge Operation` |
| Referral attribution | OMC referral/attribution records |
| Commission entitlement | `OMC Commission Allocation` + commission lifecycle |
| ERP execution | ERP `Service` and `Task` |
| ERP accounting | ERPNext finance records |

OMC does not create duplicate application records where ERPNext already owns the underlying business entity unless OMC-specific workflow state is required.

---

## Access and capability model

Capabilities are calculated by the backend and projected to Flutter.

### Guest

Guests receive only explicitly public capabilities such as public catalogue/content access and the public tax calculator where enabled.

### Customer

An approved customer account can receive customer capabilities such as:

- create a service request;
- upload service documents;
- track owned service requests;
- view owned documents;
- view payment state;
- upload payment receipts;
- create support tickets;
- access the customer dashboard;
- view customer notifications.

All customer access remains ownership-scoped.

### Internal staff

An internal user requires an approved, current `OMC Staff Access` record. Operational authority comes from explicit capabilities covering areas such as:

- customer and lead management;
- task visibility/management;
- service-case access and assignment;
- document review;
- payment review;
- settlement reconciliation;
- support operations;
- registration review;
- business settings;
- bridge retry/recovery;
- referral ownership;
- personal commission visibility;
- finance commission approval/payment operations.

Flutter visibility is convenience only. Backend APIs re-check capability and scope.

### Break-glass access

Temporary exceptional access is represented by explicit `OMC Break Glass Grant` records. Grants are time-limited, capability-specific, optionally scoped to a DocType/record, and evaluated server-side.

See [`docs/ROLE.md`](docs/ROLE.md) for the detailed access model.

---

## Production service catalogue

The production catalogue is source controlled under:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/service_catalogue/
```

The current manifest defines:

```text
9 categories
31 services
17 active services
14 inactive / review-required services
currency: PKR
company: Omc House
default activation policy: Full Settlement
```

Inactive services are intentionally retained when pricing, scope, requirements, turnaround, or other commercial facts are not sufficiently verified. The catalogue must not invent business data merely to make every service active.

### Stable identities

Catalogue identity is independent from display text. Stable fields include:

```text
service_id
category_name
document_key
```

An OMC Service maps to an **exact existing ERP Task Type**. Catalogue provisioning does not fuzzy-match or create ERP Task Types.

### Catalogue operations

Three explicit operations are available:

```text
preview_service_catalogue
validate_service_catalogue
sync_service_catalogue
```

Examples:

```bash
cd backend_omc_app/frappe-bench

bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

`preview` and `validate` are read-only. `sync` performs the explicit atomic reconciliation.

Normal `bench migrate` does **not** silently publish or rewrite the service catalogue.

### Provisioning safety

Catalogue reconciliation is designed to:

- preflight before mutation;
- fail closed on missing or ambiguous ERP Task Types;
- preserve non-owned service configuration;
- protect active/in-flight customer requests;
- protect historical pricing;
- reconcile managed rows deterministically;
- deactivate stale managed rows instead of destructively deleting them;
- validate after reconciliation;
- rollback on failure;
- remain idempotent when the site already matches source control.

---

## Required-document identity

Required service documents use stable `document_key` identity.

```text
OMC Service Required Document
        |
        | document_key
        v
OMC Service Document
```

When both requirement and uploaded document have a key, `document_key` is authoritative. A document with the wrong key cannot satisfy a requirement merely because its title/type happen to match.

For genuine legacy/unkeyed records, the backend preserves controlled compatibility using exact normalized title + document-type matching.

One upload satisfies at most one requirement.

### Grandfathering

Required-document definitions may carry `effective_from`. New requirements therefore apply only to requests created at or after their effective boundary, while legacy requirements without a boundary retain legacy behaviour.

This prevents catalogue evolution from silently changing the document contract of older in-flight requests.

---

## Customer document upload flow

Flutter can upload directly against a required-document row on a service case. The client sends the selected requirement identity, including the service request, `document_key`, title, type, and attachment.

The backend still remains authoritative. It:

1. loads the request;
2. verifies customer ownership/access;
3. resolves the requirement against that request's service;
4. treats a submitted stable key as authoritative;
5. canonicalises title/type from the requirement;
6. checks duplicate/active document state;
7. validates the attachment;
8. stores canonical identity.

Generic legacy/non-template uploads remain supported where intentionally allowed.

---

## Service request and payment lifecycle

OMC uses an explicit request lifecycle rather than treating an ERP Task as the customer request state.

Representative lifecycle states include:

```text
Draft
Pending Payment
Payment Not Required
Ready for Activation
Activating
Activated
Activation Failed
Financial Hold
Expired
Cancelled
```

Operational customer-facing status is a compatibility projection over this lifecycle.

### Payment-first activation

The normal paid-service path is:

```text
Customer creates request
        |
        v
Required documents
        |
        v
Payment / receipt workflow
        |
        v
Accounting settlement confirmed
        |
        v
Ready for Activation
        |
        v
Durable bridge
        |
        v
ERP Service + ERP Task
        |
        v
In Progress
```

For the default `Full Settlement` policy, the bridge requires settled accounting evidence before ERP activation. Explicit no-charge and authorised post-paid policies are handled separately.

A customer-visible receipt is not itself the ERP accounting authority.

---

## Durable ERP activation bridge

ERP activation is handled through `OMC Bridge Operation`.

The bridge provides:

- deterministic operation identity;
- request locking;
- final eligibility checks;
- settlement re-check immediately before ERP writes;
- retry state and bounded retry attempts;
- stale-processing lease recovery;
- rollback around ERP operational writes;
- explicit failed/cancelled/completed states;
- authorised manual recovery;
- audit events.

Successful activation must produce committed links to both ERP `Service` and ERP `Task` before the request can become `Activated`.

---

## Customer onboarding and existing ERP customers

OMC supports both new app customers and existing ERP customers.

### New app customers

Public signup and verification remain backend controlled. The backend owns identity validation, account state, role normalisation, and protected access.

### Existing ERP customer migration

`omc_app.api.customer_migration` provides controlled migration tooling for existing ERP customers.

Current deterministic identity resolution includes, in priority order:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

Tax ID/NTN is deliberately a final deterministic fallback, not a replacement for the established email/CNIC/phone rules.

Ambiguous identities are sent to review rather than guessed. Migration tooling is designed to preflight before apply, reuse safe existing profiles, avoid bulk creation of login Users, preserve ambiguous cases for review, and support idempotent reruns.

Client deployment and migration steps are documented in [`docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md).

---

## Referrals and commissions

Referral and commission authority is capability-driven.

```text
Referral ownership
        |
        v
Referral attribution
        |
        v
Service/customer evidence
        |
        v
Commission allocation
        |
        +------> personal/beneficiary commission view
        |
        +------> finance commission operations
```

Important rules:

- referral ownership requires explicit entitlement;
- attribution is preserved separately from commission state;
- historical evidence must not invent provenance;
- personal commission visibility and finance operations use separate capabilities;
- commission approval/payment authority is not implied by referral ownership;
- legacy capability aliases are compatibility-only and do not grant finance authority.

---

## Main Flutter product areas

The Flutter application includes capability-aware experiences for areas such as:

- onboarding and authentication;
- existing-customer activation;
- home/dashboard;
- service catalogue and service detail;
- service request creation and tracking;
- required-document upload/replacement;
- general customer documents;
- payments and receipt submission;
- notifications;
- support;
- profile/settings;
- public content;
- tax calculator;
- expense/budget tools;
- referral-owner experience;
- personal commission view;
- authorised finance commission operations;
- internal operational workspace where capability permits.

Routes and controls are not security boundaries. The backend remains authoritative.

---

## Internal operations

Capability-gated operational workflows include:

- internal workspace;
- customer and lead operations;
- service-case queues;
- assignment;
- task visibility/management;
- document review;
- payment review;
- settlement reconciliation;
- support tickets and replies;
- registration/customer review;
- staff-access administration;
- business/settings operations;
- referral operations;
- commission operations;
- bridge retry/recovery;
- audit-backed sensitive mutations.

---

## Setup and lifecycle behaviour

OMC setup separates validation from deliberate site mutation.

```text
before_install
    -> validate ERP/client contract

after_install
    -> explicit one-time OMC initialisation

after_migrate
    -> validation only
```

Normal migration does not silently rewrite roles, branding, Desk/workspace metadata, or the service catalogue.

Explicit setup operations are available when deliberate reconciliation is required:

```bash
cd backend_omc_app/frappe-bench

bench --site <site> execute \
  omc_app.setup.operations.initialize_site

bench --site <site> execute \
  omc_app.setup.operations.repair_permissions

bench --site <site> execute \
  omc_app.setup.operations.sync_desk_configuration

bench --site <site> execute \
  omc_app.setup.operations.apply_site_branding
```

---

## Security principles

The project follows these core rules:

- backend authorisation is authoritative;
- unsupported access fails closed;
- customer access is ownership-scoped;
- internal access requires explicit canonical capabilities;
- customer and staff authority are separate;
- normal Frappe roles do not silently grant OMC authority;
- break-glass access is explicit, scoped, and temporary;
- sensitive mutations are guarded server-side;
- idempotency is used where repeated requests could create duplicate effects;
- payment eligibility is re-checked before ERP activation;
- document requirement identity is backend validated;
- historical/in-flight customer contracts are protected from unsafe catalogue changes;
- ambiguous customer identities are reviewed rather than guessed;
- runtime secrets, dumps, private files, logs, and credentials must not be committed;
- ERPNext source code remains untouched by OMC customisation;
- installation and reconciliation operations should be repeatable and non-destructive.

---

## Repository structure

Relevant project-owned areas:

```text
.
├── README.md
├── docs/
│   ├── OMC_APP_FEATURES.md
│   ├── OMC_Client_Deployment_and_Customer_Migration_Handover.md
│   ├── ROLE.md
│   └── omc_detailed_explanation.md
│
├── omc_app/                         # Flutter application
│   ├── lib/
│   ├── test/
│   └── docs/
│
├── backend_omc_app/
│   ├── backend_readme.md
│   ├── deploy/
│   └── frappe-bench/
│       └── apps/
│           └── omc_app/             # custom OMC Frappe application
│
├── erp_lead_app/                    # retained legacy/reference material
└── scripts/
```

The Bench also contains Frappe/ERPNext framework sources and runtime files. Those are not the place to implement OMC business customisations.

---

## Local development

Use repo-relative paths rather than machine-specific absolute paths.

### Flutter

```bash
cd omc_app
flutter pub get
flutter analyze
flutter test
```

Example development run:

```bash
flutter run -d chrome \
  --web-port=8085 \
  --dart-define=OMC_ENV=development \
  --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=OMC_LINK_BASE_URL=http://localhost:8085
```

Use a backend endpoint reachable from the target device. Production builds must use the intended HTTPS origin.

### Frappe backend

```bash
cd backend_omc_app/frappe-bench
bench list-sites
bench --site <site> list-apps
bench start
```

Do not recreate or destroy an existing client site merely to perform normal application development or testing.

---

## Installation and updates

The project does not require ERPNext source patches.

### First installation

After placing/registering the app in the Bench:

```bash
cd backend_omc_app/frappe-bench
bench --site <site> install-app omc_app
bench --site <site> migrate
bench --site <site> clear-cache
```

### Updating an existing installation

After deploying newer application code:

```bash
cd backend_omc_app/frappe-bench
bench --site <site> migrate
bench build --app omc_app
bench --site <site> clear-cache
```

Production process restart/reload depends on the actual Supervisor/nginx deployment.

Remember: **`bench migrate` is not the catalogue publisher.** If the source-controlled catalogue must be reconciled, use its explicit preview/validate/sync workflow separately.

---

## Validation

Validation must come from actual command output for the exact commit/environment being released.

### Backend

```bash
cd backend_omc_app/frappe-bench

bench --site <site> run-tests \
  --app omc_app \
  --skip-test-records
```

A populated restored/client site may require `--skip-test-records` so unrelated global ERP fixture creation is not confused with the OMC application suite.

### Catalogue

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

A clean reconciled site should report no pending catalogue mutations, conflicts, or blockers.

### Flutter

```bash
cd omc_app

dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Focused contract tests are useful during development but are not a replacement for broader release validation.

---

## Documentation

Current high-level documentation:

- [`README.md`](README.md) — architecture, boundaries, setup, and validation;
- [`docs/ROLE.md`](docs/ROLE.md) — role/capability/access model;
- [`docs/OMC_APP_FEATURES.md`](docs/OMC_APP_FEATURES.md) — feature catalogue;
- [`docs/omc_detailed_explanation.md`](docs/omc_detailed_explanation.md) — detailed business/workflow architecture;
- [`docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md) — client installation and existing-customer migration;
- [`backend_omc_app/frappe-bench/apps/omc_app/README.md`](backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend-specific engineering notes.

Documentation should describe implemented code and explicitly identify retained compatibility paths or operational requirements. Superseded planning documents should not be presented as current architecture.

---

## Ownership

This repository contains OMC House application code and project documentation. Distribution and reuse are subject to the project owner's authorisation and applicable licence terms.
