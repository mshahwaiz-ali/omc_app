# OMC App Role, Identity and Capability Architecture

## Purpose

This document is the canonical description of OMC App identity, approval, persona, capability, ownership, and internal-access rules.

The application has two user-facing domains:

1. **Customer domain** — guest, pending customer, approved customer, and imported-customer activation.
2. **Internal domain** — Frappe users who are classified as staff identities and are authorised through an approved `OMC Staff Profile` plus an effective OMC staff persona.

The central rule is:

> Identity classification, approval, role/persona, capability, and record scope are separate checks. Passing one check must never silently satisfy the others.

Flutter may hide or show navigation based on the capability payload, but the Frappe backend remains authoritative for every protected read and mutation.

---

# 1. Identity domains

OMC App deliberately separates customer identity from internal staff identity.

```text
CUSTOMER

ERP Customer
    |
    +--> OMC Customer Profile
             |
             +--> Frappe Website User when app login exists


INTERNAL STAFF

Frappe System User
    |
    +--> OMC Staff Profile
             |
             +--> ERP Employee when one is linked
```

A customer is not modelled as staff, and staff must not accidentally fall through into customer-profile creation merely because their OMC approval is still pending.

## 1.1 Customer identity

Customer application state is centred on `OMC Customer Profile`.

A customer may have:

- an ERPNext `Customer` master record;
- an `OMC Customer Profile` containing OMC lifecycle and application state;
- a Frappe `User` only when an app/web login exists.

Imported ERP customers are intentionally allowed to have an active approved OMC profile without a Frappe User until secure account activation is completed.

## 1.2 Staff identity

`access.is_internal_user()` classifies identity; it does **not** grant OMC authorisation.

A user is treated as an internal identity when any of the following is true:

- the Frappe user has `System Manager` or an OMC staff role;
- the Frappe user is a `System User`;
- an `OMC Staff Profile` exists for the user;
- an ERP `Employee` is linked to the user.

This fail-safe classification is important: a pending or unapproved System User must remain in the internal domain and must not be treated as a customer.

---

# 2. Customer access states

Customer permissions are lifecycle- and ownership-driven. `OMC Customer` is a portal identity role; the role by itself is never enough to grant approved-customer access.

## 2.1 Guest

A guest may use guest-safe functionality such as:

- public service catalogue and service detail;
- approved public content;
- FAQs and knowledge content;
- tax calculator;
- login and signup;
- registration verification;
- password recovery;
- imported-customer activation request and activation-token completion.

A guest cannot access private customer records or internal workspaces.

## 2.2 Pending customer

A newly registered customer may exist before OMC approval.

Typical lifecycle state:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending customers may use the permitted profile/account experience and public functionality, but approved-only workflows remain closed.

## 2.3 Approved customer

Typical approved lifecycle state:

```text
customer_status = Active
approval_status = Approved
is_active = 1
```

Approved customers may use customer workflows exposed by the current capability payload, including service requests, documents, payments, support, dashboard data, and notifications where applicable.

The non-negotiable customer boundary is:

> An approved customer may only read or mutate records belonging to that customer's own OMC customer identity and its authorised relationships.

A customer must never gain internal review, assignment, lead-management, staff-management, or cross-customer authority merely because a route exists in Flutter.

## 2.4 Imported customer before login activation

Existing ERP customers may be migrated profile-only:

```text
ERP Customer
    -> OMC Customer Profile
       customer_origin = Imported
       customer_status = Active
       approval_status = Approved
       is_active = 1
       manual_customer_status = Unregistered
       user = blank
       linked_app_user = blank
```

This represents **business approval**, not login activation.

A Frappe Website User is created and linked only after the customer proves control of an eligible identity through the secure activation flow. No shared/default password is used.

---

# 3. Internal staff lifecycle

Internal staff use `OMC Staff Profile` as the OMC-specific approval and persona record.

The profile currently contains identity/professional fields including:

```text
user
linked_employee
full_name
email
username
phone
whatsapp_no
staff_status
approval_status
staff_role
is_active
cnic
ntn
company_name
address
education
experience
remarks
referral_record
own_referral_code
```

