# OMC App Role and Access Guide

This document is the canonical functional guide for role behavior across the OMC Flutter app and Frappe backend.

Implementation remains the source of truth, especially:

- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/roles.py`
- `backend_omc_app/frappe-bench/apps/omc_app/omc_app/permissions.py`
- backend capability and mobile API modules
- Flutter authentication, routing, shell navigation, and capability checks

Any mismatch between this guide and implementation is a defect.

---

## 1. Access-control principles

1. **Default deny** — authenticated users do not gain access merely because a route or endpoint exists.
2. **Backend enforcement** — hidden UI is not security; APIs must enforce the same permission.
3. **Capabilities drive Flutter** — routes, navigation, home actions, and controls use backend capabilities.
4. **Ownership and assignment matter** — customers access only their own records; specialists access assigned or relevant records.
5. **Least privilege** — every role receives only the minimum access needed.
6. **No role escalation from profile data** — signup metadata never grants staff permissions.
7. **UI/API parity** — a hidden screen, direct route, and direct API call must all follow the same rule.

---

## 2. Canonical roles

### Portal role

- `OMC Customer`

### Internal staff roles

- `OMC Admin`
- `OMC Manager`
- `OMC Support Agent`
- `OMC Document Reviewer`
- `OMC Finance Reviewer`
- `OMC Consultant`
- `OMC Tax Associate`
- `OMC Business Partner`

### Platform role

- `System Manager`

`System Manager` is a Frappe platform role, not a normal OMC operational persona.

### Legacy roles

- `OMC Customer Applicant`
- `OMC Customer Support`

Legacy roles remain only for compatibility and must not be assigned to new users.

---

## 3. Account types

### OMC Customer

- Frappe `Website User`
- Mobile/customer experience
- Access controlled by customer-profile ownership, approval state, backend capabilities, and access state

### Internal staff

All active OMC staff roles use Frappe `System User` accounts.

A user must not be treated as internal staff merely because the user is authenticated.

---

## 4. Customer lifecycle

Public signup assigns only `OMC Customer`.

Expected flow:

1. Signup creates or updates the Frappe User.
2. An `OMC Customer Profile` is created or linked.
3. The account remains a Website User.
4. Initial profile state is normally:
   - `customer_status = Pending`
   - `approval_status = Pending Review`
5. OMC Admin or OMC Manager reviews the profile.
6. Approved profiles normally become:
   - `customer_status = Active`
   - `approval_status = Approved`
7. Flutter unlocks protected features from backend capabilities and access state.

### Guest

May access only explicitly public areas, such as service catalogue, onboarding, branding, login, and signup.

Must not access customer data, service requests, documents, notifications, payments, or internal workspaces.

### Pending customer

May use only the limited pending experience. Approved-only actions remain locked.

### Approved customer

May access only the customer's own profile, service requests, documents, progress, payments where exposed, notifications, support features, and approved customer tools.

All customer access is ownership-scoped.

---

## 5. Role behavior

### OMC Admin

**Purpose:** full OMC application administration.

May generally:

- access all OMC operational records;
- access all service requests, customer profiles, tasks, leads, and support tickets;
- review documents and payments;
- manage timelines, notifications, services, branding, mobile settings, and other configuration;
- create, update, delete, import, export, print, email, report, and share where supported;
- submit, cancel, or amend submittable DocTypes where supported.

Normal Frappe and special-DocType restrictions still apply.

**Record scope:** all relevant OMC records.

### OMC Manager

**Purpose:** senior operational administration without destructive or sensitive configuration powers.

May generally:

- manage daily operations;
- review and approve customer profiles;
- access operational service records, customer profiles, tasks, support work, document review, and payment review where capabilities permit;
- coordinate staff and update service progress.

Must not:

- delete records through normal role permissions;
- share records through normal role permissions;
- manage Admin-only configuration.

Blocked configuration includes branding, mobile settings, quick actions, services, service categories, service form fields, required documents, stage templates, banners, onboarding slides, FAQs, knowledge articles, announcements, expense categories, payment accounts, and tax configuration.

**Record scope:** broad operational scope excluding blocked configuration.

### OMC Support Agent

**Purpose:** customer support, enquiries, leads, tickets, communication, and support tasks.

May:

- read/create/update leads;
- read/create/update support tickets and messages;
- read relevant customer profiles;
- read or create relevant service requests where the workflow allows;
- read/create/update support-domain tasks;
- read/create relevant notifications.

Must not review documents or payments as a reviewer, manage configuration, or access unrelated service cases.

**Record scope:** support-domain records plus relevant or assigned service requests and tasks.

### OMC Document Reviewer

**Purpose:** verify customer-submitted service documents.

May:

- read/update service documents;
- read required-document definitions;
- read related service requests and customer profiles;
- create relevant timeline entries;
- read/update relevant assigned tasks.

Must not access payment review, unrelated cases, service configuration, or general service-status actions without an explicit capability.

**Record scope:** document-domain records and related context.

### OMC Finance Reviewer

**Purpose:** verify service payments and financial evidence.

May:

- read/update service payments;
- read payment accounts as reference data;
- read related service requests and customer profiles;
- create relevant timeline entries;
- read/update relevant assigned tasks.

Must not access document-review decisions, unrelated cases, configuration, or general service-status actions without an explicit capability.

**Record scope:** finance-domain records and related context.

### OMC Consultant

**Purpose:** process assigned general consulting or service-delivery cases.

May:

- read/update assigned service requests;
- read related documents and customer profiles;
- create relevant timeline entries;
- read/update assigned tasks;
- update assigned service status only when the canonical capability permits it.

Must not access or update unassigned cases, review payments, perform formal document-review decisions, reassign tasks without authority, manage configuration, delete, or share.

**Record scope:** assigned service requests, related records, and assigned tasks.

### OMC Tax Associate

**Purpose:** process assigned tax-related service cases.

May:

- read/update assigned service requests;
- read related documents and customer profiles;
- create relevant timeline entries;
- read/update assigned tasks;
- update assigned service status only when permitted.

Must not access unassigned cases, broad tax configuration, payment review, formal document-review decisions, or task reassignment without authority.

**Record scope:** assigned tax-related service requests and tasks.

### OMC Business Partner

**Purpose:** process assigned business-service cases.

May:

- read/update assigned service requests;
- read related documents and customer profiles;
- create relevant timeline entries;
- read/update assigned tasks;
- update assigned service status only when permitted.

Must not access unassigned cases, unrelated review domains, configuration, or task reassignment without authority.

**Record scope:** assigned business-related service requests and tasks.

---

## 6. Functional domain separation

### Support domain

Primary role: `OMC Support Agent`

Includes leads, support tickets, support messages, support notifications, and support tasks.

### Document domain

Primary role: `OMC Document Reviewer`

Includes service documents, required-document references, document-review status, and document timeline activity.

### Finance domain

Primary role: `OMC Finance Reviewer`

Includes service payments, payment-account reference data, payment-review status, and payment timeline activity.

### Service specialist domain

Primary roles:

- `OMC Consultant`
- `OMC Tax Associate`
- `OMC Business Partner`

Includes assigned service requests, related profiles and documents, assigned tasks, and relevant timelines.

Domains remain separate unless multiple roles or capabilities are deliberately assigned.

---

## 7. Service-request rules

- Admin and authorized Manager may receive broad service-case access.
- Reviewers may see service requests related to their review work.
- Support Agent may see service requests relevant to support operations.
- Consultant, Tax Associate, and Business Partner are normally assignment-scoped.
- Assigned-only users may view and update only assigned service cases.
- Unassigned access must raise a permission error, including direct API calls.

---

## 8. Task rules

1. `assigned_to` must be an enabled Frappe user.
2. The assignee must be a `System User`.
3. A customer or Website User must not receive an internal OMC Task.
4. Specialists work only on assigned tasks.
5. Specialists must not reassign existing tasks without authority.
6. Task visibility follows role and assignment scope.
7. Related service request, support ticket, and customer profile references must remain consistent.

---

## 9. Document ownership rules

1. The customer must own or be authorized for the target service request.
2. The uploaded file must be valid.
3. A file already attached to another service request must not be reused.
4. A mismatched `attached_to_name` must raise a permission error.
5. Customer upload actions and reviewer decisions remain separate capabilities.

---

## 10. Notification ownership rules

### Customer notification

The notification's `customer_profile` must exactly match the current customer's profile.

Blank or mismatched ownership is rejected.

### Internal notification

The notification's `recipient_user` must exactly match the current user.

Blank or mismatched recipients are rejected.

The same rules apply to listing, detail, marking one notification read, and bulk-read actions.

---

## 11. Flutter rules

Flutter uses backend capabilities and access state for:

- route guards;
- shell navigation;
- home actions;
- service actions;
- internal workspace entry;
- document review;
- payment review;
- service-status controls;
- customer-only features.

Public, customer, internal, and specialist routes must be explicitly classified.

Unclassified authenticated routes are denied.

A navigation item appears only when its destination route is allowed.

---

## 12. Backend rules

Every protected endpoint independently verifies:

- authentication;
- canonical capability;
- customer ownership;
- functional domain;
- record assignment;
- approval or access state where relevant.

The backend must not trust client-provided roles, hidden UI state, route visibility, profile metadata, or record IDs without ownership/assignment checks.

---

## 13. Multi-role users

A staff user may intentionally hold multiple OMC roles.

- Capabilities are additive only where deliberately designed.
- Record-level restrictions still apply.
- Assignment restrictions are not automatically removed.
- Admin capability may supersede narrower operational limits.
- Missing legitimate access should be fixed in the capability model, not by casually combining roles.

---

## 14. Role assignment guidance

- Assign `OMC Admin` for full system and configuration ownership.
- Assign `OMC Manager` for operations and approvals without destructive/configuration powers.
- Assign `OMC Support Agent` for leads, tickets, enquiries, and customer communication.
- Assign `OMC Document Reviewer` for document verification.
- Assign `OMC Finance Reviewer` for payment verification.
- Assign `OMC Consultant` for assigned general service cases.
- Assign `OMC Tax Associate` for assigned tax cases.
- Assign `OMC Business Partner` for assigned business cases.
- Assign `OMC Customer` for mobile/customer portal accounts.

---

## 15. Always-prohibited behavior

Unless a future capability explicitly permits it, no non-admin role may:

- bypass assignment scope;
- access another customer's private data;
- read blank-owner notifications;
- reuse a file attached to another service request;
- convert profile metadata into a staff role;
- access blocked configuration by direct URL;
- rely only on hidden UI for security;
- assign internal tasks to Website Users;
- reassign tasks outside its authority;
- use an unclassified route;
- call a protected API without the matching capability.

---

## 16. Required production smoke tests

Test each role with a real account.

### Guest

- public routes open;
- login/signup open;
- protected customer and internal routes blocked;
- protected APIs rejected.

### Pending Customer

- limited pending experience shown;
- approved-only actions locked;
- other-customer data blocked.

### Approved Customer

- own profile, requests, documents, and notifications work;
- other-customer records rejected.

### OMC Admin

- broad operations and configuration work;
- all review domains work.

### OMC Manager

- operational work and customer review work;
- delete/share blocked;
- blocked configuration inaccessible.

### OMC Support Agent

- leads, tickets, and messages work;
- unrelated review domains and cases blocked.

### OMC Document Reviewer

- document review works;
- payment review and unrelated cases blocked.

### OMC Finance Reviewer

- payment review works;
- document review and unrelated cases blocked.

### OMC Consultant

- assigned cases/tasks work;
- unassigned cases, reassignment, configuration, and review-only domains blocked.

### OMC Tax Associate

- assigned tax cases/tasks work;
- unassigned cases and broad tax configuration blocked.

### OMC Business Partner

- assigned business cases/tasks work;
- unassigned cases, review domains, and configuration blocked.

---

## 17. Regression requirements

Automated tests must continue covering:

- canonical role provisioning;
- manager configuration restrictions;
- specialist domain boundaries;
- assignment-scoped service requests and tasks;
- invalid task assignees;
- prohibited task reassignment;
- cross-service uploaded-file reuse rejection;
- blank/mismatched notification ownership rejection;
- exact notification-owner access;
- Flutter route and shell capability alignment.

Any new role, route, endpoint, screen, DocType, or action must update:

1. canonical role constants;
2. capability mapping;
3. backend enforcement;
4. query and record-level permissions;
5. Flutter route policy;
6. Flutter navigation visibility;
7. automated tests;
8. this document.

---

## 18. Current state

The role and access-control implementation is functionally complete except for final real-account end-to-end smoke verification across Guest, Pending Customer, Approved Customer, and all active internal roles.

No role is production-verified until its real-environment smoke test is executed and recorded.
