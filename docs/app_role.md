# OMC App Role System and Capability Implementation Plan

## Purpose

OMC App has two user-facing sides:

1. Customer App
2. Internal App

The interface should remain simple, but backend authorization must be role-based and capability-driven.

Internal users must not automatically receive access to every internal action merely because they can open the Internal App.

This document defines the final role architecture, Frappe roles, capabilities, permission boundaries, implementation phases, migration strategy, and validation requirements.

---

# 1. Core Access Model

## 1.1 Customer Side

The Customer App supports three access states:

### Guest

A user who is not logged in.

Allowed access:

* Public service catalogue
* Public service details
* FAQs
* Knowledge articles
* Tax calculator
* Signup
* Login
* Guest-safe onboarding and banners

Not allowed:

* Service requests
* Customer dashboard
* Customer documents
* Payments
* Notifications
* Support tickets
* Customer profile records
* Any internal functionality

---

### Pending Customer

A registered customer whose account has not yet been approved.

Allowed access:

* Everything available to guests
* Own profile
* Approval status
* Pending-account information
* Logout and account settings

Not allowed:

* Creating service requests
* Viewing private customer service cases
* Uploading documents
* Viewing payments
* Uploading payment receipts
* Creating support tickets
* Viewing customer notifications

---

### Approved Customer

A verified and active customer.

Allowed access:

* Public service catalogue
* Customer dashboard
* Own service requests
* Own service request details
* Own documents
* Uploading own service documents
* Own payments
* Uploading own payment receipts
* Own support tickets
* Own customer notifications
* Own profile and preferences

Customer rule:

> An approved customer may only view or mutate records belonging to their own customer profile.

An approved customer must never be allowed to:

* View another customer
* View another customer's service request
* View another customer's documents
* View another customer's payments
* View another customer's support tickets
* Review documents
* Review payments
* Change internal service statuses
* View internal notes
* Manage leads
* Manage internal tasks
* Access the Internal App

---

# 2. Internal Side

The Internal App is one application area shared by OMC staff.

All internal users may use the same shell and overall navigation structure, but modules, records, and actions must be controlled through capabilities.

The following principle is mandatory:

> Internal workspace access does not grant permission to perform every internal action.

Entering the Internal App only means:

```text
can_access_internal_workspace = true
```

Every sensitive read or mutation must require an additional specific capability.

---

# 3. Built-in Frappe Roles

The following roles must be created automatically during app installation or migration.

These roles must be shipped with the OMC Frappe app so administrators do not need to create them manually.

## 3.1 OMC Customer

Purpose:

* Customer portal identity
* Assigned to registered customer accounts
* Used together with customer profile approval status

User type:

```text
Website User
```

This role alone must not grant approved-customer capabilities.

Approved access must still depend on:

```text
customer_status = Active
approval_status = Approved
```

---

## 3.2 OMC Admin

Purpose:

* Full OMC application administration
* Full operational access
* Full customer and workflow management

User type:

```text
System User
```

Capabilities:

```text
can_access_internal_workspace
can_manage_customers
can_manage_leads
can_manage_tasks
can_update_service_status
can_review_documents
can_review_payments
can_view_support_tickets
can_reply_support_tickets
can_update_support_ticket_status
can_assign_support_tickets
can_view_internal_notes
can_manage_settings
```

Data access:

* All customers
* All leads
* All service requests
* All documents
* All payments
* All support tickets
* All tasks
* All internal notes
* OMC settings

---

## 3.3 OMC Manager

Purpose:

* Daily operational management
* Workflow supervision
* Team and service oversight

User type:

```text
System User
```

Capabilities:

```text
can_access_internal_workspace
can_manage_customers
can_manage_leads
can_manage_tasks
can_update_service_status
can_review_documents
can_review_payments
can_view_support_tickets
can_reply_support_tickets
can_update_support_ticket_status
can_assign_support_tickets
can_view_internal_notes
```

Recommended restriction:

```text
can_manage_settings = false
```

A manager may receive settings access later if explicitly required.

---

## 3.4 OMC Support Agent

Purpose:

* Customer support
* Lead handling
* Customer communication
* Support-ticket operations

