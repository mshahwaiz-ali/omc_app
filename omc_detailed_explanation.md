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

Last source cross-check: **3 August 2026**. The guide distinguishes implemented software, environment-dependent operation, hardware verification, and features that are deliberately not claimed.

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

The backend sends the verification email immediately after an eligible registration is created. The link contract supports both the `omchouse://auth/verify-email` app scheme and a browser endpoint. Successful browser verification redirects into the app's login state; invalid or expired tokens return a safe invalid-verification state. Verification does not itself bypass the later OMC approval decision.

## 5.4 Password recovery

The recovery workflow includes:

- validated account identity;
- pending-secret lifecycle handling;
- cooldown and resend behaviour;
- safe cleanup of temporary recovery state;
- backend-authoritative password mutation.

## 5.5 Optional device lock

An authenticated user can enable **Device lock** from Settings. Enabling it first requires a successful operating-system authentication.

Depending on the configured device, the operating system may offer:

- fingerprint;
- Face ID or another enrolled biometric;
- device PIN, passcode, or pattern.

The preference is stored in encrypted device storage. When the signed-in app is paused, hidden, or moved to the background, the app marks itself locked and requests device authentication again on resume. Cancelling or failing the prompt leaves the OMC interface locked and the user can tap **Unlock** to retry.

This is a local, post-login privacy control. It does not send biometric data to OMC, does not replace the original OMC login, and does not create passwordless backend authentication. Unsupported or unconfigured devices cannot enable it. Logout clears the device-lock preference together with the local session.

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

## 6.5 Admin control and recovery operations

OMC Admin and other specifically capable users receive only the administration actions granted by the backend:

- review pending customer or staff registrations;
- approve or reject a registration with the correct role context;
- invite staff and grant only supported OMC roles;
- edit eligible staff roles or enable/disable their accounts;
- view and update the guarded subset of mobile business settings;
- search and page through cases eligible for reassignment;
- select an eligible assignee and record the reassignment reason;
- inspect exhausted ERP-sync status, last error, and retry count before retrying;
- inspect pending discounts and approve or reject them;
- require review remarks when a discount is rejected.

Reassignment, ERP retry, and discount review use separate capabilities and separate server-filtered queues. Opening the Admin area therefore does not automatically grant every recovery action.

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

ERP Task is the operational task authority. Task list/detail reads are assignment-scoped unless the user has all-task authority.

Supported guarded actions include:

- moving a task through the allowed OMC operational-status values;
- assigning or reassigning it to an eligible enabled System User;
- closing replaced open assignments during reassignment;
- updating priority and expected completion date;
- synchronising related planning fields to the linked service request where configured;
- completing the task through `Submitted by QC` when the workflow allows it.

The QC completion path changes only ToDos linked to the exact ERP Task and uses a database savepoint. If Task validation or saving fails, assignment state and in-memory status are rolled back rather than leaving partial completion. Repeated no-change operations return safely without fabricating an update.

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

The Flutter interface also supports notification detail, mark read, mark unread, mark all read where allowed, dismiss, restore/undo, unread badges, filtering, pagination, and navigation to linked content. Each mutation refreshes the relevant list, detail, and count rather than globally discarding unrelated state.

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

Depending on backend configuration and result data, the customer can also receive:

- detailed slab calculation breakdown;
- filer versus non-filer comparison;
- tax-readiness/health guidance;
- backend-authored insights and recommended next steps;
- authenticated calculation history;
- a guarded action to start the configured tax service from a saved calculation.

Starting a service from a calculation requires an authenticated eligible account, a saved backend calculation log, and a linked service in tax settings. The presence of repository contracts for PDF generation or consultant sharing is not treated as a completed customer-facing button unless a reachable Flutter action exists.

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

The storage mode depends on access state:

- Guest and Pending Customer modes keep expense data locally on the device;
- Approved Customer mode uses ownership-guarded cloud records and supports bounded local-to-cloud synchronisation;
- clearing local tracker data does not claim to delete cloud records;
- JSON import/export supports local backup and recovery;
- import reports success only after validation and persistence complete.

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

## 18.1 Fallback and failure behaviour

Fallbacks are deliberate and have different trust levels:

| Situation | User-visible behaviour | Data rule |
|---|---|---|
| Branding, legal, or support configuration unavailable | Packaged safe defaults keep navigation and contact guidance usable | No protected record is fabricated |
| Onboarding unavailable or empty | Packaged onboarding slides are shown | Public presentation only |
| Quick actions unavailable | Packaged actions are capability-filtered before display | A fallback button never grants backend access |
| Optional service-template enrichment fails | The base backend service remains visible | Backend catalogue record remains authoritative |
| Catalogue backend fails in production | Error and retry state | No fake production services |
| Explicit development preview/fallback enabled | Bundled sample catalogue may be used | Development only; production forces it off |
| Profile details fail | Identity may fall back to the authenticated user ID | Private profile data is not invented |
| Dashboard sub-queue fails | That queue shows unavailable/unknown state | It is not reported as zero |
| Network/timeout/server failure | Friendly classified message and retry where meaningful | Failed mutations do not show success |
| Session expires | Protected navigation returns to authentication | Protected state fails closed |
| Device authentication fails or is cancelled | Lock screen stays active with retry | OMC session content stays covered |
| Support reply fails after attachment upload | Draft text and uploaded attachment reference are retained where possible | User decides when to retry |
| Expense local persistence/import fails | Failure is shown and local records are preserved | No false deletion or import success |

The shared failure classifier distinguishes offline, timeout, unauthorised, forbidden, missing-record, configuration, validation, server-unavailable, malformed-response, and unknown failures. Retry is not shown for failures that require a permission, authentication, or data correction instead of repetition.

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

## 19.1 Customer guidance by current state

| What the customer sees | Meaning | Recommended action |
|---|---|---|
| Account under review | Registration exists but OMC approval is incomplete | Wait for review, refresh status, or contact support |
| Draft/request form | Service has not yet been submitted | Complete required fields and attach requested files |
| Waiting for Customer | A document, receipt, or requested detail needs customer action | Open the case and follow the latest rejection/next-action note |
| Document under review | File is uploaded and awaiting an authorised reviewer | Do not repeatedly upload unless asked |
| Waiting for Payment | Required documents passed and a valid payment record exists | Follow payment instructions and upload the correct receipt |
| Receipt under review | Finance has received the receipt | Wait for the decision; resubmit only after rejection |
| In Progress | Customer blockers are clear and operational work is active | Follow timeline/notifications and respond to new requests |
| Completed | Completion safeguards passed and work is closed | Review the final timeline and retain any delivered records |

Displayed labels can be customer-friendly projections; backend workflow state remains authoritative.

## 19.2 Document replacement workflow

1. Open the rejected document or linked case.
2. Read the rejection remarks and re-upload instruction.
3. Select the corrected file from camera, gallery, or file picker where the platform permits it.
4. Submit once and wait for upload completion.
5. The new record is linked to the same request while prior private review history remains preserved.
6. A reviewer makes a new human decision.

The app skips a selected item whose local bytes/path are no longer available and reports the partial result instead of pretending every file uploaded.

## 19.3 Receipt correction workflow

1. Open the payment detail and confirm that receipt submission is currently allowed.
2. Review amount, currency, payment instructions, and the previous rejection reason.
3. Select or capture the corrected receipt.
4. Upload through the protected authenticated path.
5. Finance reviews the actual private receipt.
6. `Paid` moves the request forward; `Rejected` returns it to customer action.

An uploaded receipt is evidence for review, not an automatic payment confirmation. The app has no card-charging or payment-gateway claim.

## 19.4 Support workflow

1. Search FAQs/knowledge and check current service notifications.
2. Create a ticket with the correct topic, subject, and clear description if help is still needed.
3. Attach a supported file only when it adds useful evidence.
4. Continue the conversation in the same ticket.
5. Internal support can reply and update status within capability scope.
6. Closed-ticket restrictions prevent unsupported follow-up actions; create a new ticket when guidance requires it.

## 19.5 Admin recovery workflow

For reassignment, exhausted ERP sync, or pending discounts:

1. Open the capability-specific administration queue.
2. Search/filter and inspect the server-provided case context.
3. Confirm that the operation is still eligible.
4. Supply the required assignee, decision, or remarks.
5. Submit once; duplicate taps are blocked.
6. On success, only related case, task, payment, document, dashboard, and admin providers are refreshed.
7. On failure, the original state remains visible and no success is claimed.

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

# 22. Operational guidance

## 22.1 Customer guidance

