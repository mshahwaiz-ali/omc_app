# OMC App — Detailed Product, Workflow, and Operations Guide

## 1. Purpose of this document

This document explains the OMC App in practical business language.

It is intended for:

- OMC House management;
- client representatives;
- operations staff;
- support, document, finance, and service teams;
- developers and deployment engineers;
- testers performing role-based verification.

The guide describes:

- what the platform does;
- who can use each part;
- how customer and staff workflows connect;
- how each major feature behaves;
- what OMC manages from Frappe Desk;
- which security and access rules apply;
- how the platform should be tested before release.

For installation commands and engineering setup, see [`README.md`](README.md).

For the complete role and capability matrix, see [`docs/app_role.md`](docs/app_role.md).

---

# 2. Executive summary

OMC App is a full-stack digital service platform for OMC House.

It combines:

1. a Flutter application for guests, customers, and authorised internal users;
2. a custom Frappe backend for data, workflows, permissions, and operations;
3. Frappe Desk for controlled business administration;
4. backend-managed content, services, cases, documents, payments, support, and customer records.

The operating model is:

```text
Customer or staff member uses the Flutter app
                    |
                    | Secure API requests
                    v
             Custom OMC backend
                    |
                    | Business rules and permissions
                    v
        Frappe Desk and OMC operational records
```

The customer experience should feel simple. The backend remains strict.

> The app may hide or lock a feature for user experience, but the backend must independently enforce every protected action.

---

# 3. Client-facing explanation

OMC House provides customers with a digital portal where they can:

- browse available OMC services;
- understand service requirements;
- create an account;
- wait for approval where verification is required;
- request services;
- upload supporting documents;
- track the progress of their cases;
- review payment instructions and receipt status;
- receive notifications;
- contact support;
- use tax and expense tools;
- manage their profile and settings.

OMC staff manage the business workflow from Frappe Desk and authorised internal modules, including:

- customer onboarding and approval;
- service catalogue management;
- service-case processing;
- document review;
- payment-receipt review;
- support tickets;
- leads;
- operational tasks;
- notifications and customer-facing content.

The mobile app and Frappe Desk use the same backend records, which keeps customers and staff aligned.

---

# 4. Platform sides

## 4.1 Customer side

The customer side supports three core states:

- Guest;
- Pending Customer;
- Approved Customer.

Each state receives a different set of routes, actions, and records.

## 4.2 Internal side

The internal side is used by authorised OMC personnel.

Internal access is capability-based. A staff member does not receive every action simply because the internal shell is visible.

For example:

- a Document Reviewer may review documents but not payments;
- a Finance Reviewer may review payment receipts but not documents;
- a Support Agent may manage support tickets but not application settings;
- a Consultant may access assigned cases but not every customer record;
- an Admin may manage the full OMC application.

## 4.3 Shared backend

Both sides use the same Frappe backend for:

- users and sessions;
- customer profiles;
- services;
- service requests;
- document records;
- payment records;
- support tickets;
- notifications;
- leads;
- tasks;
- tax configuration;
- expense data;
- content and settings.

---

# 5. User types and access states

## 5.1 Guest

A guest has not signed in.

### Guest users can

- open the app;
- view public home content;
- browse active services;
- open public service details;
- read approved FAQs and knowledge content;
- use guest-safe tax tools;
- view contact and support information;
- open login and signup.

### Guest users cannot

- create service requests;
- upload customer documents;
- view customer dashboards;
- track private service cases;
- view payments;
- view customer notifications;
- access customer support history;
- view another user's data;
- access internal workspace features.

### Expected app behaviour

When a guest opens a protected route, the app should redirect or show a clear access message without exposing private data.

Suggested wording:

```text
Sign in or create an account to continue.
```

---

## 5.2 Pending Customer

A Pending Customer has registered but has not yet been approved by OMC.

Typical state:

```text
customer_status = Pending
approval_status = Pending Review
```

### Pending customers can

- sign in;
- view their own profile;
- view approval status;
- browse active public services;
- read public content;
- use guest-safe utilities;
- update allowed profile fields;
- sign out and manage local settings.

### Pending customers cannot

- create a service request;
- upload service documents;
- view private case history;
- view payment records;
- submit payment receipts;
- create customer-specific support tickets;
- access internal tools.

Suggested message:

```text
Your account is under review. OMC will enable service access after verification.
```

---

## 5.3 Approved Customer

An Approved Customer has passed OMC verification.

