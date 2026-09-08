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
backend_omc_app/frappe-bench/apps/omc_app/
├── scripts/
│   └── configuration.sh           # guarded post-install production configurator
└── omc_app/
    ├── api/                       # guarded API and workflow modules
    ├── omc_app/doctype/           # OMC DocTypes
    ├── setup/                     # install/migrate/reconciliation/catalogue setup
    ├── patches/                   # controlled migrations/patches
    ├── fixtures/                  # project fixtures such as workspace metadata
    ├── public/                    # Desk/static assets
    ├── hooks.py                   # Frappe integration hooks
    └── README.md                  # app-package engineering guide
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
        +------> OMC Customer Profile
```

`OMC Customer Account` is the canonical authenticated customer-to-business mapping.

A customer profile remains relevant for customer business/profile information and compatibility, but protected customer access resolves through the canonical Customer Account layer.

Customer access is ownership-scoped and fail-closed.

## 4.2 New customer registration

Public registration is customer-only.

The backend manages:

- pending registration;
- email verification;
- username validation;
- customer Website User creation;
- customer profile/account creation;
- customer-role normalisation;
- activation/access state.

Public registration is not a staff self-enrolment path.

## 4.3 Existing ERP customer activation / claim

Existing ERP Customers can be represented in OMC without bulk-creating login Users.

Historical customer migration separates:

```text
ERP business customer
        !=
authenticated app login
```

A safe historical customer can receive/reuse OMC profile/account business state while login activation remains a separate secure process.

The current deterministic customer identity order is:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

Tax ID/NTN is deliberately the last deterministic fallback.

Runtime ERP customer resolution is more schema-tolerant: it detects which standard/legacy Customer and Lead identity fields still exist before reading them, so removal of old custom fields does not become an automatic ownership guess.

---

# 5. Internal staff authority

## 5.1 Canonical model

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +------> explicit capability rows
        +------> access status
        +------> reconciliation status
        +------> persona snapshot
        +------> optional break-glass grants
```

An ERP Employee or Frappe role by itself is not sufficient OMC authority.

Normal access requires a current, approved Staff Access decision.

## 5.2 Personas vs authority

ERP/persona labels such as Consultant, Tax Associates, Business Partner and Employee are evidence used by staff reconciliation.

The actual protected permission check uses OMC capabilities.

Important distinction:

```text
persona / Frappe role
    -> helps determine intended access

OMC Staff Access + capability
    -> actual OMC backend authority
```

`System Manager` is not a hidden universal OMC business-authority override.

## 5.3 Break-glass

`OMC Break Glass Grant` supports explicit emergency access that is:

- time-limited;
- capability-specific;
- optionally DocType/record scoped;
- audited;
- evaluated server-side.

---

# 6. Frappe hooks and enforcement

`hooks.py` integrates OMC with Frappe through:

- `required_apps = ['erpnext']`;
- install/migrate lifecycle hooks;
- API method overrides that route legacy/public aliases into guarded canonical implementations;
- permission query conditions;
- per-record `has_permission` hooks;
- User referral-code synchronization;
- ERP Task status synchronization;
- Sales Invoice / Payment Entry accounting reconciliation hooks;
- commission-writer suppression where OMC owns the new authority;
- hourly/daily scheduled jobs;
- Workspace fixture ownership;
- OMC Desk CSS.

The override map is intentionally important: old mobile method names can remain compatible while policy is enforced in newer guard/policy modules.

---

# 7. Permission model

Frappe DocPerm is not the only security boundary.

OMC combines:

1. Frappe authentication;
2. OMC canonical customer/staff identity;
3. capability checks;
4. scope/ownership checks;
5. permission query conditions;
6. per-record permission functions;
7. guarded mutation APIs;
8. audit/idempotency where required.

Protected OMC DocTypes with explicit query/record permission hooks include service requests, customer profiles, referrals, service documents, service payments and support tickets.

The Flutter UI can hide or show controls, but the API must still reject unauthorised access independently.

---

# 8. Main backend data domains

