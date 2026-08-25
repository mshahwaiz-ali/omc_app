# OMC App — Current Feature Catalogue

Source cross-check: **25 August 2026**, branch `main`.

This document describes implemented OMC App features and the current authority boundaries between Flutter, the custom Frappe app, and ERPNext.

> **Authority rule:** Flutter controls presentation and navigation. The OMC/Frappe backend remains authoritative for identity, access, ownership, capabilities, pricing, workflow state, documents, payments, assignment, ERP activation, and protected mutations.

---

## Validation snapshot

Latest directly observed validation for the current implementation before this documentation refresh:

```text
Backend OMC suite:                 932 / 932 passed
Flutter case-detail contract:        4 / 4 passed
Flutter analyze:                  No issues found

Production service catalogue:
  categories:                         9 unchanged
  services:                          31 unchanged
  required documents:               93 unchanged
  form fields:                       62 unchanged
  total managed objects:            195 unchanged
  pending creates/updates:            0 / 0
  conflicts/blockers:                 0 / 0
```

These results describe the exact tested repository/site state. They are not a substitute for validating a later commit or another site.

---

# 1. App entry, routing and UX

**Implemented**

- splash/onboarding flow;
- guest entry;
- capability-aware routing;
- customer shell navigation;
- internal workspace navigation for authorised users;
- access-denied handling;
- loading, empty, retry and safe-error states;
- duplicate-action protection on sensitive actions;
- deep-link normalisation;
- fail-closed treatment of unsupported protected routes;
- responsive Flutter layouts.

Flutter route visibility is not the security boundary; protected APIs re-check backend authority.

---

# 2. Authentication and session handling

**Implemented**

- password login;
- session restoration;
- logout and local session cleanup;
- secure credential/session storage;
- approval/access-state-aware post-login routing;
- forgot/reset password flows;
- email verification flows;
- existing-customer activation flow;
- guarded Google mobile login where configured;
- friendly authentication errors;
- optional local device lock using platform authentication.

Device lock protects an already authenticated local session. It does not replace backend authentication.

---

# 3. Public signup

**Implemented — customer-only public signup**

Current public self-registration accepts customer account types only. Internal staff personas are not granted through public signup.

Registration includes supported customer identity/contact fields, username/password, acquisition context, and optional referral data. Backend validation remains authoritative.

`OMC Pending Registration` provides guarded verification with:

- cryptographically random verification tokens;
- stored token digests rather than plaintext secrets;
- expiry and resend cooldown;
- token rotation/supersede behavior;
- safe terminal cleanup.

Staff access is provisioned separately from ERP/internal identity and canonical `OMC Staff Access` reconciliation.

---

# 4. Customer identity authority

**Implemented**

Authenticated customer access uses:

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +------> ERP Customer
        +------> OMC Customer Profile
```

`OMC Customer Account` is the canonical authenticated mapping. An account must have the required verified, linked and approved state before protected customer capabilities are enabled.

`OMC Customer Profile` remains a business/profile and compatibility record, but it does not independently override canonical account authority.

Customer reads/writes are ownership-scoped.

---

# 5. Existing ERP customer migration and claims

**Implemented**

`omc_app.api.customer_migration` classifies existing ERP Customers without bulk-creating Frappe login users.

Current deterministic identity priority is:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

Tax ID/NTN is a final deterministic fallback; it does not replace email/CNIC/phone precedence.

Migration behavior includes:

- read-only preflight;
- explicit apply confirmation;
- idempotent reuse of safe existing records;
- profile-only migration where appropriate;
- no shared/default password generation;
- no bulk login-user creation;
- preservation of ambiguous identities for review;
- staff/referral reconciliation phases where configured;
- historical attribution only when evidence is supportable.

Existing-customer claim/activation is separated from business-profile migration.

---

# 6. Existing-customer activation

**Implemented**

Imported customers can activate app login through the supported identity-proof flow rather than receiving generated passwords.

The backend protects activation with enumeration-safe responses, expiring one-time tokens, collision checks, row locking where required, and explicit identity eligibility.

Existing identities are not silently merged when ambiguity exists.

---

# 7. Internal staff access

**Implemented**

Canonical internal authority is:

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +------> capability rows
        +------> access status
        +------> reconciliation status
        +------> persona snapshot/source
```

Normal protected staff access requires an approved, current Staff Access record.

ERP-owned personas currently include:

- `Consultant`;
- `Tax Associates`;
- `Business Partner`;
- `Employee`.

OMC-owned operational roles include:

- `OMC Admin`;
- `OMC Manager`;
- `OMC Support Agent`;
- `OMC Document Reviewer`;
- `OMC Finance Reviewer`.