Typical state:

```text
customer_status = Active
approval_status = Approved
```

### Approved customers can

- access the customer dashboard;
- browse services;
- create service requests;
- upload required documents;
- track their own cases;
- view their own documents;
- view their own payment information where enabled;
- upload payment receipts where enabled;
- receive notifications;
- create and follow support tickets;
- manage profile and preferences;
- use tax and expense tools;
- read customer-safe content.

### Ownership rule

An Approved Customer may only access records attached to their own customer profile.

They must never be able to:

- view another customer;
- view another customer's service request;
- view another customer's documents;
- view another customer's payments;
- view another customer's support tickets;
- see internal notes;
- review documents;
- review payments;
- update internal case status;
- manage leads or internal tasks.

---

## 5.4 Internal OMC roles

| Role | Primary responsibility |
|---|---|
| OMC Admin | Full OMC application administration and operations |
| OMC Manager | Operational oversight, customers, cases, tasks, and reviews |
| OMC Support Agent | Support tickets, leads, and customer communication |
| OMC Document Reviewer | Document queue, attachments, approval, and rejection |
| OMC Finance Reviewer | Payment queue, receipt review, approval, and rejection |
| OMC Consultant | Assigned service cases and assigned tasks |
| OMC Tax Associate | Assigned tax-related service work |
| OMC Business Partner | Assigned partner-managed work |
| OMC Customer | Customer portal identity, still subject to approval state |

Internal access should always combine:

```text
Role
+ capability
+ record scope
+ user status
```

---

# 6. User approval workflow

The recommended onboarding model is:

```text
User submits signup
        |
        v
Frappe User and OMC Customer Profile are created or linked
        |
        v
Profile remains Pending Review
        |
        v
OMC staff review identity, contact details, and requested registration type
        |
        +--> Keep Pending
        +--> Reject
        +--> Approve as Customer
        +--> Approve for an internal or partner role
        +--> Correct the requested user type before approval
```

This model prevents unverified users from immediately creating cases or uploading protected information.

## 6.1 Signup information

Signup may include:

| Field | Purpose |
|---|---|
| Full name | Customer or applicant identity |
| Email | Login identity |
| Mobile number | Contact |
| WhatsApp number | Communication |
| CNIC or identifier | Verification where required |
| Registration type | Customer, Consultant, Business Partner, or Tax Associate |
| Address | Contact record |
| Password | Account access |
| Education, experience, or remarks | Additional review information where relevant |

Input is bounded and validated before account creation.

## 6.2 Profile updates

Customers may update supported profile fields such as name, phone, company, or identifiers within defined limits.

Account email is not changed through normal profile-edit endpoints. Email changes require a separate controlled account process.

---

# 7. Navigation model

The exact navigation may change by screen size and role, but the customer experience is organised around the following areas.

| Area | Purpose |
|---|---|
| Home | Summary, greetings, shortcuts, featured content, and current actions |
| Services | Browse active services and open details |
| Cases / My Services | View and track submitted service requests |
| Documents | View document requirements and upload status |
| More | Profile, payments, support, notifications, knowledge, tax, expenses, and settings |

Visibility is state-dependent:

- Guests see public modules;
- Pending Customers see public modules plus profile and approval status;
- Approved Customers see customer workflows;
- Internal users see only modules allowed by capabilities.

---

# 8. End-to-end customer journey

```text
Guest opens app
        |
        v
Browses services and public content
        |
        v
Attempts a protected action
        |
        v
Signs up or logs in
        |
        v
Account enters Pending Review
        |
        v
OMC reviews and approves account
        |
        v
Customer selects an active service
        |
        v
Customer submits a service request
        |
        v
Required documents are uploaded
        |
        v
OMC assigns and processes the case
        |
        v
Statuses, notes, and next actions are updated
        |
        v
Customer receives notifications
        |
        v
Payment and receipt review occurs if needed
        |
        v
Case is completed or cancelled
```

---

# 9. Feature-by-feature guide

## 9.1 Home

Home is the main entry point.

### Guest Home

Guest Home may show:

- OMC introduction;
- active featured services;
- public announcements;
- FAQs or knowledge highlights;
- tax calculator shortcut;
- login and signup actions;
- contact options.

### Customer Home

Approved Customer Home may show:

- time-based greeting;
- open cases;
- actions required;
- missing documents;
- payment reminders;
- recent notifications;
- service shortcuts;
- support shortcut;
- tax and expense tools.