The OMC DocType tree includes multiple families.

## Identity / access

Examples:

- `OMC Customer Account`
- `OMC Customer Profile`
- `OMC Staff Access`
- staff capability child rows
- `OMC Break Glass Grant`
- registration / activation / identity-review support records

## Catalogue / service definition

Examples:

- `OMC Service Category`
- `OMC Service`
- `OMC Service Required Document`
- `OMC Service Form Field`

## Service execution

Examples:

- `OMC Service Request`
- timeline/event rows
- `OMC Service Document`
- assignment/review state
- `OMC Bridge Operation`

## Payment / accounting

Examples:

- `OMC Service Payment`
- `OMC Accounting Link`
- reconciliation/audit state

## Referral / commission

Examples:

- `OMC Referral`
- referral attribution records
- `OMC Commission Allocation`
- commission lifecycle/history records

## Support / communication

Examples:

- support tickets/messages
- notifications/read-state support
- push-token/settings state

## Content / branding / public configuration

Examples:

- `OMC Announcement`
- `OMC App Banner`
- branding settings
- knowledge/FAQ/onboarding configuration

## Tax / expenses

Examples:

- tax calculator settings/years/slabs/input fields/logs
- expense categories/entries/budgets

This list describes domain families rather than claiming every directory name is a public API contract.

---

# 9. Backend API architecture

The `omc_app/api/` package contains canonical workflow modules plus compatibility wrappers.

Major API/policy areas include:

## Authentication / account security

- login and multi-identifier login;
- pending registration;
- email verification;
- customer activation;
- password reset/change;
- session-user/profile projection;
- guest-session handling.

## Access / policy

- customer/staff authority resolution;
- capabilities;
- break-glass evaluation;
- profile/ownership guards;
- internal workspace scope.

## Service requests

- service request creation;
- assisted service creation;
- customer selection policy;
- service case read contract;
- status/cancellation mutations;
- assignment/reassignment;
- workflow automation;
- completion blockers.

## Documents

- required-document template reads;
- customer document reads;
- canonical upload handling;
- document review/status guards;
- archive/replacement behavior.

## Payments / accounting

- payment read guards;
- receipt upload/review mutations;
- payment opening/eligibility;
- accounting policy;
- invoice/payment-entry reconciliation;
- financial hold behavior.

## ERP bridge

- Service/Task adapter;
- ERP customer resolver;
- bridge outbox/retry;
- Task status synchronization;
- activation/completion authority.

## Referrals / commissions

- referral validation;
- referral analytics;
- referral attribution;
- commission allocation;
- personal commission reads;
- finance commission operations;
- historical referral/commission migration helpers.

## Internal operations

- admin control/read;
- internal workspace;
- lead/customer/task guarded reads;
- registration/staff review;
- settings/configuration operations.

## Customer utilities

- dashboard;
- profile self-service;
- support;
- notifications;
- knowledge/content;
- tax calculator;
- expenses.

Flutter method constants are documented separately in [`../omc_app/docs/backend_api_contract.md`](../omc_app/docs/backend_api_contract.md).

---

# 10. Production service catalogue

The source-controlled production catalogue lives at:

```text
frappe-bench/apps/omc_app/omc_app/setup/service_catalogue/
```

Current manifest baseline:

```text
Company:                  Omc House
Currency:                 PKR
Categories:               9
Services:                 31
Active services:          17
Inactive/review services: 14
Default activation:       Full Settlement
```

The catalogue is deliberately conservative: uncertain pricing/scope/requirements are not invented merely to activate a service.

## 10.1 Exact ERP Task Type authority

`OMC Service.erp_task_type` maps to an exact already-existing ERP `Task Type`.

The catalogue provisioner does not:

- create Task Types;
- fuzzy-match Task Types;
- silently pick between ambiguous Task Types.

Missing/ambiguous mappings are blockers.

## 10.2 Stable IDs

Service/category identity is separate from display labels.

Stable identifiers include:

```text
service_id
category_name
```

