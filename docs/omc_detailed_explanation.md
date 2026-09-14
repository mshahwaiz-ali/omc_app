# OMC App — Business and Workflow Architecture Guide

Source cross-check: **14 September 2026**, branch `main`, repository HEAD `0813d3b7fed0de3662fa906ed1fbe6031360a362`.

This document describes the authoritative OMC App business architecture and intended production workflow.

The guiding rule is simple:

> **ERPNext remains the authoritative ERP. OMC App extends it for mobile/customer experience, identity, service orchestration, documents, payment workflow, security, audit, integrations and operational automation without modifying ERPNext core.**

Where current source still contains older behavior that conflicts with this architecture, that behavior is documented separately under **Known Conformance Gaps** and must not be treated as the intended design.

For the feature inventory, see [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md).
For access control, see [`ROLE.md`](ROLE.md).
For deployment and customer migration, see [`OMC_Client_Deployment_and_Customer_Migration_Handover.md`](OMC_Client_Deployment_and_Customer_Migration_Handover.md).

---

## 1. Core architecture

OMC App is not a replacement ERP and must not become a second independent business system.

The production relationship is:

```text
Flutter / Web Client
        |
        v
OMC custom Frappe application
        |
        v
ERPNext / Frappe v14
```

OMC App is responsible for:

* customer/mobile experience;
* identity mapping and onboarding;
* OMC-specific permissions and capabilities;
* service-request orchestration;
* required-document handling and reuse;
* customer payment workflow;
* accounting reconciliation;
* activation/retry orchestration;
* referral and commission projection;
* internal operational views;
* notifications;
* audit and security evidence.

ERPNext remains authoritative where it already owns the business record.

### Canonical authority

| Business area                   | Authoritative record/system                                     |
| ------------------------------- | --------------------------------------------------------------- |
| Business customer               | ERPNext `Customer`                                              |
| Customer login mapping          | `OMC Customer Account`                                          |
| Customer app/profile projection | `OMC Customer Profile`                                          |
| Authentication                  | Frappe `User` / session                                         |
| Internal OMC authority          | `OMC Staff Access` + explicit capabilities                      |
| Service catalogue               | `OMC Service` and source-controlled catalogue configuration     |
| Service request                 | `OMC Service Request`                                           |
| Required documents              | `OMC Service Required Document`                                 |
| Request documents               | `OMC Service Document`                                          |
| OMC payment workflow            | `OMC Service Payment`                                           |
| ERP accounting                  | ERPNext accounting records                                      |
| Settlement evidence             | OMC accounting/reconciliation records derived from ERP evidence |
| Activation/retry state          | `OMC Bridge Operation`                                          |
| Service execution               | ERPNext `Task`                                                  |
| Referral provenance             | OMC referral/attribution records                                |
| Commission projection           | `OMC Commission Allocation`                                     |
| Support                         | OMC support records                                             |
| Security/audit evidence         | OMC audit/security/reconciliation records                       |

**ERPNext and Frappe core/source must never be edited for OMC-specific behavior.**

All custom fields, hooks, APIs and integration behavior belong in the `omc_app` custom application.

---

## 2. Fundamental service contract

The current business contract is:

> **One OMC Service Request = one authoritative ERP Task.**

A service request must not create several operational Tasks for the same requested service.

The expected lifecycle is:

```text
Customer chooses service
        |
        v
Service Request created
        |
        +--> customer/ERP Customer snapshot
        +--> pricing snapshot
        +--> required-document contract
        |
        v
Required documents satisfied
(uploaded or securely reused)
        |
        v
Payment opened
        |
        v
ERP accounting evidence
        |
        v
Settlement reconciliation
        |
        v
Request eligible for activation
        |
        v
Durable activation bridge
        |
        v
Exactly one ERP Task
        |
        v
Internal execution
        |
        v
Task completed
        |
        v
Service Request completed
```

Creating a Service Request alone does **not** activate operational work.

Uploading documents alone does **not** activate operational work.

Uploading or approving a payment receipt alone does **not** settle the request.

For positive-price services, activation happens only after ERP accounting authority proves the required settlement.

---

## 3. Customer identity model

The business Customer remains ERPNext `Customer`.

OMC adds the identity bridge required by the mobile and web experience:

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