User type:

```text
System User
```

Capabilities:

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
```

Not allowed:

```text
can_review_documents = false
can_review_payments = false
can_manage_settings = false
can_view_all_financial_data = false
```

Support agents should only receive the customer and service information required to resolve support cases.

---

## 3.5 OMC Document Reviewer

Purpose:

* Document verification
* Document approval and rejection
* Document review remarks

User type:

```text
System User
```

Capabilities:

```text
can_access_internal_workspace
can_view_document_queue
can_view_document_attachments
can_review_documents
can_view_related_customer_summary
can_view_related_service_cases
can_view_internal_notes
can_manage_assigned_tasks
```

Not allowed:

```text
can_review_payments = false
can_manage_support_tickets = false
can_manage_leads = false
can_manage_settings = false
```

Document reviewers should only see customer information required for document verification.

---

## 3.6 OMC Finance Reviewer

Purpose:

* Payment verification
* Receipt review
* Payment approval and rejection
* Finance review remarks

User type:

```text
System User
```

Capabilities:

```text
can_access_internal_workspace
can_view_payment_queue
can_view_payment_receipts
can_review_payments
can_view_related_customer_summary
can_view_related_service_cases
can_view_internal_notes
can_manage_assigned_tasks
```

Not allowed:

```text
can_review_documents = false
can_manage_support_tickets = false
can_manage_leads = false
can_manage_settings = false
```

Finance reviewers should only see customer and service information required for payment verification.

---

## 3.7 OMC Consultant

Purpose:

* Assigned service-case work
* Customer service execution
* Task completion
* Service progress updates

User type:

```text
System User
```

Capabilities:

```text
can_access_internal_workspace
can_view_assigned_service_cases
can_update_assigned_service_status
can_manage_assigned_tasks
can_view_related_customer_summary
can_view_related_documents
can_view_internal_notes
```

Not allowed by default:

```text
can_view_all_customers = false
can_review_documents = false
can_review_payments = false
can_manage_support_tickets = false
can_manage_settings = false
```

---

## 3.8 OMC Tax Associate

Purpose:

* Tax-related service execution
* Assigned tax tasks
* Relevant service and customer access

User type:

```text
System User
```

Capabilities should initially match OMC Consultant, with future tax-specific capabilities added only when needed.

---

## 3.9 OMC Business Partner

Purpose:

* Assigned partner-managed cases
* Assigned operational tasks
* Limited customer and service visibility

User type:

```text
System User
```

Capabilities should initially match OMC Consultant but remain assignment-scoped.

---

# 4. Capability Matrix

| Capability                  | Admin | Manager |  Support | Documents |       Finance | Consultant |
| --------------------------- | ----: | ------: | -------: | --------: | ------------: | ---------: |
| Access internal workspace   |   Yes |     Yes |      Yes |       Yes |           Yes |        Yes |
| Manage settings             |   Yes |      No |       No |        No |            No |         No |
| View all customers          |   Yes |     Yes |  Limited |   Related |       Related |   Assigned |
| Manage customers            |   Yes |     Yes |  Limited |        No |            No |         No |
| Manage leads                |   Yes |     Yes |      Yes |        No |            No |   Optional |
| View all service cases      |   Yes |     Yes | Relevant |   Related |       Related |   Assigned |
| Create service for customer |   Yes |     Yes |      Yes |        No |            No |   Optional |
| Update service status       |   Yes |     Yes |  Limited |        No |            No |   Assigned |
| View document summaries     |   Yes |     Yes | Relevant |       Yes |       Related |    Related |
| Open document attachments   |   Yes |     Yes |  Limited |       Yes | No by default |    Related |
| Review documents            |   Yes |     Yes |       No |       Yes |            No |         No |
| View payment summaries      |   Yes |     Yes |  Limited |   Limited |           Yes |    Limited |
| Open payment receipts       |   Yes |     Yes |       No |        No |           Yes |         No |
| Review payments             |   Yes |     Yes |       No |        No |           Yes |         No |
| View support tickets        |   Yes |     Yes |      Yes |        No |            No |   Optional |
| Reply as support            |   Yes |     Yes |      Yes |        No |            No |         No |
| Update ticket status        |   Yes |     Yes |      Yes |        No |            No |         No |
| Assign support tickets      |   Yes |     Yes |      Yes |        No |            No |         No |
| Manage all tasks            |   Yes |     Yes |       No |        No |            No |         No |
| Manage assigned tasks       |   Yes |     Yes |      Yes |       Yes |           Yes |        Yes |
| View internal notes         |   Yes |     Yes | Relevant |  Relevant |      Relevant |   Assigned |

---

# 5. Canonical Capabilities

The backend must return one canonical capability payload.

Recommended internal capability keys:

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
```