Changing a customer-facing title therefore does not require changing canonical service identity.

## 10.3 Operator operations

```bash
bench --site <site> execute \
  omc_app.setup.operations.preview_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue

bench --site <site> execute \
  omc_app.setup.operations.sync_service_catalogue
```

`preview` and `validate` are read-only.

`sync` is the explicit mutation operation.

Normal `bench migrate` does not publish the catalogue.

## 10.4 Provisioning transaction

Catalogue sync follows a guarded sequence:

```text
preflight preview
    -> blocker/conflict checks
    -> savepoint
    -> category reconciliation
    -> service reconciliation
    -> required-document reconciliation
    -> form-field reconciliation
    -> post-sync validation
    -> commit
```

Failures roll back the sync transaction boundary.

## 10.5 Idempotency

Once source and site match, repeat sync/validation should converge to no additional managed changes.

The latest directly observed production validation before this documentation refresh showed:

```text
9 categories unchanged
31 services unchanged
93 required-document definitions unchanged
62 form fields unchanged
195 managed objects unchanged
0 pending creates
0 pending updates
0 pending deactivations
0 conflicts
0 blockers
```

---

# 11. Required-document contract

Required-document templates use stable `document_key` identity.

Relevant records:

```text
OMC Service Required Document
OMC Service Document
```

Rules:

- when both rows carry a key, the key is authoritative;
- a wrong key never falls back to matching title/type;
- genuine legacy/unkeyed rows may use exact normalized title + type compatibility;
- one uploaded document can satisfy at most one requirement;
- upload identity is canonicalised server-side;
- Flutter-provided title/type is not trusted as catalogue authority.

## 11.1 `effective_from`

New managed required-document rows may carry `effective_from`.

This protects in-flight requests from retroactive catalogue changes.

Conceptually:

```text
request created before new requirement effective date
    -> new requirement not imposed retroactively

request created at/after effective date
    -> requirement applies normally
```

Repeat idempotent syncs do not shift the original effective boundary.

---

# 12. Service request lifecycle

The canonical request state machine is separate from simple customer-facing labels.

Representative states include:

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

Legacy/customer-facing `status` remains a compatibility/operational projection where required.

The backend is authoritative for allowed transitions.

---

# 13. Service request creation

Service creation routes converge toward shared backend authority rather than duplicating business logic in Flutter.

Supported concepts include:

- self-service request;
- referral-assisted request;
- authorised existing-customer assistance;
- authorised walk-in/manual customer flow.

The backend controls:

- acting user;
- target customer;
- consent/assistance scope;
- service availability;
- pricing snapshot;
- required fields/documents;
- duplicate/parallel-request policy;
- referral attribution;
- assignment inputs;
- request lifecycle.

A client payload cannot simply declare itself authorised for another customer's request.

---

# 14. Pricing authority

`OMC Service Request` stores authoritative pricing snapshot state derived from service configuration and guarded pricing policy.

The backend protects:

- original/base price;
- allowed discounts;
- discount approval state;
- tax policy/rate snapshot;
- pricing versioning;
- activation policy;
- request company snapshot.

Catalogue sync also checks historical/in-flight request exposure before changing managed service pricing.

Historic customer economics are not silently rewritten because a service master changes later.

---

# 15. Document upload and review

Service-document upload is backend-canonical.

For a keyed requirement, the server:

1. resolves the service request;
2. checks customer/internal authority;
3. loads applicable service requirements;
4. validates `document_key` if provided;
5. chooses canonical document title/type from the requirement;
6. checks duplicate/active upload state;
7. saves the file/document relationship;
8. returns canonical identity/status.

Arbitrary legacy/non-template uploads remain supported only where the existing contract intentionally allows them.

Payment eligibility and final completion use shared required-document matching semantics.

---

# 16. Payment workflow vs ERP accounting

`OMC Service Payment` is the OMC customer/payment workflow record.

It can represent:

- amount/currency;
- payment status;
- receipt/proof upload;
- receipt review;
- customer-facing payment state.

