# OMC App — Business and Workflow Architecture Guide

## 1. Purpose

This document explains the **current OMC App business workflow** from customer acquisition through service execution and ERP handoff.

It is intended for:

- OMC House management;
- client stakeholders;
- operations, support, document, finance, referral, and service teams;
- developers and testers;
- deployment/handover engineers.

This is not a future design document. It describes the repository state currently implemented on branch `feature/customer-home-dashboard`, while clearly marking remaining alignment gaps and release gates.

Last source cross-check: **18 August 2026**.

For installation and engineering commands, see [`README.md`](README.md).

For the exact role/capability architecture, see [`docs/app_role.md`](docs/app_role.md).

For a feature-by-feature inventory, see [`OMC_APP_FEATURES.md`](OMC_APP_FEATURES.md).

---

# 2. Current validation snapshot

The latest recorded test state after the customer/staff identity split, ERP Lead cleanup, customer migration work, and imported-customer activation implementation is:

```text
Backend OMC suite:            591 / 591 passed
Customer activation tests:      8 / 8 passed
Flutter analyze:              No issues found
Flutter suite:                326 / 326 passed
Router policy parity suite:    51 / 51 passed
```

Two release facts remain important:

1. the permanent bulk migration of existing ERP customers has **not** been run;
2. the real browser/device imported-customer activation journey still needs its final manual E2E rehearsal before that migration is released.

---

# 3. Core operating model

OMC App does not try to replace ERPNext. It adds the mobile/customer experience, OMC-specific approval state, guarded workflows, and operational automation around ERP records.

The key design rule is:

> **Use ERPNext as the source of truth where ERPNext already owns the business record. Use OMC DocTypes only for OMC-specific application/workflow state.**

The current boundaries are:

| Business area | Source of truth | OMC responsibility |
| --- | --- | --- |
| Lead | ERPNext `Lead` | mobile/internal guarded create/read and workflow integration |
| ERP customer master | ERPNext `Customer` | link to OMC customer profile and activation bridge |
| Customer app profile | `OMC Customer Profile` | app identity, lifecycle, referral attribution, mobile profile state |
| Customer login | Frappe `User` when activated | Website User + `OMC Customer` role |
| Internal employee | ERP `Employee` | existing HR/ERP employee record |
| OMC staff state | `OMC Staff Profile` | OMC approval, persona, active state, referral ownership |
| Service catalogue | `OMC Service` | customer-facing service configuration and ERP Task Type mapping |
| Customer service case | `OMC Service Request` | customer-facing lifecycle, documents, payment gate, assignment, timeline |
| ERP service execution | ERP `Service` + ERP `Task` | created only when OMC request becomes ERP-eligible |
| Payment review | `OMC Service Payment` | receipt collection/review and service activation gate |
| Accounting/invoicing | ERPNext finance | not replaced by OMC payment records |

ERPNext source files must remain untouched. OMC integration belongs inside the custom `omc_app` through hooks, APIs, DocTypes, permission guards, and adapters.

---

# 4. High-level end-to-end workflow

The intended main business path is:

```text
Lead / existing customer / new app customer
                |
                v
         ERP Customer exists
                |
                v
       OMC Customer Profile
                |
                v
        OMC Service Request
                |
                v
       Required Documents
                |
                v
      Payment (if required)
                |
                v
        Payment Confirmed
                |
                v
      ERP Service + ERP Task
                |
                v
       Operational execution
                |
                v
           Completion
```

For a zero-price service, the payment step is skipped once the request reaches the relevant eligibility point; the request moves to `In Progress` and ERP activation is attempted directly.

---

# 5. Customer identity model

The customer side deliberately separates **business customer status** from **login account activation**.

```text
ERP Customer
    |
    +--> OMC Customer Profile
             |
             +--> Frappe Website User only when app login exists
```

This is especially important for the client's existing ERP customers. OMC does not need to create thousands of Frappe Users merely to represent existing business customers.

---

# 6. New app customer signup

## 6.1 Flutter registration

The Flutter signup currently offers:

```text
Customer
Consultant
Business Partner
Tax Associate
```

The form collects the supported identity/profile data, username, acquisition source, optional referral data, and password.

## 6.2 Pending Registration token

A new signup first creates an `OMC Pending Registration` rather than immediately trusting the submitted email.

The backend:

- validates the public payload;
- requires a valid email and password;
- creates a random verification token;
- stores only the token digest;
- applies a 30-minute token lifetime;
- applies a 60-second resend cooldown;
- supersedes/rotates old verification tokens safely;
- emails the verification link unless email delivery is explicitly muted in development/test.

## 6.3 Email verification

When the user opens the verification link, the backend consumes the pending registration and calls the canonical signup flow.

For a normal `Customer` registration, the current implementation creates:

```text
Frappe User
    user_type = Website User
    role includes OMC Customer

OMC Customer Profile
    customer_status = Active
    approval_status = Approved
    is_active = 1
    customer_origin = App Signup
    linked_app_user = customer email
```

Therefore, **normal Customer signup is currently activated after successful email verification; it is not waiting for a separate manual OMC customer approval step.**

If OMC later wants every new Customer to require manual approval, that is a business-rule change and should be implemented deliberately rather than assumed from older documentation.

---

# 7. Staff/customer signup alignment note

The Flutter signup still exposes `Consultant`, `Business Partner`, and `Tax Associate` application types.

Current legacy-compatible behaviour for these non-customer registration types is:

```text
email verified
    -> Frappe Website User initially created
    -> OMC Customer Profile created as Pending / Pending Review
    -> Admin Control can later replace OMC Customer role with staff role(s)
```

This path is **not fully aligned with the newer `OMC Staff Profile` authority model** yet.

The target/current staff authority is:

```text
Frappe System User
    -> OMC Staff Profile
       -> staff_role
       -> staff_status
       -> approval_status
       -> is_active
       -> effective OMC capabilities
```

Before production reliance on self-service staff applications or Admin Control staff invitation/editing, those flows should be normalised so staff creation/approval updates the Staff Profile rather than treating direct Frappe role assignment as the complete OMC approval mechanism.

---

# 8. Existing ERP customer migration

The client already has thousands of ERP Customers. The migration is intentionally **profile-only**.

## 8.1 What migration creates

For a safely resolved existing ERP Customer, the migration creates or reuses an `OMC Customer Profile` like:

```text
linked_erpnext_customer = <existing ERP Customer>
customer_origin = Imported
acquisition_source = Existing
customer_status = Active
approval_status = Approved
is_active = 1
manual_customer_status = Unregistered
user = blank
linked_app_user = blank
```

No Frappe User is created.

No password is created.

No shared/default password is assigned.

Existing profile/app identity is preserved and is never blindly overwritten.

## 8.2 Identity resolution order

The migration classifies customers using this priority:

```text
1. safe unique Customer email
2. unique CNIC from the linked ERP Lead
3. safe unique resolved phone with no Customer/Lead phone conflict
4. identity review
```

Only a real **unique Customer email** is persisted as profile email during migration.

CNIC/phone fallback profiles remain email-less until a future secure activation path resolves their login identity.

## 8.3 Restored client-data snapshot

The tested restored client dataset produced:

```text
Total ERP Customers:                 4,886
Profile-only auto-migratable:        4,530
Identity review:                       356

Unique-email activation candidates:  3,245
Unique-CNIC fallback:                1,004
Unique-safe-phone fallback:            281
```

The 356 identity-review customers are intentionally skipped rather than guessed.

## 8.4 Safety behaviour

The migration code is designed to be:

- read-only during `dry_run()` and `preflight()`;
- explicit-confirmation protected during `apply()`;
- idempotent;
- batch-commit capable;
- profile-only;
- collision-aware;
- non-destructive to existing User/profile links.

The permanent 4,530-profile apply is still on hold until the real activation E2E is complete.

---

# 9. Existing customer first-time app activation

An imported ERP customer is already a valid business customer but does not automatically have an app password.