### Internal Home

Internal Home should show role-relevant operational data only, such as:

- assigned tasks;
- assigned cases;
- review queues;
- support queue;
- lead activity;
- current workload;
- urgent or overdue items.

Home should not show fake statuses derived from list position or placeholder calculations. Operational status must come from real backend records.

---

## 9.2 Service catalogue

The service catalogue is controlled from the backend.

OMC staff can configure:

| Field | Purpose |
|---|---|
| Service title | Name shown to users |
| Description | Customer-facing explanation |
| Category | Grouping and filtering |
| Fee label | Price or contact instruction |
| Completion time | Expected duration |
| Required documents | Upload requirements |
| Icon or visual | Service identity |
| Featured flag | Home or catalogue promotion |
| Active flag | Public availability |
| Sort order | Display priority |
| Instructions | Customer guidance |

### Public catalogue rules

Public service APIs expose active services only.

Internal-only configuration, implementation details, and non-customer-safe fields are not returned publicly.

### Customer flow

```text
Open Services
    |
    v
Filter or search
    |
    v
Open service details
    |
    v
Review requirements, fees, expected time, and documents
    |
    v
Start request if account is approved
```

---

## 9.3 Service details

Service details provide the information required before a request is started.

The screen may include:

- service title;
- category;
- summary;
- detailed description;
- price or fee guidance;
- expected completion time;
- required documents;
- instructions;
- customer eligibility information;
- primary call to action.

The app should not expose internal workflow configuration or hidden stages.

Inactive services cannot be requested through the guarded backend flow.

---

## 9.4 Service request creation

A service request is the central customer-to-operations record.

### Preconditions

Before creation, the backend verifies:

- the user is authenticated;
- the customer profile is approved and active;
- the selected service exists;
- the service is active;
- supplied fields are valid and within limits;
- the requested priority is supported.

### Customer-provided information

A request may contain:

- service selection;
- request title;
- description;
- contact phone;
- contact email;
- supported priority;
- service-specific answers;
- supporting files where applicable.

### Active request behaviour

When an active request already exists for the same service, the app may warn the user and offer:

- Resume existing request;
- Start new request.

The backend remains responsible for deciding whether duplicates are permitted.

### Initial result

After successful submission:

- a service request is created;
- the request belongs to the customer profile;
- timeline or history records may be created;
- the request appears in Cases / My Services;
- staff can process it from Desk or authorised internal modules.

---

## 9.5 Cases / My Services

Cases lets customers follow their submitted requests.

A case card may show:

- service title;
- request reference;
- current status;
- priority;
- created date;
- last update;
- expected completion;
- customer action required;
- document or payment indicators.

### Case detail

The case detail may show:

- service information;
- customer-visible status;
- progress summary;
- next step;
- required documents;
- uploaded documents;
- payment status;
- customer-visible timeline;
- support options.

### Status guidance

Typical statuses include:

| Status | Meaning |
|---|---|
| Open | Request has been created |
| Waiting for Customer | OMC needs information, documents, or action |
| In Progress | OMC is processing the request |
| Under Review | Work is being checked or finalised |
| Completed | Service work is finished |
| Cancelled | Request is no longer active |

Customer-facing wording should remain simple even when internal operations use more detailed stages.

---

## 9.6 Documents

Documents support evidence collection and verification.

### Customer view

Customers may see:

- required document name;
- description;
- required or optional status;
- upload state;
- review state;
- rejection reason or reviewer remarks where customer-safe;
- replace or upload action where allowed.

### Upload rules

Protected document uploads use file upload handling rather than direct user-controlled URLs.

The backend verifies:

- authentication;
- customer ownership;
- service-request relationship;
- allowed upload context;
- file association;
- prevention of cross-request reuse.

A file linked to one request must not be silently reused for another request.

### Internal review

Document Reviewers, Managers, and Admins may review documents according to capability.

Review actions may include:

- approve;
- reject;
- request replacement;
- add remarks;
- update review status.

Finance Reviewers and unrelated staff should not automatically receive document-review access.

---

## 9.7 Payments and receipts

Payment records track amounts or instructions connected to a service request.

Customers may see:

- payment title;
- amount or fee guidance;
- due date;
- payment status;
- payment instructions;
- receipt-upload action where enabled;
- receipt-review result.

### Receipt upload

Receipt files must be uploaded through the protected multipart flow.

Direct receipt URL injection is rejected.

### Internal review