It is **not** the ERP accounting ledger.

ERP accounting authority remains in ERPNext records such as Sales Invoice and Payment Entry, connected to OMC through `OMC Accounting Link` and reconciliation policy.

---

# 17. Accounting reconciliation

OMC hooks observe relevant ERP accounting events.

Current hooks include Sales Invoice and Payment Entry submit/cancel integration.

Accounting reconciliation can:

- connect ERP accounting evidence to an OMC request/payment;
- update settlement state;
- open/close financial eligibility;
- create financial holds when required;
- feed the durable activation decision.

For `Full Settlement`, OMC does not activate ERP operational execution merely because a receipt screenshot exists.

---

# 18. Durable ERP activation bridge

`OMC Bridge Operation` provides durable, exactly-once-oriented ERP activation state.

The bridge protects against duplicated/partial ERP writes using concepts such as:

- deterministic operation identity;
- request locking;
- final eligibility re-check;
- accounting settlement re-check immediately before ERP writes;
- processing lease/state;
- bounded retries/backoff;
- stale-processing recovery;
- transaction/savepoint rollback;
- explicit failure state;
- audit evidence.

Successful activation must result in committed links to:

```text
ERP Service
ERP Task
```

before the OMC request is considered fully Activated.

---

# 19. ERP Service / Task integration

OMC does not replace ERP operational execution.

Once activation is valid:

```text
OMC Service Request
        -> exact ERP Customer
        -> exact ERP Task Type
        -> ERP Service
        -> ERP Task
```

The ERP adapter controls creation/linking and the OMC request stores the resulting ERP references.

Task update hooks synchronize supported ERP Task status changes back into OMC workflow state without allowing Flutter to become Task authority.

---

# 20. Assignment

Assignment is backend-controlled.

Inputs can include:

- explicit authorised assignee;
- referral owner where eligible;
- service default configuration where retained;
- capability/persona eligible staff;
- workload/fallback logic.

OMC can create/update Frappe assignment/ToDo state and later synchronize it to the ERP Task when appropriate.

Catalogue provisioning intentionally does not own every assignment field, so catalogue sync cannot unexpectedly rewrite unrelated operational staff configuration.

---

# 21. Completion authority

Completion checks do more than inspect a visible status field.

Backend blockers can include:

- required documents incomplete/not approved where required;
- payment/accounting conditions unresolved;
- ERP activation/link state incomplete;
- other lifecycle restrictions.

Stable document keys are propagated into completion matching, so a wrong keyed upload cannot clear a completion blocker through title/type fallback.

---

# 22. Referrals

Referral ownership is a separate entitlement domain.

The backend manages concepts including:

- referral registry/code;
- owner eligibility;
- customer referral attribution;
- referral-assisted service consent/scope;
- referral analytics;
- historical attribution evidence.

Historical migration fills only relationships that can be proven under the implemented rules.

It does not overwrite conflicting application-origin referral/acquisition state.

---

# 23. Commissions

Commission authority is deliberately separated into layers.

```text
Referral relationship
        -> attribution/evidence
        -> commission allocation
        -> beneficiary/personal view
        -> finance approval/payment operations
```

`OMC Commission Allocation` is evidence/entitlement state.

Referral ownership does **not** automatically grant:

- global commission visibility;
- commission approval;
- commission payment authority.

Personal commission visibility and finance operations use different capabilities.

Legacy commission writer behavior is suppressed where the newer OMC commission authority owns the lifecycle.

---

# 24. Support, notifications and content

The backend contains guarded workflows for:

- support ticket creation/read/replies;
- internal support status/assignment;
- customer support read state;
- notifications;
- mark read/unread/all-read;
- dismiss/restore;
- push-token registration;
- customer settings;
- app banners;
- onboarding slides;
- knowledge/FAQ/public content;
- support configuration.

Customer reads remain ownership scoped, while internal support mutations require staff capability.

---

# 25. Profile and account self-service

Customer profile operations include guarded support for areas such as:

- profile read;
- profile field updates;
- contact/work-address updates;
- profile image;
- password/account security;
- account activation/claim state.

The backend decides which profile fields are writable by the authenticated customer.

Direct generic DocType write access is not the self-service contract.

---

# 26. Tax calculator

The tax calculator is backend configurable.

The backend owns:

- tax calculator settings;
- active tax years;
- slabs/rates;
- supported income types;
- filer status rules;
- optional advanced inputs;
- calculation history;
- PDF/share/service-start operations.

If required configuration is missing, the calculator fails safely/returns disabled configuration rather than inventing current tax law.

Optional tax seed operations are explicit and are not run automatically by normal `bench migrate` or by the production `configuration.sh`.

---

# 27. Expense/budget module

The backend provides guarded expense features including:

- expense configuration/categories;
- entries;
- create/update/delete;
- bulk sync;
- receipts;
- summaries;
- budgets.

Read and write guards separate customer ownership from internal access.

---

# 28. Internal workspace / admin operations

Internal APIs support capability-gated operational work such as:

- workspace summary;
- service-case queues;
- lead/customer/task visibility;
- customer-assisted service creation;
- registration review;
- staff invitation/access updates;
- service reassignment;
- bridge retry;
- discount review;
- payment/document/support review;
- business settings;
- referral/commission operations.

The existence of a Frappe route or Desk page does not replace the backend capability check.

---

# 29. Audit, idempotency and security evidence

Sensitive operations use OMC security/audit mechanisms where appropriate.

Backend hardening areas include:

- authentication/session validation;
- CSRF/CORS policy;
- rate limiting/throttling;
- ownership filters;
- capability checks;
- POST-only mutation contracts where required;
- idempotency keys/records;
- pagination;
- file restrictions;
- audit events;
- break-glass evidence;
- reconciliation state;
- deterministic bridge operations.

Unknown or ambiguous authority should fail closed.

---

# 30. Existing customer/staff migration

The unified migration entrypoints are:

```bash
bench --site <site> execute \
  omc_app.api.customer_migration.preflight

bench --site <site> execute \
  omc_app.api.customer_migration.apply \
  --kwargs '{"confirm":"APPLY_CUSTOMER_MIGRATION","limit":0,"batch_size":100}'
```

## 30.1 Preflight

`preflight()` is read-only and reports:

- customer classifications;
- safe profile imports;
- deferred claim-on-signup identities;
- identity-review cases;
- profile create/reuse projections;
- blockers/warnings;
- historical Service/Task migration plan;
- expected User creation count.

Expected invariant:

```text
user_accounts_to_create = 0
```

## 30.2 Apply

`apply()`:

1. reconciles supported staff first;
2. rebuilds canonical staff/referral context;
3. migrates only safe unique-email customer profiles in bulk;
4. leaves CNIC/phone/tax-only identities for verified claim-on-signup;
5. preserves identity-review customers;
6. creates/reuses historical referral attribution only when proven;
7. projects supported historical ERP Service/Task state;
8. commits in controlled batches when requested.

Expected invariant:

```text
user_accounts_created = 0
```

Bulk migration is not a password or login-user factory.

---

# 31. Historical / compatibility migration

The repository retains controlled migration helpers for historical state, including Service/Task and commission/referral evidence.

These helpers must preserve provenance and classify uncertain data for review.

They should not convert incomplete historical evidence into fabricated certainty.

Compatibility aliases may remain at API boundaries so old Flutter/backend call sites continue to work while canonical policy executes behind them.

---

# 32. Legacy service retirement

Known pre-manifest service duplicates have a dedicated retirement module under:

```text
omc_app/setup/service_catalogue/legacy_retirement.py
```

It supports:

```text
preview_legacy_service_retirement()
retire_legacy_service_duplicates()
```

Safety properties include:

- read-only preview;
- exact known legacy/canonical pairs;
- historical-only request repointing;
- scan for other Link references;
- explicit Single DocType handling;
- reference-scan errors become blockers;
- no hard-delete of service masters;
- savepoint/rollback;
- post-validation;
- idempotent no-op after retirement.