The first-time journey is:

```text
Customer opens Flutter app
        |
        v
"Activate existing account"
        |
        v
Enter registered email
        |
        v
Backend sends secure activation link
        |
        v
Customer opens link
        |
        v
Create password + confirm password
        |
        v
Website User created now
        |
        v
OMC Customer role applied
        |
        v
Existing Customer Profile linked
        |
        v
Normal login available
```

## 9.1 Token security

`OMC Customer Activation` stores the activation lifecycle, but not the plaintext token.

Security rules include:

- cryptographically random token;
- SHA-256 digest stored in the database;
- 30-minute expiry;
- 60-second request cooldown;
- old pending token superseded by a newer request;
- one-time consumption;
- public activation request response does not reveal whether the customer exists;
- eligibility is checked both when requesting and when consuming the token;
- minimum eight-character chosen password;
- no automatic merge with an existing Frappe User identity.

On successful activation:

```text
User.user_type = Website User
OMC Customer role = applied
profile.user = email
profile.linked_app_user = email
profile.manual_customer_status = Linked
activation.status = Used
```

The imported profile's business approval (`Active + Approved`) is preserved; activation only adds login identity.

## 9.2 Collision handling

If an existing Frappe User appears for the same identity, the backend does not guess.

The activation moves to review, and an existing-user collision can mark the customer profile for duplicate review.

## 9.3 Current activation coverage

Email self-service activation is initially suitable for the **3,245 unique-email** migration candidates.

The CNIC-only and phone-only migration candidates still need a future secure SMS/OTP or controlled staff-assisted activation path. They must not receive fabricated emails or default passwords.

---

# 10. Internal staff model

Internal OMC users are separate from customers.

```text
Frappe User
    |
    +--> OMC Staff Profile
             |
             +--> ERP Employee
```

## 10.1 Default staff lifecycle

A newly ensured Staff Profile starts as:

```text
staff_status = Pending
approval_status = Pending Review
is_active = 0
```

Normal staff access requires:

```text
Frappe User exists and is enabled
+ effective OMC staff persona exists
+ OMC Staff Profile exists
+ staff_status = Active
+ approval_status = Approved
+ is_active = 1
+ linked ERP Employee is Active when present
```

An active ERP Employee by itself does not approve OMC access.

## 10.2 Staff persona

Recognised OMC staff personas are:

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

The effective OMC role set can combine recognised direct Frappe OMC roles with `OMC Staff Profile.staff_role`.

## 10.3 Role Profile rule

OMC must not modify a client's shared Frappe Role Profile merely to express the OMC persona.

Existing ERP/Frappe Role Profiles remain ERP configuration. OMC persona and approval belong in the Staff Profile.

System Manager and Administrator remain trusted system-level overrides.

---

# 11. Lead workflow

`OMC Lead` has been retired. The canonical lead is the native ERPNext `Lead`.

```text
Lead source / enquiry
        |
        v
ERPNext Lead
        |
        v
ERPNext Customer conversion
        |
        v
OMC Customer Profile
```

## 11.1 Flutter lead capability

The current Flutter/internal APIs can:

- create an ERP `Lead` through the OMC guarded API;
- list ERP Leads;
- open ERP Lead detail;
- show customer/conversion context returned by the backend.

The backend lead read guard requires `can_manage_leads`.

## 11.2 Lead conversion

The current Flutter Lead detail does **not** implement the full ERP Lead-to-Customer conversion action.

Lead conversion remains an ERP/Frappe Desk business operation unless/until a guarded OMC conversion endpoint is deliberately added.

After an ERP Customer exists, OMC can link/migrate that customer into the Customer Profile model.

The existing customer migration also uses the ERP Customer's linked Lead as a trusted fallback source for CNIC/phone classification where applicable.

---

# 12. Service catalogue and ERP Task Type mapping

Customer-visible service configuration is owned by `OMC Service`.

An OMC Service can contain:

- title and description;
- category;
- public/mobile presentation fields;
- price and currency;
- estimated/completion time;
- required documents;
- default assignee;
- default assignment role;
- parallel-request rule;
- active/featured state;
- `erp_task_type` mapping.