Finance Reviewers, Managers, and Admins may:

- view payment queue;
- open allowed receipt files;
- approve or reject receipts;
- add review remarks;
- update payment status.

Document Reviewers do not receive finance authority by default.

---

## 9.8 Notifications

Notifications communicate important events.

Examples:

- account approval;
- request created;
- case status changed;
- customer action required;
- document accepted or rejected;
- payment due;
- receipt accepted or rejected;
- support reply;
- service completed.

Customer notification access requires an exact customer-profile or recipient-user match.

A user must not be able to retrieve notifications belonging to another user.

---

## 9.9 Support tickets

Support lets approved customers request help.

### Customer actions

Customers may:

- create a ticket;
- choose a category;
- describe the issue;
- connect the ticket to a case where supported;
- view replies;
- follow status;
- add further customer replies where allowed.

### Staff actions

Support Agents, Managers, and Admins may:

- view support queues;
- reply;
- change status;
- assign tickets;
- view relevant customer and service context;
- escalate issues.

Support Agents should not receive unrelated document, finance, or settings access.

---

## 9.10 Leads

Leads represent prospective customers or business opportunities.

Authorised staff may:

- create leads;
- update contact and status;
- assign ownership;
- record follow-up;
- convert or link records where supported;
- view lead history.

Lead access is primarily intended for Admins, Managers, and Support Agents with the appropriate capability.

---

## 9.11 Tasks

Tasks organise internal work.

A task may contain:

- title;
- description;
- assigned user;
- related customer;
- related case;
- due date;
- priority;
- status;
- internal notes.

Internal tasks can only be assigned to enabled System Users.

Assignment-scoped users normally see and manage only their assigned tasks.

---

## 9.12 Profile

Profile allows a user to manage supported personal and business details.

Typical fields include:

- full name;
- phone;
- mobile number;
- WhatsApp number;
- CNIC or identifier;
- NTN or tax identifier;
- company;
- address;
- registration type;
- approval status.

Profile input is bounded. Non-scalar or oversized values are rejected.

The account email is protected from mutation through standard profile endpoints.

---

## 9.13 Settings

Customer settings may include:

- appearance preference;
- notification preference;
- local app preference;
- privacy and policy links;
- logout;
- app version information.

Admin-only backend configuration is separate from customer settings.

---

## 9.14 Tax calculator

The tax calculator provides an estimate based on supported inputs and backend tax configuration.

Typical inputs may include:

- income type;
- filer status;
- monthly or annual mode;
- income amount;
- advanced numeric fields.

### Safety rules

Before calculation, the public guard enforces:

- maximum payload size;
- maximum number of advanced fields;
- valid field names;
- supported income types;
- supported filer statuses;
- supported income modes;
- finite numeric values;
- non-negative amounts;
- maximum supported amount;
- rejection of nested or malformed numeric structures.

The calculator is an estimate and should not be presented as a substitute for professional advice or an official tax filing result.

---

## 9.15 Expense tracker

The expense tracker lets a customer record and review personal expense information.

Typical capabilities:

- create expense;
- edit expense;
- view list and totals;
- categorise expenses;
- record payment method;
- add merchant and notes;
- attach a receipt;
- synchronise bounded batches;
- define budget alerts.

### Validation rules

- amount must be finite;
- amount must be greater than zero;
- amount must remain within the supported maximum;
- text and identifiers are bounded;
- bulk sync has entry-count and payload-size limits;
- each bulk entry must be an object;
- budget alert threshold must remain between 0 and 100;
- receipt upload must use the protected file endpoint.

Expense data is customer-owned and must not be exposed across accounts.

---

## 9.16 Knowledge, FAQs, banners, and announcements

Public and customer content may be controlled through Frappe records.

Benefits:

- content can be updated without rebuilding the app;
- inactive content can be hidden;
- sort order can be controlled;
- customer-safe content can be separated from internal records;
- OMC can publish service guidance, FAQs, and announcements centrally.

---

# 10. Internal operations model

## 10.1 Customer approval

Authorised staff review new profiles and decide whether to:

- keep pending;
- approve;
- reject;
- correct user type;
- assign a role;
- request more information.

Approval must update both customer status and approval status consistently.

## 10.2 Case management

Authorised staff can:

- open a case;
- assign staff;
- change status;
- set expected completion;
- request customer action;
- update customer-visible notes;
- maintain internal notes;
- review related documents;
- review related payments;
- complete or cancel the case.