Existing customer capabilities should remain:

```text
can_view_public_catalogue
can_view_public_content
can_use_tax_calculator
can_create_service_request
can_upload_documents
can_track_requests
can_view_documents
can_view_payments
can_upload_payment_receipt
can_upload_payment_receipts
can_create_support_ticket
can_view_support_tickets
can_view_customer_dashboard
can_access_customer_dashboard
can_view_customer_notifications
```

---

# 6. Frappe Role Creation

## 6.1 Automatic Setup

The OMC Frappe app must create all required roles automatically.

Recommended location:

```text
omc_app/setup/roles.py
```

The setup must be idempotent.

Running it multiple times must not:

* create duplicate roles
* create duplicate role assignments
* remove unrelated user roles
* reset administrator configuration unexpectedly

Roles to create:

```text
OMC Customer
OMC Admin
OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

The app installation and migration workflow should call the role setup function.

Recommended integration points:

```text
after_install
after_migrate
```

---

## 6.2 Role Profile Support

Optional but recommended Frappe Role Profiles:

```text
OMC Administrator
OMC Operations Manager
OMC Customer Support
OMC Document Review
OMC Finance Review
OMC Consultant
```

Role Profiles make staff account setup easier.

Example:

```text
OMC Customer Support
- OMC Support Agent
```

Example combined profile:

```text
OMC Operations Manager
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
```

Role Profiles must not replace backend capability checks.

---

# 7. Frappe DocType Permissions

Frappe DocType permissions should provide a baseline protection layer.

Backend endpoint checks remain mandatory, especially where code uses:

```python
ignore_permissions=True
```

## Recommended permission direction

### OMC Customer Profile

* OMC Admin: full
* OMC Manager: full
* OMC Support Agent: read/write limited by backend endpoint
* Document Reviewer: related read only through guarded endpoint
* Finance Reviewer: related read only through guarded endpoint
* Consultant: assigned related read only through guarded endpoint
* OMC Customer: own-profile access through guarded API only

### OMC Service Request

* Admin: full
* Manager: full
* Support: relevant read/create
* Consultant/Associate/Partner: assigned read/update
* Document Reviewer: related read
* Finance Reviewer: related read
* Customer: own records through guarded API only

### OMC Service Document

* Admin: full
* Manager: full
* Document Reviewer: read/write
* Consultant: related read where needed
* Finance Reviewer: no attachment access by default
* Customer: own visible documents through guarded API only

### OMC Service Payment

* Admin: full
* Manager: full
* Finance Reviewer: read/write
* Other internal roles: summary-only through guarded APIs
* Customer: own visible payments through guarded API only

### OMC Support Ticket

* Admin: full
* Manager: full
* Support Agent: read/write
* Other internal roles: no access by default
* Customer: own tickets through guarded API only

### OMC Lead

* Admin: full
* Manager: full
* Support Agent: read/write
* Other roles: no access unless explicitly required

### OMC Internal Task

* Admin: full
* Manager: full
* Internal users: assigned tasks only through guarded APIs

---

# 8. Backend Enforcement Rules

## 8.1 Never use workspace access as universal authorization

This pattern is not sufficient:

```python
if _can_access_internal_workspace():
    allow()
