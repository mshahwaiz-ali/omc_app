# OMC App — Business and Workflow Architecture Guide

Source cross-check: **25 August 2026**, branch `main`.

This document explains the implemented OMC business workflow from identity and customer onboarding through service execution, accounting settlement, ERP activation, referrals, commissions, support, and operational control.

For engineering/setup commands, see [`../README.md`](../README.md). For the feature inventory, see [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md). For access control, see [`ROLE.md`](ROLE.md).

---

## 1. Core operating model

OMC App does not replace ERPNext. It adds the customer/mobile experience and OMC-specific workflow state around ERP-owned business records.

The design rule is:

> **Use ERPNext as source of truth where ERPNext already owns the business record. Use OMC DocTypes for OMC-specific identity links, workflow, access, audit, documents, payments, referrals, commissions, and bridge state.**

| Business area | Canonical authority |
| --- | --- |
| Lead | ERPNext `Lead` |
| Customer master | ERPNext `Customer` |
| Authenticated customer mapping | `OMC Customer Account` |
| Customer profile/business compatibility | `OMC Customer Profile` |
| Internal OMC access | `OMC Staff Access` |
| Service catalogue | source-controlled manifest + `OMC Service` |
| Customer service case | `OMC Service Request` |
| Required documents | `OMC Service Required Document` |
| Uploaded service documents | `OMC Service Document` |
| OMC payment/receipt workflow | `OMC Service Payment` |
| Accounting settlement relationship | `OMC Accounting Link` |
| ERP activation/retry state | `OMC Bridge Operation` |
| Referral provenance | referral/attribution records |
| Commission entitlement/lifecycle | `OMC Commission Allocation` + commission APIs |
| ERP service execution | ERP `Service` and `Task` |
| ERP accounting | ERPNext finance records |

ERPNext source files must remain untouched by OMC customisation.

---

## 2. High-level customer service workflow

The main path is:

```text
New app customer / imported ERP customer
                |
                v
     Authenticated customer account
                |
                v
        OMC Service Request
                |
                +--> pricing snapshot
                +--> required-document contract
                |
                v
       Document submission
                |
                v
      Payment/accounting gate
                |
                v
       Ready for Activation
                |
                v
      Durable Bridge Operation
                |
                +--> ERP Service
                +--> ERP Task
                |
                v
       Assignment/execution
                |
                v
            Completion
```

This means a customer request is not operationally activated in ERP merely because the customer pressed Submit. The backend enforces the request lifecycle and payment policy first.

---

## 3. Customer identity model

The authenticated customer model is:

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +------> ERP Customer
        +------> OMC Customer Profile
```

`OMC Customer Account` is the canonical mapping used by protected customer access. It links the login identity to the ERP Customer and may retain a legacy Customer Profile link.

Protected customer access requires the account to be verified, linked and approved for service access.

`OMC Customer Profile` remains useful for business/profile history, migration compatibility, referral fields, and older relationships, but it does not independently bypass Customer Account authority.

---

## 4. New customer signup

Public self-registration is **customer-only**.

Internal staff personas are not granted through public signup.

The registration flow uses backend validation and pending-registration verification before account activation. Sensitive verification tokens are managed as expiring one-time secrets rather than durable plaintext credentials.

After the verified signup path establishes a valid customer identity, the canonical account/profile links and customer capability state control access to protected customer functions.

---

## 5. Existing ERP customer migration

Existing ERP Customers can be migrated into OMC business/profile state without pre-creating thousands of Frappe Users.

The migration resolves identity in this order:

```text
1. unique valid Customer email
2. unique linked-Lead CNIC
3. unique safe resolved phone
4. unique supported Customer tax ID / NTN
5. identity review
```

The tax-ID/NTN rule is intentionally the final deterministic fallback.

Migration principles:

- preflight before mutation;
- explicit apply confirmation;
- no shared/default customer passwords;
- no bulk login-user creation;
- reuse existing safe records;
- preserve ambiguous records for review;
- do not guess historical relationships;
- support idempotent reruns;
- reconcile eligible staff/referral state as defined by the migration workflow.

Business migration and login activation are separate concerns.

---

## 6. Existing-customer claim/activation

An imported customer may exist as a valid ERP/OMC business customer before an app login exists.

The supported activation/claim flow proves control of an accepted identity before establishing or linking login authority. The backend uses collision checks and safe review paths rather than automatically merging ambiguous Frappe identities.

The result is that imported business data does not require a fabricated email or default password.

---

## 7. Internal staff model

Internal authority is:

```text
Frappe System User
        |
        v