- Use the same login identity established during signup; email, username, mobile number, and CNIC are supported identifiers where backend resolution succeeds.
- Complete email verification first, then wait for OMC approval when the account is pending.
- Start services from the active backend catalogue; an empty production catalogue means no published services are available, not that sample services should appear.
- Upload documents and receipts from their linked case/payment screens so relationship validation can succeed.
- Treat `Waiting for Customer` as an action state and read the latest remarks before resubmitting.
- Use Support for account-deletion requests; the app intentionally does not instantly destroy the account.
- Enable Device lock on a personal device after configuring a fingerprint, Face ID, PIN, passcode, or pattern in the operating system.

## 22.2 Reviewer and staff guidance

- Work from the queue matching the granted role instead of relying on a copied direct link.
- Review the attached private file and linked record before approving or rejecting.
- Give actionable remarks on rejection so the customer knows what to correct.
- Do not mark a payment `Paid` based only on a filename or customer message.
- Keep task updates inside the allowed operational-state path; use `Submitted by QC` only when QC is genuinely complete.
- Reassign only to a backend-listed eligible user and record a useful reason.
- Retry ERP synchronisation only from an eligible exhausted/failed record after reading the stored error.
- Never interpret a hidden Flutter action as the security control; the backend capability and object scope are authoritative.

## 22.3 Administrator guidance

- Approve registrations only after identity and requested-role review.
- Grant the minimum supported OMC roles needed for the person's work.
- Disabling a staff account is different from deleting operational history.
- Manage service price, currency, required documents, tax slabs, content, and other authoritative configuration in the approved backend surfaces.
- Keep scheduler, workers, Redis, database, backups, HTTPS, nginx, and Supervisor healthy.
- After deployment, test both allowed actions and expected denials for every supported persona.
- Do not remove or recreate the client ERP `HS Code` metadata from OMC code; its current empty references are a separate client-owned prerequisite.

## 22.4 Developer and tester guidance

- Flutter screens call providers/repositories; protected authority stays in Frappe guards.
- Production must receive a valid HTTPS `OMC_API_BASE_URL`.
- Mock auth, service preview, and catalogue fallback are development-only flags and are forced off in production.
- Test mutations for success, forbidden scope, duplicate submission, stale state, and partial failure.
- Do not claim biometric success from a desktop or APK build; use physical Android/iOS hardware with enrolled credentials.
- Use the recorded E2E report as historical evidence and rerun relevant gates after behaviour changes.

---

# 23. Frequently asked questions

## Can a guest create or track a service request?

No. Guests can browse public content and services, use guest-safe tools, and register/login. Protected request, document, payment, support-history, and staff data requires the correct authenticated state.

## Why can a signed-in customer still not start a service?

The account may still be pending approval, the service may be inactive, or the backend may deny the requested action. Check the Under Review screen and service availability, then contact support if the status appears incorrect.

## Does fingerprint or Face ID replace the OMC password?

No. It unlocks an already authenticated local session after the user opts into Device lock. Initial backend authentication still uses the supported OMC login flow. The operating system handles the biometric or device credential; OMC does not receive biometric data.

## What happens if biometric authentication fails or is cancelled?

The app stays on the lock screen and offers another unlock attempt. If the device no longer supports its configured authentication, the user may need to restore the device credential or clear/re-establish the app session through the normal platform process.

## Does the app work fully offline?

No. Guest and pending-user expense tracking has a local mode, and selected presentation content has safe packaged fallbacks. Services, cases, documents, payments, support, tax authority, and staff operations need the backend. Production does not invent catalogue or operational data during an outage.

## Why did a service remain visible when its optional template failed?

The base service came from the authoritative backend catalogue. Optional dynamic form/stage enrichment fails soft so a temporary template problem does not erase the real service. Required backend validation still applies when a request is submitted.

## Are uploaded documents or receipts approved automatically?

No. Automation can route work, send reminders, and move state after a decision, but an authorised human reviews documents and receipts.

## When is a payment created?

Only after required-document conditions pass, the service has a valid positive amount and currency, and no conflicting active payment exists. The amount comes from trusted service configuration, not a customer-supplied total.

## Does uploading a receipt charge a card or confirm payment?

No. The current product supports manual payment instructions and protected receipt review. It does not implement an in-app card gateway.

## What should a customer do after a document or receipt rejection?

Open the linked detail, read the reviewer remarks, correct the issue, and use the provided replacement/resubmission action. Do not create unrelated records to bypass the rejected item.

## Who can see customer data?

