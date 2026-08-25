# OMC App — Role, Persona and Capability Guide

This document describes the current access-control model used by the OMC Flutter app and Frappe backend.

Source cross-check: **25 August 2026**, branch `main`.

> **Authority rule:** backend capabilities and record scope are the security boundary. Flutter visibility, Frappe Role names, Desk permissions, and legacy profile fields do not independently grant protected OMC authority.

Implementation remains the source of truth, especially:

- `omc_app/api/capabilities.py`;
- `omc_app/api/access.py`;
- `omc_app/api/identity.py`;
- `omc_app/setup/roles.py`;
- `omc_app/setup/staff_sync.py`;
- capability-guarded API modules;
- Flutter route, shell, and capability checks.

---

## 1. Access-control principles

1. **Default deny** — unsupported or incomplete authority fails closed.
2. **Backend enforcement** — hidden Flutter UI is not security.
3. **Capabilities drive protected behavior** — internal operations require explicit backend capabilities.
4. **Customer and staff authority are separate** — a customer account never becomes staff merely from profile metadata or a route.
5. **Ownership and assignment matter** — customers are ownership-scoped; specialists are assigned/relevant-record scoped.
6. **Staff reconciliation matters** — an internal Staff Access record must be both approved and current.
7. **Frappe roles are not the whole OMC policy** — DocPerm helps with Desk access, but protected APIs still evaluate OMC authority.
8. **ERP personas are not duplicate OMC roles** — Consultant, Tax Associates, Business Partner, and Employee are ERP-owned persona values.
9. **System Manager is infrastructure authority, not OMC business authority.**
10. **Exceptional access is explicit** — temporary break-glass access is capability-specific, scoped, expiring, and auditable.
11. **Legacy aliases never broaden authority** — compatibility flags must fail closed for newer finance/security decisions.
12. **UI/API parity** — hidden navigation, direct routes, and direct API calls must resolve to the same backend policy.

---

# 2. Identity layers

## 2.1 Customer

The authenticated customer path is:

```text
Frappe Website User
        |
        v
OMC Customer Account
        |
        +------> ERP Customer
        |
        +------> OMC Customer Profile
                 legacy/business-profile compatibility
```

`OMC Customer Account` is the canonical authenticated customer mapping.

A customer is approved for protected service access only when the account has the required verified/linked/approved state. Customer reads and writes remain ownership-scoped.

`OMC Customer Profile` still carries business/profile and compatibility information, but it does not independently override canonical account access.

## 2.2 Internal staff

The internal access path is:

```text
Frappe System User
        |
        +------> ERP persona / Employee evidence
        |
        v
OMC Staff Profile
        |
        v
OMC Staff Access
        |
        +------> explicit capability rows
        +------> access status
        +------> reconciliation status
        +------> optional break-glass grants
```

`OMC Staff Access` is the canonical operational authority record.

The Staff Profile remains useful as reconciled staff/business metadata, but effective internal access is evaluated from Staff Access plus capability policy.

---

# 3. Account types

## Guest

A guest is not a customer or staff identity.

Guests may receive only explicitly public capabilities, currently including public catalogue/content access and the public tax calculator where supported.

Guests must not receive customer-owned records or internal operations.

## Customer

A customer uses a Frappe `Website User` account.

Public signup is **customer-only**.

Protected customer capabilities are unlocked only from canonical backend customer-account state.

## Internal staff

Internal staff use Frappe `System User` accounts.

Staff authority is not inferred merely because a user is authenticated, has Desk access, or has a platform role.

---

# 4. Active roles and personas

There are three different concepts that must not be mixed together.

## 4.1 Portal role

Active customer portal role:

```text
OMC Customer
```

This is the only active OMC portal role used for normal customer login.

## 4.2 OMC-managed operational Frappe roles

The OMC app actively manages these OMC-specific staff roles:

```text
OMC Admin
OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
```

These roles also participate in controlled Desk DocPerm configuration.

They do **not** replace the canonical Staff Access capability check for protected application APIs.

## 4.3 ERP-owned staff personas

These are current staff persona values sourced from client ERP identity data:

```text
Consultant
Tax Associates
Business Partner
Employee
```

They normally come from `User.omc_user_type`.

For `Employee`, an explicit linked ERP Employee may be used as a fallback where the legacy ERP user-type column is missing.