Retired duplicate OMC specialist role names remain compatibility-only and must not be used as new authority.

`System Manager` is a Frappe infrastructure role, not implicit OMC business authority.

---

# 8. Capability model and break-glass access

**Implemented**

Backend capabilities cover areas such as:

- internal workspace;
- customer/lead visibility and management;
- task visibility/management;
- all/relevant/assigned service-case access;
- assisted service creation;
- service-status updates;
- document queue/review;
- payment queue/review;
- settlement reconciliation;
- support operations;
- staff/business settings;
- service reassignment;
- bridge retry/recovery;
- referral ownership;
- personal commission visibility;
- finance commission approval/payment.

Exceptional access can be represented by scoped, expiring `OMC Break Glass Grant` records. Break-glass capability does not permanently mutate the user's normal authority.

---

# 9. Home and dashboards

**Implemented**

- guest/public home experience;
- approved-customer dashboard;
- quick actions;
- service/activity context;
- notifications/profile entry points;
- capability-aware internal workspace summaries;
- safe unavailable/error states rather than fabricated success values.

---

# 10. Production service catalogue

**Implemented and production-reconciled**

The source-controlled catalogue defines:

```text
9 categories
31 services
17 active
14 inactive / review-required
currency: PKR
company: Omc House
default activation policy: Full Settlement
```

Catalogue source lives under:

```text
omc_app/setup/service_catalogue/
```

Key features:

- stable `service_id` identity;
- stable category identity;
- exact existing ERP Task Type mapping;
- no fuzzy Task Type matching;
- no automatic ERP Task Type creation;
- managed required-document definitions;
- managed service form fields;
- explicit commercial confidence/review state;
- inactive services for unresolved pricing/scope rather than invented values;
- idempotent preview/validate/sync operations;
- in-flight request protection;
- pricing-change safety;
- rollback on failed sync;
- stale managed-row deactivation instead of destructive deletion.

Catalogue publishing is explicit. Normal `bench migrate` does not publish it.

---

# 11. Service request creation

**Implemented**

Customer and authorised assisted-service flows create `OMC Service Request` records through backend authority.

Request creation protects:

- customer identity/ownership;
- active service eligibility;
- canonical pricing snapshots;
- duplicate/parallel-request policy;
- required service input validation;
- idempotency where applicable;
- customer/referral attribution;
- staff capability/scope for assisted creation.

---

# 12. Request lifecycle

**Implemented**

The backend uses an explicit request-state machine with states including:

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

Customer-facing operational status is a compatibility projection over the canonical lifecycle.

Terminal transitions also clean related review work, payment/document state, bridge operations, timeline state and notifications in the same transaction where required.

---

# 13. Required documents and stable document identity

**Implemented end-to-end**

Required-document templates and uploaded service documents support stable `document_key` identity.

Rules:

- when both sides have a key, `document_key` is authoritative;
- a wrong key cannot match by title/type;
- genuine legacy/unkeyed records can use exact normalized title + document-type fallback;
- one upload can satisfy at most one requirement;
- the backend canonicalises title/type from the requirement;
- requirement identity is validated against the request's service;
- arbitrary generic uploads remain supported only where intentionally allowed.

### Grandfathering

Required-document templates can carry `effective_from`. New managed requirements therefore apply to new requests without retroactively changing older in-flight contracts.

---

# 14. Flutter required-document upload UX

**Implemented and validated**

Service-case detail can present inline required-document actions such as Upload or Replace.

The client carries the selected requirement identity to the backend and refreshes relevant case/document/dashboard state after success.

Accessibility semantics are preserved for document rows and actions.

---

# 15. Document review

**Implemented**

- customer-owned document listing/detail;
- attachment validation;
- service-request ownership validation;
- upload/replacement;
- reviewer queue;
- document status and review reason;
- capability-gated document attachments/review;
- completion checks using the same stable requirement identity rules.

---

# 16. Payment and accounting gate

**Implemented**

OMC separates customer payment/receipt workflow from ERP accounting authority.

`OMC Service Payment` tracks OMC payment state and evidence. `OMC Accounting Link` represents the accounting settlement relationship used by activation eligibility.

For the default `Full Settlement` policy, ERP activation requires settled accounting evidence.

The backend also supports explicit no-charge and authorised post-paid paths.

Finance capabilities are separated between payment review, settlement reconciliation, post-paid approval and commission operations.

---

# 17. Durable ERP activation bridge

**Implemented**

`OMC Bridge Operation` provides exactly-once-oriented activation behavior with:

- deterministic operation keys;
- request locking;
- eligibility re-checks;
- final settlement re-check before ERP writes;
- bounded retry/backoff;
- stale-processing lease recovery;
- rollback around ERP operational writes;
- failed/cancelled/completed terminal states;
- authorised manual recovery;
- audit events.