OMC Staff Access
        |
        +--> access_status
        +--> reconciliation_status
        +--> persona snapshot/source
        +--> explicit capability rows
        +--> optional scoped break-glass grants
```

Normal staff access requires approved and current canonical Staff Access.

ERP-owned staff personas include:

- `Consultant`;
- `Tax Associates`;
- `Business Partner`;
- `Employee`.

OMC-owned operational roles include Admin, Manager, Support Agent, Document Reviewer and Finance Reviewer.

Legacy `OMC Consultant`, `OMC Tax Associate`, `OMC Business Partner` and `OMC Employee` role names are retirement/compatibility seams, not the current provisioning model.

`System Manager` is a Frappe infrastructure role and does not implicitly grant OMC business capabilities.

---

## 8. Staff reconciliation

OMC can reconcile trusted ERP users into canonical Staff Access without rewriting ERP role profiles.

Important behavior:

- disabled or non-System Users are not eligible staff;
- unsupported/missing ERP persona fails closed;
- explicit reviewed persona conflicts produce reconciliation conflict rather than silent overwrite;
- suspended/rejected Staff Access remains suspended/rejected on rerun;
- referral and commission capabilities are derived deliberately from eligible persona;
- existing ERP Employee linkage is checked for duplicate ownership.

---

## 9. Capability and record scope

Protected OMC operations use explicit capabilities plus record scope.

Examples:

- customers: own records only;
- consultants/tax associates/business partners: assigned/relevant service cases;
- support: support-domain and relevant customer/case context;
- document reviewers: document queue/review context;
- finance reviewers: payment/settlement/commission-finance context;
- managers/admin: broader operational/configuration scope according to capability.

Flutter navigation is a projection of this authority, not the authority itself.

---

## 10. Break-glass access

`OMC Break Glass Grant` supports exceptional temporary access.

A grant can be:

- capability-specific;
- time-limited;
- globally or record-scoped;
- revoked;
- audited.

Break-glass does not permanently mutate the user's normal role/persona.

---

## 11. Service catalogue

The production catalogue is source controlled.

Current manifest totals:

```text
9 categories
31 services
17 active
14 inactive/review-required
currency: PKR
company: Omc House
activation policy: Full Settlement
```

Service identity uses stable `service_id`; category identity is stable independently from display labels.

Each service maps only to an **exact existing ERP Task Type**. OMC does not fuzzy-match or create ERP Task Types.

Inactive services remain inactive when commercial facts are uncertain. The system does not invent pricing, recurring-fee modeling, requirements, or completion time merely to publish every service.

---

## 12. Catalogue provisioning

Operator-facing catalogue operations are:

```text
preview_service_catalogue     read-only
validate_service_catalogue    read-only
sync_service_catalogue        explicit mutation
```

Sync behavior includes:

- exact preflight;
- conflict/blocker reporting;
- one controlled transaction/savepoint boundary;
- category/service/document/form reconciliation;
- stale managed-row deactivation;
- in-flight request safety;
- price-change safety;
- post-sync validation;
- rollback on failure;
- idempotent no-op when already aligned.

Normal `bench migrate` does not publish the catalogue.

---

## 13. Pricing snapshots

Service requests persist authoritative pricing context rather than reading a mutable service price forever.

The backend protects historical and in-flight customer economics from unsafe catalogue changes. Discount and payment decisions are controlled by backend policy/capability, not arbitrary client values.

---

## 14. Required-document contract

Service requirements use stable `document_key` identity.

When both template and upload are keyed, the key is authoritative. A wrong key cannot become valid because title/type happen to match.

Legacy/unkeyed history remains compatible through controlled exact normalized title+type fallback.

One upload satisfies at most one requirement.

### Requirement grandfathering

New managed requirements can have `effective_from`, so a new requirement does not retroactively change an older request's document contract.

This is critical for production catalogue evolution.

---

## 15. Customer document flow

The service-case UI shows required documents and can offer inline Upload/Replace actions.

The client sends the selected requirement identity, but the backend canonicalises and validates it against the request's service before storing the upload.

Document completion and payment/completion blockers use the same identity rules so different flows cannot disagree about which requirement has been satisfied.

---

## 16. Request lifecycle

Canonical request states include:

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

Customer-facing statuses such as Open, Waiting for Payment, In Progress, Waiting for Customer and Completed are compatibility/operational projections.

Invalid state transitions fail closed.

Terminal cleanup is transactional where necessary: request state, ToDos, open payment records, bridge work, document archival, timeline and notification side effects must not leave contradictory states.

---

## 17. Payment and accounting model

OMC separates three concepts:

1. customer-visible payment/receipt workflow;
2. OMC payment review state;
3. ERP accounting settlement authority.

`OMC Service Payment` does not replace ERP accounting.

For `Full Settlement`, activation requires an `OMC Accounting Link` showing settled accounting evidence.

The system also supports explicitly authorised no-charge and post-paid policies.

---

## 18. Durable ERP activation

`OMC Bridge Operation` is the durable activation boundary.

It provides:

- deterministic operation keys;
- row locking;
- final eligibility re-checks;
- settlement re-check immediately before ERP writes;
- bounded retries/backoff;
- stale Processing lease recovery;
- savepoint rollback around operational writes;
- explicit Pending/Retry/Processing/Completed/Failed/Cancelled state;
- authorised manual recovery;
- audit events.

A request reaches `Activated` only after committed ERP Service and Task links exist.

---

## 19. Assignment and execution

After activation, assignment is resolved through backend policy. Referral-owner/default/eligible staff context can participate where configured.

The selected assignment is reflected in OMC request/ToDo/ERP task state as applicable. Specialists remain scoped to assigned/relevant work unless broader authority is explicitly granted.

---

## 20. Completion authority

Completion checks combine:

- required-document completion;
- payment state;
- ERP Task completion where linked;
- valid service/request state.

Stable document keys are propagated into completion checks so a wrong keyed upload cannot clear a requirement by falling back to title/type.

---

## 21. Leads and customer masters

ERPNext `Lead` and `Customer` remain canonical business masters.

OMC guarded APIs can expose or create relevant ERP records without turning legacy OMC lead tables into a second source of truth.

Historical/legacy OMC lead data remains a compatibility or retirement concern only.

---

## 22. Referrals

Referral ownership is explicit staff entitlement.

The system separates:

- referral owner;
- referral code;
- customer attribution;
- service referral evidence;
- assistance consent where relevant;
- commission allocation.

This prevents payout state from becoming the only evidence of business provenance.

---

## 23. Commissions

Commission architecture separates personal entitlement from finance operations.

Current concepts include:

- `OMC Commission Allocation`;
- beneficiary/personal commission visibility;
- finance approval;
- mark-paid authority;
- historical commission evidence/provenance;
- compatibility aliases that do not widen finance access.

A referral owner does not automatically become a finance reviewer.

---

## 24. Support and notifications

Customers can create/view their support work where enabled. Support staff use capability-gated queues and actions.

Notifications cover customer and internal events and can connect service/document/payment/support activity to Flutter navigation.

---

## 25. Audit, reconciliation and quarantine

The backend contains dedicated security/audit/reconciliation evidence models. These are generally not normal user-editable operational records.

Examples include:

- security audit events;
- reconciliation runs/reviews;
- technical quarantine;
- accounting links;
- bridge operations;
- referral attribution;
- commission allocations.

Sensitive mutations occur through guarded APIs rather than broad DocPerm write access.

---

## 26. Setup lifecycle

Normal lifecycle behavior is intentionally conservative:

```text
before_install -> validate ERP contract
after_install  -> explicit one-time OMC initialization
after_migrate  -> validation only
```

Normal migration does not silently rewrite OMC roles, branding, Desk/workspace metadata or the service catalogue.

Explicit operator commands exist for deliberate repair/sync operations.

---

## 27. Release validation

The latest directly observed implementation validation before this documentation refresh was:

```text
Backend OMC suite:             932 / 932 passed
Flutter case-detail contract:    4 / 4 passed
Flutter analyze:              No issues found
Catalogue validation:         195 unchanged, 0 conflicts, 0 blockers
```

A real deployment/release still requires environment-specific migration, smoke testing, connectivity, email/deep-link, file-upload and device/browser validation as applicable.

---

## 28. Intentional constraints

Current production safety deliberately prefers review over guessing:

- ambiguous customer identities remain review cases;
- unresolved catalogue commercial data keeps services inactive;
- legacy document matching exists only for genuine unkeyed history;
- Staff Access reconciliation conflicts fail closed;
- System Manager does not receive implicit OMC business authority;
- ERP activation fails/retries rather than leaving partial links;
- ERPNext source remains untouched.
