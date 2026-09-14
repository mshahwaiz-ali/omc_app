# OMC App — Current Feature Catalogue

Source cross-check: **14 September 2026**, branch `main`, repository HEAD `0813d3b7fed0de3662fa906ed1fbe6031360a362`.

This document is the current OMC App feature inventory.

It describes the intended production feature set and the authority boundaries between Flutter, the custom OMC Frappe application, and ERPNext v14.

> **Authority rule:** Flutter controls presentation and navigation. The OMC/Frappe backend remains authoritative for identity, access, ownership, capabilities, pricing, workflow state, documents, payments, assignment, settlement, ERP activation and protected mutations.

Where current source still contains legacy behavior that conflicts with the intended production model, it is listed separately under **Known Conformance Gaps** rather than presented as a supported feature.

---

## Validation status

This documentation refresh does not itself constitute a fresh release validation.

The repository has accumulated focused backend and Flutter regression coverage during the current development cycle, including service-request, document-reuse, payment, activation and client-contract tests.

Exact historical pass counts are intentionally not treated here as proof of the current HEAD unless the relevant suites are rerun against that exact checkout and site.

Before production release or deployment, rerun the applicable backend tests, Flutter tests and static analysis against the exact release commit and target environment.

---

# 1. App entry, routing and UX

**Implemented**

* splash/onboarding flow;
* guest entry;
* authenticated routing;
* customer navigation;
* capability-aware internal navigation;
* access-denied handling;
* loading, empty, retry and safe-error states;
* duplicate-action protection where applicable;
* deep-link normalization;
* responsive Flutter layouts;
* fail-closed handling of unsupported protected routes.

Flutter route visibility is not the security boundary.

Protected backend APIs always remain authoritative.

---

# 2. Authentication and session handling

**Implemented**

* password login;
* session restoration;
* logout and local cleanup;
* protected authenticated requests;
* approval/access-aware routing;
* forgot/reset password flows;
* email verification flows;
* existing-customer activation;
* supported social/mobile authentication where configured;
* safe authentication errors;
* optional local device lock.

Local biometric/device lock protects an already authenticated local session.

It does not replace backend authentication or authorization.

---

# 3. Public signup

**Implemented — customer-only public signup**

Public registration cannot provision internal staff authority.

Registration supports controlled customer identity/contact information and optional referral/acquisition context.

`OMC Pending Registration` supports verification controls including:

* one-time verification secrets;
* token digest storage;
* expiry;
* resend cooldown;
* token supersession/rotation;
* safe terminal cleanup;
* collision handling.

Internal employees and staff are provisioned through trusted ERP/internal processes instead.

---

# 4. Canonical customer identity

**Implemented**

The customer identity relationship is:

```text
Frappe User
     |
     v
OMC Customer Account
     |
     +----> ERPNext Customer
     |
     +----> OMC Customer Profile
```

### ERPNext Customer

ERPNext `Customer` remains the canonical business customer.

### OMC Customer Account

`OMC Customer Account` is the protected authenticated mapping between the Frappe login and the ERP Customer.

### OMC Customer Profile

`OMC Customer Profile` remains an OMC application/profile projection and compatibility record.

It does not replace ERP Customer as the business master.

Customer operations are ownership-scoped.

---

# 5. Existing ERP customer migration

**Implemented**

Existing ERP Customers can be classified and linked into OMC customer/profile state without bulk-generating login users.