These persona values are **not OMC-created duplicate Frappe roles**.

They are reconciled into OMC Staff Profile / Staff Access and used to derive the default capability set.

---

# 5. Retired and legacy roles

The following old duplicate external OMC roles are retired compatibility values:

```text
OMC Consultant
OMC Tax Associate
OMC Business Partner
OMC Employee
```

They map conceptually to the ERP personas:

| Retired OMC role | Current ERP persona |
| --- | --- |
| `OMC Consultant` | `Consultant` |
| `OMC Tax Associate` | `Tax Associates` |
| `OMC Business Partner` | `Business Partner` |
| `OMC Employee` | `Employee` |

They must not be treated as the current staff-authority model or assigned to new staff as a substitute for Staff Access.

Additional older compatibility roles are:

```text
OMC Customer Applicant
OMC Customer Support
```

These are legacy roles and must not be used for new authorization design.

---

# 6. System Manager and Administrator

## System Manager

`System Manager` is a Frappe platform/infrastructure role.

It is **not** normal OMC business authority.

OMC role synchronization intentionally removes OMC-managed DocPerm grants associated with `System Manager`, and OMC APIs do not use it as an implicit operational bypass.

A System User who needs OMC business access should receive canonical Staff Access and the required capabilities.

## Administrator

Frappe `Administrator` remains a framework superuser special case.

The canonical capability policy treats Administrator as internal with broad operational capabilities, but self-scoped referral ownership / personal commission entitlement are not automatically granted merely because Administrator is the framework superuser.

Application design should not use Administrator behavior as the normal staff-persona model.

---

# 7. Canonical Staff Access state

A normal internal user can use protected OMC staff functions only when their Staff Access record is valid.

The effective gate requires:

```text
access_status = Approved
reconciliation_status = Current
```

If either condition is not satisfied, normal internal capabilities are not activated.

Examples of fail-closed states include:

```text
Pending
Suspended
Rejected
Conflict / non-current reconciliation
```

## Reconciliation behavior

Trusted ERP staff identity can be reconciled into Staff Access.

Reconciliation records:

- user;
- linked Employee when available;
- legacy Staff Profile link;
- persona snapshot;
- persona source;
- source version;
- reconciliation status/time;
- canonical capability rows.

A deliberately reviewed persona must not be silently overwritten by later ERP reconciliation. If the reviewed persona conflicts with the mapped ERP persona, reconciliation moves to conflict rather than guessing.

Explicit `Suspended` or `Rejected` status survives migration/reconciliation reruns.

---

# 8. Capability model

Protected application behavior should reason in capabilities, not in UI labels.

Examples of internal capability domains include:

- workspace access;
- customer management and customer scope;
- lead management;
- task view/manage/assigned-task authority;
- service-case all/relevant/assigned scopes;
- service creation for a customer;
- service status update;
- service reassignment;
- document queue, summaries, attachments, and review;
- payment queue, summaries, receipts, and review;
- settlement reconciliation;
- post-paid approval;
- support ticket view/reply/status/assignment;
- internal notes;
- settings and business configuration;
- staff administration;
- registration review;
- ERP synchronization/bridge retry;
- referral ownership;
- personal commission visibility;
- commission approval/payment;
- internal notifications.

Approved staff also receive the internal baseline required to enter the workspace, view tasks, and receive internal notifications.

---

# 9. Default capability presets

Staff Access stores explicit capability rows. The current role/persona presets provide the default set used by reconciliation and administration.

The descriptions below summarize the current canonical presets; backend source remains authoritative.

## OMC Admin

**Purpose:** broad OMC application administration.

Default authority includes essentially the full internal capability set except capabilities that are intentionally personal/self-scoped.

Not automatically implied by Admin status:

```text
can_own_referrals
can_view_own_commissions
```

Referral ownership and personal commission entitlement must represent the actual beneficiary/persona rather than generic administrative power.

## OMC Manager

**Purpose:** broad operational management without the most sensitive administration/configuration powers.

Manager receives broad internal operational capability, but the preset excludes:

```text
can_manage_settings
can_manage_staff
can_review_registrations
can_manage_business_settings
can_own_referrals
can_view_own_commissions
```

The retired overloaded referral-commission capability is also excluded.

## OMC Support Agent

Default specialist capabilities include:

```text
can_access_internal_workspace
can_manage_leads
can_view_support_tickets
can_reply_support_tickets
can_update_support_ticket_status
can_assign_support_tickets
can_view_relevant_customers
can_view_relevant_service_cases
can_view_internal_notes
can_manage_assigned_tasks
can_create_service_for_customer
```

Support scope is for customer communication, enquiries, leads, support work, and relevant service context.

Support authority does not imply document-review or finance-review authority.

## OMC Document Reviewer

Default specialist capabilities include:

```text
can_access_internal_workspace
can_view_document_queue
can_view_document_summaries
can_view_document_attachments
can_review_documents
can_view_relevant_customers
can_view_relevant_service_cases
can_view_internal_notes
can_manage_assigned_tasks
```

Document-review authority does not imply payment review, settlement reconciliation, or unrelated configuration authority.

## OMC Finance Reviewer

Default specialist capabilities include:

```text
can_access_internal_workspace
can_view_payment_queue
can_view_payment_summaries
can_view_payment_receipts
can_review_payments
can_reconcile_settlement
can_approve_post_paid
can_approve_commissions
can_mark_commissions_paid
can_view_relevant_customers
can_view_relevant_service_cases
can_view_internal_notes
can_manage_assigned_tasks
```

Finance Reviewer is the normal specialist authority for payment evidence, accounting settlement workflow, post-paid approval, and finance-side commission operations.

Finance authority does not imply referral ownership or personal commission entitlement.

## Consultant

Default ERP-persona capabilities include:

```text
can_access_internal_workspace
can_create_service_for_customer
can_view_assigned_service_cases
can_update_assigned_service_status
can_manage_assigned_tasks
can_view_relevant_customers
can_view_document_summaries
can_view_document_attachments
can_view_internal_notes
can_own_referrals
can_view_own_commissions
```

Consultants are assigned-case operators and may own referrals / view their own commission entitlement.

They do not automatically gain finance commission approval/payment authority.

## Tax Associates

Current default capability preset matches the Consultant operating pattern:

```text
can_access_internal_workspace
can_create_service_for_customer
can_view_assigned_service_cases
can_update_assigned_service_status
can_manage_assigned_tasks
can_view_relevant_customers
can_view_document_summaries
can_view_document_attachments
can_view_internal_notes
can_own_referrals
can_view_own_commissions
```

The persona value is `Tax Associates` in current ERP mapping. Legacy singular `Tax Associate` input is normalized to that persona during reconciliation.

## Business Partner

Default ERP-persona capabilities include:

```text
can_access_internal_workspace
can_create_service_for_customer
can_view_assigned_service_cases
can_update_assigned_service_status
can_manage_assigned_tasks
can_view_relevant_customers
can_view_document_summaries
can_view_document_attachments
can_view_internal_notes
can_own_referrals
can_view_own_commissions
```

Business Partner is also a referral-owner and personal-commission beneficiary persona when canonical Staff Access is current.

## Employee

Default ERP-persona capabilities include:

```text
can_access_internal_workspace
can_view_assigned_service_cases
can_view_relevant_customers
can_view_document_summaries
can_view_document_attachments
can_view_own_commissions
```

Employee is a commission-beneficiary persona but is **not** a default referral-owner persona.

---

# 10. Referral and commission authority split

The current model deliberately separates three concepts.

## Referral ownership

Canonical capability:

```text
can_own_referrals
```

Default referral-owner personas are:

```text
Consultant
Tax Associates
Business Partner
```

`Employee` is not in the default referral-owner set.

## Personal commission visibility

Canonical capability:

```text
can_view_own_commissions
```

Default commission-beneficiary personas are:

```text
Consultant
Tax Associates
Business Partner
Employee
```

This capability is self-scoped. It is not generic access to every commission allocation.

## Finance commission operations

Separate capabilities govern finance-side commission processing:

```text
can_approve_commissions
can_mark_commissions_paid
```

These are part of the Finance Reviewer preset and are not implied by referral ownership or own-commission visibility.

## Legacy overloaded capability

The old compatibility capability:

```text
can_view_referral_commissions
```

is retained only as a temporary compatibility alias for older consumers.

It no longer represents finance commission authority and must not be used as the canonical check for commission approval/payment.

---

# 11. Customer capabilities

