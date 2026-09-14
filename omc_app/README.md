# OMC House Flutter App

Source cross-check: **14 September 2026**, branch `main`.

The Flutter application is the customer and authorised-staff client for OMC House. It connects to the custom Frappe `omc_app` backend and treats backend identity, capabilities, ownership, workflow state, pricing, document requirements, document reuse, payment eligibility, settlement and ERP activation as authoritative.

---

## Tech stack

- Flutter / Dart
- Riverpod
- GoRouter
- Dio
- Flutter Secure Storage
- file/image pickers
- local platform authentication for optional device lock
- URL/deep-link handling
- backend-driven Frappe method APIs

---

## Architecture rule

> Flutter renders the experience; it does not grant authority.

The app consumes backend capability/access state and must not infer protected access from a route, local role label, visible button, or locally cached workflow state.

Customer records remain ownership-scoped. Internal operations require canonical backend capabilities.

---

## Main product areas

Current Flutter features include:

- onboarding and guest entry;
- login/session restoration/logout;
- password reset and account security;
- customer signup and email verification;
- existing-customer activation/claim flows;
- home/dashboard;
- service catalogue and service detail;
- service request creation;
- My Services / service-case tracking;
- required-document reuse/upload/replacement;
- customer document list/detail;
- payment list/detail and receipt upload;
- notifications and push-token registration;
- support tickets/chat;
- profile and settings/preferences;
- knowledge/FAQ/public content;
- tax calculator;
- expense/budget tools;
- leads/customers/tasks for authorised internal users;
- internal workspace/service-case operations;
- referral-owner experience;
- personal commission view;
- authorised finance commission operations.

---

## Customer service flow

The current service journey is backend driven:

```text
Browse service
    -> create request
    -> required-document eligibility
         -> reuse qualifying approved document when allowed
         -> otherwise upload/replace document
    -> payment/receipt workflow
    -> ERP accounting settlement gate
    -> ERP Service + exactly one authoritative ERP Task
    -> tracking/progress through OMC Service Request
    -> completion
```

Flutter does not create ERP execution records directly.

The customer-facing service lifecycle is the `OMC Service Request`. The ERP Task is internal operational work and must not be exposed to the customer as the customer-facing service record.

---

## Required-document eligibility

Required-document rows carry stable backend identity (`document_key`).

When a user uploads or replaces a requirement, Flutter sends the selected requirement identity to the backend. The backend validates that identity against the request's service and canonicalises the stored title/type.

This prevents a locally supplied label from redefining a service requirement.

### Reusable documents

A required-document response may also include backend reuse metadata such as:

```text
reuse_policy
reuse_validity_days
source
source_document
is_reused
```

Supported reuse policies are:

```text
Always New
Reusable Until Replaced
Reusable for N Days
```

`Always New` remains the safe default.

Current reuse is deliberately constrained by backend rules including the same canonical customer, same service, matching stable requirement identity, approved source evidence, configured policy, validity period where applicable, and replacement/archive eligibility.

Flutter does not decide whether a prior document is reusable. It renders the state returned by the backend.

When a requirement is already satisfied by reused evidence, the UI may present it as already on file and allow replacement where supported. A fresh replacement upload supersedes the request-local reused projection through backend logic.

Reusable evidence satisfies document eligibility only. It does not bypass payment, settlement or activation.

After a successful upload/replacement, the app refreshes the relevant case/document/dashboard state so the user sees the latest backend contract.

---

## Customer and staff authority

### Customer

Approved customer capability state is derived from the canonical backend customer account. Flutter must not treat an `OMC Customer Profile` alone as sufficient authority.

### Staff

Internal navigation and actions are driven by backend capabilities derived from canonical `OMC Staff Access`.

`System Manager` is not treated as an automatic OMC business persona by the client.

Referral ownership, own-commission visibility, and finance commission operations are separate capability surfaces.

---

## Backend configuration

API configuration is centralised in:

```text
lib/core/config/api_config.dart
```

Important build-time values:

```text
OMC_ENV
OMC_API_BASE_URL
OMC_LINK_BASE_URL
OMC_SENTRY_DSN
```

Development defaults can use a local backend. Production release builds enforce the production environment/origin rules defined in `ApiConfig` and require the diagnostics configuration expected by the current build profile.

Current production origin:

```text
https://erp.omchouse.com
```

Do not hardcode alternate production endpoints in feature repositories.

---

## API usage

The app primarily calls Frappe methods through:

```text
/api/method/<method>
```

Method names are centralised in `ApiConfig`.

Current canonical areas include:

- auth/login/password/activation;
- pending registration;
- dashboard/quick actions;
- service catalogue/templates;
- secured service cases;
- customer documents and service-document reuse/upload;
- payments/receipt upload/review;
- profile/settings;
- knowledge/FAQ/banners/onboarding;
- notifications;
- support;
- tax calculator;
- expense tools;
- customers/leads/tasks;
- internal workspace/admin control;
- referrals and commissions.

See [`docs/backend_api_contract.md`](docs/backend_api_contract.md) for the current contract map.

---

## Environment and release safety

`ApiConfig.validateBuildProfile()` protects release builds from accidental non-production configuration.

A release build must satisfy the production URL/security conditions implemented in the code. Do not disable those checks to make a misconfigured release build pass.

Sensitive session/token data belongs in secure storage; it must not be logged or committed.

---

## Local setup

From the Flutter app directory:

```bash
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

Use a backend URL reachable by the selected device/emulator.

---

## Validation

Before a Flutter release or major merge:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Focused contract tests are useful during feature development, but broad regression validation is still required before release.

Historical pass counts are not treated as proof of the current HEAD unless those tests are rerun against the exact checkout and environment being released.

---

## Android release

Android remains the primary packaged release target.

A production release must use the required production build profile and configured signing material.

Typical build:

```bash
flutter build appbundle --release \
  --dart-define=OMC_ENV=production \
  --dart-define=OMC_API_BASE_URL=https://erp.omchouse.com \
  --dart-define=OMC_LINK_BASE_URL=https://erp.omchouse.com \
  --dart-define=OMC_SENTRY_DSN=<https-dsn>
```

Signing secrets/keystores must remain outside source control except for safe templates/examples.

---

## iOS release

The Flutter codebase supports iOS, but TestFlight/App Store release still requires macOS/Xcode for:

- bundle identity verification;
- signing team/provisioning;
- app icons/launch assets;
- archive/export;
- TestFlight/App Store validation.

---

## Project structure

```text
lib/
  app/                 router, shell, theme, providers
  core/                config, network, storage, shared widgets
  features/
    auth/
    home/
    service_catalogue/
    service_requests/
    documents/
    payments/
    notifications/
    support/
    profile/
    settings/
    knowledge/
    tax_calculator/
    expense_tracker/
    customers/
    leads/
    tasks/
    internal_workspace/
    referrals/
    commissions/
```

The exact feature tree is the source of truth if a directory name changes.

---

## Backend authority and compatibility

Do not reintroduce old production assumptions such as:

- sample service-case data in normal mode;
- placeholder API method names;
- customer-side authority based only on local role labels;
- specialist self-signup as a route to internal access;
- direct ERP activation from Flutter;
- title-only required-document matching when stable keys exist;
- assuming every required document must be freshly uploaded;
- exposing internal ERP Tasks as customer service records;
- treating receipt submission as final accounting settlement.

Compatibility aliases may remain in the backend for older clients, but new Flutter code should use the canonical methods in `ApiConfig`.

---

## Related documentation

- [`../README.md`](../README.md) — repository architecture;
- [`../docs/OMC_APP_FEATURES.md`](../docs/OMC_APP_FEATURES.md) — feature catalogue;
- [`../docs/ROLE.md`](../docs/ROLE.md) — role/persona/capability model;
- [`docs/backend_api_contract.md`](docs/backend_api_contract.md) — Flutter/backend API map.