Current deterministic identity resolution uses supported evidence such as:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. manual identity review
```

Migration behavior includes:

* read-only preflight;
* explicit apply mode;
* idempotent reruns;
* reuse of safe existing records;
* no shared/default passwords;
* no required mass login-user creation;
* ambiguous identities retained for review;
* no unsupported historical relationship guessing.

### Important lifecycle rule

This migration does **not** need to be rerun whenever an already-linked customer later receives a new:

* Service Request;
* ERP Task;
* document;
* payment;
* commission allocation.

Those records continue to use the existing canonical ERP Customer relationship.

---

# 6. Existing-customer activation

**Implemented**

Imported ERP Customers can later activate app login using the supported identity-proof workflow.

The activation path protects against:

* account enumeration;
* identity collisions;
* ambiguous matches;
* expired tokens;
* duplicate ownership;
* unsafe automatic merges.

Business migration and login activation remain separate operations.

---

# 7. New ERP-only Customer onboarding

**Partially automated / explicit onboarding required**

A newly created ERP Customer that has no OMC identity relationship does not automatically become an app-enabled login solely because normal reconciliation runs.

A supported onboarding/import/linking action is still required.

This is intentional until a safe automatic discovery policy exists.

---

# 8. Internal staff access

**Implemented**

Canonical OMC staff authority is:

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +--> status
        +--> persona
        +--> explicit capabilities
        +--> record scope
```

Normal protected internal access requires valid Staff Access.

Supported ERP/internal personas can include:

* Consultant;
* Tax Associates;
* Business Partner;
* Employee.

OMC operational roles include areas such as:

* administration;
* management;
* support;
* document review;
* finance review.

`System Manager` remains a Frappe infrastructure role.

It does **not** automatically grant OMC business authority.

---

# 9. Capabilities and break-glass access

**Implemented**

Backend capability controls cover areas such as:

* internal workspace;
* customer and lead access;
* assisted service creation;
* service-case visibility;
* Task visibility;
* service assignment;
* document review;
* payment review;
* settlement reconciliation;
* support operations;
* bridge recovery;
* referral ownership;
* commission visibility;
* commission finance operations.

Exceptional access can use scoped `OMC Break Glass Grant` records.

Break-glass grants can be:

* capability-specific;
* temporary;
* record-scoped;
* revoked;
* audited.

They do not permanently alter normal persona authority.

---

# 10. Home and dashboards

**Implemented**

The application supports:

* guest/public home;
* customer dashboard;
* quick actions;
* service activity;
* document/payment context;
* notifications;
* profile access;
* authorised internal workspace summaries;
* explicit unavailable/error states.

Dashboard values must derive from real backend data rather than fabricated placeholders.

---

# 11. Service catalogue

**Implemented**

The service catalogue supports:

* stable `service_id`;
* categories;
* active/inactive state;
* pricing;
* accounting/tax mapping;
* required documents;
* service form fields;
* Task Type mapping;
* availability;
* activation/payment policy;
* source-controlled provisioning.

Current catalogue configuration contains:

```text
9 categories
31 services
```

Some services remain inactive where business/commercial information is not approved.

OMC must not invent commercial facts just to make a service active.

---

# 12. Catalogue provisioning

**Implemented**

Operator-facing catalogue operations include explicit:

* preview;
* validation;
* synchronization.

Provisioning supports:

* deterministic matching;
* exact ERP Task Type mapping;
* no fuzzy Task Type creation;
* reconciliation of managed records;
* in-flight request safety;
* pricing-change safety;
* stale managed-row deactivation;
* rollback on failure;
* idempotent reruns.

Normal `bench migrate` does not implicitly publish the commercial catalogue.

---

# 13. Service Request creation

**Implemented**

Both customers and authorised internal staff can create `OMC Service Request` records through controlled backend workflows.

Request creation protects:

* ERP Customer authority;
* service eligibility;
* pricing;
* tax/accounting context;
* required service inputs;
* required documents;
* duplicate/parallel request policy;
* referral context;
* assisted-service scope;
* idempotency.

Important request facts are snapshotted so later catalogue changes do not silently rewrite an existing customer's commercial agreement.

---

# 14. Assisted/internal service creation

**Implemented**

Authorised staff can create or assist with a service for an existing customer.

Assisted creation:

* uses the canonical ERP Customer;
* does not create a second customer master;
* preserves customer ownership;
* preserves document rules;
* preserves payment-first rules;
* preserves accounting authority;
* records internal provenance;
* remains capability-gated.