`linked_employee` connects the profile to the existing ERP Employee where available. ERP Employee remains an ERP record; the OMC Staff Profile owns OMC approval/persona state.

## 3.1 New staff state

`ensure_staff_profile()` creates new staff profiles conservatively:

```text
staff_status = Pending
approval_status = Pending Review
is_active = 0
```

If the user already has exactly one recognised OMC staff role, that role may seed `staff_role`; otherwise the persona remains unset until deliberately configured.

No new staff identity becomes authorised merely because an Employee is Active or a System User exists.

## 3.2 Approved staff state

Normal OMC staff authorisation requires all of the following:

```text
Frappe User exists
Frappe User enabled = 1
at least one effective OMC staff role exists
OMC Staff Profile exists
staff_status = Active
approval_status = Approved
is_active = 1
```

If `linked_employee` is present, the linked ERP Employee must also have:

```text
status = Active
```

The Employee status is a safety condition only. It does not replace OMC approval.

## 3.3 Suspended, rejected, or pending staff

When the profile is not fully approved, internal operational capabilities fail closed.

A pending internal user receives an internal-pending capability payload rather than customer capabilities.

This prevents the dangerous fallback:

```text
unapproved staff
    -> treated as customer
    -> customer profile accidentally created
```

That fallback is not part of the OMC architecture.

---

# 4. OMC persona vs Frappe Role Profile

The project previously treated Frappe role assignment as the main OMC persona mechanism. The current architecture deliberately separates ERP/Frappe role-profile management from the OMC application persona.

```text
Existing ERP/Frappe authorisation
User
    -> existing Role Profile, e.g. Operations
       -> Accounts User / Mobile / Projects User / other ERP roles

OMC application authorisation
User
    -> OMC Staff Profile
       -> staff_role
       -> staff_status
       -> approval_status
       -> is_active
       -> OMC capabilities
```

## 4.1 Do not modify shared client Role Profiles

OMC must not add/remove roles from a client's shared Frappe Role Profile merely to give a user an OMC persona.

Reasons:

- Role Profiles are shared ERP/Frappe configuration;
- changing one profile can affect many users;
- Frappe can repopulate a user's roles from the assigned Role Profile;
- direct user-role edits can therefore be overwritten;
- the OMC persona should remain owned by `omc_app`, not by unrelated ERP role-profile configuration.

Existing client Role Profiles should remain intact unless the client deliberately changes them for ERP purposes.

## 4.2 Effective OMC staff roles

`staff_profile.get_effective_staff_roles(user)` combines two sources:

```text
recognised OMC roles returned by frappe.get_roles(user)
+
OMC Staff Profile.staff_role
```

The result is a set. Capabilities from all effective OMC staff roles are unioned.

This provides compatibility with intentionally assigned OMC Frappe roles while allowing the Staff Profile persona to remain authoritative for normal OMC staff setup.

Least privilege still applies: do not assign additional direct OMC roles unless their additional capabilities are actually required.

---

# 5. Canonical roles

`omc_app.setup.roles` declares the canonical OMC roles.

## 5.1 Customer portal role

```text
OMC Customer
```

Characteristics:

- portal/customer identity;
- configured without Desk access;
- customer lifecycle and ownership checks remain mandatory;
- role presence alone does not mean approved customer access.

## 5.2 Staff roles

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

These are staff roles with Desk access at the Frappe Role definition layer.

For ordinary OMC staff, having one of these roles or selecting the corresponding Staff Profile persona does **not** bypass Staff Profile approval.

## 5.3 System override

`System Manager` and `Administrator` are emergency/system-level overrides in the OMC capability resolver.

An Administrator/System Manager receives internal capability authority without requiring ordinary Staff Profile approval.

This override is for trusted system administration. It must not be reproduced for normal operational roles.

---

# 6. Canonical internal capability keys

`omc_app.api.access.INTERNAL_CAPABILITY_KEYS` is the canonical internal capability inventory:

```text
can_access_internal_workspace

can_manage_customers
can_view_all_customers
can_view_relevant_customers

can_manage_leads

can_manage_tasks
can_manage_assigned_tasks

can_view_all_service_cases
can_view_relevant_service_cases
can_view_assigned_service_cases
can_create_service_for_customer
can_update_service_status
can_update_assigned_service_status

can_view_document_queue
can_view_document_summaries
can_view_document_attachments
can_review_documents

can_view_payment_queue
can_view_payment_summaries
can_view_payment_receipts
can_review_payments

can_view_support_tickets
can_reply_support_tickets
can_update_support_ticket_status
can_assign_support_tickets

can_view_internal_notes
can_manage_settings
can_manage_staff
can_review_registrations
can_manage_business_settings
can_reassign_service_cases
can_retry_sync
```

`can_access_internal_workspace` means only that the user may enter the internal application area. Every sensitive operation must still require its specific capability and record-scope check.

---

# 7. Role capability mapping

The current backend mapping is defined by `ROLE_CAPABILITIES` in `omc_app.api.access`.

## 7.1 OMC Admin

`OMC Admin` receives every canonical internal capability.

This includes:

```text
internal workspace
customer management
lead management
all/assigned task management
all/relevant/assigned service access
assisted service creation
service-status control
document queue/review
payment queue/review
support operations
internal notes
settings
staff management
registration review
business settings
service-case reassignment
sync retry
```

Normal OMC Admin users still require an approved active Staff Profile. The System Manager/Administrator override is separate.

## 7.2 OMC Manager

`OMC Manager` receives the canonical internal set except:

```text
can_manage_settings = false
can_manage_staff = false
can_review_registrations = false
can_manage_business_settings = false
```

Manager retains broad operational capabilities including:

```text
can_reassign_service_cases
can_retry_sync
can_manage_customers
can_manage_leads
can_manage_tasks
can_review_documents
can_review_payments
support operations
```

## 7.3 OMC Support Agent

Current capabilities:

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

Support is intentionally excluded from document-review, payment-review, global settings, staff administration, and broad all-customer/all-case authority.

## 7.4 OMC Document Reviewer

Current capabilities:

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

Document review does not imply finance review, support administration, lead management, or settings authority.

## 7.5 OMC Finance Reviewer

Current capabilities:

```text
can_access_internal_workspace
can_view_payment_queue
can_view_payment_summaries
can_view_payment_receipts
can_review_payments
can_view_relevant_customers
can_view_relevant_service_cases
can_view_internal_notes
can_manage_assigned_tasks
```

Finance review does not imply document review, support administration, lead management, or settings authority.

## 7.6 OMC Consultant

Current capabilities:

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
```

Consultant service access is assignment/relevance-scoped; it is not global operational authority.

## 7.7 OMC Tax Associate

Current capability set is the same as OMC Consultant:

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
```

Tax-specific capabilities can be introduced later if the actual tax workflow requires a different authority boundary.

## 7.8 OMC Business Partner

Current capability set is also assignment-scoped and matches Consultant/Tax Associate:

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
```

---

# 8. Capability matrix

| Capability group | Admin | Manager | Support | Document Reviewer | Finance Reviewer | Consultant | Tax Associate | Business Partner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Internal workspace | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Global customer management | Yes | Yes | No | No | No | No | No | No |
| Relevant customer view | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Lead management | Yes | Yes | Yes | No | No | No | No | No |
| Manage all tasks | Yes | Yes | No | No | No | No | No | No |
| Manage assigned tasks | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| View all service cases | Yes | Yes | No | No | No | No | No | No |
| Relevant service cases | Yes | Yes | Yes | Yes | Yes | No* | No* | No* |
| Assigned service cases | Yes | Yes | No | No | No | Yes | Yes | Yes |
| Assisted service creation | Yes | Yes | Yes | No | No | Yes | Yes | Yes |
| Global service-status update | Yes | Yes | No | No | No | No | No | No |
| Assigned status update | Yes | Yes | No | No | No | Yes | Yes | Yes |
| Document review | Yes | Yes | No | Yes | No | No | No | No |
| Payment review | Yes | Yes | No | No | Yes | No | No | No |
| Support operations | Yes | Yes | Yes | No | No | No | No | No |
| Internal notes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| OMC settings | Yes | No | No | No | No | No | No | No |
| Staff management | Yes | No | No | No | No | No | No | No |
| Registration review | Yes | No | No | No | No | No | No | No |
| Business settings | Yes | No | No | No | No | No | No | No |
| Service-case reassignment | Yes | Yes | No | No | No | No | No | No |
| ERP sync retry | Yes | Yes | No | No | No | No | No | No |

`*` Consultant, Tax Associate, and Business Partner receive assignment-scoped service-case authority rather than the generic `can_view_relevant_service_cases` capability.

The matrix is a capability summary. Endpoint-specific ownership, assignment, relationship, workflow-state, and validation checks remain mandatory.

---

# 9. Capability resolution algorithm

The backend resolves access in this order.

```text
1. Determine current Frappe user.