This is targeted maintenance, not a generic deletion utility.

---

# 33. Scheduled jobs

Frappe scheduler hooks currently include hourly and daily OMC processing.

Examples include:

```text
Hourly
  omc_app.api.scheduler_jobs.run_hourly_jobs
  omc_app.api.bridge_outbox.process_pending
  omc_app.api.bridge_outbox.expire_pending_requests

Daily
  omc_app.api.scheduler_jobs.run_daily_jobs
  omc_app.api.idempotency.cleanup_expired_records
```

The scheduler therefore matters for bridge retry/recovery, expiry handling and scheduled maintenance.

Production site health should include scheduler/worker checks.

---

# 34. Setup lifecycle

Frappe hooks point to:

```text
before_install -> omc_app.setup.lifecycle.before_install
after_install  -> omc_app.setup.lifecycle.after_install
after_migrate  -> omc_app.setup.lifecycle.after_migrate
```

Current semantics:

```text
before_install
    -> validate ERP contract

after_install
    -> initialize_site(commit=False)

after_migrate
    -> validate ERP contract only
```

This is intentional.

A routine schema migration should not unexpectedly rewrite business configuration.

---

# 35. Explicit setup operations

`omc_app.setup.operations` provides deliberate operator entrypoints.

Current operations include:

```text
validate_site
initialize_site
repair_permissions
sync_desk_configuration
apply_site_branding
seed_tax_calculator_defaults
seed_business_rental_tax_slabs
sync_service_task_type_mappings
preview_service_catalogue
validate_service_catalogue
sync_service_catalogue
```

`initialize_site` reconciles:

- ERP compatibility;
- canonical OMC roles/permissions;
- Desk metadata;
- referral workspace links;
- branding.

Optional business-data seeds remain separate by design.

---

# 36. Guarded post-install configuration script

The preferred client production flow after `install-app omc_app` is the script shipped with the custom app:

```bash
cd /path/to/frappe-bench/apps/omc_app
bash scripts/configuration.sh
```

Why the script lives inside the app folder:

- the client may receive only `apps/omc_app`, not the entire development repository;
- it can infer the containing Bench in the normal `frappe-bench/apps/omc_app` layout;
- it keeps deployment orchestration versioned with the backend code it configures.

Site selection behavior:

```text
one site in Bench   -> auto-select
multiple sites      -> numbered selector
--site <site>       -> explicit selection
```

The script then performs, in order:

```text
verify Bench/site/apps
    -> explicit target confirmation
    -> backup
    -> bench migrate + clear-cache
    -> ERP contract validation
    -> initialize_site
    -> customer/staff migration preflight
    -> verify no bulk User creation
    -> pre-data-migration backup
    -> idempotent migration apply
    -> post-migration preflight
    -> catalogue preview
    -> catalogue sync only when ready_to_sync=true
    -> catalogue validation
    -> optional explicitly selected legacy-app uninstall
    -> post-removal ERP/catalogue revalidation
    -> enable scheduler
    -> build assets
    -> clear cache
    -> restart when Supervisor production runtime is detected
    -> final ERP/catalogue/doctor validation
```

Safety boundaries:

- production regression tests are **not** automatically run against the live client DB;
- tax/business regulatory seeds are not silently installed;
- arbitrary fix scripts are not executed;
- unknown third-party apps are never automatically removed;
- the legacy app source folder is not deleted because other Bench sites may still use it;
- all failed ERP/catalogue checks stop the script;
- timestamped run logs are written under `frappe-bench/logs/`;
- migration/catalogue operations are designed for safe reruns.

The repository-root convenience wrapper is:

```bash
bash scripts/configuration.sh
```