## 10.3 Review separation

Document and finance review are separate domains.

This separation reduces unnecessary access to attachments and payment evidence.

## 10.4 Assignment scope

Consultants, Tax Associates, and Business Partners normally receive assigned or relevant records only.

They should not automatically see:

- all customers;
- all service cases;
- all support tickets;
- all documents;
- all payment information;
- global settings.

---

# 11. Capability model

The backend returns canonical capabilities used by Flutter and backend methods.

Examples include:

```text
can_access_internal_workspace
can_manage_customers
can_manage_leads
can_manage_tasks
can_manage_assigned_tasks
can_view_all_service_cases
can_view_assigned_service_cases
can_update_service_status
can_update_assigned_service_status
can_view_document_queue
can_view_document_attachments
can_review_documents
can_view_payment_queue
can_view_payment_receipts
can_review_payments
can_view_support_tickets
can_reply_support_tickets
can_update_support_ticket_status
can_assign_support_tickets
can_view_internal_notes
can_manage_settings
```

The frontend uses these values for visibility and navigation.

The backend uses independent checks for actual authorisation.

Unknown authenticated routes and unknown access levels should fail closed.

---

# 12. Security and privacy model

## 12.1 Backend-first security

The backend verifies:

- authentication;
- customer approval state;
- internal capabilities;
- ownership;
- assignment;
- file relationships;
- active service state;
- valid input shape and size.

## 12.2 Public endpoint safety

Public endpoints return customer-safe data only.

Examples:

- active services only;
- active public templates only;
- customer-visible stages only;
- no internal wizard configuration;
- bounded tax requests;
- bounded signup data.

## 12.3 Protected write guards

Sensitive write routes are passed through validation guards for:

- signup;
- profile changes;
- service-request creation;
- expense creation and updates;
- expense bulk sync;
- budget settings;
- receipt upload;
- tax calculation.

## 12.4 Secrets and runtime data

The repository must not contain:

- production passwords;
- API secrets;
- site configuration;
- database dumps;
- private files;
- local `.env` credentials;
- logs;
- generated runtime state.

---

# 13. Data ownership summary

| Record type | Customer access | Internal access |
|---|---|---|
| Customer Profile | Own profile only | Capability and role scoped |
| Service Request | Own requests only | All, relevant, or assigned scope |
| Service Document | Own request documents | Review or related-case scope |
| Payment | Own request payments | Finance, Manager, or Admin scope |
| Notification | Exact recipient match | Operational access where required |
| Support Ticket | Own tickets | Support capability scope |
| Expense | Own expenses | No broad internal access by default |
| Task | None unless exposed | All or assigned scope |
| Lead | No customer access | Lead-management capability |

---

# 14. Backend-controlled versus app-controlled behaviour

## Backend-controlled

- user state;
- approval status;
- capabilities;
- service availability;
- service content;
- case records;
- document requirements;
- document review;
- payment review;
- support records;
- notifications;
- tax rules;
- permission decisions.

## App-controlled

- layout;
- visual hierarchy;
- loading and empty states;
- responsive design;
- local navigation presentation;
- formatting;
- local appearance preference;
- user-friendly error display.

The app should never invent authoritative operational status.

---

# 15. Error and empty-state expectations

The app should communicate failures clearly without exposing internal stack traces.

Recommended categories:

| Situation | User-facing response |
|---|---|
| No internet | Connection message with retry |
| Session expired | Ask user to sign in again |
| Pending approval | Explain account is under review |
| Permission denied | Explain feature is unavailable |
| No records | Show a useful empty state and next action |
| Invalid form | Highlight fields and validation message |
| Upload failed | Preserve context and offer retry |
| Backend unavailable | Show temporary service message |
| Record not found | Return safely to the relevant list |

Internal error details should remain in server logs, not customer-facing UI.

---

# 16. Operational lifecycle examples

## 16.1 Document-required service

```text
Customer submits request
        |
        v
Required document list is created or loaded
        |
        v
Customer uploads files
        |
        v
Document Reviewer checks files
        |
        +--> Approved
        +--> Rejected with customer-safe reason
        +--> Replacement requested
        |
        v
Case continues
```

## 16.2 Payment-required service

```text
Case reaches payment stage
        |
        v
Payment instruction is shown
        |
        v
Customer uploads receipt
        |
        v
Finance Reviewer checks receipt
        |
        +--> Approved
        +--> Rejected with reason
        |
        v
Case proceeds or waits for customer
```