2. Classify whether the identity is internal.

3. If internal but not approved:
      return internal-pending capabilities
      all internal action capabilities = false
      do not fall through to customer capabilities

4. If Administrator/System Manager:
      grant canonical internal capability set

5. Otherwise:
      resolve effective OMC staff roles
      union ROLE_CAPABILITIES for those roles

6. If identity is not internal:
      use the customer/mobile capability resolver
```

This separation is why these concepts must not be collapsed:

```text
is_internal_user(user)
!=
is_approved_staff(user)
!=
can_access_internal_workspace(user)
!=
has a specific operation capability
!=
may access this specific record
```

---

# 10. Referral role rules

Referral ownership is intentionally narrower than general staff access.

Canonical referral-owner personas are:

```text
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

A referral owner must also be:

```text
an existing Frappe User
enabled
a System User
backed by an approved active OMC Staff Profile
holding an effective referral-capable OMC role
```

`Administrator` is explicitly not treated as a referral-code owner.

When a staff profile becomes eligible, referral automation can create/reactivate the user's `OMC Referral` and sync:

```text
OMC Staff Profile.referral_record
OMC Staff Profile.own_referral_code
```

When the user is no longer eligible, the referral record is made inactive and the Staff Profile referral linkage is cleared.

Customers do **not** own their own referral code. Referred-customer attribution belongs on the customer side, while the referral code belongs to the eligible staff referrer.

## 10.1 Assisted-service role declarations

The current referral/assisted-service capability declarations also define:

```text
Walk-in customer roles:
- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Consultant
- OMC Tax Associate
- OMC Business Partner
- System Manager

All-customer assist roles:
- OMC Admin
- OMC Manager
- System Manager

Referral administration roles:
- OMC Admin
- OMC Manager
- System Manager
```

These declarations do not bypass normal endpoint checks, customer resolution, assignment, or workflow validation.

---

# 11. Record-scope rules

Capabilities answer **what kind of action** a user may perform. Object checks answer **which records** the user may perform it on.

Both are required.

## 11.1 Customer ownership

Customer endpoints must continue to verify relationships such as:

```text
current user
    -> own OMC Customer Profile
    -> own Service Request
    -> own Document
    -> own Payment
    -> own Support Ticket
    -> own Notification
```

Knowing a record name or URL must never grant access.

## 11.2 Staff assignment/relevance

Specialist staff access must be constrained by the relevant scope model.

Examples:

- Consultants/Tax Associates/Business Partners: assigned service cases and tasks.
- Document Reviewer: document review queue plus related customer/request context.
- Finance Reviewer: payment review queue plus related customer/request context.
- Support Agent: support/lead work plus only the customer/service context needed for that work.
- Manager/Admin: broader operational scope according to canonical capabilities.

## 11.3 Workflow-state checks

A valid capability and valid record scope still do not mean every transition is legal.

Examples:

```text
review document
    -> correct reviewer capability
    -> correct document/request relationship
    -> document is in a reviewable state

review payment
    -> finance capability
    -> correct payment/request relationship
    -> payment is in a reviewable state

complete assigned service work
    -> assigned-service capability
    -> current user is authorised for the case/task
    -> required workflow gates are satisfied
```

---

# 12. Frappe Role and DocPerm setup

Canonical role/permission synchronisation lives in:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/roles.py
```

and is called by the OMC lifecycle setup during install/migrate.

The setup is designed to be idempotent:

- create missing canonical roles;
- keep `OMC Customer` without Desk access;
- keep staff roles with Desk access;
- disable legacy OMC roles;
- rebuild canonical OMC DocPerm rows;
- preserve unrelated non-OMC user roles;
- clear permission caches after synchronisation.

Legacy declarations currently include:

```text
OMC Customer Applicant
OMC Customer Support
```

They are retired/disabled. Customer Applicant assignments can be migrated to `OMC Customer`; legacy role state must not be treated as the current authorisation model.

## 12.1 DocPerm is only the baseline

Frappe DocPerm is a first protection layer, not the complete mobile/internal security model.

The backend must still enforce:

```text
approval
capability
ownership or assignment
record relationship
workflow state
validated mutation payload
```

This is especially important for methods that use `ignore_permissions=True` internally after their own explicit guards.

## 12.2 Specialist DocPerm direction

Current setup grants specialist DocPerm only to the OMC records required for their work. Examples include:

- Support Agent: support tickets/messages, relevant customer/referral/manual-customer/service-request/notification records;
- Document Reviewer: service documents, required-document metadata, service request, related customer/referral/manual-customer/timeline records;
- Finance Reviewer: service payments, payment account read, service request, related customer/referral/manual-customer/timeline records;
- Consultant/Tax Associate/Business Partner: service request, service-document read, related customer/referral/manual-customer/timeline records.

These DocPerm rows must not be interpreted as permission to bypass guarded OMC endpoints or assignment scope.

---

# 13. Current permission-alignment note

The canonical API capability model intentionally makes these Admin-only:

```text
can_manage_staff
can_review_registrations
can_manage_business_settings
can_manage_settings
```

`roles.py` also gives `OMC Manager` broad Frappe DocPerm on OMC DocTypes except those listed in `MANAGER_BLOCKED_DOCTYPES`.

At the current repository state, `OMC Staff Profile` is not included in that blocked list. Therefore direct Desk-level Staff Profile permissions should be reviewed before production if the intended rule remains that Manager cannot manage staff.

This does not change the API capability contract above; it is an explicit permission-alignment hardening item so documentation does not overstate the current Desk boundary.

---

# 14. Backend enforcement rules

## 14.1 Never authorise from UI visibility

This is invalid:

```text
button hidden in Flutter
therefore action is secure
```

Every protected backend method must enforce its own authority.

## 14.2 Never use internal-workspace access as universal authority

This is not sufficient:

```python
if can_access_internal_workspace(user):
    allow_sensitive_action()