Successful activation requires committed ERP `Service` and ERP `Task` links.

---

# 18. Assignment and tasks

**Implemented**

Assignment supports backend-controlled eligibility and can use explicit/default/referral/role-based resolution depending on the request and service configuration.

Task visibility and mutation are capability/scope controlled. Flutter task views are not allowed to bypass backend assignment authority.

---

# 19. Leads and customers

**Implemented**

Native ERPNext `Lead` and `Customer` remain the business source of truth. OMC provides guarded APIs and workflow integration rather than replacing these ERP masters with duplicate canonical records.

Legacy OMC Lead data remains compatibility/retirement territory and must not regain authority merely because an old table exists.

---

# 20. Referrals

**Implemented**

Referral ownership requires explicit capability and eligible staff persona. Referral attribution is stored separately from commission lifecycle so business provenance is not inferred from a payout record alone.

Referral owners can have self-scoped referral/commission experiences without receiving finance authority.

---

# 21. Commissions

**Implemented**

Current commission architecture includes:

- `OMC Commission Allocation`;
- commission lifecycle operations;
- personal/beneficiary commission visibility;
- finance commission operations;
- approval/payment capabilities separated from referral ownership;
- historical evidence/provenance handling;
- safe legacy compatibility aliases that do not broaden finance authority.

---

# 22. Support

**Implemented**

- customer support-ticket creation;
- customer ticket visibility;
- internal support queue;
- staff reply/status/assignment actions under capability control;
- relevant customer/service context;
- customer-safe support communication.

---

# 23. Notifications

**Implemented**

- customer notifications;
- internal notifications;
- unread/read behavior where exposed;
- service/payment/document/support event integration;
- deep-link/navigation context where configured;
- push-token infrastructure.

---

# 24. Profile and settings

**Implemented**

Customer/profile self-service is backend guarded and limits writable fields. Internal users have a separate safe profile path and do not need a customer profile merely to update allowed user fields.

Settings/preferences and notification preferences are backend connected where implemented.

---

# 25. Tax calculator and expense tools

**Implemented**

The app contains customer tax-calculator and expense/budget functionality with backend support. Tax configuration remains OMC-owned configuration and is not an excuse to patch ERPNext source.

---

# 26. Internal workspace and Desk

**Implemented**

Internal workspace provides capability-aware access to operational areas including service cases, customers, leads, tasks, document review, payment review, support, referral/commission operations and selected configuration.

OMC Desk/workspace metadata is source controlled and can be deliberately reconciled through setup operations.

---

# 27. Setup and migrations

**Implemented with explicit boundaries**

Lifecycle behavior:

```text
before_install -> validate ERP/client contract
after_install  -> explicit one-time OMC initialisation
after_migrate  -> validation only
```

Normal migrate does not silently rewrite roles, branding, Desk metadata or service catalogue content.

Explicit setup operations exist for deliberate permission, workspace, branding and catalogue reconciliation.

---

# 28. Security and hardening

**Implemented across the current architecture**

Major controls include:

- backend-first authorisation;
- fail-closed unsupported access;
- ownership and assignment scope;
- explicit staff capabilities;
- break-glass scoping/expiry;
- sensitive POST guards;
- CSRF/CORS/auth hardening where applicable;
- idempotency controls;
- safe upload validation;
- pagination/limits on operational lists;
- audit events for sensitive transitions;
- no implicit OMC authority from System Manager;
- no mass customer-role mutation during migration;
- no silent identity guessing;
- no ERPNext source modifications for OMC business logic.

---

## Current intentional constraints

The following are deliberate constraints rather than hidden implementation claims:

- unresolved commercial data keeps affected catalogue services inactive;
- legacy/unkeyed document compatibility remains for historical records;
- customer migration keeps ambiguous identities in review;
- existing-customer login activation depends on supported identity proof;
- production/device E2E should still be performed for a release even when automated suites are green;
- iOS release still requires the normal macOS/Xcode signing and App Store workflow.

---

## Related documentation

- [`../README.md`](../README.md) — high-level architecture and operating boundaries;
- [`ROLE.md`](ROLE.md) — role/persona/capability model;
- [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — business workflow architecture;
- [`OMC_Client_Deployment_and_Customer_Migration_Handover.md`](OMC_Client_Deployment_and_Customer_Migration_Handover.md) — client deployment/migration runbook;
- [`../omc_app/README.md`](../omc_app/README.md) — Flutter engineering guide;
- [`../backend_omc_app/frappe-bench/apps/omc_app/README.md`](../backend_omc_app/frappe-bench/apps/omc_app/README.md) — backend engineering guide.