```

It should only be used to determine whether the user may enter the Internal App.

Sensitive operations must use specific checks:

```python
require_capability("can_review_documents")
require_capability("can_review_payments")
require_capability("can_update_support_ticket_status")
require_capability("can_manage_customers")
```

---

## 8.2 Recommended Shared Helpers

Create or consolidate helpers such as:

```python
get_current_capabilities()
require_internal_workspace()
require_capability(capability_name)
require_any_capability(*capability_names)
require_role_set(roles, message)
```

Recommended object-level helpers:

```python
require_customer_owns_service_request(service_request)
require_customer_owns_document(document)
require_customer_owns_payment(payment)
require_customer_owns_support_ticket(ticket)

require_assigned_service_case_access(service_request)
require_related_customer_access(customer_profile)
```

---

## 8.3 Customer Ownership Checks

Every customer read or mutation must verify ownership.

Required examples:

```text
service_request.customer_profile == current_customer_profile.name
document.service_request belongs to current customer
payment.service_request belongs to current customer
support_ticket.customer_profile == current_customer_profile.name
notification.customer_profile == current_customer_profile.name
```

Do not rely only on route visibility or Flutter navigation.

---

## 8.4 Internal Object Scope

Internal roles must use scoped access where appropriate.

Examples:

Support Agent:

```text
support tickets
related customer
related service request
assigned or relevant leads
```

Document Reviewer:

```text
document queue
related service request
related customer verification fields
```

Finance Reviewer:

```text
payment queue
receipt attachment
related service summary
limited customer identity
```

Consultant:

```text
assigned service requests
assigned tasks
related documents
related internal notes
```

---

# 9. Required Backend Corrections

The following issues should be corrected during implementation.

## 9.1 Support Ticket Mutations

Restrict these endpoints to support-capable roles:

```text
update_support_ticket_status
assign_support_ticket
internal support replies
```

Required capability checks:

```text
can_update_support_ticket_status
can_assign_support_tickets
can_reply_support_tickets
```

A generic internal user must not automatically reply as OMC Support.

---

## 9.2 Customer Payment Receipt Upload

Customer receipt upload must require:

```text
approved customer
payment belongs to current customer
can_upload_payment_receipt = true
```

Internal users must not use the customer receipt-upload endpoint.

Finance review must use a separate endpoint.

---

## 9.3 Payment Review

Move payment review into a dedicated endpoint such as:

```text
omc_app.api.payments.review_payment_receipt
```

Required capability:

```text
can_review_payments
```

The Flutter app should stop calling the legacy payment review method after migration.

---

## 9.4 Document Reads

Separate document access into levels:

### Customer document view

* Own documents only
* Only customer-visible rows
* No internal remarks
* No reviewer-sensitive metadata

### Internal document summary

* Case-level document status
* Counts and required-document information
* No attachment unless role permits it

### Document review detail

* Full attachment access
* Review fields
* Restricted to document reviewers, managers, and admins

---

## 9.5 Payment Reads

Separate payment access into levels:

### Customer payment view

* Own payments only
* Customer-visible data
* Own receipt and payment instructions

### Internal payment summary

* Status and amount summary
* No receipt attachment unless required

### Finance review detail

* Full receipt
* Payment reference
* Review remarks
* Restricted to finance reviewers, managers, and admins

---

## 9.6 Service Request Creation for Customers

Both internal service-request creation endpoints must use the same authorization rule.

Recommended capability:

```text
can_create_service_for_customer
```

Suggested roles:

```text
OMC Admin
OMC Manager
OMC Support Agent
```

Consultants may receive it later only if required.

---

## 9.7 Read Endpoints Must Not Create Records

`get_payments()` or similar read endpoints must not create payment records or mutate workflow state.

Payment creation should happen through an explicit workflow transition such as:

```text
required documents approved
service stage changed to payment required
staff explicitly opens payment
```

---

# 10. Flutter Implementation

## 10.1 Two App Modes

Keep only two high-level UI modes:

```text
Customer App
Internal App
```

Customer mode handles:

```text
Guest
Pending Customer
Approved Customer
```

Internal mode handles all internal roles.

---

## 10.2 Capability-Aware Navigation

Routes must require explicit capabilities.

Examples:

```text
Internal operations center:
can_access_internal_workspace

Document review:
can_view_document_queue

Payment review:
can_view_payment_queue

Support center:
can_view_support_tickets

Customer management:
can_manage_customers or can_view_relevant_customers

Lead management:
can_manage_leads

