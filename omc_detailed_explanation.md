# OMC App — Complete Product and Feature Guide

## 1. Purpose

This document explains the OMC App in practical business and operational language.

It is intended for:

- OMC House management;
- clients and project stakeholders;
- customer-service teams;
- support, document, finance, referral, and service teams;
- developers and deployment engineers;
- testers performing role-based verification.

It explains:

- what the platform does;
- who can use each feature;
- how the customer and staff experiences connect;
- how the main workflows behave;
- what remains controlled by Frappe Desk;
- which access and security rules apply;
- how the platform is validated before release.

For engineering setup and deployment commands, see [`README.md`](README.md).

For the canonical role and capability matrix, see [`docs/app_role.md`](docs/app_role.md).

---

# 2. Executive summary

OMC App is a full-stack digital service platform for OMC House.

It combines:

1. a Flutter application for guests, customers, and authorised internal users;
2. a custom Frappe backend for business data, workflows, permissions, and automation;
3. Frappe Desk for controlled operational administration;
4. backend-managed services, customer records, cases, documents, payments, support, notifications, tax data, and expense records.

The operating model is:

```text
Guest, customer, or staff member uses the Flutter app
                            |
                            | Secure API requests
                            v
                    Custom OMC backend
                            |
                            | Business rules and permissions
                            v
             Frappe Desk and OMC operational records
```

The customer interface should remain simple. The backend remains strict.

> The Flutter app may hide, disable, or redirect a feature for user experience, but the Frappe backend independently enforces every protected read and action.

---

# 3. Platform sides

## 3.1 Public and guest side

The public side introduces OMC House and allows visitors to explore safe content without exposing private records.

Guest-safe areas include:

- public home content;
- active service catalogue;
- service descriptions and requirements;
- approved FAQs and knowledge content;
- announcements and contact details;
- tax calculator;
- login, signup, email verification, and password recovery.

## 3.2 Customer side

The customer side supports three important states:

- Guest;
- Pending Customer;
- Approved Customer.

Each state receives different routes, actions, and backend access.

## 3.3 Internal side

The internal side is used by authorised OMC personnel.

Internal access is capability-based. Visibility of the internal workspace does not grant every action.

Examples:

- a Document Reviewer can review documents but cannot make finance decisions;
- a Finance Reviewer can review receipts but cannot approve documents;
- a Support Agent can manage support work but cannot administer the full application;
- a Consultant can access assigned work but not every customer record;
- an Admin can manage the full OMC application.

## 3.4 Shared backend

All sides use the same Frappe backend for:

- users and sessions;
- customer profiles;
- services and categories;
- service requests and timelines;
- document records and attachments;
- payment records and receipts;
- support tickets and replies;
- notifications and push tokens;
- referrals and leads;
- tasks and assignments;
- tax configuration;
- expense and budget records;
- branding, announcements, FAQs, and application content.

This shared data model keeps customers and staff aligned.

---

# 4. User types and access states

## 4.1 Guest

A guest has not signed in.

### Guest users can

- open the application;
- view public home content;
- browse active services;
- open customer-safe service details;
- read approved FAQs and knowledge articles;
- use guest-safe tax tools;
- view contact information;
- open login, signup, verification, and recovery screens.

### Guest users cannot

- create service requests;
- upload customer documents;
- track private cases;
- view payments or receipts;
- view customer notifications;
- view support history;
- view expense records;
- access internal workspaces;
- read any other user's data.

Protected routes redirect or show a clear access message without exposing private records.

---

## 4.2 Pending Customer

A Pending Customer has registered but has not yet completed OMC approval.

Typical state:

```text
customer_status = Pending
approval_status = Pending Review
```

### Pending customers can

- sign in;
- view their own profile;
- view approval status;
- update allowed profile fields;
- manage notification preferences;
- browse active public services;
- read public content;
- use guest-safe utilities;
- sign out securely.

### Pending customers cannot

- start approved-only service workflows;
- upload service documents;
- view private case history;
- view or submit payments;
- access internal tools.