## 16.3 Support escalation

```text
Customer creates support ticket
        |
        v
Support Agent receives ticket
        |
        v
Agent reviews relevant customer and case context
        |
        +--> Replies
        +--> Updates status
        +--> Assigns or escalates
        |
        v
Customer receives reply and notification
```

---

# 17. Client administration responsibilities

OMC should maintain the following in Frappe Desk:

- active services;
- service categories;
- service descriptions;
- required documents;
- fee guidance;
- expected completion times;
- customer approvals;
- staff users and roles;
- staff assignments;
- case statuses;
- document reviews;
- payment reviews;
- support queues;
- lead follow-up;
- tasks;
- public FAQs and knowledge content;
- tax configuration;
- system settings and branding where supported.

OMC should also maintain operational policies for:

- customer verification;
- document retention;
- payment evidence retention;
- role assignment;
- staff offboarding;
- backup and restore;
- incident response.

---

# 18. Release validation matrix

A release is not complete until real user-state and role testing is performed.

## 18.1 Guest tests

Verify that a guest can:

- browse active services;
- open public service details;
- read public content;
- use approved utilities;
- open login and signup.

Verify that a guest cannot:

- create requests;
- view customer records;
- upload protected files;
- access internal routes.

## 18.2 Pending Customer tests

Verify that a pending user can:

- sign in;
- view profile and approval state;
- browse public content.

Verify that approved-only actions remain blocked.

## 18.3 Approved Customer tests

Verify that an approved customer can:

- create a request for an active service;
- view only their own cases;
- upload files to their own request;
- view only their own payments;
- receive their own notifications;
- create and view their own support tickets;
- create and update their own expenses.

Attempt cross-customer access and confirm denial.

## 18.4 Internal role tests

For every internal role, verify:

- visible modules;
- allowed records;
- allowed actions;
- assignment scope;
- attachment access;
- denied modules;
- denied mutations;
- internal-note visibility;
- settings access.

## 18.5 File tests

Verify:

- allowed file upload;
- wrong-customer upload denial;
- wrong-request upload denial;
- cross-request reuse denial;
- receipt URL injection denial;
- reviewer attachment access boundaries.

## 18.6 API tests

Verify:

- unauthenticated protected calls fail;
- inactive services cannot be requested;
- oversized payloads fail;
- malformed numeric values fail;
- unsupported enum values fail;
- unknown routes fail closed;
- valid payloads still succeed.

---

# 19. Deployment and handover expectations

Before production handover, confirm:

- production domain uses HTTPS;
- API base URL is correct in the Flutter build;
- Frappe site is migrated;
- assets are built;
- Supervisor processes are healthy;
- nginx is healthy;
- Redis and database are healthy;
- private files remain private;
- backup jobs are configured;
- restore steps are documented;
- role smoke tests are completed;
- customer signup and approval are tested;
- document and receipt uploads are tested;
- Android APK or app bundle is tested against production.

Routine deployment should update the existing app without recreating the Bench, site, or database.

---

# 20. Current implementation status

The current platform includes:

- Flutter customer and internal modules;
- public, pending, approved, and internal access states;
- capability-driven navigation;
- backend ownership and assignment checks;
- service catalogue and service details;
- customer signup and approval flow;
- service-request creation and tracking;
- document upload and review;
- payment and receipt workflows;
- notifications;
- support;
- leads and tasks;
- profile and settings;
- tax calculator;
- expense tracker;
- backend security guards for sensitive public and authenticated writes;
- deployment assets and validation scripts;
- focused Flutter and backend tests.

Repository hardening and local static validation have been completed for the current codebase.

The remaining release sequence is environment-specific:

1. update the production server from GitHub `main`;
2. migrate and rebuild the existing Frappe deployment;
3. restart services safely;
4. perform live API and role smoke tests;
5. build and test the Android release against production.

---

# 21. Final product summary

OMC App is not only a mobile interface. It is a connected operations platform.

For customers, it provides a clear way to discover services, submit requests, provide documents, follow progress, handle payments, and obtain support.

For OMC, it provides controlled customer onboarding, structured case processing, specialised review queues, assignment-based staff access, and centralised operational records.

The platform is designed around four rules:

1. keep the customer experience simple;
2. keep operational data centralised;
3. give each role only the access it needs;
4. enforce trust and permissions in the backend.

---

**OMC App connects customers and OMC operations through one secure, role-aware, and auditable service workflow.**