The important ERP bridge is:

```text
OMC Service.erp_task_type
        |
        v
existing ERP Task Type
        |
        +--> ERP Service.service_type
        +--> ERP Task.type
```

OMC does not own or replace ERP `Task Type` records.

---

# 13. Service request creation

All service-request creation routes converge on the shared assisted-service authority.

Supported customer modes are:

```text
Self
My Referral
Existing Customer
Walk-in Customer
```

## 13.1 Self

An approved customer creates a request for their own Customer Profile.

The backend validates the service, customer identity, request payload, and duplicate/parallel-request rules.

## 13.2 My Referral

An eligible referral owner can assist a referred customer only when the referral relationship and required assistance consent are valid.

## 13.3 Existing Customer

Broad assisted access is reserved for the authorised operational roles defined by the backend and requires customer-consent context.

## 13.4 Walk-in Customer

Authorised internal staff can create an `OMC Manual Customer` for a walk-in identity and create an OMC Service Request against it.

A walk-in customer is **not automatically an ERP Customer**.

The ERP bridge intentionally reports pending configuration until that identity is converted/resolved to a valid ERP Customer.

---

# 14. Pricing and discount workflow

The service request stores a pricing snapshot derived from trusted OMC Service configuration.

Customers cannot submit internal discount values.

Authorised internal creation can include a discount request using:

```text
Percentage
Fixed Amount
```

The backend validates:

- non-negative discount;
- percentage not greater than 100%;
- fixed discount not greater than original price;
- reason required when a discount exists;
- configured auto-approval threshold;
- configured minimum service price.

A discount can become:

```text
None
Approved
Pending Approval
```

A request with `discount_status = Pending Approval` does not open its payment until the pricing decision is resolved.

---

# 15. Assignment workflow

The service assignment resolver currently uses this precedence:

```text
1. explicit eligible assignee
2. referral owner
3. service default assignee
4. least-loaded user for service assignment role
5. least-loaded OMC Manager fallback
6. unassigned if nobody eligible
```

When an assignee is selected, OMC can:

- store `assigned_staff` on the service request;
- create/reuse a Frappe ToDo for the exact OMC Service Request;
- notify the assignee;
- add an internal assignment timeline entry;
- synchronise assignment to the linked ERP Task when that Task already exists.

### Current persona-alignment note

The central capability resolver understands Staff Profile personas, but some operational discovery helpers still search direct Frappe `Has Role` / `frappe.get_roles()` membership when finding assignable staff, referral-assisted modes, or reviewer pools.

Therefore final production hardening should normalise those discovery paths to the same effective Staff Profile persona model before relying exclusively on Staff Profile-only personas for every automatic assignment/reviewer workflow.

---

# 16. Document workflow

The customer document lifecycle is tied to the exact OMC Service Request.

## 16.1 Customer upload

The backend validates:

- customer ownership;
- request/document relationship;
- file data and allowed upload contract;
- prevention of cross-request file reuse;
- protected/private file handling where applicable.

## 16.2 Review

Document-review authority requires the correct backend capability.

A reviewer can approve or reject according to the supported workflow.

Rejected documents can move the case to:

```text
Waiting for Customer
```

and the customer is notified to provide a correction/replacement.

## 16.3 All required documents approved

After required-document completion, the backend evaluates pricing/payment eligibility.

This is the main gate that determines whether the case opens a payment or can proceed directly as a zero-price service.

---

# 17. Payment workflow

The current OMC payment flow is a **manual transfer/receipt-review workflow**, not an online card/payment gateway.

## 17.1 Positive-price service

When required documents are approved and pricing is ready:

```text
OMC Service Payment created
status = Pending
        |
OMC Service Request
status = Waiting for Payment
```

The amount is derived from the trusted request final price/service price.

The customer can receive configured bank/payment instructions and a WhatsApp support link.

The backend explicitly reports:

```text
online_gateway_available = false
payment_channel = whatsapp_support
```