The application communicates that the account is under review rather than showing a broken or empty protected workflow.

---

## 4.3 Approved Customer

Typical state:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can use customer workflows such as:

- service requests;
- cases and timelines;
- documents;
- payments and receipts;
- support tickets;
- notifications;
- profile and settings;
- expense tracking.

Every protected customer query remains ownership-scoped.

> An approved customer may only read or modify records that belong to their own OMC customer profile.

---

## 4.4 Internal roles

The current role model includes:

- **OMC Admin** — full application administration and broad operations;
- **OMC Manager** — operational oversight without normal Admin-only configuration authority;
- **OMC Support Agent** — support, leads, and customer communication;
- **OMC Document Reviewer** — document queues, attachments, and review decisions;
- **OMC Finance Reviewer** — payment queues, receipts, and finance decisions;
- **OMC Consultant** — assigned service cases and tasks;
- **OMC Tax Associate** — assigned tax-related service work;
- **OMC Business Partner** — assigned partner-managed work;
- **OMC Customer** — customer identity governed by approval and ownership.

Sensitive internal reads and mutations require the correct capability and record scope.

---

# 5. Authentication and onboarding

## 5.1 Login

The login experience supports:

- canonical backend authentication;
- identity resolution for supported login identifiers;
- secure local session storage;
- approval-aware post-login routing;
- clear handling of invalid or expired sessions;
- safe logout and local session cleanup.

## 5.2 Four-step signup

The signup flow is structured into four stages.

### Step 1 — Account type

The applicant selects one supported path:

- Customer;
- Consultant;
- Business Partner;
- Tax Associate.

The selected type affects required details and the backend review pathway.

### Step 2 — Basic details

The form collects validated information such as:

- full name;
- email;
- username;
- mobile number;
- WhatsApp number;
- CNIC;
- address;
- professional details where required.

Username availability is checked before progression.

The WhatsApp number may match the mobile number or be entered separately.

### Step 3 — Referral and preferences

Customers can provide:

- acquisition source;
- optional referral code;
- optional referral-assistance consent;
- source detail where required.

Referral authority remains backend-controlled.

### Step 4 — Security

The user creates and confirms a password, reviews the process, and accepts the required terms.

Duplicate submission is prevented while the request is in progress.

## 5.3 Email verification

After successful signup submission, the app shows the email-verification state:

- the registered email address is displayed;
- the user is told to open the verification link;
- resend availability uses a cooldown;
- repeated resend attempts are controlled;
- the user can return to login.

## 5.4 Password recovery

The recovery workflow includes:

- validated account identity;
- pending-secret lifecycle handling;
- cooldown and resend behaviour;
- safe cleanup of temporary recovery state;
- backend-authoritative password mutation.

---

# 6. Home, navigation, and dashboard

## 6.1 Role-aware navigation

Navigation is generated from current identity, approval state, and canonical capabilities.

The application does not rely on visual hiding as a security boundary.

Unknown or unsupported protected routes fail closed.

## 6.2 Home experience

The home screen can present:

- time-aware greeting;
- customer or staff identity;
- key workflow shortcuts;
- current service activity;
- alerts and next actions;
- backend-driven announcements or content.

## 6.3 Customer dashboard

The customer dashboard summarises the customer's own data, such as:

- active service requests;
- pending actions;
- documents awaiting action;
- payments awaiting action;
- recent activity;
- support or notification indicators.

## 6.4 Internal operations centre

Internal users receive capability-specific operational views, for example:

- assigned cases;
- document review queues;
- payment review queues;
- support tickets;
- leads;
- tasks;
- unassigned or overdue work;
- recent operational activity.

Dashboard reads are routed through backend guards. Service activity resolves the correct service reference rather than using misleading generic metadata.

---

# 7. Service catalogue

The service catalogue is managed by OMC through the backend.

Customer-facing behaviour includes:

- active categories and services;
- clean service cards;
- descriptions and requirements;
- customer-safe pricing context;
- required-document information;
- availability and request actions.