The ERPNext `Customer` is the canonical business customer used by ERP business processes.

Services, accounting and other ERP records must continue to refer to the real ERP Customer rather than an unrelated duplicate OMC customer master.

### OMC Customer Account

`OMC Customer Account` is the authoritative mapping between an authenticated login identity and the corresponding ERP Customer.

It is used for protected customer access and ownership resolution.

### OMC Customer Profile

`OMC Customer Profile` is an OMC application/profile projection used for app-specific information, compatibility, migration history, customer lifecycle and related OMC features.

It must not replace ERPNext `Customer` as the business master.

---

## 4. Existing ERP customers

Existing ERP Customers can be connected to OMC without converting ERPNext into a different data model.

The migration/onboarding process exists to establish OMC identity links around existing Customers.

It is **not** a recurring synchronization job that must be rerun every time a customer receives a new service, Task, document or payment.

Once identity is correctly linked:

```text
ERP Customer
     |
     +--> OMC Customer Account/Profile
     |
     +--> future Service Requests
     +--> future ERP Tasks
     +--> future documents
     +--> future accounting records
```

Future operational records continue to reference the same canonical ERP Customer.

### Important limitation

A completely new ERP Customer created only inside ERPNext does not automatically become an app login merely because periodic reconciliation runs.

New ERP-only Customers require a deliberate supported onboarding/import/linking path before they can use protected customer app features.

This prevents ambiguous identity guessing.

---

## 5. New customer signup

Public self-registration is customer-only.

Internal employee, consultant, manager, reviewer or administrator authority must never be granted through public customer signup.

The signup process must:

* validate customer identity;
* use controlled pending-registration state;
* prove ownership of the accepted login identity;
* avoid shared/default passwords;
* detect identity collisions;
* link or create the proper ERP Customer where allowed;
* create the OMC identity relationship;
* activate protected customer access only after required verification.

Ambiguous identity matches must fail safely rather than silently merging records.

---

## 6. Internal staff authority

Internal OMC authority is not derived simply from being a Frappe `System Manager`.

The model is:

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
        +--> optional break-glass grants
```

`System Manager` remains an infrastructure/administration role.

OMC business actions require OMC business authority.

Supported internal personas and operational roles may include consultants, tax associates, business partners, employees, managers, support staff, document reviewers and finance reviewers according to configured policy.

Flutter navigation is only a UI projection of authority.

The backend remains authoritative.

---

## 7. Service catalogue

The service catalogue is controlled by the OMC application and ERP integration contract.

Current production catalogue design uses stable service identities and service-specific configuration.

A service can define:

* service identity;
* category;
* display information;
* pricing;
* tax/accounting mapping;
* Task Type mapping;
* required documents;
* service form fields;
* activation/payment policy;
* availability.

ERP Task Type matching must be explicit and deterministic.

OMC must not fuzzy-create or silently guess Task Types.

Catalogue changes must preserve historical Service Request snapshots.

---

## 8. Service Request creation

A customer or authorised internal staff member can create a Service Request.

Customer-created and assisted/internal-created requests must ultimately follow the same authoritative lifecycle.

At creation time, the backend should snapshot the information that must not change underneath an existing request, including applicable:

* service identity;
* customer;
* pricing;
* discount;
* taxes;
* accounting mapping;
* document requirements;
* activation policy;
* referral context;
* assignment context;
* idempotency information.

The client must not be able to override authoritative pricing, ownership or workflow state arbitrarily.

---

## 9. Assisted/internal service requests

Internal employees may create or assist with a service on behalf of a customer.

Assisted service creation must still use the canonical ERP Customer.

It must not create a hidden parallel customer identity.

Assisted requests must preserve:

* ownership;
* customer visibility where appropriate;
* payment-first rules;
* document requirements;
* accounting authority;
* audit provenance;
* one-request/one-Task execution.

An internal employee creating a request does not bypass financial or document rules unless an explicit supported policy allows it.

---

## 10. Document requirement identity

Required-document matching uses a stable document key.

The authoritative matching concept is:

```text
customer
+ service
+ document_key
+ policy
+ approval/validity state
```

When a stable key exists, it must be preferred over display labels.

Display title or document type alone must not override an explicit key mismatch.

Legacy unkeyed historical records may use controlled compatibility matching where necessary.

---

## 11. Document upload

A Service Request can receive required documents through the protected upload workflow.

The backend must validate:

* authenticated user;
* request ownership or authorised staff scope;
* service/request relationship;
* required-document identity;
* file restrictions;
* upload security checks;
* replacement rules;
* document status.

Uploaded files must remain private unless an explicit business requirement says otherwise.

A customer must never gain access to another customer's private file merely because the document title is the same.

---

## 12. Reusable customer documents

Returning customers should not be forced to upload the same qualifying document again for the same service when reuse is permitted.

A document is reusable only when the reuse contract permits it.

Typical requirements include:

* same canonical customer;
* same service;
* same stable document key;
* approved/accepted document state;
* allowed reuse policy;
* valid expiry/reuse period;
* not replaced or invalidated;
* protected file accessibility.

A requirement configured as **Always New** must never be automatically reused.

Reusable documents establish document eligibility only.

They do not bypass payment or activation requirements.

### Replacement and expiry

A newly supplied replacement must supersede the reusable document according to backend policy.

Expired, rejected, revoked or otherwise invalid documents must not satisfy future requirements.

---

## 13. Document flow before payment

Documents and payment are separate lifecycle concerns.

The customer should not be forced into a simplistic assumption that every service always requires a brand-new upload before payment.

The correct flow is:

```text
Resolve required-document contract
        |
        +--> qualifying approved document already reusable
        |        -> requirement can be satisfied
        |
        +--> no reusable document
                 -> customer uploads required document
        |
        v