## 17.2 Customer receipt submission

The customer uploads a private receipt file.

The payment becomes:

```text
Receipt Submitted
```

and a payment-review assignment can be created for Finance Review.

## 17.3 Finance review

Allowed review outcomes are guarded transitions among:

```text
Under Review
Paid
Rejected
Cancelled
```

A receipt is required before `Under Review`, `Paid`, or `Rejected`.

Rejection requires remarks.

## 17.4 Paid result

When Finance marks the payment `Paid`:

```text
Payment = Paid
        |
Service Request -> In Progress
        |
ERP activation attempted
```

The customer timeline is updated and the assigned staff member can be notified that work is ready to start.

## 17.5 Rejected result

A rejected receipt moves the service request back to:

```text
Waiting for Customer
```

so a corrected/replacement receipt can be provided.

---

# 18. Zero-price service workflow

If the final service amount is exactly zero after required-document/pricing eligibility:

```text
no OMC Service Payment is created
        |
Service Request -> In Progress
        |
ERP activation attempted
```

The timeline records that no payment is required.

A negative price is treated as invalid configuration rather than silently continuing.

---

# 19. ERP activation gate

The OMC Service Request may exist **before** an ERP `Service` or ERP `Task` exists.

This is intentional.

## 19.1 Paid services

For an amount greater than zero:

```text
ERP Service/Task creation blocked
until a Paid OMC Service Payment exists
```

## 19.2 Zero-price services

For amount equal to zero:

```text
ERP Service/Task creation becomes eligible
when the request is In Progress
```

## 19.3 Required ERP configuration

ERP creation also requires:

```text
valid linked ERP Customer
+
OMC Service.erp_task_type
```

If either is missing, OMC does not invent data. The request moves into an ERP sync/configuration state such as `Pending Configuration` with an explanatory error.

---

# 20. ERP Service and Task creation

When the activation gate passes, `erp_service_task_adapter` creates or repairs the ERP execution records.

## 20.1 ERP Service

The adapter creates ERP `Service` with the resolved ERP Customer and mapped Task Type, and fills compatible client fields when they exist.

Conceptually:

```text
ERP Service.customer = linked ERP Customer
ERP Service.service_type = OMC Service.erp_task_type
```

## 20.2 ERP Task

The adapter creates ERP `Task` with:

```text
Task.customer = linked ERP Customer
Task.type = OMC Service.erp_task_type
Task.subject = OMC request title
Task.priority = OMC request priority
```

The ERP Service and Task are linked where the client's Service metadata supports it.

An assignment ToDo can be created for the request's assigned OMC staff member.

## 20.3 Idempotency/repair

Existing valid ERP links are preserved.

Partial/broken links can be marked `Repair Required` or repaired through the guarded recovery path rather than blindly creating duplicates.

---

# 21. ERP Task status back to customer workflow

ERP Task updates are hooked back into the OMC Service Request.

The Task status/operation status is mapped to customer-facing states such as:

```text
Open
In Progress
Waiting for Customer
Waiting for Payment
Completed
Cancelled
```

Important protections:

- a terminal OMC case cannot be reopened by a later ERP Task update;
- Task completion cannot complete the OMC case while required OMC completion blockers remain;
- completion attribution is recorded;
- linked ERP Service status is updated where the client's ERP Service field supports the mapped value;
- cancellation can propagate to linked OMC/ERP workflow in a controlled way.

This allows the client to continue operational execution in ERP Desk while the customer sees a controlled OMC status.

---

# 22. Completion blockers

A service case cannot simply be marked completed because one screen says the work is finished.

Completion checks include the relevant OMC/ERP state, including:

- required documents fully approved;
- active payments confirmed as Paid when payment records exist;
- linked ERP Task completed when an ERP Task exists;
- terminal-state safeguards.

When completion succeeds, the workflow can close related open work, store completion attribution/time, update timeline state, and notify the customer.

---

# 23. Referral model

Referral ownership belongs to eligible approved staff, not to customers.

Referral-capable OMC staff personas are:

```text
OMC Consultant
OMC Tax Associate
OMC Business Partner
```

Eligibility also requires:

- enabled Frappe System User;
- approved/active OMC Staff Profile;
- effective referral-capable OMC persona.

The staff side owns:

```text
OMC Referral
referral code
```

The referred customer side stores attribution such as:

```text
referred_by
referral_record
referral_code_used
referral_assistance_consent
```

A customer does not receive an `own_referral_code` merely by being a customer.

If a staff referrer becomes ineligible, referral automation can deactivate that referral relationship/code.

---

# 24. Support, notifications, tax, and expenses

These remain supporting application modules around the core service workflow.

## Support

Customers can create and follow their own support tickets; authorised Support staff operate guarded support queues and replies.

## Notifications

OMC creates ownership-scoped in-app notifications for service, document, payment, assignment, reminder, and escalation events.

Push-token contracts exist, but production Firebase/APNs delivery should not be presented as verified unless the external push stack is actually configured and tested.

## Scheduler

Hourly jobs currently include isolated recovery/maintenance work such as:

- unassigned service recovery;
- automatic ERP sync recovery;
- review assignment checks;
- submission integrity rescore;
- pending-registration cleanup.

Daily jobs include workflow reminders/escalations and notification cleanup.

Each scheduled job is run with isolated transaction handling so one failure does not automatically poison the entire scheduler batch.

## Tax calculator

The tax calculator uses backend-controlled configuration/calculation and exposes guest/customer-safe tax tooling through guarded APIs.

## Expense tracker

Guest/pending usage can remain local, while approved-customer cloud operations use guarded backend expense APIs, budgets, summaries, and receipt upload contracts.

---

# 25. Security model

Security is backend-first.

The system uses multiple layers:

```text
Flutter route visibility
        |
        v
backend authentication
        |
        v
customer/staff lifecycle gate
        |
        v
canonical capability check
        |
        v
ownership / assignment / relationship scope
        |
        v
workflow-state validation
        |
        v
protected mutation
```

Important rules:

- customer ownership is always checked on protected records;
- staff workspace access is not universal staff authority;
- document and payment review require separate capabilities;
- pending staff cannot fall through into customer authority;
- sensitive legacy API names are redirected through guarded method overrides in `hooks.py`;
- Frappe DocPerm provides a baseline, but guarded APIs remain mandatory;
- uploaded files are tied to their business record and protected against unsafe reuse;
- identity collisions fail closed rather than auto-merging.

---

# 26. Current admin/staff alignment gaps

The new Staff Profile authority is implemented in central access control, but several older operational paths still need final convergence.

Current examples include:

1. **Admin Control staff invitation/role editing** still manipulates direct Frappe User roles and does not yet make the Staff Profile lifecycle the complete write authority.
2. **Registration review for staff-like signup types** still starts from an `OMC Customer Profile` application and direct role conversion.
3. **Automatic service assignment discovery** currently searches direct Frappe role membership for eligible assignees.
4. **Review-pool discovery** uses direct `Has Role` membership before capability validation.
5. **Some assisted-service mode checks** use direct Frappe roles rather than the unified effective Staff Profile role set.

The central capability resolver is already Staff Profile-aware; these discovery/write paths are the remaining alignment work needed to make Staff Profile-only personas fully authoritative everywhere.

---

# 27. Current features that must not be overclaimed

The following are not production-complete in the current repository state:

- permanent 4,530 existing-customer profile migration;
- real browser/device E2E for imported-customer activation;
- self-service SMS/OTP activation for CNIC/phone-only imported customers;
- fully Staff Profile-native admin invitation/application workflow;
- fully Staff Profile-native assignment/reviewer discovery across every helper;
- Flutter commission screens as a working production feature — the current Flutter commission repository still points at retired `referral_commissions` backend endpoints;
- automatic ERP Sales Invoice creation from the OMC payment workflow;
- an in-app online payment gateway/card checkout;
- Flutter Lead-to-ERP-Customer conversion action;
- confirmed production Firebase/APNs push delivery;
- Google sign-in.