The catalogue does not fabricate request status from service-list position.

Public responses exclude internal configuration and inactive service data.

---

# 8. Service requests and case tracking

## 8.1 Customer request creation

Approved customers can start a request for an active service.

The request flow validates:

- service availability;
- customer approval;
- ownership identity;
- bounded text fields;
- phone and email values;
- supported priority values;
- backend request contract.

If an active request already exists, the application can offer a clear choice to resume existing work or start a new request where allowed.

## 8.2 Assisted service creation

Authorised internal staff can create a request for an eligible customer through the assisted-service policy.

This path preserves:

- customer ownership;
- staff capability requirements;
- referral authority;
- assignment rules;
- the canonical service-request payload.

## 8.3 Assignment authority

Assignment follows controlled precedence:

1. explicit authorised assignee;
2. valid referral owner;
3. service default assignee;
4. least-loaded eligible user for the configured service role;
5. OMC Manager fallback.

The backend can create duplicate-safe Frappe ToDos and operational notifications for the assignee.

## 8.4 Customer case tracking

Customers can see their own:

- request identifier;
- service name;
- current status;
- progress;
- priority;
- assigned context where customer-safe;
- required actions;
- document and payment state;
- activity timeline;
- completion state.

## 8.5 Internal case handling

Authorised staff can work on cases within capability and assignment scope.

Supported actions may include:

- review request details;
- update allowed workflow state;
- manage assignment;
- review related documents or payments;
- add operational context;
- complete work when all blockers are resolved.

---

# 9. Document workflow

## 9.1 Customer upload

Customers upload documents through multipart file handling.

The backend validates:

- authenticated customer identity;
- request ownership;
- the relationship between document and request;
- allowed file relationship;
- prevention of cross-request file reuse.

## 9.2 Document list and replacement

Customers can view document requirements and current review state.

Where the workflow allows it, rejected or replacement documents can be uploaded again.

## 9.3 Reviewer queue

Document Reviewers receive document-specific queues and attachment access.

Review decisions include:

- approve;
- reject with reason;
- return the service request to customer action where required.

A rejection can move the request to `Waiting for Customer` and notify the customer.

## 9.4 Payment eligibility

When all required documents are approved, the backend evaluates payment eligibility.

It does not create a payment unless:

- required documents are approved;
- the service has a positive payable amount;
- the currency is valid;
- no conflicting active payment exists.

---

# 10. Payment workflow

## 10.1 Payment creation

Payment records are created from trusted service configuration rather than user-supplied totals.

Safeguards include:

- positive service price requirement;
- valid currency requirement;
- duplicate active-payment prevention;
- request relationship validation.

## 10.2 Customer payment view

Customers can see their own payment context, such as:

- amount;
- currency;
- current payment status;
- instructions;
- receipt-review status;
- required next action.

## 10.3 Receipt submission

Receipt uploads use protected multipart handling.

Direct user-controlled receipt URL injection is rejected.

After submission, relevant finance and operational reviewers are notified.

## 10.4 Finance review

Authorised Finance Reviewers can review receipts and record supported outcomes.

Typical transitions include:

- `Under Review`;
- `Paid`;
- `Rejected`.

A paid result moves the request forward. A rejected result returns the workflow to customer action and requires a replacement receipt.

Payment reads and mutations are role-specific and guarded.

---

# 11. Support system

Customers can:

- create support tickets;
- review their own ticket history;
- open ticket details;
- read replies;
- send follow-up messages where allowed;
- see read/unread state.

Authorised support staff can:

- work from internal support queues;
- open customer-safe context;
- reply to tickets;
- update permitted support state;
- track read state;
- access only records allowed by support authority.

Support mutations and reads are routed through dedicated guards.

---

# 12. Leads and referrals

## 12.1 Leads

Authorised users can work with lead records according to role and scope.

Lead operations are protected by capability and mutation guards.

## 12.2 Referrals