Approved customers receive a separate customer capability set.

Current protected customer capabilities include areas such as:

```text
can_create_service_request
can_upload_documents
can_track_requests
can_view_documents
can_view_payments
can_upload_payment_receipt
can_upload_payment_receipts
can_create_support_ticket
can_view_customer_dashboard
can_access_customer_dashboard
can_view_customer_notifications
```

Customer capability does not grant internal workspace access.

A pending/blocked customer remains limited even if the Frappe User is authenticated.

---

# 12. Public signup policy

Public self-registration is **customer-only**.

Supported public account types are normalized customer values such as:

```text
customer
omc customer
```

Supported public onboarding modes include:

```text
New Customer
Existing Customer Claim
```

Internal staff identities are provisioned/reconciled from trusted System User / ERP identity and receive authority through Staff Access.

The older model where public signup exposed Consultant, Business Partner, or Tax Associate applications is no longer the canonical production policy.

---

# 13. Specialist scope rules

Capabilities alone do not always mean global record access.

## Assigned scope

Consultant, Tax Associates, Business Partner, and Employee workflows generally use assigned service-case/task scope where the capability name indicates assignment.

Examples:

```text
can_view_assigned_service_cases
can_update_assigned_service_status
can_manage_assigned_tasks
```

## Relevant scope

Support/reviewer workflows use related business context rather than unrestricted global access.

Examples:

```text
can_view_relevant_customers
can_view_relevant_service_cases
```

## Global scope

Broad/global operations use explicit all-record or management capabilities and are normally reserved for the appropriate management/admin policy.

Do not convert an assigned/relevant capability into global access in Flutter or backend helpers.

---

# 14. Frappe DocPerm vs application capabilities

The OMC app also manages Frappe `DocPerm` rows for selected OMC-owned roles.

This serves Desk/report usability, but DocPerm is not a substitute for API capability enforcement.

## OMC Admin DocPerm

Admin receives broad mutable access to explicitly allowlisted OMC business/configuration DocTypes.

Sensitive evidence/security/history DocTypes remain read-only through normal DocPerm even for OMC Admin, with legitimate mutations occurring through guarded application APIs.

Examples of read-only evidence/security models include:

```text
OMC Accounting Link
OMC Break Glass Grant
OMC Bridge Operation
OMC Commission Allocation
OMC Customer Account
OMC Reconciliation Review
OMC Reconciliation Run
OMC Referral Attribution
OMC Security Audit Event
OMC Staff Access
```

## OMC Manager DocPerm

Manager receives broad operational mutable access but is blocked from designated configuration domains and from destructive/share authority provided to Admin.

## Specialist DocPerm

Support Agent, Document Reviewer, and Finance Reviewer receive deliberately narrow Desk permissions matching their operational domains.

## Internal-only DocTypes

Security/session/idempotency internals do not receive normal managed staff DocPerm rows.

Examples include:

```text
OMC Customer Activation
OMC Guest Session
OMC Idempotency Record
OMC Password Reset
OMC Pending Registration
OMC Push Token
OMC Reconciliation Checkpoint
```

---

# 15. Break-glass access

Break-glass is for exceptional temporary authority, not ordinary provisioning.

An active grant is evaluated against:

- user;
- capability;
- expiry;
- optional target DocType;
- optional target record.

A scoped grant can authorize the named capability for the intended target without permanently rewriting the user's normal Staff Access capability set.

Expired or revoked grants do not apply.

Use break-glass only where the guarded API explicitly supports scoped capability evaluation.

---

# 16. Staff synchronization rules

Trusted ERP staff synchronization currently recognizes:

```text
Consultant
Business Partner
Tax Associates
Tax Associate -> normalized to Tax Associates
Employee
```

Eligibility requires a real enabled Frappe `System User` and a supported trusted ERP persona.

Synchronization deliberately leaves ERP roles / Role Profiles untouched.

For eligible staff it reconciles:

1. Staff Profile;
2. canonical Staff Access;
3. capability rows from persona defaults;
4. Employee link when available;
5. referral record/code where referral ownership is actually supported.

`Guest` and `Administrator` are not normal candidates for this ERP staff-sync path.

---

# 17. Referral creation during staff sync

Referral automation runs only after canonical Staff Access has been reconciled.

This order is deliberate: referral hooks must not observe stale legacy referral authority during migration or reruns.

