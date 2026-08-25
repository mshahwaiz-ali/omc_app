# OMC App — Frappe Backend Master Guide

Source cross-check: **25 August 2026**, branch `main`.

This is the **master documentation for the OMC Frappe backend**. It explains what exists under `backend_omc_app`, what the custom `omc_app` owns, how it integrates with ERPNext, the security/authority model, customer and staff identity, service catalogue, service-request lifecycle, documents, payments, accounting, ERP activation, referrals, commissions, migration, scheduled jobs, setup operations, deployment boundaries, and validation.

For Flutter-specific implementation, use [`../omc_app/README.md`](../omc_app/README.md). For the high-level repository overview, use [`../README.md`](../README.md).

> **Backend authority rule:** Flutter is a client. Frappe/OMC backend policy is authoritative for identity, access, ownership, capability, pricing, document requirements, payment eligibility, accounting settlement, workflow transitions, assignment, ERP activation, referral/commission authority, and protected mutations.

---

# 1. Backend scope

The backend is built around a custom Frappe app named `omc_app` running alongside ERPNext.

The current client runtime target is:

```text
Frappe / ERPNext: version 14
Python:           3.10 in the checked-in deployment toolkit
Node.js:          18.x in the checked-in deployment toolkit
Yarn:             1.22.x
Database:         MariaDB
Queues/cache:     Bench Redis
Process manager:  Supervisor
Web proxy:        Nginx
```

The Python package itself declares Python `>=3.10`.

OMC customisation belongs in the custom `omc_app`. **ERPNext source files must not be patched to implement OMC behaviour.**

---

# 2. Backend directory map

```text
backend_omc_app/
├── backend_readme.md              # this master backend guide
├── deploy/                        # production/runtime deployment toolkit
│   ├── README.md
│   ├── INSTALL.md
│   ├── SITE_SETUP.md
│   ├── OPERATIONS.md
│   ├── TROUBLESHOOTING.md
│   ├── install.sh
│   ├── site_setup.sh
│   ├── production.sh
│   ├── verify.sh
│   ├── config/
│   └── lib/
│
└── frappe-bench/
    ├── apps/
    │   ├── frappe/                # framework/vendor source
    │   ├── erpnext/               # ERPNext/vendor source
    │   └── omc_app/               # project-owned OMC Frappe app
    ├── sites/
    ├── config/
    ├── logs/
    └── env/
```

The project-owned Frappe app is primarily:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/
├── api/                           # guarded API and workflow modules
├── omc_app/doctype/               # OMC DocTypes
├── setup/                         # install/migrate/reconciliation/catalogue setup
├── patches/                       # controlled migrations/patches
├── fixtures/                      # project fixtures such as workspace metadata
├── public/                        # Desk/static assets
├── hooks.py                       # Frappe integration hooks
└── README.md                      # app-package engineering guide
```

---

# 3. Source-of-truth boundaries

OMC deliberately does not copy ERP records unnecessarily.

| Business area | Canonical authority |
| --- | --- |
| Lead | ERPNext `Lead` |
| ERP customer master | ERPNext `Customer` |
| Authenticated app-customer link | `OMC Customer Account` |
| Customer business/profile compatibility | `OMC Customer Profile` |
| Internal OMC access | `OMC Staff Access` |
| ERP employee | ERPNext `Employee` |
| Internal protected permissions | OMC capability engine |
| Temporary exceptional authority | `OMC Break Glass Grant` |
| Service catalogue | source-controlled manifest + `OMC Service` |
| ERP service type mapping | exact existing ERP `Task Type` |
| Customer service lifecycle | `OMC Service Request` |
| Service requirements | `OMC Service Required Document` / `OMC Service Form Field` |
| Submitted customer service documents | `OMC Service Document` |
| Customer payment/receipt workflow | `OMC Service Payment` |
| ERP-accounting relationship | `OMC Accounting Link` + ERP finance records |
| Durable ERP activation state | `OMC Bridge Operation` |
| ERP operational execution | ERP `Service` + ERP `Task` |
| Referral relationship | OMC referral/attribution records |
| Commission entitlement/history | `OMC Commission Allocation` + commission lifecycle |
| Support | OMC support ticket/message records |
| OMC security/audit evidence | dedicated OMC audit/reconciliation records |

---

# 4. Customer identity and access

## 4.1 Canonical model

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +------> ERP Customer
        |
        +------> OMC Customer Profile
                 business/profile + compatibility state
```

