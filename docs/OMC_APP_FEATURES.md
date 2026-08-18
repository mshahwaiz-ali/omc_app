# OMC App — Current Feature Catalogue

This document describes the features that are present in the current OMC App repository and separates completed behaviour from partially aligned or still-unverified flows.

Last source cross-check: **18 August 2026** on branch `feature/customer-home-dashboard`.

> **Authority rule:** Flutter controls presentation and navigation. The OMC/Frappe backend remains authoritative for identity, approval, ownership, assignment, workflow state, permissions, and protected mutations.

---

## Status legend

- **Implemented** — current Flutter/backend wiring exists for the feature.
- **Validated** — the current automated test snapshot covers the relevant implementation boundary.
- **Manual E2E pending** — code and focused tests exist, but the real browser/device flow still needs a final rehearsal.
- **Partially aligned** — a UI/API path still exists, but it does not fully match the newest source-of-truth architecture and must not be presented as production-complete.
- **Not implemented** — the current source does not provide a complete feature.

Current recorded validation snapshot:

```text
Backend OMC suite:            591 / 591 passed
Customer activation tests:      8 / 8 passed
Flutter analyze:              No issues found
Flutter suite:                326 / 326 passed
Router policy parity suite:    51 / 51 passed
```

The permanent existing-customer migration has **not** been run. The imported-customer browser/device activation journey is **manual E2E pending**.

---

# 1. App entry, navigation, and general UX

**Implemented**

- branded splash and onboarding flow;
- guest entry without creating an account;
- role/capability-aware routing;
- bottom-navigation shell for Home, Services, Track, Documents, and More;
- safe route-failure recovery;
- access-denied handling;
- loading, empty, error, and retry states;
- duplicate-action protection for sensitive UI operations;
- responsive Flutter layouts;
- app/deep-link normalisation through `LinkCoordinator`;
- authenticated route policy that fails closed for unknown protected routes.

Current authentication-related public routes include:

```text
/login
/signup
/forgot-password
/reset-password
/app/reset-password
/verify-email
/app/verify-email
/activate-existing-account
/activate-account
/app/activate-account
/under-review
```

---

# 2. Login and session access

**Implemented**

Login supports the existing multi-identifier backend path, including identifiers such as:

- email;
- username;
- mobile number;
- CNIC where the backend can resolve it safely.

The app also includes:

- password sign-in;
- show/hide password;
- session restoration;
- secure session storage;
- approval-aware routing after authentication;
- logout and local session cleanup;
- friendly authentication failure handling;
- guest continuation where allowed by application configuration.

## Device lock

**Implemented in Flutter; real-device behaviour remains environment/device dependent.**

- optional local post-login lock;
- `local_auth` integration;
- fingerprint / Face ID / device credential where supported;
- encrypted device-lock preference storage;
- re-lock after app background/resume;
- failed/cancelled unlock keeps the app locked.

Device lock protects an already authenticated session. It is **not** passwordless OMC backend login.

---

# 3. New-account signup and email verification

**Implemented**

Flutter currently exposes signup application types:

```text
Customer
Consultant
Business Partner
Tax Associate
```

The signup UI includes:

- multi-step registration;
- full name;
- email;
- username;
- mobile and WhatsApp numbers;
- CNIC;
- address;
- education;
- experience;
- remarks;
- acquisition source;
- referral code for customer referral signup;
- password and confirmation;
- terms acceptance;
- username normalisation/suggestion/availability checks.

The new-registration backend uses `OMC Pending Registration` with:

- cryptographically random verification token;
- SHA-256 token digest storage;
- 30-minute token lifetime;
- 60-second resend cooldown;
- superseding/rotation behaviour;
- email and app/browser verification links;
- terminal secret sanitisation after activation/expiry/supersede/cancel.

## Staff-application alignment note

**Partially aligned.**

The signup UI still allows Consultant, Business Partner, and Tax Associate applications, and the current registration-review API still begins from an `OMC Customer Profile` application record and grants direct Frappe OMC roles on approval.