Internal creation does not automatically bypass business rules.

---

# 15. Fundamental execution contract

**Target production architecture**

> **One OMC Service Request = one authoritative ERP Task.**

The single Task represents internal operational execution for that requested service.

Customers interact with the Service Request.

Internal employees work with the ERP Task.

A customer must not be exposed directly to internal ERP Task details.

Legacy one-to-many Task code still exists in parts of the source and is documented under **Known Conformance Gaps**.

---

# 16. Service Request lifecycle

**Implemented with legacy surfaces still under cleanup**

Important lifecycle states include:

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

Customer-facing status can be a safe projection of the internal lifecycle.

Invalid transitions must fail closed.

Terminal transitions should keep related payment, document, bridge, ToDo, timeline and notification state consistent.

---

# 17. Required-document configuration

**Implemented**

Service requirements use stable `document_key` identity.

Rules include:

* keyed requirements prefer exact `document_key`;
* an incorrect key cannot be accepted only because title/type matches;
* legacy unkeyed history may use controlled compatibility matching;
* one upload satisfies at most one requirement;
* requirement identity must belong to the correct service;
* new requirements can use effective-date/grandfathering behavior.

This protects historical requests when catalogue requirements change later.

---

# 18. Document upload

**Implemented**

Protected document upload supports:

* request ownership checks;
* authorised staff scope;
* requirement validation;
* service relationship validation;
* private file handling;
* file restrictions;
* replacement;
* document review state;
* upload security controls.

Customers must never receive another customer's private document merely because the document name or type matches.

---

# 19. Reusable customer documents

**Implemented**

Approved documents can be reused for later requests when the configured reuse policy allows it.

Reuse eligibility is scoped using facts including:

* same canonical customer;
* same service;
* same stable `document_key`;
* accepted/approved document status;
* reuse policy;
* expiry/validity period;
* replacement/invalidation state;
* secure file ownership.

A requirement marked **Always New** is never automatically reusable.

Reusable documents satisfy document eligibility.

They do **not** bypass payment or settlement.

### Current configuration boundary

Document reuse is available only when the applicable `OMC Service Required Document` row is configured with either:

* `Reusable Until Replaced`; or
* `Reusable for N Days`.

`Always New` remains the safe default.

At the current repository HEAD, the source-controlled service-catalogue provisioner does **not** provision `reuse_policy` or `reuse_validity_days`.

Therefore, the reuse engine is implemented, but catalogue-managed requirements are not automatically made reusable merely by running catalogue synchronization. Reuse depends on the requirement's actual configured policy until a source-controlled policy model is explicitly introduced.

---

# 20. Returning-customer document flow

**Implemented**

The customer flow is no longer based on the assumption that every request requires a brand-new upload.

The intended behavior is:

```text
Required document
      |
      +--> approved reusable document exists
      |        -> requirement already satisfied/reused
      |
      +--> no reusable document
               -> customer uploads document
      |
      v
Document eligibility complete
      |
      v
Payment workflow
```

This allows returning customers to reuse qualifying prior documentation.

---

# 21. Document review

**Implemented**

Document operations include:

* customer document visibility;
* service-request documents;
* upload/replace;
* reviewer queue;
* approval/rejection state;
* review reasons;
* capability-gated review;
* stable requirement identity;
* document completion checks.

Internal document handling remains subject to capability and customer/request scope.

---

# 22. Payment-first lifecycle

**Authoritative production rule**

For a positive-price service:

```text
Service Request
      |
Required documents eligible
      |
Payment workflow
      |
ERP accounting evidence
      |
Settlement reconciliation
      |
Ready for activation
      |
Exactly one ERP Task
```

Creating the Service Request does not start operational work.

Uploading documents does not start operational work.

Uploading a receipt does not start operational work.