```

The operation must require the relevant capability and scope.

Conceptually:

```python
require_capability("can_review_documents")
require_document_scope(document)
require_reviewable_state(document)
```

## 14.3 Never grant staff access from Employee status alone

This is invalid:

```text
ERP Employee.status = Active
therefore OMC staff approved
```

Correct model:

```text
Employee Active
+
User enabled
+
OMC Staff Profile Active
+
OMC approval Approved
+
is_active = 1
+
effective OMC staff persona
```

## 14.4 Never make pending staff a customer fallback

A System User/Employee/Staff Profile identity remains internal even when pending.

## 14.5 Never mutate a shared Role Profile to solve OMC persona assignment

Use the Staff Profile persona unless there is a deliberate ERP/Frappe reason to change the shared Role Profile itself.

## 14.6 Never auto-merge identity collisions

If customer activation encounters an existing User identity collision, the flow moves to review rather than granting or merging identity based on a guess.

---

# 15. Flutter contract

Flutter consumes backend-authored session/capability state and uses it for navigation and presentation.

The Flutter layer may:

- route guest/customer/internal states;
- hide unavailable internal modules;
- disable operations the user cannot perform;
- present pending-approval state;
- expose only role-relevant navigation.

Flutter must not become the authority for:

- staff approval;
- customer approval;
- capability calculation;
- ownership;
- assignment;
- document/payment review permission;
- service workflow transitions;
- staff/referral eligibility.

The backend remains authoritative even if a Flutter route is reached manually.

---

# 16. Operational examples

## Example A — active ERP Employee, pending OMC approval

```text
Frappe User = System User
ERP Employee = Active
OMC Staff Profile = Pending / Pending Review / is_active 0
```

Result:

```text
identity domain = internal
internal workspace = denied
internal capabilities = false
customer fallback = denied
```

## Example B — approved Consultant persona using an existing ERP Role Profile

```text
User Role Profile = Operations
OMC Staff Profile.staff_role = OMC Consultant
OMC Staff Profile = Active / Approved / is_active 1
Employee = Active
```

Result:

```text
Role Profile remains unchanged
OMC Consultant becomes an effective OMC persona
consultant capabilities are enabled
service access remains assignment-scoped
```

## Example C — approved staff profile but no OMC persona

```text
Staff Profile = Active / Approved / is_active 1
staff_role = blank
no recognised direct OMC staff role
```

Result:

```text
ordinary staff approval is insufficient
no effective OMC staff role
internal workspace remains denied
```

## Example D — referral-capable consultant is suspended

Before suspension:

```text
OMC Consultant
Active / Approved / is_active 1
referral record active
```

After suspension/revocation:

```text
staff no longer referral-eligible
referral record becomes inactive
Staff Profile referral linkage is cleared
referral code no longer resolves as active
```

## Example E — Manager vs Admin

Manager may supervise broad operational work, reassign service cases, retry exhausted sync, review documents/payments, and manage normal operations.

Admin additionally owns the canonical application-management capabilities for settings, staff, registration review, and business settings.

---

# 17. Validation expectations

Role/security changes are incomplete until validated at both capability and object-scope levels.

Minimum regression coverage should include:

```text
Guest
Pending Customer
Approved Customer
Imported customer before activation
Imported customer after activation
Pending internal System User
Approved OMC Admin
Approved OMC Manager
Approved OMC Support Agent
Approved OMC Document Reviewer
Approved OMC Finance Reviewer
Approved OMC Consultant
Approved OMC Tax Associate
Approved OMC Business Partner
System Manager / Administrator override
```

For each persona, tests should include both:

```text
allowed action -> succeeds
forbidden action -> fails closed
```

and where scope matters:

```text
own/assigned/related record -> succeeds
unrelated/unassigned record -> denied
```

Latest recorded repository validation after the current Staff Profile/persona, referral, migration, and customer-activation work:

```text
Backend OMC suite:            591 / 591 passed
Customer activation tests:      8 / 8 passed
Flutter analyze:              No issues found
Flutter suite:                326 / 326 passed
Router policy parity suite:    51 / 51 passed
```

These numbers are evidence for the tested snapshot only; rerun the relevant suites after any role, permission, workflow, or identity change.

---

# 18. Source locations

Primary implementation files for this architecture:

```text
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/access.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/staff_profile.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/roles.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/lifecycle.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/referral_capabilities.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/referral_automation.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/referrals.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/omc_app/doctype/omc_staff_profile/
```

Customer lifecycle and activation are implemented separately from staff authorisation and should remain separate.

---

# 19. Final architecture summary

```text
CUSTOMER AUTHORITY

Frappe User when login exists
        |
OMC Customer Profile
        |
customer lifecycle + approval
        |
ownership-scoped customer capabilities


STAFF AUTHORITY

Frappe User
        |
internal identity classification
        |
OMC Staff Profile approval gate
        |
effective OMC staff role(s)
        |
canonical capability union
        |
assignment/relevance/record/workflow checks
        |
protected internal operation
```

The defining OMC security rule is:

> **A role does not replace approval, a capability does not replace record scope, and Flutter visibility does not replace backend authorisation.**