The newer internal-authorisation architecture now requires an approved `OMC Staff Profile` for ordinary staff access. The public staff-application approval bridge therefore still needs alignment so that approving a staff applicant deliberately creates/updates and approves the corresponding Staff Profile rather than relying only on direct user-role assignment.

Do not describe public staff signup as fully production-complete until that bridge is reconciled and retested.

---

# 4. Existing ERP customer migration

**Migration engine implemented and rehearsed; permanent apply not run.**

`omc_app.api.customer_migration` analyses existing ERPNext `Customer` records and creates OMC application profiles without creating thousands of Frappe login users in advance.

Identity resolution priority is:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone with no Customer/Lead phone conflict
4. identity review
```

The restored client-data rehearsal produced:

```text
Total ERP Customers:          4,886
Auto/profile-only migratable: 4,530
Identity review:                356
```

Profile-only migration creates or reuses `OMC Customer Profile` with the ERP customer link while leaving:

```text
user = blank
linked_app_user = blank
```

until secure app activation occurs.

The migration code includes:

- read-only dry run;
- read-only preflight;
- identity conflict classification;
- no default/shared password creation;
- no mass User creation;
- existing-profile reuse;
- idempotent planning/apply behaviour;
- separation of migration blockers and activation-time warnings.

---

# 5. Existing-customer first-time app activation

**Backend + Flutter implemented and automated tests green; manual browser/device E2E pending.**

Existing imported customers do not need a pre-generated password.

Flutter provides:

```text
Login
  -> Activate existing account
  -> enter registered email
  -> receive activation email
  -> open secure activation link
  -> choose password
  -> continue to normal login
```

Backend activation is provided by `omc_app.api.customer_activation` and `OMC Customer Activation`.

Security behaviour includes:

- enumeration-safe activation request response;
- imported + Active + Approved + active-profile eligibility gate;
- no activation if the profile is already linked to a User;
- no automatic merge when an existing Frappe User collides with the email;
- cryptographically random token;
- only SHA-256 token digest stored in the activation DocType;
- 30-minute expiry;
- 60-second request cooldown;
- pending-token supersede;
- one-time token consumption;
- row locking during token consumption;
- password minimum and confirmation validation;
- Website User creation only after successful proof of email control;
- `OMC Customer` role normalisation;
- linkage back to the same imported Customer Profile;
- `manual_customer_status = Linked` after success;
- token destruction after use;
- collision/ineligibility path to `Review Required` instead of identity guessing.

Initial self-service activation is deliberately email-based. CNIC-only and phone-only migrated profiles require a future secure activation method such as verified SMS/OTP or controlled staff-assisted identity verification.

---

# 6. Customer lifecycle and approval

**Implemented**

Customer application state supports guest, pending, approved, rejected, and imported/unlinked business states.

Approved customer state is based on the profile lifecycle, typically:

```text
customer_status = Active
approval_status = Approved
is_active = 1
```

Customer permissions remain ownership-scoped even after approval.

Imported business records may already be Active/Approved before they have an app login. Business approval and login activation are intentionally separate.

---

# 7. Internal staff identity, approval, and capabilities

**Core Staff Profile architecture implemented and backend regression-tested.**

Internal identity now uses:

```text
Frappe User
    -> OMC Staff Profile
       -> ERP Employee where linked
```

New ordinary staff profiles default to:

```text
staff_status = Pending
approval_status = Pending Review
is_active = 0
```

Normal staff access requires:

- enabled Frappe User;
- recognised effective OMC staff persona;
- `OMC Staff Profile` present;
- Staff Profile Active;
- Staff Profile Approved;
- `is_active = 1`;
- linked ERP Employee Active when one is linked.

Current staff personas are:

```text
OMC Admin
OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

The backend combines direct recognised OMC Frappe roles with `OMC Staff Profile.staff_role` into an effective staff-role set.

Existing client Frappe Role Profiles must not be modified merely to assign an OMC persona.

`Administrator` and `System Manager` remain explicit trusted system overrides.

## Admin staff-management alignment note

**Partially aligned.**

The current Admin Control API still contains legacy-style `invite_staff`, registration-role approval, and user-role editing paths that directly assign Frappe OMC roles. Those paths do not yet fully drive the new Staff Profile approval/persona lifecycle.