Receipt approval alone does not establish final financial settlement.

---

# 23. OMC payment workflow

**Implemented**

`OMC Service Payment` tracks OMC payment/customer-receipt workflow.

It is not the accounting authority.

Supported operations include areas such as:

* payment opening;
* customer payment instructions;
* receipt/evidence upload;
* review workflow;
* payment method handling;
* outstanding/additional payment handling;
* request association.

### Critical rule

> **`OMC Service Payment` becomes finally Paid/settled only through ERP accounting reconciliation.**

The application must never manually force final Paid state merely because a reviewer accepted a receipt.

---

# 24. ERP accounting authority

**Implemented**

ERPNext accounting remains authoritative for financial settlement.

OMC accounting/reconciliation records link OMC service-payment workflow to actual ERP accounting evidence.

Reconciliation can distinguish states such as:

* unmatched;
* partially settled;
* settled;
* reversed;
* review required;
* quarantined/ambiguous.

Only valid required settlement makes a positive-price Full Settlement request eligible for activation.

---

# 25. Installment/additional payments

**Implemented**

The payment model supports additional/installment payment activity where applicable.

Outstanding amounts remain accounting-derived.

Partial payment must not trigger full-settlement activation.

Further payment actions should be constrained by the current authoritative outstanding balance.

---

# 26. No Charge services

**Implemented**

A service can explicitly be configured as `No Charge`.

No Charge services do not require artificial accounting evidence.

They must still satisfy other applicable eligibility rules.

`No Charge` is a real service policy.

It is not a manual bypass for a normally chargeable service.

---

# 27. Durable activation bridge

**Implemented**

`OMC Bridge Operation` provides the durable boundary between financial eligibility and operational ERP work.

Bridge behavior includes:

* deterministic operation identity;
* locking;
* final eligibility re-check;
* settlement re-check;
* idempotency;
* retries;
* bounded backoff;
* stale-processing recovery;
* rollback boundaries;
* terminal failure evidence;
* authorised manual recovery;
* audit history.

A retry must not create duplicate operational Tasks.

---

# 28. ERP Task execution

**Target production model**

Successful activation creates or resolves exactly one authoritative ERP Task for the Service Request.

The Task contains internal execution context such as applicable:

* ERP Customer;
* Task Type;
* service/request linkage;
* assignment;
* expected dates;
* internal execution state.

The Task remains ERP-owned operational work.

Customers consume safe Service Request progress instead.

---

# 29. Task completion

**Target production model**

Completion is driven by the single authoritative Task for the request.

When that Task is completed, the backend can finalize the related Service Request after verifying applicable completion conditions.

An unrelated Task cannot complete another customer's Service Request.

Legacy multi-Task completion aggregation is not part of the intended design.

---

# 30. Internal Task visibility

**Implemented, scope review pending**

Internal users can access Task information according to OMC capability rules.

Customer personas must not receive direct ERP Task access.

Internal Task APIs should continue to be narrowed to the minimum appropriate assignment/role scope.

---

# 31. Assignment

**Implemented**

Assignment is controlled by backend policy.

Eligible context can include:

* explicit assignment;
* service/team policy;
* consultant/associate eligibility;
* referral/business context;
* workload automation.

Untrusted client input cannot arbitrarily select internal Task ownership.

Assignment operations must remain idempotent.

---

# 32. Leads and Customers

**Implemented**

ERPNext `Lead` and `Customer` remain authoritative ERP business masters.

OMC provides protected integration around them.

Legacy OMC lead/customer-like records must not become a competing business source of truth.

---

# 33. Referral attribution

**Implemented**

Referral behavior separates:

* referral ownership;
* referral codes;
* customer attribution;
* service attribution/evidence;
* commission entitlement;
* finance operations.

Referral provenance exists independently of payout state.

Referral ownership does not automatically grant finance authority.

---

# 34. Commission snapshot

**Implemented**