Document eligibility satisfied
        |
        v
Payment workflow can proceed
```

This supports returning customers while preserving service-specific document requirements.

---

## 14. Payment-first lifecycle

For a positive-price service, the production contract is payment-first.

Operational work must not start merely because the Service Request exists.

The intended path is:

```text
Service Request
     |
Documents eligible
     |
Payment opened
     |
ERP accounting evidence
     |
Settlement reconciled
     |
Activation eligible
     |
Exactly one ERP Task created
```

The client cannot manually set a Service Request as financially settled.

---

## 15. OMC payment workflow versus ERP accounting

Three concepts must remain separate:

1. customer payment/receipt interaction;
2. OMC payment review/workflow state;
3. authoritative ERP accounting settlement.

`OMC Service Payment` tracks OMC payment workflow.

It does **not** replace ERPNext accounting.

A reviewer accepting a receipt is not the same thing as ERP accounting proving settlement.

### Critical invariant

> **`OMC Service Payment` may become Paid/settled only through ERP accounting reconciliation.**

No API, reviewer action, Flutter action or manual OMC workflow should directly force a payment to final Paid status while ERP settlement evidence is absent.

---

## 16. Installments

The backend supports installment/additional payment workflows where applicable.

A request may therefore have remaining accounting outstanding after an initial payment.

Installment behavior must continue to derive from authoritative outstanding/settlement information.

Partial payment must not accidentally trigger full-settlement activation.

---

## 17. No Charge services

A legitimate service can be explicitly configured as `No Charge`.

Such a service does not require artificial payment evidence.

No Charge is an explicit service policy, not a manual shortcut for bypassing payment on a normally chargeable service.

Its activation still requires the other applicable eligibility rules.

---

## 18. ERP accounting reconciliation

ERP accounting is the settlement authority.

OMC reconciliation links customer/service payment workflow to real ERP accounting evidence.

The reconciliation layer must support conditions such as:

* unmatched;
* partial settlement;
* settled;
* reversed;
* review required;
* quarantined or ambiguous.

Only valid settled evidence can unlock a Full Settlement service for activation.

If the accounting evidence is reversed or becomes invalid, OMC must preserve the financial truth rather than pretending the earlier state remains settled.

---

## 19. Payment Entry and commission snapshot

OMC must not create a second commission engine.

Where the client's existing ERP Customer/payment configuration defines commission information, OMC snapshots the relevant commission configuration onto the new Payment Entry at the proper creation stage.

Submitted historical Payment Entries must not be mutated merely to retrofit new OMC snapshot fields.

The accounting record remains ERP-owned.

---

## 20. Commission projection

Commission entitlement is projected from authoritative submitted ERP accounting evidence.

The projection uses the existing OMC commission implementation, including `commission_projection.py`.

The intended flow is:

```text
Customer commission configuration
        |
        v