Settings:
can_manage_settings
```

Unknown authenticated routes must remain denied by default.

---

## 10.3 Capability-Aware Providers

Providers should avoid fetching protected data when access is absent.

Example behavior:

```dart
if (!capabilities.canViewPaymentQueue) {
  return const [];
}
```

For strict screens, providers may return an access-denied state instead of an empty list.

Providers requiring capability guards include:

```text
customer list and detail
lead list and detail
task list and detail
internal service cases
document review queue
document review detail
payment review queue
payment review detail
support ticket list and detail
internal notes
settings
```

---

## 10.4 Mutation Guards

Controllers or repositories must check capability before invoking mutations.

Examples:

```text
review document:
can_review_documents

review payment:
can_review_payments

change service status:
can_update_service_status or can_update_assigned_service_status

reply as support:
can_reply_support_tickets

change support status:
can_update_support_ticket_status

assign support ticket:
can_assign_support_tickets

manage customer:
can_manage_customers

manage lead:
can_manage_leads

manage task:
can_manage_tasks or can_manage_assigned_tasks
```

Flutter checks improve UX, but backend checks remain authoritative.

---

# 11. Internal Notes

Internal notes must never be returned to customers.

Recommended note access:

* Admin: all
* Manager: all
* Support Agent: related support/customer notes
* Document Reviewer: related document/service notes
* Finance Reviewer: related payment/service notes
* Consultant: assigned-case notes

Internal note endpoints must require:

```text
can_view_internal_notes
```

They must also verify record scope.

---

# 12. User Assignment Workflow

## 12.1 Customer Account

On signup:

```text
assign OMC Customer
set user_type = Website User
create or link OMC Customer Profile
set approval state to Pending
```

After approval:

```text
retain OMC Customer role
set customer_status = Active
set approval_status = Approved
```

Do not create separate approved-customer and pending-customer roles unless future Frappe Desk permissions require them.

Customer approval state should remain profile-driven.

---

## 12.2 Internal Account

When creating an internal user:

```text
set user_type = System User
assign one or more OMC internal roles
```

Examples:

Support employee:

```text
OMC Support Agent
```

Finance employee:

```text
OMC Finance Reviewer
```

Operations manager:

```text
OMC Manager
```

Multi-function employee:

```text
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
```

Capabilities should be the union of all assigned roles.

---

# 13. Migration Strategy

## Phase 1 — Role Foundation

* Create canonical role constants
* Create all built-in Frappe roles
* Add idempotent installation and migration setup
* Remove or normalize legacy OMC role names
* Preserve existing valid internal users
* Ensure customer users remain Website Users
* Ensure internal users remain System Users

Deliverable:

```text
All required roles exist automatically after migrate.
```

---

## Phase 2 — Canonical Capability Engine

* Define role-to-capability mapping
* Return one canonical capability object
* Remove conflicting capability implementations
* Add unit tests for every role
* Verify multi-role capability union
* Verify Guest, Pending, Approved, and Internal states

Deliverable:

```text
One backend capability source of truth.
```

---

## Phase 3 — Backend Mutation Enforcement

Audit and secure:

* document review
* payment review
* service status updates
* support replies
* support status changes
* support assignment
* customer mutations
* lead mutations
* task mutations
* internal notes mutations
* internal service creation

Deliverable:

```text
Every mutation checks its specific capability.
```

---

## Phase 4 — Backend Read Enforcement

Audit and secure:

* customer list and detail
* service case list and detail
* document summary and attachment access
* payment summary and receipt access
* support ticket list and detail
* leads
* tasks
* internal notes

Deliverable:

```text
Every sensitive read checks role and object scope.
```

---

## Phase 5 — Flutter Provider and Controller Guards

* Add capability checks before protected fetches
* Add capability checks before mutations
* Replace route-only assumptions
* Clear stale protected provider data after logout or role change
* Add explicit access-denied states
* Remove legacy API method usage where replaced

Deliverable:

```text
Flutter UI, providers, controllers, and backend enforce the same policy.
```

---

## Phase 6 — Frappe Permission Alignment

* Configure DocType role permissions
* Review `ignore_permissions=True` usage
* Keep guarded API checks wherever permission bypass is necessary
* Add user permission or assignment filters where appropriate
* Verify Desk access does not exceed mobile access policy

Deliverable:

```text
Frappe Desk and mobile APIs follow the same authorization model.
```

---

## Phase 7 — Tests and Production Validation

Test each access state:

```text
Guest
Pending Customer
Approved Customer
OMC Admin
OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
OMC Consultant
Multi-role internal user
```

For every role, test:

```text
allowed read
forbidden read
allowed mutation
forbidden mutation
cross-customer access
direct endpoint invocation
deep-link navigation
stale session capability state
```

---

# 14. Required Security Test Matrix

## Customer tests

* Guest cannot access customer endpoints
* Pending customer cannot access approved-customer endpoints
* Approved customer can access own records
* Approved customer cannot access another customer's records
* Customer cannot invoke internal mutation endpoints
* Customer cannot read internal notes
* Customer cannot read archived/internal-only documents

## Support tests

* Support Agent can view support queue
* Support Agent can reply
* Support Agent can change support status
* Support Agent cannot review documents
* Support Agent cannot review payments
* Support Agent cannot access settings

## Document reviewer tests

* Document Reviewer can view review queue
* Document Reviewer can open allowed attachments
* Document Reviewer can approve/reject documents
* Document Reviewer cannot review payments
* Document Reviewer cannot reply as support
* Document Reviewer cannot change support status

## Finance reviewer tests

* Finance Reviewer can view payment queue
* Finance Reviewer can open receipt
* Finance Reviewer can approve/reject payment
* Finance Reviewer cannot review customer identity documents by default
* Finance Reviewer cannot reply as support
* Finance Reviewer cannot manage leads

## Consultant tests

* Consultant can view assigned service cases
* Consultant cannot view unrelated service cases
* Consultant can update allowed assigned stages
* Consultant cannot approve documents
* Consultant cannot approve payments
* Consultant cannot view all customers
* Consultant cannot manage settings

## Admin and manager tests

* Admin has all expected capabilities
* Manager has operational capabilities
* Manager settings access follows final policy
* Multi-role users receive the correct capability union

---

# 15. Validation Rules

Do not claim validation has passed unless actual terminal output is available.

Recommended Flutter validation:

```bash
cd ~/data_drive/app_omc/omc_app