The referral system supports:

- referral code entry during signup;
- referral validation;
- assistance consent;
- referral summaries;
- referral detail views;
- referral-aware service assignment where valid;
- ownership and authority checks.

Referral data does not grant unrestricted access to customer records.

---

# 13. Tasks

Operational tasks are assignment-scoped.

The backend validates that task assignees are enabled System Users and that the acting user has authority.

Internal users can access only the task data appropriate to their role and assignment.

---

# 14. Notifications

## 14.1 In-app notifications

The notification system supports:

- ownership-safe notification lists;
- recipient-user and customer-profile matching;
- unread/read state;
- pagination;
- workflow-driven messages;
- customer and internal recipients.

## 14.2 Notification preferences

Users can manage categories such as:

- service updates;
- document reminders;
- payment alerts;
- tax alerts.

Preferences are enforced by the backend where applicable.

## 14.3 Push-ready infrastructure

The backend includes push-token registration and integrity controls.

Notification content can be authored from backend-managed workflow data, allowing OMC to control customer communication without embedding all message text in the mobile application.

## 14.4 Scheduler reminders

Scheduled jobs support reminders and escalations for areas such as:

- uploaded documents awaiting review;
- submitted receipts awaiting finance review;
- unassigned service requests;
- customer action required;
- payment action required;
- overdue work.

Scheduler runners isolate failures and return operational summaries rather than allowing one bad record to silently block the whole job.

---

# 15. Profile and settings

## 15.1 Profile self-service

Users can update allowed personal, contact, and business data through guarded endpoints.

Protected identity fields remain controlled. For example, the account email cannot be changed through an ordinary profile-edit mutation.

## 15.2 Settings

The Settings area includes:

- profile preferences;
- security and password management;
- notification preferences;
- account deletion request;
- legal documents;
- application version information;
- logout.

Account deletion is submitted as a support request rather than performing an unsafe immediate destructive action.

## 15.3 Legal and branding content

Privacy policy, terms, branding, onboarding, and application content can be supplied by backend configuration with safe fallbacks.

---

# 16. Tax calculator

The tax calculator can be available to guests and authenticated users.

The backend remains the calculation authority.

Validated inputs include:

- supported tax year;
- income mode;
- income type;
- filer status;
- bounded advanced inputs;
- finite monetary values;
- non-negative values;
- supported payload shape.

Tax slabs are managed in the backend so multiple tax years can be supported without hard-coding every slab in the Flutter interface.

---

# 17. Expense tracker

The expense tracker supports customer-owned records.

Features include:

- expense creation and editing;
- amount, date, category, and description;
- positive finite amount validation;
- expense lists and summaries;
- budget thresholds;
- budget-versus-actual views;
- receipt uploads;
- bounded bulk sync;
- cloud/local sync integrity;
- protected record ownership.

Direct receipt URL injection is not accepted for protected uploads.

---

# 18. Content and app configuration

Customer-facing content can be managed through the backend, including:

- announcements;
- FAQs;
- knowledge articles;
- onboarding content;
- contact information;
- branding configuration;
- legal policy content;
- service data;
- notification fallback content.

Public content is separated from authenticated and internal operational data.

---

# 19. End-to-end service lifecycle

```text
Customer account created
    |
Email verified
    |
OMC approval completed where required
    |
Customer selects active service
    |
Service request created
    |
Assignee resolved
    |
ToDo and operational notifications created
    |
Customer uploads required documents
    |
Document Reviewer decision
    |
    +--> Rejected
    |       -> Waiting for Customer
    |       -> replacement required
    |
    +--> All required documents approved
            -> service price and currency validated
            -> one active payment created
            -> Waiting for Payment

Customer submits receipt
    |
Finance review
    |
    +--> Rejected
    |       -> Waiting for Customer
    |       -> replacement receipt required
    |
    +--> Paid
            -> request moves forward

Operational work completed
    |
Completion safeguards verify:
    - required documents approved
    - active payments paid
    - no unresolved rejection blockers
    |
Open ToDos closed
    |
Completion timeline and notification created
```