The current payment workflow ends at OMC receipt review and ERP service/task activation. Accounting/invoice creation remains an ERPNext finance responsibility unless a separate guarded OMC integration is implemented and tested later.

---

# 28. Practical customer journey examples

## 28.1 New customer

```text
Install/open app
    -> Sign up as Customer
    -> Receive verification email
    -> Verify email
    -> Website User + OMC Customer Profile created
    -> Customer profile Active/Approved
    -> Login
    -> Browse service
    -> Create request
    -> Upload required documents
    -> Finance/payment flow if required
    -> ERP Service/Task activated when eligible
    -> Track progress
    -> Completion
```

## 28.2 Existing ERP customer with unique email

```text
ERP Customer already exists
    -> profile-only migration
    -> Active/Approved imported OMC Customer Profile
    -> no User/password yet
    -> customer opens app
    -> Activate existing account
    -> email link
    -> choose password
    -> Website User created and linked
    -> login
    -> normal service workflow
```

## 28.3 Existing ERP customer without safe email

```text
ERP Customer
    -> profile-only migration via unique CNIC/phone
    -> Active/Approved business profile
    -> no login identity yet
    -> wait for secure SMS/OTP or controlled assisted activation
```

No fake email or default password is used.

---

# 29. Practical staff journey example

Target operational model:

```text
Existing Frappe User / ERP Employee
        |
        v
OMC Staff Profile created
Pending + Pending Review + inactive
        |
        v
OMC administrator approves profile/persona
        |
        v
Active + Approved + is_active
        |
        v
capability-specific internal workspace
        |
        v
assigned/relevant work only
```

The client's existing ERP Role Profile remains unchanged.

---

# 30. Practical service-to-ERP example

For a paid service:

```text
Customer requests OMC Service
        |
OMC Service Request created
        |
Documents submitted/reviewed
        |
all required documents approved
        |
OMC Service Payment created
Waiting for Payment
        |
customer transfers payment + uploads receipt
        |
Finance Reviewer marks Paid
        |
OMC Service Request -> In Progress
        |
ERP activation gate passes
        |
linked ERP Customer resolved
OMC Service.erp_task_type resolved
        |
ERP Service created
ERP Task created
Task assigned
        |
ERP staff execute work
        |
ERP Task status syncs customer-visible OMC status
        |
completion blockers pass
        |
OMC Service Request Completed
```

This is the core backend-driven bridge between the Flutter customer experience and the client's normal ERP execution environment.

---

# 31. Source locations

The main implementation areas behind this guide are:

```text
Customer signup / verification
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/pending_registration.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/mobile.py

Existing customer migration / activation
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/customer_migration.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/customer_activation.py

Staff identity and capability
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/staff_profile.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/access.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/roles.py

Service request / assignment
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/service_request_guard.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/assisted_service.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/service_assignment.py

Documents / payment / workflow
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/customer_documents.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/payments.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/workflow_automation.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/review_routing.py

ERP bridge
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/erp_activation.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/erp_service_task_adapter.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/erp_task_status_sync.py

Lead authority
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/lead_read_guard.py
backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/mobile.py

Flutter routing
omc_app/lib/app/router.dart
```

---

# 32. Final architecture summary

OMC App now follows this principle:

```text
ERP owns ERP records.
OMC owns OMC application/workflow state.
Flutter is the user experience.
Frappe backend is the authority.
```

The core customer workflow is:

```text
Customer identity
    -> OMC Customer Profile
    -> OMC Service Request
    -> documents
    -> payment gate
    -> ERP Service / Task
    -> execution
    -> completion
```

The core staff workflow is:

```text
Frappe User / ERP Employee
    -> OMC Staff Profile approval
    -> effective OMC persona
    -> capabilities
    -> assignment/relevance scope
    -> guarded operation
```

And the core security rule remains:

> **Never create identity from a guess, never grant access from UI visibility, never use one broad staff flag as authority, and never patch ERPNext source to implement OMC business logic.**