Until aligned, the Staff Profile gate is the authoritative access rule and the Admin Control staff-management workflow should not be represented as end-to-end complete.

---

# 8. Capability and permission system

**Implemented**

The backend exposes canonical capability state for Flutter navigation and protected operations.

Major internal capability groups include:

- internal workspace access;
- customer management and scoped customer viewing;
- lead management;
- all-task and assigned-task management;
- all/relevant/assigned service-case access;
- assisted service creation;
- global/assigned service-status updates;
- document queue, attachment, and review permissions;
- payment queue, receipt, and review permissions;
- support viewing/reply/status/assignment;
- internal notes;
- settings;
- staff management;
- registration review;
- business settings;
- service-case reassignment;
- ERP synchronisation retry.

Capability checks do not replace record ownership/assignment checks.

Frappe DocPerm, permission-query conditions, record-level `has_permission`, endpoint guards, and Flutter route policy form layered protection.

---

# 9. Home and dashboards

**Implemented**

Customer/guest home provides a role-aware entry experience with shortcuts into the main customer features.

The repository includes:

- home screen;
- customer dashboard;
- account/approval-aware presentation;
- service/activity context;
- quick actions;
- notification/profile access;
- retry/error states.

Internal users have dedicated workspace/dashboard surfaces for operational queues and role-appropriate shortcuts.

Partial backend failures are represented as unavailable/error states rather than fabricated zero values where implemented by the current repositories.

---

# 10. Service catalogue

**Implemented**

`OMC Service` is the mobile/customer service catalogue authority.

Supported service configuration includes:

- generated service ID;
- title;
- OMC service category;
- description and short description;
- mobile icon/accent configuration;
- base price and currency;
- fee labels;
- government fee label;
- estimated/completion time;
- support message;
- default assignee;
- default assignment role;
- parallel-request flag;
- sort/featured/active state;
- canonical ERP `Task Type` mapping through `erp_task_type`.

Flutter supports:

- service list;
- search/filter presentation;
- service detail;
- requirements and required documents;
- pricing/duration context;
- start-service flow;
- assisted-service query context where authorised.

Inactive services are not valid for normal public request creation.

---

# 11. Service requests and tracking

**Implemented**

Customer features include:

- start a request from a service;
- request draft/form flow;
- approved-customer gate;
- duplicate/parallel-request handling;
- request detail and tracking;
- status/progress/timeline context;
- next-action presentation;
- required-document and payment state;
- cancellation where allowed;
- retry and safe failure handling.

Internal/assisted flow includes creating service requests on behalf of authorised customers where the caller has the required capability and customer scope.

---

# 12. Assignment and operational workflow

**Implemented**

The current backend includes:

- explicit/default assignment resolution;
- referral-owner assignment where valid;
- role-based fallback;
- least-loaded eligible assignee selection;
- manager fallback;
- duplicate-safe Frappe ToDo creation;
- unassigned-request recovery;
- assignment notifications;
- workflow timeline/audit handling;
- service-case reassignment for authorised operations;
- completion blockers and completion attribution.

Specialist access remains assignment/relevance-scoped.

---

# 13. ERP service and task activation

**Implemented**

OMC does not modify ERPNext source files to create the service workflow.

The integration boundary is:

```text
OMC Service.erp_task_type
        -> existing ERP Task Type

OMC Service Request
        -> guarded ERP activation
        -> ERP Service
        -> ERP Task
```

For paid services, ERP Service/Task creation is gated until an `OMC Service Payment` is confirmed `Paid`.

For a zero-price request, ERP activation becomes eligible when the request is `In Progress`.

Existing valid ERP links are preserved and can be reconciled rather than recreated destructively.

---

# 14. Documents

**Implemented**

Customer document capabilities include:

- own-document listing;
- document detail;
- required-document context;
- multipart/file upload;
- file-size/type/content validation;
- request ownership validation;
- cross-request file-reuse prevention;
- rejected-document replacement/re-upload;
- status, rejection reason, and re-upload guidance.

Internal document-review capabilities include:

- review queue;
- related service/customer context;
- guarded attachment access;
- approve/reject decisions;
- rejection reason/re-upload instruction;
- duplicate-review protection;
- capability enforcement;
- request-state update after rejection;
- payment eligibility evaluation after required approvals.

Human review remains required. Document upload does not auto-approve a document.

---

# 15. Payments and receipts

**Implemented**

Customer payment features include:

- own-payment list/detail;
- amount/currency/status;
- payment instructions;
- receipt submission/replacement where allowed;
- finance-review state;
- guarded invoice/receipt access where supported by the backend endpoints.

Internal finance features include:

- payment-review queue;
- authenticated receipt access;
- receipt review;
- `Paid`, `Rejected`, and `Under Review` decisions;
- duplicate active-payment prevention;
- service-price validation;
- capability/relationship checks;
- workflow updates and notifications after review.

Paid-service ERP activation occurs only after payment confirmation.

---

# 16. ERP-native leads

**Implemented**

Native ERPNext `Lead` is the canonical lead record.

The retired `OMC Lead` DocType is not the current source of truth.

Flutter still provides lead list/detail/create experiences for authorised internal users. Backend lead creation writes to ERP `Lead` and supports the existing client ERP Lead custom metadata required by the integration.

Lead reads/writes are capability guarded.

---

# 17. Customer management

**Implemented**

Internal customer screens support:

- customer list;
- search/filtering;
- customer detail;
- profile/contact status;
- related service context;
- role/capability-aware access.

The customer application record is `OMC Customer Profile`; ERP customer master remains ERPNext `Customer`.

The project also contains profile-only import tooling for the existing ERP customer population as described earlier.

---

# 18. ERP tasks and internal work

**Implemented**

Flutter includes task list/detail surfaces. The backend uses ERPNext `Task` for operational task authority rather than a duplicate OMC task DocType.

Current guarded task behaviour includes:

- task reads based on internal capabilities/scope;
- assignment/reassignment to eligible users;
- task priority and expected-completion updates;
- allowed operational status updates;
- linked service-planning synchronisation where configured;
- transaction-safe completion handling;
- closing ToDos linked to the exact ERP Task;
- rollback protection;
- ERP Task status synchronisation back into the OMC service workflow.

---

# 19. Referrals

**Implemented for approved referral-capable staff.**

Canonical referral-owner personas are:

```text
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

Referral ownership additionally requires:

- existing enabled Frappe User;
- System User type;
- approved active `OMC Staff Profile`;
- effective referral-capable staff persona.

Eligible staff own an `OMC Referral` and the Staff Profile can display:

```text
referral_record
own_referral_code
```

Customers do not own a referral code. Referred-customer profiles store attribution such as the referrer, referral record/code used, and assistance consent.

Flutter includes:

- My Referrals;
- referral customer list/detail;
- referral customer service analytics;
- referral-code validation during customer signup;
- capability-aware referral access.

Referral codes become inactive when the owner no longer satisfies the referral-owner eligibility contract.

---

# 20. Commission screens

**Partially wired / currently not an end-to-end supported feature.**

Flutter still contains:

```text
/my-commissions
/my-commissions/:earningId
```

and a commission repository that calls:

```text
omc_app.api.referral_commissions.get_my_commission_summary
omc_app.api.referral_commissions.get_my_commissions
omc_app.api.referral_commissions.get_my_commission
```

However, the current branch no longer contains `omc_app/api/referral_commissions.py`, and the old OMC referral-commission / settlement DocTypes were retired from the backend in the current changeset.

Therefore the commission UI must **not** be advertised as a working production feature in the current state. It needs either:

```text
A. a new authoritative commission backend and contract,
or
B. removal of the stale Flutter commission routes/repository.
```

---

# 21. Internal operations workspace

**Implemented**

Flutter routes include:

```text
/internal-workspace
/internal-workspace/service-cases
/internal-workspace/service-cases/:caseId
/internal-workspace/customers
/internal-workspace/documents
/internal-workspace/payments
```

The workspace supports capability-aware queues for:

- service cases;
- customers;
- document review;
- payment review;
- assigned/relevant work;
- operational service-case details.

The backend remains authoritative for every queue read and mutation.

---

# 22. Admin Control and recovery operations

**Operational queues implemented; staff-management portion partially aligned as noted earlier.**

Admin Control currently includes APIs/UI for:

- registration review;
- staff invitation/editing;
- business settings;
- service-case reassignment;
- eligible assignee options;
- exhausted ERP-sync recovery;
- pending-discount review;
- reason/audit capture;
- searchable/paginated operation queues.

Capability boundaries include Admin-only and Manager-allowed operations according to `omc_app.api.access`.

The staff invitation/role-edit part still needs migration to the new Staff Profile approval/persona authority before it should be considered production-complete.

---

# 23. Support centre

**Implemented**

Customer support includes:

- create ticket;
- support ticket list/detail;
- threaded messages;
- reply with text and/or supported attachment;
- upload validation;
- status handling;
- retry/failure preservation;
- contact/support configuration.

Internal support includes guarded ticket reads, replies, status changes, read-state handling, and role/capability checks.

Customer ticket visibility remains ownership-scoped.

---

# 24. Notifications

**Implemented for in-app notification records and workflow delivery.**

The app includes:

- notification list/detail;
- unread count;
- read/unread operations;
- dismiss/restore;
- mark-all-read;
- linked-content navigation;
- ownership-safe customer notification reads;
- backend-authored workflow notifications;
- assignment/review/payment/completion/reminder/escalation events;
- push-token registration/unregistration contracts;
- notification preference handling where configured.

The current repository should not be described as having confirmed production Firebase Cloud Messaging / APNs delivery unless that external push delivery is separately configured and verified.

---

# 25. Scheduler, recovery, and automation

**Implemented**

Current scheduler entry points are consolidated through `omc_app.api.scheduler_jobs`.

Hourly jobs include:

- unassigned-service recovery;
- automatic ERP-sync recovery;
- review-assignment checks;
- submission-integrity rescore;
- pending-registration cleanup.

Daily jobs include:

- workflow reminder/escalation checks;
- notification cleanup;
- idempotency-record cleanup through the configured scheduler event.

Daily workflow checks currently include customer reminders for:

```text
Waiting for Customer
Waiting for Payment
```

and overdue escalation notifications to relevant operational recipients.

Each scheduler task is isolated so one failing job does not automatically roll back or suppress every other scheduled task in that scheduler run.

---

# 26. Knowledge, FAQs, banners, onboarding, and content

**Implemented**

The repository includes backend-managed customer-safe content for areas such as:

- knowledge articles;
- FAQs;
- app banners;
- onboarding slides;
- announcements/content surfaces;
- support/contact information;
- mobile application configuration.

Flutter also carries safe packaged fallbacks for selected customer-facing configuration/content so a temporary optional-content failure does not fabricate protected business data.

---

# 27. Tax calculator

**Implemented**

Current tax module includes:

- public/guest calculator access;
- backend tax configuration;
- tax-year handling;
- filer/income mode inputs;
- advanced inputs where configured;
- validation of malformed/negative/non-finite values;
- backend-authored calculation result and breakdown;
- calculation history;
- previous-calculation opening;
- link/start-tax-service backend contracts where allowed.

A backend tax-estimate PDF method exists, but a complete customer-facing PDF download/share UI should not be advertised unless the Flutter presentation for that exact behaviour is verified.

---

# 28. Expense tracker and budget

**Implemented**

Expense features include:

- income and expense entries;
- create/edit/archive/delete flows according to mode;
- categories;
- date, amount, account, payment method, merchant, notes;
- tax-relevant/business/recurring/reimbursable flags;
- receipt upload;
- guest/pending local mode;
- approved-customer guarded cloud mode;
- local/cloud synchronisation helpers;
- bounded bulk sync;
- summary views;
- budget records;
- budget progress/comparison;
- backup import/export in Flutter local mode;
- persistence-aware success/failure behaviour.

Clearing local expense data must not be represented as deleting cloud records.

---

# 29. Profile and settings

**Implemented**

Customer/profile UI includes:

- profile display;
- edit profile;
- contact/business/profile fields;
- account status;
- approval state;
- guarded self-service updates;
- protected account-email authority;
- profile image upload where supported;
- work-address self-service endpoints;
- settings/preferences;
- change password;
- notification preferences;
- legal/support links;
- logout;
- support-based delete-account request rather than unsafe immediate deletion.

Internal staff profile state is separately represented by `OMC Staff Profile`; customer and staff profiles are not interchangeable.

---

# 30. Security and reliability behaviour

**Implemented across the current backend/Flutter boundary**

The codebase contains layered controls for:

- backend-first authentication and authorisation;
- CSRF/session-aware Frappe communication;
- customer ownership checks;
- internal assignment/relevance checks;
- capability checks;
- DocPerm + permission-query + record-level permissions;
- bounded text/numeric inputs;
- file validation;
- duplicate/idempotent mutation protection;
- payment/request/ToDo duplication prevention;
- fail-closed routing;
- token hashing and expiry for verification/activation/reset-style flows;
- safe identity-collision handling;
- retry/error classification;
- transaction rollback on guarded multi-step operations;
- secrets/runtime/private data excluded from source control.

The project deliberately does **not** patch ERPNext source code for OMC-specific behaviour. Integrations live in the custom OMC app through APIs, hooks, adapters, permissions, fixtures, and migrations.

---

# 31. Technical platform

Current application stack includes:

```text
Flutter / Dart
Riverpod
GoRouter
Dio
Flutter Secure Storage
Shared Preferences
File Picker / Image Picker
Cached Network Image
Charts
URL launcher / share support
local_auth
Frappe Framework / ERPNext
Python
MariaDB
Redis workers / scheduler
Custom OMC DocTypes and whitelisted APIs
nginx / Supervisor deployment assets
```

Flutter supports Android and web builds in the repository. The Flutter codebase is iOS-capable, but iOS signing/archive/App Store validation still requires macOS/Xcode and real release verification.

---

# 32. Current known gaps and release gates

The following items should remain explicit instead of being presented as completed:

1. **Imported-customer activation manual E2E** — backend/Flutter implementation and tests are green, but the real email-link → Flutter/web password creation → actual login rehearsal is still pending.
2. **Permanent ERP Customer migration** — the 4,530 profile-only apply has not been run on the client dataset.
3. **CNIC/phone-only imported customer activation** — no secure SMS/OTP or equivalent first-login method has been implemented yet.
4. **Staff application/Admin Control alignment** — the newest Staff Profile approval/persona authority is not yet fully wired into legacy registration approval, staff invitation, and direct role-edit APIs.
5. **Commission UI/backend mismatch** — Flutter commission routes/repository remain, but the referenced `referral_commissions` backend API has been retired.
6. **Manager Desk permission alignment** — API capabilities make staff-management/settings authority narrower than Admin, while direct Desk DocPerm should be reviewed so Frappe Desk access matches that intent.
7. **Production external services** — email, push delivery, HTTPS, scheduler/workers, release signing, and physical-device behaviour require environment-specific verification.

---

# 33. Features not confirmed as complete

Do not advertise the following as completed current features:

- passwordless biometric login to the OMC backend;
- a separate remember-password feature;
- production Google sign-in;
- confirmed production Firebase/APNs push delivery;
- in-app card/payment-gateway charging;
- socket-based real-time chat;
- full offline operation for every business module;
- secure SMS/OTP first-time activation for imported customers;
- a working end-to-end commission/settlement module in the current branch;
- automatic customer/user identity merging when records conflict.

---

# Summary

OMC App currently provides a broad customer-service and internal-operations platform around ERPNext/Frappe: customer onboarding and activation, service catalogue and requests, documents, payments, ERP Task/Service execution, native ERP leads and tasks, referrals, support, notifications, tax tools, expense tracking, customer management, internal queues, and operational recovery.

The newest architecture intentionally removes duplicated OMC authority where ERPNext already owns the business record, while preserving OMC-specific mobile approval, customer profile, staff profile, referral, service-workflow, and security state inside the custom app.

The catalogue above should be treated as the release-facing truth: implemented features are listed as implemented, while known wiring gaps and unverified environment-dependent behaviour remain explicitly labelled.