`OMC Customer Account` is the canonical authenticated application-access link.

Protected customer access is not granted merely because a Frappe User exists. The backend evaluates the canonical account state, customer linkage, approval/service-access state, and record ownership.

`OMC Customer Profile` remains useful for customer business/profile state, imported-customer compatibility, referral/customer relationships, and legacy data, but it does not independently override canonical account authority.

## 4.2 Public signup

Public self-registration is **customer-only**.

The current backend includes:

- username normalisation and availability checks;
- pending registration records;
- email verification token handling;
- signup policy/role normalisation;
- rate limiting and input limits;
- customer-only public account-type policy;
- referral-code validation where applicable.

Internal staff are not created through public customer signup.

## 4.3 Existing-customer activation

Imported ERP customers may exist before an application login exists.

Activation therefore separates:

```text
business customer exists
        !=
app login exists
```

The activation flow proves control of a supported customer identity before lazily creating/linking a Website User. It is intentionally separate from bulk customer migration.

## 4.4 Password/account security

Backend account-security modules cover protected password verification/change/reset and associated session/security handling. Secrets must never be logged or stored in business DocTypes as plaintext credentials.

---

# 5. Existing ERP customer migration

`omc_app.api.customer_migration` provides controlled migration/reconciliation for an existing ERP customer base without creating thousands of login users in advance.

Current deterministic identity priority is:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The NTN/tax-ID rule is intentionally a final deterministic fallback, not a replacement for established email/CNIC/phone identity.

Migration principles:

- read-only preflight before writes;
- no shared/default passwords;
- no bulk creation of Frappe customer Users;
- safe reuse of existing OMC profiles/accounts;
- no forced merge of ambiguous identities;
- identity conflicts go to review;
- repeat runs are designed to be idempotent;
- historical referral/acquisition evidence is preserved only when supportable;
- customer business migration and app-login activation remain separate.