Default referral-code owner personas are:

```text
Consultant
Business Partner
Tax Associates
```

Employee may have personal commission entitlement without referral ownership.

---

# 18. Suspension and revocation

Security authority must survive reconciliation.

If Staff Access is explicitly:

```text
Suspended
Rejected
```

staff synchronization does not silently restore it to Approved.

Likewise, a reconciliation conflict must be reviewed instead of automatically overwriting a deliberately reviewed persona.

This prevents routine sync jobs from undoing a human security decision.

---

# 19. Flutter behavior

Flutter receives backend-projected capability state and uses it to control:

- routes;
- shell navigation;
- home actions;
- service-case controls;
- document/review actions;
- payment/review actions;
- support tools;
- referral-owner surfaces;
- personal commission screens;
- finance commission screens;
- internal workspace entry.

Flutter must not reconstruct authority locally from display role names when canonical capability state is available.

If Flutter hides an action, the backend must still reject the same unauthorized direct API call.

---

# 20. Security invariants

The following rules should remain true during future changes:

- `System Manager` alone does not imply OMC authority;
- Website Users cannot become internal staff merely from signup metadata;
- public self-signup remains customer-only unless deliberately redesigned;
- current external personas are ERP persona values, not duplicate OMC roles;
- retired OMC Consultant/Tax Associate/Business Partner/Employee roles must not regain authority;
- Staff Access must be Approved and Current for normal staff capability activation;
- suspended/rejected access must survive reconciliation;
- reviewed persona conflicts fail closed;
- customer ownership is server-side enforced;
- assigned/relevant scope must not become global scope accidentally;
- referral ownership is separate from finance commission authority;
- personal commission visibility is self-scoped;
- finance commission approval/payment requires dedicated capability;
- break-glass access must be explicit, temporary, and scoped;
- sensitive evidence/history records should mutate through guarded APIs rather than broad DocPerm;
- legacy compatibility flags must not silently broaden current authority.

---

# 21. Testing expectations

Any role/capability change should test at least the affected boundaries:

1. canonical backend capability output;
2. approved vs pending/suspended/reconciliation-conflict behavior;
3. record scope (own/relevant/assigned/all);
4. direct protected API denial;
5. Flutter route/navigation/action visibility where applicable;
6. legacy role/capability compatibility behavior;
7. referral/personal-commission/finance-commission separation when relevant;
8. Staff Access reconciliation behavior if persona provisioning changes.

The latest recorded broader backend regression snapshot in the root README is **932 / 932 passed** for the implementation state cross-checked on 25 August 2026.

---

# 22. Quick reference

| Identity / role / persona | Normal account type | Canonical authority model | Typical scope |
| --- | --- | --- | --- |
| Guest | none | public capabilities only | public |
| OMC Customer | Website User | Customer Account + customer capabilities | own records |
| OMC Admin | System User | Staff Access + broad admin capabilities | broad OMC |
| OMC Manager | System User | Staff Access + broad operational capabilities | broad operations |
| OMC Support Agent | System User | Staff Access + support capabilities | relevant/support |
| OMC Document Reviewer | System User | Staff Access + document-review capabilities | relevant/document |
| OMC Finance Reviewer | System User | Staff Access + finance-review capabilities | relevant/finance |
| Consultant | System User | ERP persona -> Staff Access capabilities | assigned/relevant + referral owner |
| Tax Associates | System User | ERP persona -> Staff Access capabilities | assigned/relevant + referral owner |
| Business Partner | System User | ERP persona -> Staff Access capabilities | assigned/relevant + referral owner |
| Employee | System User | ERP persona -> Staff Access capabilities | assigned/relevant + own commissions |
| System Manager | System User | platform role only; no implicit OMC business authority | infrastructure |
| Administrator | framework superuser | special framework/capability handling | exceptional |

---

## Related documentation

- [`../README.md`](../README.md) — current system architecture and operating boundaries;
- [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md) — feature inventory;
- [`omc_detailed_explanation.md`](omc_detailed_explanation.md) — detailed business/workflow architecture;
- [`OMC_Client_Deployment_and_Customer_Migration_Handover.md`](OMC_Client_Deployment_and_Customer_Migration_Handover.md) — client installation/migration guide.

Implementation is always the final authority when documentation and code differ.