Human reviewers remain responsible for document and receipt decisions.

---

# 20. Security and authority model

## 20.1 Backend-first authority

The backend enforces:

- authentication;
- approval state;
- role and capability;
- ownership;
- assignment;
- record relationships;
- workflow transitions;
- validated payloads.

## 20.2 Route and endpoint authority

- unknown authenticated routes are denied by default;
- blank or unknown access levels are denied;
- legacy mobile methods route through guarded wrappers;
- sensitive reads use read guards;
- sensitive writes use mutation guards;
- endpoint authority mappings are covered by automated tests.

## 20.3 Ownership and assignment

- customers see only their own records;
- Consultants, Tax Associates, and Business Partners are assignment-scoped by default;
- Document Reviewers and Finance Reviewers operate in separate domains;
- Support Agents receive only the customer and service context required for support;
- Managers receive broad operational visibility without ordinary Admin-only authority.

## 20.4 File and payload safety

- text, identifier, and numeric payloads are bounded;
- malformed, nested, unsupported, or non-finite values are rejected;
- bulk operations have size and count limits;
- uploaded files must match the correct customer and operational record;
- direct protected-file URL injection is rejected;
- secrets and runtime state remain outside tracked source code.

---

# 21. Frappe Desk responsibilities

Frappe Desk remains the administrative and operational control centre for authorised staff.

Typical responsibilities include:

- user and role administration;
- customer approval;
- service catalogue configuration;
- service pricing and currency;
- required-document templates;
- assignment defaults;
- tax slabs;
- announcements and knowledge content;
- operational record review;
- scheduler and worker health;
- audit and troubleshooting.

The mobile application does not replace controlled backend administration.

---

# 22. Validation status

The latest confirmed code-level validation on `main` includes:

```text
Frappe backend: 285 tests passed
Flutter application: 294 tests passed
Flutter analysis: No issues found
Repository diff check: clean
```

The validated Flutter suite includes the current four-step signup flow, username availability handling, WhatsApp behaviour, canonical payload assertions, and the email-verification success state.

The backend suite covers authority, ownership, operational integrity, guarded reads and writes, scheduler behaviour, workflow automation, and compatibility wrappers.

Validation must always be based on actual terminal output.

---

# 23. Remaining release work

Code-level validation is complete for the current state, but release validation remains environment-specific.

Before final production release:

1. build the Android release APK or App Bundle with the production HTTPS endpoint;
2. install and launch it on a real Android device;
3. test login, signup, services, uploads, payments, notifications, and support against production;
4. run allowed and denied smoke tests for every supported role;
5. verify scheduler, workers, Redis, database, nginx, and Supervisor health;
6. verify backup and restore readiness;
7. perform iOS archive, signing, and App Store validation on macOS with Xcode if an iOS release is required.

---

# 24. Client-facing feature summary

OMC House receives a connected platform with:

- public service discovery;
- structured account onboarding;
- email verification and account approval;
- customer profiles and preferences;
- service-request submission;
- customer case tracking;
- document collection and review;
- payment and receipt workflows;
- support tickets and replies;
- leads and referrals;
- internal assignments and tasks;
- operational dashboards;
- in-app and push-ready notifications;
- tax calculation;
- expense and budget tracking;
- backend-managed content and branding;
- role-based security;
- audit-friendly Frappe records;
- automated reminders and escalations;
- Android and iOS-capable Flutter source.

---

# 25. Final product statement

OMC App is not only a collection of mobile screens. It is a controlled service-delivery system in which:

- customers receive a simple self-service experience;
- OMC teams receive role-specific operational tools;
- Frappe remains the source of truth;
- protected records remain ownership- and capability-scoped;
- document and payment decisions remain human-controlled;
- reminders and workflow transitions reduce manual follow-up;
- automated tests protect the core contracts.

**The result is a unified customer portal and OMC operations platform designed for controlled, auditable, production deployment.**