For full client instructions and manual fallback commands, see [`../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md).

---

# 37. Deployment boundary

The deployment toolkit under `backend_omc_app/deploy/` is separate from OMC application business logic.

The checked-in installer currently targets:

```text
Frappe branch: version-14
Python:        3.10
Node:          18
Yarn:          1.22.x
```

Important safety distinction:

- `deploy/install.sh` prepares OS/runtime/Bench dependencies;
- `deploy/site_setup.sh` can create/manage sites when deliberately requested;
- `apps/omc_app/scripts/configuration.sh` configures an already-installed OMC app on an existing target site;
- OMC app install/update on an existing client site should not recreate the client's Bench/database.

---

# 38. Installation / update basics

If the app source already exists at `apps/omc_app`:

```bash
cd backend_omc_app/frappe-bench

./env/bin/pip install -e apps/omc_app
./env/bin/python -c "import omc_app; print('OMC App import: OK')"
```

First site installation:

```bash
bench --site <site> install-app omc_app
```

Then use the guarded post-install configurator:

```bash
cd apps/omc_app
bash scripts/configuration.sh --site <site>
```

For ordinary later code/schema updates without a full historical reconfiguration run:

```bash
bench --site <site> migrate
bench build --app omc_app
bench --site <site> clear-cache
```

Use explicit setup/catalogue operations only when required by the deployment plan.

---

# 39. Validation

## Backend suite

Run on the intended development/restored/test site:

```bash
cd backend_omc_app/frappe-bench

bench --site <site> run-tests \
  --app omc_app \
  --skip-test-records
```

Latest directly observed complete OMC suite before this documentation update:

```text
Ran 932 tests in 120.732s
OK
```

Do not automatically run the full suite as part of the live production configuration script.

## ERP contract

```bash
bench --site <site> execute \
  omc_app.setup.erp_contract.validate_client_erp_contract
```

## Catalogue

```bash
bench --site <site> execute \
  omc_app.setup.operations.validate_service_catalogue
```

Latest observed reconciled production catalogue:

```text
valid: true
managed objects unchanged: 195
pending changes: 0
conflicts: 0
blockers: 0
```

## Production health

```bash
bench --site <site> doctor
sudo supervisorctl status
sudo nginx -t
```

Use the checks appropriate to the client's actual process-manager/proxy deployment.

---

# 40. Backend release checklist

Before calling a backend release ready:

- [ ] exact OMC code revision is known;
- [ ] ERPNext/Frappe client contract is validated;
- [ ] schema migration completed;
- [ ] OMC site initialization/reconciliation completed if required;
- [ ] customer/staff migration preview was reviewed before apply;
- [ ] no bulk customer Users/passwords were created;
- [ ] catalogue preview was clean before sync;
- [ ] catalogue validation is clean;
- [ ] required-document keyed matching/grandfathering is intact;
- [ ] accounting settlement gates paid activation;
- [ ] bridge workers/scheduler are healthy;
- [ ] staff capabilities resolve from canonical Staff Access;
- [ ] legacy app retirement, if needed, was backed up and post-validated;
- [ ] latest applicable backend tests passed on a safe test/restored environment;
- [ ] production smoke test covers customer and authorised internal paths;
- [ ] no secrets/backups/runtime logs were committed;
- [ ] no ERPNext source edits were introduced.

---

# 41. Related documentation

- [`../README.md`](../README.md) — repository architecture and high-level setup;
- [`../docs/ROLE.md`](../docs/ROLE.md) — full roles/personas/capability model;
- [`../docs/OMC_APP_FEATURES.md`](../docs/OMC_APP_FEATURES.md) — feature inventory;
- [`../docs/omc_detailed_explanation.md`](../docs/omc_detailed_explanation.md) — detailed product/workflow architecture;
- [`../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md`](../docs/OMC_Client_Deployment_and_Customer_Migration_Handover.md) — client production deployment/migration runbook;
- [`deploy/README.md`](deploy/README.md) — deployment toolkit;
- [`frappe-bench/apps/omc_app/README.md`](frappe-bench/apps/omc_app/README.md) — Frappe app engineering notes;
- [`../omc_app/docs/backend_api_contract.md`](../omc_app/docs/backend_api_contract.md) — Flutter-to-backend API map.