New ERP Payment Entry snapshot
        |
        v
Submitted ERP allocation evidence
        |
        v
OMC Commission Allocation
```

`OMC Commission Allocation` is an immutable/projection-style OMC record representing commission evidence and lifecycle.

OMC must not parse commission percentages from display names or structure labels.

Projection keys and idempotency must prevent duplicate allocations for the same authoritative evidence.

A referral owner does not automatically receive finance-review authority.

---

## 21. Durable activation bridge

Once all activation requirements are satisfied, operational creation occurs through the durable bridge.

`OMC Bridge Operation` exists to make activation safe and retryable.

It should provide:

* deterministic operation identity;
* final eligibility checks;
* accounting re-check before ERP writes;
* locking/idempotency;
* bounded retries;
* backoff;
* stale-processing recovery;
* rollback boundaries;
* explicit failure evidence;
* manual recovery where authorised;
* audit history.

The bridge must not create duplicate Tasks when retried.

---

## 22. Exactly one ERP Task

The target production contract is:

> **Every activated OMC Service Request has exactly one authoritative ERP Task.**

The Task represents the internal execution of that requested service.

The request should retain or expose the authoritative Task link needed by internal operations.

A retry of activation must reuse/detect the existing Task rather than creating another operational Task.

The service should not require a collection of mandatory and optional Tasks to determine completion.

---

## 23. Task visibility

ERP Tasks are internal operational records.

Customers should see their service/request progress through customer-safe Service Request projections.

Customers must not receive direct access to internal ERP Task details.

Authorised internal staff may receive read-only or operational Task visibility according to their capability and record scope.

The backend, not Flutter route visibility alone, must enforce this boundary.

---

## 24. Task completion and Service Request completion

The authoritative Task drives internal service execution.

When the single authoritative Task is completed, OMC can move the related Service Request toward completion after verifying all applicable request rules.

Completion must not be inferred from an unrelated Task.

The completion process should maintain:

* request status;
* service timeline/history;
* internal assignment state;
* customer-safe progress;
* notifications;
* audit evidence.

---

## 25. Assignment

Assignment must be resolved server-side.

Depending on configured business policy, assignment context may use:

* eligible consultants/associates;
* explicit staff assignment;
* referral/business relationship;
* service team/policy;
* workload/automation policy.

A customer cannot choose arbitrary internal Task ownership through an untrusted client payload.

Assignment retries must remain idempotent.

---

## 26. Internal review queues and automation

OMC contains operational automation for document review, payment review, workflow routing, ERP sync recovery and related internal work.

Automation must:

* remain capability-gated;
* avoid broad permission escalation;
* use explicit status transitions;
* preserve audit history;
* retry safely;
* avoid duplicate work;
* fail closed where authority or identity is ambiguous.

Automation should reduce manual operational effort without becoming a second business authority.

---

## 27. Support and notifications

Customers can interact with OMC support functionality where enabled.

Notifications can connect service, document, payment, support and operational events to the Flutter application.

Notification state is an OMC application concern.

Notifications must not expose internal-only ERP information to customers.

Channel/category preferences should be respected where supported.

---

## 28. Security model

Security is layered.

Relevant controls include:

* authenticated sessions;
* customer ownership resolution;
* Staff Access;
* explicit capabilities;
* record scope;
* break-glass grants;
* CSRF/CORS protections;
* rate limiting;
* upload validation;
* idempotency;
* audit records;
* controlled sensitive POST mutations;
* pagination and bounded reads.

A UI button being hidden is never sufficient authorization.

Sensitive backend methods must enforce authority independently.

---

## 29. Break-glass access

Exceptional internal access can use `OMC Break Glass Grant`.

Break-glass access should be:

* explicit;
* capability-specific;
* time-bounded;
* record-scoped where possible;
* revocable;
* audited.

It must not permanently mutate the user's normal persona.

---

## 30. Setup, installation and migrations

OMC installation must remain additive to the client's existing ERPNext v14 system.

Setup may install:

* OMC DocTypes;
* roles/capability structures;
* OMC custom fields;
* workspace metadata;
* hooks;
* patches;
* ERP integration contract fields;
* lifecycle/configuration records.

ERPNext core source must not be modified.

Normal migrations must be restart-safe and must not silently invent business relationships.

Catalogue publication or destructive reconciliation must not occur merely because `bench migrate` ran unless explicitly designed and documented as a migration requirement.

---

## 31. Compatibility and legacy wrappers

Some compatibility APIs and fields exist because the application evolved over several versions.

Compatibility code may remain when required for a safe migration path.

However:

* compatibility must not widen permissions;
* compatibility must not create a second authority;
* obsolete behavior must not be documented as the preferred architecture;
* retirement should be deliberate and test-covered.

---

## 32. Known conformance gaps

The following items were identified during the September 2026 source audit.

They describe **current legacy residue or verification gaps**, not intended architecture.

### 32.1 Legacy multi-Task implementation

Parts of the backend still contain a one-to-many Task model, including logic around `OMC Service Task Link`, required/optional linked Tasks and multi-Task completion aggregation.

Some backend and Flutter tests also encode this older behavior.

This conflicts with the current client requirement:

> **One Service Request = one authoritative ERP Task.**

This legacy behavior must be retired through a compatibility-safe implementation change.

### 32.2 `Post-paid Approval` configuration surface

The source still contains a `Post-paid Approval` activation-policy surface.

For positive-price production services, the intended architecture is payment-first with ERP settlement before activation.

`No Charge` remains a legitimate separate policy.

The legacy post-paid surface should be reviewed and constrained/retired so it cannot bypass the production financial contract.

### 32.3 Two document-reuse materialization paths

Self-service and assisted/internal document reuse currently use different materialization approaches.

Both are ownership-scoped, but lineage and storage behavior should eventually be unified so one canonical reuse model exists.

### 32.4 New ERP-only Customer discovery

Periodic identity reconciliation does not automatically convert every newly created raw ERP Customer into an app-enabled customer identity.

A deliberate onboarding/import/linking strategy remains required.

### 32.5 Internal Task visibility scope

Internal Task APIs should be reviewed for least-privilege scope so authorised staff see the Tasks appropriate to their role/assignment rather than an unnecessarily broad Task universe.

### 32.6 Template reuse metadata consistency

The public catalogue exposes richer document-reuse metadata than some service-template serialization paths.

These contracts should eventually be normalized.

### 32.7 Internal document summary matching

Some internal workspace/document summary behavior should be checked to ensure stable `document_key` identity is consistently preferred over title/type matching.

### 32.8 Fresh financial end-to-end verification

A fresh controlled real accounting flow should still be executed after architecture cleanup to verify:

```text
New Payment Entry
-> commission snapshot
-> submitted ERP settlement evidence
-> reconciliation
-> commission allocation
-> activation
-> exactly one ERP Task
```

This is a verification requirement, not permission to bypass the accounting model.

---

## 33. Architectural invariants

Future OMC changes should preserve these invariants:

1. **ERPNext Customer remains the canonical business customer.**
2. **OMC identity records bridge the app to ERP Customer; they do not replace it.**
3. **ERPNext/Frappe core source is never modified for OMC business behavior.**
4. **One Service Request creates exactly one authoritative ERP Task.**
5. **Positive-price services activate only after authoritative ERP settlement.**
6. **A receipt review alone cannot make a payment finally settled.**
7. **No Charge is explicit policy, not a payment bypass.**
8. **Installments cannot bypass outstanding-balance rules.**
9. **Reusable documents require same customer, same service, stable key and valid reuse policy.**
10. **`Always New` documents are never automatically reused.**
11. **Customers do not receive internal ERP Task access.**
12. **System Manager is not automatically OMC business authority.**
13. **Commission projection reuses the existing commission engine and ERP evidence.**
14. **Submitted ERP accounting records are not mutated to retrofit OMC behavior.**
15. **Retries and integrations must be idempotent.**
16. **Ambiguous identity, accounting or authority situations fail safely.**
17. **Existing APIs may remain for compatibility, but compatibility cannot become a second source of truth.**

---

## 34. Documentation rule

This document describes the intended production architecture.

Old implementation plans, abandoned multi-Task design material, outdated setup instructions and stale workflow descriptions must not be used as architectural authority.

Where source code still contradicts this guide, the discrepancy should be treated as a conformance gap and resolved deliberately with focused regression testing.