flutter analyze
flutter test
git diff --check
```

Recommended backend validation:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench

bench --site <site-name> migrate
bench --site <site-name> run-tests --app omc_app
git diff --check
```

Focused backend authorization tests should be added before the full suite.

---

# 16. Implementation Principles

The following rules are mandatory throughout implementation:

1. Keep two high-level UI sides only:

   * Customer
   * Internal

2. Do not make every internal user a full administrator.

3. Create all OMC roles automatically through the Frappe app.

4. Use one canonical capability engine.

5. Treat capabilities as backend security rules, not only UI flags.

6. Check object ownership for every customer record.

7. Check assignment or domain scope for internal records.

8. Do not rely only on route protection.

9. Do not rely only on hidden buttons.

10. Do not use general internal access for domain-specific mutations.

11. Avoid exposing unnecessary customer PII.

12. Keep customer and internal endpoints separated where their workflows differ.

13. Keep read endpoints free from workflow mutations.

14. Preserve existing working functionality unless a security change requires adjustment.

15. Implement and validate one phase at a time.

---

# 17. Final Target Architecture

```text
OMC App
│
├── Customer Side
│   ├── Guest
│   ├── Pending Customer
│   └── Approved Customer
│
└── Internal Side
    ├── OMC Admin
    ├── OMC Manager
    ├── OMC Support Agent
    ├── OMC Document Reviewer
    ├── OMC Finance Reviewer
    ├── OMC Consultant
    ├── OMC Tax Associate
    └── OMC Business Partner
```

Final authorization chain:

```text
Session
→ Access state
→ Assigned roles
→ Canonical capabilities
→ Route permission
→ Provider/controller permission
→ Backend endpoint permission
→ Record ownership or assignment scope
```

This architecture keeps the product simple for users while making the backend secure, maintainable, scalable, and production-ready.