Customers are ownership-scoped. Internal users receive only the capabilities and object scope needed by their roles—such as assigned cases, document review, finance review, or support context. Managers/Admins may have broader explicitly granted authority.

## Can an Admin perform every operation merely because the screen is visible?

The backend evaluates the specific capability for each queue and action. Reassignment, ERP retry, discount review, staff management, and registration review remain separate authorities.

## What happens when the backend is unavailable?

The app classifies the failure and shows an appropriate retry or corrective message. Public presentation may use approved packaged defaults, but protected records and successful mutations are never fabricated.

## Does clearing the expense tracker delete cloud expenses?

The clear-local-data action removes local cache only and explicitly does not claim to delete cloud records. Cloud changes use their own guarded backend operations.

## Are push notifications live?

The source includes in-app notifications, preferences, and push-token registration/integrity contracts. Firebase/APNs delivery is not confirmed and must not be presented as a completed production channel until configured and tested.

## How is account deletion handled?

The app creates a support-based deletion request with context. Immediate destructive self-deletion is intentionally not exposed.

## Where should configuration and content be maintained?

Authoritative service, pricing, role, workflow, tax, content, scheduler, and operational administration belongs in the approved Frappe/OMC backend surfaces. Flutter renders and submits within those rules.

---

# 24. Validation status

The latest recorded full audit on 3 August 2026 includes:

```text
OMC backend: 556/556 passed with --skip-test-records
Flutter application: 303/303 passed
Flutter analysis: No issues found
Linux workflow integration contract: 1/1 passed
Android debug APK: built successfully
Focused live HTTP access and admin-operation checks: passed
```

The validated Flutter suite includes the current four-step signup flow, username availability handling, WhatsApp behaviour, canonical payload assertions, and the email-verification success state.

The backend suite covers authority, ownership, operational integrity, guarded reads and writes, scheduler behaviour, workflow automation, and compatibility wrappers.

These are dated evidence, not a timeless claim about every later commit or environment. The isolated OMC backend result intentionally uses `--skip-test-records` on the populated site; ordinary global ERP fixture bootstrap is outside that gate. Physical fingerprint/Face ID success was not verified because no biometric device was connected. See [`inspection.md`](inspection.md) and the [E2E report](docs/test_reports/omc_e2e_workflow_report_2026-08-02.md).

During this documentation refresh at `main` commit `5e599a92`, Flutter analysis passed and the Flutter suite remained 303/303. The backend rerun executed 557 tests and reported one failure: `test_web_link_uses_frappe_origin_by_default` still asserts the former `/verify-email` path, while current verification-link code generates the `pending_registration.verify_registration_web` endpoint. Until that assertion and intended contract are reconciled and rerun, the later backend state must not be called fully green.

Validation must always be based on actual terminal output.

---

# 25. Remaining release work

Code-level validation is complete for the current state, but release validation remains environment-specific.

Before final production release:

1. build the Android release APK or App Bundle with the production HTTPS endpoint;
2. install and launch it on a real Android device;
3. test login, signup, verification links, device lock, services, uploads, payments, notifications, and support against production;
4. run allowed and denied smoke tests for every supported role;
5. verify scheduler, workers, Redis, database, nginx, and Supervisor health;
6. verify backup and restore readiness;
7. perform iOS archive, signing, and App Store validation on macOS with Xcode if an iOS release is required.
8. resolve the retained empty client ERP `HS Code` Link prerequisite if those fields will be used.
9. reconcile the verification-web-link contract test with the intended browser endpoint and rerun the backend suite.

---

# 26. Client-facing feature summary

OMC House receives a connected platform with:

- public service discovery;
- structured account onboarding;
- email verification and account approval;
- optional fingerprint, Face ID, or device-credential session lock;
- customer profiles and preferences;
- service-request submission;
- customer case tracking;
- document collection and review;
- payment and receipt workflows;
- support tickets and replies;
- leads and referrals;
- internal assignments and tasks;
- registration/staff administration and operational recovery queues;
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

# 27. Final product statement

OMC App is not only a collection of mobile screens. It is a controlled service-delivery system in which:

- customers receive a simple self-service experience;
- OMC teams receive role-specific operational tools;
- Frappe remains the source of truth;
- protected records remain ownership- and capability-scoped;
- document and payment decisions remain human-controlled;
- reminders and workflow transitions reduce manual follow-up;
- automated tests protect the core contracts.

**The result is a unified customer portal and OMC operations platform designed for controlled, auditable, production deployment.**