The operator-facing workflow is documented in [`../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md).

---

# 6. Internal staff identity and capability authority

## 6.1 Canonical model

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +------> explicit capability rows
        +------> access status
        +------> reconciliation status
        +------> ERP persona snapshot/source
        +------> optional ERP Employee
        +------> legacy Staff Profile compatibility
```

`OMC Staff Access` is the canonical internal authority record.

Normal `System Manager` membership is **not** implicit OMC business authority.

## 6.2 ERP personas

The backend recognises ERP-owned persona values including:

```text
Consultant
Tax Associates
Business Partner
Employee
```

These are persona values, not duplicate OMC Frappe Role records.

Legacy role names such as `OMC Consultant`, `OMC Tax Associate`, `OMC Business Partner`, and `OMC Employee` are compatibility/retirement concerns and must not become a new authority source.

## 6.3 Reconciliation

Staff synchronisation can derive trusted persona evidence from ERP user/employee relationships and reconcile an `OMC Staff Access` record.

Security-sensitive behaviour includes:

- disabled or unsupported users fail eligibility;
- suspended/rejected access survives automated reruns;
- deliberately reviewed persona conflicts fail closed;
- explicit capability rows are reconciled deterministically;
- ERP roles/Role Profiles are not rewritten merely to express OMC capability.

## 6.4 Capability categories

Internal capability domains include areas such as:

- internal workspace;
- customer/lead operations;
- relevant/assigned/all service-case access;
- task visibility/management;
- assisted service creation;
- document queue/review;
- payment queue/review;
- accounting settlement reconciliation;
- support ticket operations;
- internal notes;
- settings/business settings;
- staff administration;
- registration/reconciliation review;
- service-case reassignment;
- bridge retry/recovery;
- referral ownership;
- personal commission visibility;
- finance commission approval/payment operations.

Capability checks still combine with record scope. A capability to view relevant customers is not a global all-customer bypass.

## 6.5 Break-glass

Exceptional temporary access uses `OMC Break Glass Grant`.

Break-glass authority is:

- explicit;
- capability-specific;
- time limited;
- optionally DocType/record scoped;
- auditable;
- not a permanent role escalation.

---

# 7. Frappe roles, DocPerm and API authority

The app still manages selected Frappe Role/DocPerm rows for Desk usability, but protected OMC APIs do not treat DocPerm alone as sufficient business authority.

The role setup intentionally separates:

- OMC-owned operational roles;
- ERP personas;
- read-only evidence/security DocTypes;
- mutable operational/configuration DocTypes;
- internal-only DocTypes;
- retired/legacy role assignments.

Permission-query conditions and record-level `has_permission` handlers exist for important customer/operational DocTypes including service requests, customer profiles, referrals, service documents, service payments, and support tickets.

---

# 8. Service catalogue

The production service catalogue is source controlled under:

```text
frappe-bench/apps/omc_app/omc_app/setup/service_catalogue/
```

Current managed baseline:

```text
Categories:               9
Services:                31
Active services:         17
Inactive/review services:14
Currency:                PKR
Company:                 Omc House
Default activation:      Full Settlement
```

The current 31 canonical service identities are based on the client's exact ERP Task Types. Display titles may be improved without changing the stable service identity.

Current service set includes:

1. 7E Exemption Certificate
2. Commissioner Hearing & Advocacy
3. AOP Tax Return Filing
4. AOP / Partnership Firm Registration
5. Business Tax Return Filing
6. Family Contribution Tax Filing
7. FBR POS Challan
8. Financial Statements / Financials
9. GST Registration
10. Housewife Tax Filing
11. Monthly GST Filing
12. Monthly Services
13. Monthly SRB Filing
14. Non-Resident Pakistani Tax Return Filing
15. NTN Modification
16. NTN Registration
17. Other Services
18. Other Sources
19. Pakistan Single Window (PSW) Registration
20. FBR / IRIS Password Reset Assistance
21. Pensioner Filing
22. POS Integration
23. Private Limited Company Registration
24. Quarterly WHT Filing
25. KCCI Registration
26. Income Tax Return Filing — Salaried Individuals
27. SECP Compliance
28. SRB / PRA / BRA / KEPRA Registration
29. Stock Audit
30. TAX Club
31. UBL Lead

Services remain inactive where pricing/scope/requirements/turnaround are not sufficiently verified. A zero placeholder does **not** automatically mean a service is free.

## 8.1 Exact ERP Task Type mapping

The provisioner uses exact identity. It does not fuzzy-match titles and it does not create ERP Task Types.

Examples where exact ERP spelling matters include values such as:

```text
NTN  MODIFICATION
other sources
POS intergation
```

Stable OMC service IDs allow cleaner customer-facing titles while retaining exact ERP mapping.

## 8.2 Catalogue operations

```bash
cd frappe-bench

bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

`preview` and `validate` are read-only.

`sync` is explicit mutation. Normal `bench migrate` is **not** the service-catalogue publisher.

## 8.3 Provisioner safety

The provisioner is designed to:

- validate the target company and ERP contract;
- fail closed on missing/ambiguous Task Type mapping;
- preview changes before mutation;
- use one transaction/savepoint boundary;
- validate after reconciliation;
- rollback on failure;
- preserve non-owned service configuration;
- protect in-flight requests;
- protect historical pricing;
- deactivate stale managed definitions rather than hard-delete business history;
- remain idempotent when the site matches source control.

---

# 9. Service requirements and form fields

`OMC Service Required Document` defines service-document requirements.

`OMC Service Form Field` defines additional service-specific customer input requirements.

Catalogue-managed form fields are marked so the provisioner can distinguish managed data from unrelated/manual configuration.

Requirement changes are guarded so an in-flight customer request is not silently given a materially different required-document contract.

---

# 10. Stable document identity

`OMC Service Required Document` and `OMC Service Document` support stable `document_key` identity.

The logical identity is service-scoped:

```text
(service, document_key)
```

Matching rules:

1. if both requirement and upload have a non-empty key, the key is authoritative;
2. a wrong key never falls back to matching title/type;
3. if either side is genuinely legacy/unkeyed, exact normalized title + document type compatibility may be used;
4. one upload satisfies at most one requirement;
5. backend canonicalises key/title/type for a keyed template upload.

This prevents UI labels from becoming an accidental security/workflow identity.

## 10.1 Grandfathering

Requirements may carry `effective_from`.

A newly introduced managed requirement therefore applies only to requests at/after its effective boundary. Older in-flight requests keep their historical contract.

Repeated no-op catalogue syncs must not shift that boundary.

---

# 11. Service request lifecycle

`OMC Service Request` is the customer-facing workflow authority.

Representative canonical request states include:

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

The displayed operational status is a compatibility/customer-facing projection over the canonical request lifecycle.

The lifecycle module owns legal transitions, locking and state-change authority instead of allowing arbitrary clients to mutate state directly.

---

# 12. Service request creation and assisted service

Service creation converges on backend policy whether the request originates from the customer app or an authorised staff flow.

Supported concepts include:

- self-service creation;
- customer ownership validation;
- assisted creation for authorised staff;
- referral-owner assisted cases where valid;
- existing-customer selection under capability/scope rules;
- walk-in/manual customer handling;
- duplicate/parallel-request policy;
- service-specific form validation;
- server-side pricing snapshot generation;
- discount workflow where authorised.

Clients must never be trusted to submit authoritative internal pricing/discount/assignment state.

---

# 13. Pricing and versioning

The service-request record receives an authoritative pricing snapshot from the backend.

Important rules include:

- request pricing is derived from trusted service configuration;
- historical request pricing is not silently rewritten when a catalogue price changes;
- catalogue provisioning does not downgrade `service_version`;
- pricing versioning remains controller-generated/owned;
- government fee is not invented when unknown;
- existing tax policy/rate is preserved according to the service/controller rules;
- inactive/unknown-price services are not presented as falsely free.

Price-change safety checks protect active/historical requests before catalogue reconciliation modifies a service price.

---

# 14. Documents workflow

The backend supports:

- customer-owned document listing/detail;
- service-specific required-document presentation;
- multipart/service-document upload;
- canonical requirement identity resolution;
- duplicate submission checks;
- attachment/file validation;
- request ownership validation;
- review status updates through guarded internal APIs;
- rejected-document replacement;
- completion/payment eligibility checks using shared requirement logic.

Generic legacy/non-template uploads remain supported only where intentionally compatible; they must not accidentally satisfy a keyed requirement.

---

# 15. Payment and receipt workflow

`OMC Service Payment` is OMC's customer-facing payment/receipt workflow record.

It can represent the customer-visible payment state, payment instructions, submitted receipt/proof, reviewer decision, and links needed by the application workflow.

It is **not** a replacement for ERP accounting authority.

Payment-related API layers are split between:

- read guards;
- upload/mutation guards;
- payment-opening policy;
- receipt review;
- accounting settlement/reconciliation.

---

# 16. ERP accounting and settlement

ERPNext finance remains authoritative for accounting.

`OMC Accounting Link` connects the OMC request/payment lifecycle to ERP accounting evidence such as Sales Invoice/Payment Entry relationships.

Accounting reconciliation handles events such as:

- Sales Invoice submit/cancel;
- Payment Entry submit/cancel;
- settlement re-evaluation;
- financial holds where settled state is invalidated;
- safe restoration/reconciliation when accounting becomes valid again.

The hooks on ERP finance documents allow OMC lifecycle state to track authoritative ERP settlement without modifying ERPNext source.

For `Full Settlement`, durable ERP service activation requires settled accounting evidence.

---

# 17. Durable ERP activation bridge

ERP operational activation is managed by `OMC Bridge Operation` and `bridge_outbox` rather than a fragile single HTTP request.

The normal paid path is:

```text
OMC Service Request
        |
        v
Required documents complete
        |
        v
Payment/accounting settlement valid
        |
        v
Ready for Activation
        |
        v
OMC Bridge Operation
        |
        +------> ERP Service
        +------> ERP Task
        |
        v
Assignment / operational execution
```

Bridge safety includes:

- deterministic operation key;
- request row locking;
- final eligibility check;
- settlement re-check immediately before ERP writes;
- savepoint rollback around operational writes;
- bounded retries/backoff;
- stale-processing lease recovery;
- Pending/Retry/Processing/Completed/Failed-style operation state;
- capability-gated manual recovery;
- audit events;
- committed ERP Service and Task links required before request activation completes.

The bridge is designed for exactly-once business effect even when execution itself may be retried.

---

# 18. ERP Task and assignment integration

OMC maps an `OMC Service` to an exact ERP Task Type and creates/links ERP operational records only through the guarded activation flow.

Assignment logic can consider:

- explicit eligible assignee;
- referral-owner relationship;
- service configuration;
- role/persona eligibility;
- least-loaded eligible staff;
- manager/operational fallback;
- unassigned recovery.

The provisioner intentionally does **not** own default assignee/default assignment role configuration, so catalogue publishing does not unexpectedly rewrite operations staffing.

ERP Task status changes can be projected back into the OMC request workflow through the task-status sync hook.

---

# 19. Completion authority

A request cannot be considered complete merely because a UI says so.

Completion blockers can include unresolved document requirements, payment/accounting state, operational prerequisites and other lifecycle constraints.

Required-document completion uses the same stable-key matching authority as payment/document flows. A wrong keyed upload with a matching label does not clear a completion blocker.

---

# 20. Referrals

Referral behaviour is separated into distinct concepts:

```text
Referral owner
        |
        v
Referral relationship / code
        |
        v
Attribution evidence
        |
        v
Customer/service history
```

The backend includes:

- referral-code creation/synchronisation;
- referral-code validation;
- customer/referral analytics;
- assisted-service referral scope;
- historical attribution migration where evidence exists;
- source/provenance preservation.

`can_own_referrals` is the explicit current referral-owner capability.

---

# 21. Commissions

Commission authority is deliberately separate from referral ownership.

```text
Referral / attribution evidence
        |
        v
OMC Commission Allocation
        |
        +------> beneficiary personal view
        |
        +------> finance approval/payment lifecycle
```

Important separation:

- owning referrals does not grant finance authority;
- `can_view_own_commissions` is self-scoped;
- finance review/approval/payment uses separate capabilities;
- historical commission migration must preserve evidence/provenance;
- legacy overloaded referral-commission capability is compatibility-only and must not grant new finance authority.

ERP Payment Entry hooks suppress/avoid legacy commission-writing paths that conflict with the current allocation model.

---

# 22. Support, notifications and content

The backend also provides OMC-owned customer communication and content domains including:

- support tickets;
- support ticket messages/replies;
- support read/unread state;
- support assignment/status guards;
- customer/internal notifications;
- notification read/unread/dismiss/restore state;
- push-token registration;
- announcements;
- app banners;
- onboarding slides;
- FAQ/knowledge content;
- support/contact configuration;
- mobile settings/quick actions;
- branding configuration.

Read and mutation paths are intentionally separated where stronger guard logic is required.

---

# 23. Customer profile and settings

Profile operations include guarded self-service access such as:

- read current profile;
- update allowed customer fields;
- contact/work-address updates;
- profile-image upload;
- notification/settings preferences;
- audit logging for protected profile changes.

Customer self-service may only update fields explicitly allowed by backend policy.

---

# 24. Tax calculator

The Frappe backend owns the configurable tax-calculator domain, including settings/configuration, inputs, tax-year/slab data, adjustment rules, result insights and calculation history/logging.

Guarded tax-calculator operations include:

- configuration retrieval;
- tax calculation;
- calculation history;
- estimate PDF generation;
- share-with-consultant workflow;
- start-service-from-calculation workflow.

Tax configuration is backend data, not a Flutter hardcoded authority.

---

# 25. Expense tools

The backend supports OMC expense/budget features including:

- expense categories;
- expense entries;
- expense budgets;
- receipt upload;
- summary/read APIs;
- create/update/delete operations;
- bulk synchronisation.

Customer expense data remains ownership-scoped and write operations use dedicated guards.

---

# 26. Internal workspace and administrative operations

Internal workspace APIs provide capability-scoped access to operational summaries and records such as:

- customers;
- leads;
- tasks;
- service cases;
- documents;
- payments;
- support;
- referrals;
- commissions;
- administration/settings where allowed.

Administrative mutations such as reassignment, discount review, staff operations, business-setting changes and bridge recovery are protected independently rather than inferred from Flutter route access.

---

# 27. Security and audit infrastructure

The backend includes security/audit infrastructure around the business APIs.

Key concerns include:

- explicit authentication requirements;
- capability enforcement;
- ownership/scope enforcement;
- rate limiting;
- CSRF/CORS policy;
- safe file validation;
- idempotency keys/records;
- sensitive POST-only mutations;
- safe error messages;
- audit events;
- reconciliation evidence;
- technical quarantine/review where data cannot be safely reconciled;
- fail-closed behaviour when security/reference checks fail.

Selected audit/evidence models are intentionally read-only through normal staff DocPerm and are mutated only by guarded backend code.

---

# 28. Important OMC DocType families

The current custom app contains DocTypes across these major families.

## Identity and security

Examples include:

```text
OMC Customer Account
OMC Customer Profile
OMC Customer Activation
OMC Pending Registration
OMC Staff Access
OMC Staff Profile                 # compatibility/profile layer
OMC Break Glass Grant
OMC Guest Session
OMC Password Reset
OMC Idempotency Record
OMC Push Token
OMC Profile Change Log
OMC Security Audit Event
OMC Reconciliation Run
OMC Reconciliation Review
OMC Reconciliation Checkpoint
OMC Technical Quarantine
```

## Service catalogue and workflow

```text
OMC Service Category
OMC Service
OMC Service Required Document
OMC Service Form Field
OMC Service Stage Template
OMC Service Request
OMC Service Document
OMC Service Timeline
OMC Service Payment
OMC Payment Account
OMC Accounting Link
OMC Bridge Operation
```

## Referral and commission

```text
OMC Referral
OMC Referral Attribution
OMC Commission Allocation
```

## Support/content/mobile configuration

```text
OMC Support Ticket
OMC Support Ticket Message
OMC Notification
OMC Announcement
OMC App Banner
OMC Onboarding Slide
OMC FAQ
OMC Knowledge Article
OMC Mobile Settings
OMC Mobile Quick Action
OMC Branding Settings
```

## Customer utilities

```text
OMC Customer Preference
OMC Expense Category
OMC Expense Entry
OMC Expense Budget
OMC Tax Calculator Settings
OMC Tax Input Field
OMC Tax Result Insight
OMC Tax Slab
OMC Tax Year
OMC Tax Adjustment Rule
OMC Tax Alert
OMC Tax Calculation Log
```

## Compatibility/operational support

`OMC Manual Customer` supports authorised walk-in/manual-customer workflows. `OMC Lead` is retired legacy state; the canonical lead is ERPNext `Lead`.

The actual DocType tree in `apps/omc_app/omc_app/omc_app/doctype/` is always the final source of truth if a future release adds/removes models.

---

# 29. API architecture

The backend deliberately contains compatibility endpoints while routing protected behaviour through newer guard/policy modules.

Major API domains include:

```text
access / access_v2 / capabilities / identity
auth_login / pending_registration / signup_policy
customer_activation / customer_migration
account_security / password_reset / profile_self_service
service_requests / service_templates / public_catalogue
service_case_contract / service_request_lifecycle
service_request_mutations / assisted_service / assisted_service_policy
service_assignment / workflow_automation
document_upload / service_document_read / service_document_guard
payment_read_guard / payment_mutation_guard / payment_opening
accounting_policy / accounting_reconciliation
bridge_outbox
internal_workspace / internal_workspace_summary
admin_control / admin_read
lead_read_guard / task_read_guard
support_chat / support_ticket_* guards
referral_analytics / referral_commissions
commission_lifecycle / commission_operations / commission_projection
tax_calculator / tax_calculator_guard / tax_calculator_mutations
expense / expense_read_guard / expense_write_guard / expense_guard
mobile / secured_mobile / mobile_state_mutations
dashboard / dashboard_read_guard
security / idempotency / scheduler_jobs
```

Legacy method names may remain callable for client compatibility, but `hooks.py` overrides many methods to newer guarded implementations. New development should follow the canonical target module, not assume an old wrapper contains final authority.

---

# 30. Frappe hooks and integration points

`hooks.py` currently wires the OMC app into Frappe through several mechanisms.

## Installation/migration

```text
before_install -> omc_app.setup.lifecycle.before_install
after_install  -> omc_app.setup.lifecycle.after_install
after_migrate  -> omc_app.setup.lifecycle.after_migrate
```

## Request hook

OMC adds controlled CORS headers after requests through its CORS module.

## Whitelisted-method overrides

Many public/legacy endpoints are redirected to policy/guard implementations for:

- signup;
- Google login;
- capabilities/session;
- branding/config;
- catalogue;
- profile/contact mutations;
- service creation/read/status/cancel;
- document read/review;
- support read/state/mutations;
- task/lead reads;
- dashboard/internal summary;
- assisted service;
- tax/expense guards;
- payments;
- notification/settings mutations;
- accounting linking.

## ERP document events

Current ERP hooks include:

```text
User
  -> referral-code synchronisation

Task.on_update
  -> OMC task-status synchronisation

Payment Entry.before_submit
  -> suppress legacy commission writer

Payment Entry.on_submit/on_cancel
  -> accounting reconciliation

Sales Invoice.on_submit/on_cancel
  -> accounting reconciliation
```

This is how OMC reacts to ERP state without editing ERPNext source.

---

# 31. Scheduled/background jobs

Current scheduler hooks include:

## Hourly

```text
omc_app.api.scheduler_jobs.run_hourly_jobs
omc_app.api.bridge_outbox.process_pending
omc_app.api.bridge_outbox.expire_pending_requests
```

These cover recurring OMC automation plus bridge retry/processing and pending-request expiry.

## Daily

```text
omc_app.api.scheduler_jobs.run_daily_jobs
omc_app.api.idempotency.cleanup_expired_records
```

The scheduler must therefore be enabled and workers/queue processes healthy in production.

---

# 32. Setup lifecycle and explicit operations

The normal setup lifecycle is intentionally conservative:

```text
before_install
    -> validate ERP/client contract

after_install
    -> explicit one-time OMC initialization

after_migrate
    -> validation only
```

Normal migration must not silently republish catalogue content, mutate client ERP personas, or perform unrelated destructive reconciliation.

The setup package includes areas such as:

```text
erp_contract.py
lifecycle.py
operations.py
roles.py
staff_sync.py
desk_metadata.py
referral_workspace.py
service_catalogue/
```

Explicit operations include functions for:

- site initialization;
- permission repair;
- Desk/workspace sync;
- branding;
- tax defaults/configuration;
- service/Task-Type mapping support;
- catalogue preview/validation/sync.

Use explicit mutation operations only when the deployment/reconciliation plan requires them.

---

# 33. Legacy service retirement

Historical catalogue work identified duplicate physical OMC Service aliases for canonical services.

The retirement module safely handles known legacy aliases such as:

```text
advocacy-service---hearing-with-commissioner
    -> advocacy-service-hearing-with-commissioner

ntn--modification
    -> ntn-modification
```

Retirement logic is designed to:

- inspect historical references;
- repoint only when necessary/safe;
- clear legacy Task Type mappings only when appropriate;
- keep legacy aliases inactive;
- fail closed if reference scanning itself fails;
- correctly inspect Single DocTypes through single-value reads rather than normal table counts.

Use the read-only preview before any retirement mutation.

---

# 34. Data-protection and compatibility principles

The backend preserves several important compatibility guarantees:

- old customer/profile data is not discarded merely because canonical Customer Account exists;
- legacy unkeyed service documents can remain readable/completable through controlled fallback;
- legacy API method names may route to guarded canonical implementations;
- ERP role/persona data is not rewritten unnecessarily;
- historical pricing/document contracts are protected;
- ambiguous identity/financial/history data is reviewed rather than guessed;
- evidence/security records are not casually editable through Desk.

Compatibility is not permission broadening. Where old data conflicts with new security identity, new authority fails closed.

---

# 35. Production catalogue state and validation evidence

The production catalogue was explicitly reconciled and then repeatedly validated as idempotent.

Latest directly observed catalogue validation before this documentation refresh:

```text
categories:          9 unchanged
services:           31 unchanged
required documents: 93 unchanged
form fields:         62 unchanged
--------------------------------
total managed:      195 unchanged
created:              0
updated:              0
deactivated:          0
conflicts:            0
blockers:             0
key backfill pending: 0
```

Latest directly observed full backend regression suite:

```text
Ran 932 tests in 120.732s
OK
```

This is evidence for that exact tested commit/site state, not a permanent guarantee for future changes.

---

# 36. Backend validation commands

From the Bench:

```bash
cd backend_omc_app/frappe-bench
```

## Installed apps

```bash
bench --site <site> list-apps
```

## Full OMC backend regression suite

```bash
bench --site <site> run-tests \
  --app omc_app \
  --skip-test-records
```

## Catalogue validation

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

## Read-only catalogue preview

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue
```

## Legacy-service retirement preview

```bash
bench --site <site> execute \
  omc_app.setup.service_catalogue.legacy_retirement.preview_legacy_service_retirement
```

Do not infer success from shell exit status alone when a test runner can print a failure summary. Inspect the actual textual test footer.

---

# 37. Installation/update boundary

For a client site, application-code deployment and OMC business-data reconciliation are separate operations.

Basic code/schema update:

```text
place/update omc_app source
        |
        v
install Python package / ensure apps.txt
        |
        v
install-app (first installation only)
        |
        v
bench migrate
        |
        v
clear cache / build as required
```

Then explicitly run only the OMC data/catalogue operations required by the approved deployment plan.

`bench migrate` updates Frappe schema/metadata and executes registered patches. It does **not** mean “bulk migrate all historical customers” and it does **not** mean “publish the production service catalogue”.

---

# 38. Deployment toolkit boundary

`backend_omc_app/deploy/` is an operational toolkit around the Bench.

The checked-in installer currently targets **Frappe v14 / Python 3.10 / Node 18** and validates that runtime.

Important scripts:

```text
install.sh       -> machine/runtime/Bench prerequisites
site_setup.sh    -> explicit site/create/install/migrate/production actions
production.sh    -> runtime Supervisor/Nginx refresh only
verify.sh        -> deployment verification
```

Production configuration and secrets remain local and Git-ignored.

Detailed operations:

- [`deploy/README.md`](deploy/README.md)
- [`deploy/INSTALL.md`](deploy/INSTALL.md)
- [`deploy/SITE_SETUP.md`](deploy/SITE_SETUP.md)
- [`deploy/OPERATIONS.md`](deploy/OPERATIONS.md)
- [`deploy/TROUBLESHOOTING.md`](deploy/TROUBLESHOOTING.md)

---

# 39. Security rules for backend contributors/operators

1. Do not modify ERPNext source to implement OMC business logic.
2. Do not trust Flutter route visibility as permission.
3. Do not use System Manager as an implicit OMC-authority shortcut.
4. Do not bypass `OMC Staff Access` capability/reconciliation rules.
5. Do not force-link ambiguous customers.
6. Do not bulk-create customer Users/passwords during profile migration.
7. Do not create/fuzzy-match ERP Task Types from the catalogue.
8. Do not bypass stable `document_key` authority for keyed requirements.
9. Do not treat receipt upload as ERP accounting settlement.
10. Do not activate ERP Service/Task before request eligibility is proven.
11. Do not rewrite historical pricing/document contracts unsafely.
12. Do not silently swallow reference-scan/security failures.
13. Do not commit runtime secrets, database dumps, private files or production credentials.
14. Keep mutation endpoints capability/ownership guarded and idempotent where repeated calls could duplicate effects.
15. Re-run relevant regression tests after backend changes.

---

# 40. Documentation map

Use these documents for different audiences:

- [`../README.md`](../README.md) — whole-repository architecture and developer entry point;
- **`backend_readme.md`** — this master Frappe/backend guide;
- [`frappe-bench/apps/omc_app/README.md`](frappe-bench/apps/omc_app/README.md) — custom Frappe app engineering guide;
- [`frappe-bench/apps/omc_app/omc_app/README.md`](frappe-bench/apps/omc_app/omc_app/README.md) — concise package-local pointer/notes;
- [`../docs/ROLE.md`](../docs/ROLE.md) — access/persona/capability model;
- [`../docs/OMC_APP_FEATURES.md`](../docs/OMC_APP_FEATURES.md) — current feature inventory;
- [`../docs/omc_detailed_explanation.md`](../docs/omc_detailed_explanation.md) — business/workflow explanation;
- [`../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md) — client operator deployment/migration runbook;
- [`../omc_app/docs/backend_api_contract.md`](../omc_app/docs/backend_api_contract.md) — Flutter-facing backend API contract.

---

# 41. Final backend model

In one diagram:

```text
                           ERPNext
            +----------------+----------------+
            |                |                |
          Lead            Customer         Finance
                             |                |
                             |                v
                             |        Sales Invoice / Payment Entry
                             |                |
                             v                v
Flutter <-> Guarded OMC APIs <-> OMC Customer Account
                             |        OMC Staff Access
                             |        Capability Engine
                             |
                             v
                    Source-Controlled Catalogue
                             |
                             v
                    OMC Service Request
                      |      |       |
                      |      |       +--> Documents / document_key
                      |      +----------> Payment + Accounting Link
                      |                  
                      +-----------------> Referral / Commission evidence
                             |
                             v
                    Ready for Activation
                             |
                             v
                    OMC Bridge Operation
                             |
                       +-----+-----+
                       |           |
                       v           v
                  ERP Service   ERP Task
                       |
                       v
              assignment / execution
```

The core architectural intent is consistent throughout the backend:

> **OMC owns the application workflow and security overlay; ERPNext continues to own ERP business and accounting records. Integration happens through explicit, guarded, auditable boundaries.**