OMC reuses the client's existing commission configuration rather than creating an independent commission calculation engine.

When applicable, commission configuration is snapshotted onto a newly created ERP Payment Entry.

Submitted historical Payment Entries are not mutated simply to retrofit new OMC commission fields.

---

# 35. Commission projection

**Implemented**

Existing `commission_projection.py` projects submitted ERP allocation evidence into `OMC Commission Allocation`.

Important properties include:

* ERP evidence remains authoritative;
* immutable/projection-oriented OMC allocation records;
* deterministic allocation identity;
* duplicate prevention/idempotency;
* beneficiary visibility;
* finance approval/payment lifecycle;
* separation of referral ownership from finance authority.

Commission percentages must not be parsed from human-readable structure names.

---

# 36. Support

**Implemented**

Support features include:

* customer ticket creation;
* customer ticket visibility;
* support messages;
* internal support queue;
* controlled assignment/status handling;
* customer/service context;
* capability-gated staff operations.

---

# 37. Notifications

**Implemented**

Notification functionality covers:

* customer notifications;
* internal notifications;
* unread/read state;
* service events;
* document events;
* payment events;
* support events;
* deep-link/navigation context;
* device token/push infrastructure;
* notification preferences.

Customer notifications must not expose internal ERP-only information.

---

# 38. Profile and settings

**Implemented**

Customer profile changes are backend-controlled.

Writable fields are restricted.

Internal users use appropriate internal/profile paths rather than being forced into customer-profile semantics.

Settings and notification preferences connect to backend state where supported.

---

# 39. Tax and expense functionality

**Implemented**

The Flutter application includes customer-facing tax/expense functionality backed by OMC APIs.

Relevant configuration remains inside the OMC custom application.

ERPNext core is not modified for these features.

---

# 40. Internal workspace

**Implemented**

Capability-aware internal workspace functionality can surface operational areas such as:

* service requests;
* customers;
* leads;
* ERP Tasks;
* documents;
* payment review;
* reconciliation;
* support;
* referrals;
* commissions;
* selected configuration.

Internal workspace actions remain backend-authorized.

---

# 41. Review and workflow automation

**Implemented**

Operational automation exists for areas including:

* assignment;
* document review routing;
* payment review routing;
* ERP synchronization recovery;
* bridge retries;
* workflow/status automation.

Automation must preserve:

* authority;
* idempotency;
* bounded retries;
* explicit state;
* auditability;
* safe failure behavior.

---

# 42. ERP synchronization recovery

**Implemented**

OMC has explicit recovery state for integration failures rather than relying on silent repeated writes.

Recovery behavior can include:

* attempt counting;
* backoff;
* next-attempt tracking;
* exhausted/failed state;
* retry eligibility;
* operator visibility.

Retries must be safe and idempotent.

---

# 43. Security and hardening

**Implemented across the architecture**

Controls include:

* authenticated sessions;
* customer ownership enforcement;
* explicit Staff Access;
* capability checks;
* record scope;
* break-glass access;
* sensitive mutation guards;
* CSRF/CORS protections where applicable;
* rate limiting;
* idempotency;
* upload validation;
* audit events;
* pagination/bounded reads;
* safe error handling;
* no implicit System Manager business authority;
* no silent identity guessing;
* no OMC business modification of ERPNext core.

---

# 44. Setup and migration lifecycle

**Implemented**

OMC setup is additive to an existing Frappe/ERPNext v14 environment.

Setup can install or reconcile:

* OMC DocTypes;
* custom fields;
* OMC roles/capabilities;
* workspace metadata;
* hooks;
* patches;
* ERP integration contract fields;
* controlled lifecycle/configuration records.

Normal migration must remain restart-safe.

It must not silently invent business identities or commercial configuration.

---

# 45. Compatibility APIs and legacy surfaces

**Implemented where required for migration safety**

Compatibility wrappers may remain temporarily where older application paths still depend on them.

Compatibility code must not:

* widen permissions;
* create a second authority;
* restore retired architecture;
* override ERP accounting truth;
* expose internal Task data to customers.

Retirement should be deliberate and regression-tested.

---

# 46. Known Conformance Gaps

These items exist in current source but are **not intended production features**.

## 46.1 Legacy one-to-many Task model

Parts of the backend still contain:

* `OMC Service Task Link`;
* multiple linked Task logic;
* required/optional Task concepts;
* multi-Task completion aggregation;
* related backend/Flutter tests.

This conflicts with the current contract:

> **One Service Request = one authoritative ERP Task.**

It should be removed or reduced to compatibility-only behavior in a later focused implementation phase.

## 46.2 `Post-paid Approval` legacy surface

A `Post-paid Approval` activation policy still exists in portions of the current source.

For positive-price production services, the intended contract is ERP-settlement-before-activation.

`No Charge` remains supported.

The post-paid surface should be reviewed and constrained/retired.

## 46.3 Two document-reuse materialization mechanisms

Self-service and assisted/internal reuse currently use different underlying materialization strategies.

Both are ownership-scoped, but storage/lineage behavior should eventually be unified.

## 46.4 New raw ERP Customer discovery

A brand-new ERP Customer without an OMC identity relationship is not automatically converted into an app-enabled customer by normal reconciliation.

A deliberate onboarding/linking workflow remains necessary.

## 46.5 Internal Task scope

Current internal Task visibility should be reviewed for least-privilege behavior, especially where broad Task access may exceed assignment-based needs.

## 46.6 Service-template reuse metadata

Some service-template responses expose less document-reuse metadata than the richer catalogue contract.

The API contracts should eventually be normalized.

## 46.7 Internal document summary identity

Internal document summaries should be checked to ensure stable `document_key` matching is used consistently instead of relying on title/type where a key exists.

## 46.8 Fresh accounting/commission/activation E2E

A fresh controlled integration test is still required after architecture cleanup for:

```text
new Payment Entry
-> commission snapshot
-> submitted ERP settlement
-> reconciliation
-> commission allocation
-> activation
-> exactly one ERP Task
```

This is a verification gap, not permission to bypass accounting authority.

---

# 47. Production invariants

All future feature changes must preserve:

1. ERPNext `Customer` is the canonical business customer.
2. OMC Account/Profile records are identity/application layers around ERP Customer.
3. ERPNext/Frappe core remains untouched.
4. One Service Request maps to exactly one authoritative ERP Task.
5. Positive-price services require authoritative settlement before activation.
6. Receipt review alone cannot make final payment settlement true.
7. No Charge remains explicit policy.
8. Installments respect accounting outstanding.
9. Reusable documents require correct customer, service, document key and reuse policy.
10. `Always New` documents are never automatically reused.
11. Customers cannot access internal ERP Task details.
12. System Manager does not imply OMC business authority.
13. Commission projection reuses existing ERP/OMC commission evidence.
14. Submitted ERP accounting records are not mutated to retrofit new behavior.
15. Integration retries remain idempotent.
16. Ambiguous identity, authority or accounting evidence fails safely.

---

## Related documentation

* [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — authoritative business/workflow architecture;
* [`ROLE.md`](ROLE.md) — role, persona and capability model;
* [`OMC_Client_Deployment_and_Customer_Migration_Handover.md`](OMC_Client_Deployment_and_Customer_Migration_Handover.md) — deployment and customer migration runbook;
* [`../README.md`](../README.md) — repository overview;
* [`../omc_app/README.md`](../omc_app/README.md) — Flutter engineering guide;
* [`../omc_app/docs/backend_api_contract.md`](../omc_app/docs/backend_api_contract.md) — Flutter/backend API contract;
* [`../backend_omc_app/frappe-bench/apps/omc_app/README.md`](../backend_omc_app/frappe-bench/apps/omc_app/README.md) — OMC backend application guide.
