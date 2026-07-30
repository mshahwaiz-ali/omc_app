Final architecture target
Client Custom ERP
├── Customer                    canonical customer/business record
├── Service                     canonical ERP service/work transaction
├── Task                        canonical internal operational task
├── Sales Invoice               canonical invoice
├── Payment Entry               canonical payment
└── GL                          canonical accounting

OMC App
├── OMC Customer Profile        mobile/app identity and ERP Customer link
├── OMC Service                 mobile catalogue/presentation layer
├── OMC Service Request         customer-facing booking and tracking record
├── OMC Service Document        mobile document workflow
├── OMC Service Payment         mobile payment/receipt presentation
├── OMC Service Timeline        customer-visible activity
├── notifications               mobile/in-app notification layer
└── secured ERP adapters        controlled access to ERP Customer/Service/Task

Retired eventually
├── lead_app
└── OMC Task

This respects the fixed rule:

ERP code and workflow remain untouched.
All integration and compatibility work happens inside omc_app.

That aligns with the original consolidation objective and preservation requirements.

Key authority decisions
Customer
ERP Customer
= canonical business/customer record

OMC Customer Profile
= app identity, onboarding, access and mobile metadata

Each valid OMC customer profile should link to an existing ERP Customer where one exists.

OMC Customer Profile already contains:

User
CNIC
NTN
phone
customer type
company information
linked_erpnext_customer

However, linked_erpnext_customer is currently a plain Data field rather than a proper Frappe Link.

Recommended outcome:

OMC Customer Profile.linked_erpnext_customer
→ proper Link to Customer

This change will be made only after production values are inspected and normalized.

Service Request
OMC Service Request
= customer-facing booking and tracking case

It should not be deleted.

It already contains the app-specific information that ERP Service may not be designed to provide cleanly:

customer submission context;
self-service versus staff-assisted booking;
referral ownership;
consent reference;
source channel;
customer-facing status;
assigned staff;
expected completion date;
customer profile;
mobile timeline context.

This is valuable and distinct from ERP internal processing.

ERP Service
ERP Service
= existing client ERP service/work transaction

We must inspect whether:

every Service automatically creates a Task;
Task is the actual work unit;
Service controls pricing and customer relationship;
Service status is derived from Task;
multiple Tasks may belong to one Service;
invoice creation uses Service;
Service is a catalogue item or transaction record.

Current repository documentation indicates that Service and Task are connected through erpnext/service.py.

Likely final relationship:

OMC Service Request
    ├── customer tracking authority
    └── linked ERP Service
             └── ERP Task(s)
Task
ERP Task
= final internal task authority

OMC Task
= temporary duplicate to be retired

OMC Task currently contains only a simple parallel model:

title;
description;
status;
priority;
due date;
assigned user;
customer profile;
service request;
support ticket;
completion date;
notes.

ERP Task is likely richer and already used by the client.

But OMC backend currently reads OMC Task directly, filters it by assignment, and exposes it through mobile task endpoints.

Therefore, the final transition will replace the implementation behind the API contract, rather than breaking the task feature.

Strict implementation plan
Phase 0 — Live ERP truth inspection
Goal

Confirm the real live-site schema and production workflow before changing any backend logic.

Read-only inspection targets
Installed apps
bench --site omc.local list-apps
bench version
ERP Customer

Inspect:

custom fields;
user_link;
CNIC/NTN fields;
phone/email fields;
customer status;
customer ownership;
links to Service;
links to Task;
existing mobile-related fields.
ERP Service

Inspect:

complete schema;
workflow;
statuses;
customer field;
Lead field;
user link;
service type;
amount;
discount;
net amount;
assigned employee/user;
Task links;
invoice links;
payment fields;
cancellation;
completion;
document links.
ERP Task

Inspect:

customized fields;
workflow state;
status;
subject;
priority;
expected dates;
assigned users;
_assign;
customer links;
Service links;
Lead links;
Consultant/Partner/Tax Associate links;
document fields;
filing fields;
completion rules;
cancellation rules.
Data counts
Customer
Service
Task
OMC Customer Profile
OMC Service Request
OMC Task
Deliverable

A live-site matrix:

Domain	ERP field	OMC field	Existing production values	Final authority
Customer identity	Customer.name	linked ERP Customer	count	ERP
Service status	custom_status	status	count	To determine
Task status	Task.status/workflow_state	OMC Task.status	count	ERP
Assignment	_assign / custom user field	assigned_to	count	ERP
Cancellation	ERP workflow	Cancelled	count	ERP where equivalent
Exit condition

No field or workflow assumption remains unverified.

Phase 1 — Freeze the canonical mapping

No code yet.

Create the exact domain map:

ERP Customer
↔ OMC Customer Profile

ERP Service
↔ OMC Service Request

ERP Task
↔ OMC Service Request / Flutter Tasks

ERP Sales Invoice
↔ OMC Service Request / OMC Service Payment

ERP Payment Entry
↔ OMC Service Payment

For every field, assign one classification:

ERP_AUTHORITY
OMC_AUTHORITY
OMC_READS_ERP
OMC_WRITES_ERP
DERIVED_DISPLAY_ONLY
MIGRATION_ONLY
OBSOLETE
Example
Meaning	Authority
Accounting customer	ERP Customer
App login	User
App customer preferences	OMC Customer Profile
Service booking intent	OMC Service Request
Internal work assignment	ERP Task
Internal work status	ERP Task
Customer-visible request status	OMC Service Request
Invoice status	ERP Sales Invoice
Payment status	ERP Payment Entry/gateway
Mobile notification state	OMC
Phase 2 — Customer Profile ↔ ERP Customer integration
Backend changes
2.1 Normalize ERP Customer link

Change or migrate:

linked_erpnext_customer
Data → Link / Customer

No ERP field changes.

2.2 Build ERP Customer resolver

Inside omc_app:

resolve_erp_customer(profile)

Resolution order:

explicit existing ERP Customer link;
verified existing user_link;
exact CNIC/NTN match;
exact verified email;
exact verified phone;
manual duplicate review.
2.3 Do not auto-create blindly

ERP Customer creation should occur only when:

no existing match exists;
business flow requires an ERP Customer;
the user is a real customer;
required identity data exists;
the caller has proper capability;
duplicate checks pass.

Never create ERP Customers for:

Guest;
Administrator;
internal staff;
integration accounts;
unverified signups;
abandoned registrations.
2.4 Existing customer linking utility

Create a controlled backend reconciliation command or patch that:

OMC Customer Profile
→ finds matching ERP Customer
→ records proposed link
→ auto-links only unambiguous matches
→ reports ambiguous matches for review
Validation

Test:

existing Customer by explicit link;
matching by user;
matching by CNIC;
duplicate CNIC;
duplicate email;
no ERP Customer;
internal user;
disabled customer;
manually reviewed link.
Phase 3 — ERP Service and OMC Service Request integration

This is the most important design phase.

Recommended model
OMC Service Request
= customer-facing case

ERP Service
= ERP operational service record

Add an OMC-side reference conceptually:

OMC Service Request.erp_service

This should be a proper Link if the ERP Service DocType exists on the site.

Creation flow

Recommended flow:

Customer submits OMC Service Request
→ OMC validates customer profile
→ OMC resolves linked ERP Customer
→ OMC Service Request created
→ backend evaluates ERP Service creation policy
→ ERP Service created or existing one linked
→ ERP’s existing logic creates/links ERP Task
→ OMC stores ERP Service reference
→ customer sees OMC tracking status
Important choice: immediate versus approved creation

We should inspect the live workflow and choose one:

Option A — Immediate ERP Service creation

Use when every valid mobile booking should immediately become ERP operational work.

OMC request creation
→ ERP Service creation
→ ERP Task creation
Option B — Approval-gated ERP Service creation

Recommended if customers can submit incomplete, duplicate, invalid, or unpaid requests.

OMC request created as Open
→ manager reviews
→ request approved
→ ERP Service created
→ ERP Task created

My current recommendation is Option B, unless the client’s existing workflow expects immediate Service creation.

It provides:

duplicate protection;
cleaner ERP;
staff review;
document validation;
pricing confirmation;
customer matching;
better failure handling.
Phase 4 — ERP Task adapter inside omc_app
Goal

Replace all mobile usage of OMC Task with controlled ERP Task access.

Do not expose generic Frappe Task APIs

Build dedicated OMC APIs:

omc_app.api.erp_tasks.get_tasks
omc_app.api.erp_tasks.get_task
omc_app.api.erp_tasks.update_task_status
omc_app.api.erp_tasks.assign_task
omc_app.api.erp_tasks.get_task_activity

Exact methods depend on client workflow and capabilities.

Backend task list

The adapter should read ERP Task and return the existing stable Flutter shape:

{
  "name": "TASK-0001",
  "title": "Tax Filing",
  "status": "Open",
  "priority": "Medium",
  "due_date": "2026-08-10",
  "assigned_to": "staff@example.com",
  "service_request": "OMC-SR-...",
  "erp_service": "SERVICE-...",
  "customer_name": "..."
}

Flutter already expects task aliases such as:

subject, title, or task_name;
exp_end_date, due_date, or deadline;
assigned_to or owner.

Therefore, the backend can preserve the existing contract while replacing the source DocType.

Permission policy
Manager

Can:

see eligible ERP Tasks;
assign/reassign;
update permitted fields;
review linked Service and Customer.
Assigned staff

Can:

see assigned tasks;
update permitted statuses;
add notes/documents where allowed.
Customer

Must not access raw ERP Task records.

Customers see only the mapped state through OMC Service Request.

Assignment resolution

ERP Task may use:

_assign;
owner;
custom user_link;
custom assigned user;
project assignment.

We must use the actual client workflow—not invent a second assignment field.

Phase 5 — Request status mapping

OMC Request and ERP Task statuses should not be blindly identical.

Proposed mapping layer
derive_customer_request_status(
    service_request,
    erp_service,
    erp_tasks,
    documents,
    payments,
)

Example:

ERP operational state	Other condition	OMC customer status
Task Open	staff not started	Open
Task Working	none	In Progress
Any Task state	customer document required	Waiting for Customer
Any Task state	invoice outstanding	Waiting for Payment
Task Completed	all closure gates satisfied	Completed
Service/Task Cancelled	approved cancellation	Cancelled

OMC Service Request already supports:

Open
In Progress
Waiting for Customer
Waiting for Payment
Completed
Cancelled
Closure rule

ERP Task completion must not automatically close the customer request when:

documents are pending;
payment is pending;
finance review is pending;
more than one ERP Task exists;
final customer delivery is pending;
ERP Service remains open.
Phase 6 — Backend notifications

After ERP Task becomes canonical:

ERP Task created/assigned
→ omc_app detects or triggers notification
→ assigned user receives in-app notification
→ push notification sent
→ notification links to Flutter task detail

Because ERP cannot be edited, use one of these OMC-side methods:

OMC creates/assigns the Task and sends notification immediately.
OMC scheduler detects new ERP assignments.
Existing ERP events are observed through an omc_app hook on standard Task.

Registering a doc_events hook in omc_app does not modify ERP source.

Possible future hook:

doc_events = {
    "Task": {
        "after_insert": "...",
        "on_update": "...",
    }
}

The handler must be read-safe, idempotent and limited to relevant OMC/client Tasks.

Phase 7 — Replace OMC Task backend dependencies

Current dependencies include:

task_read_guard.py;
mobile task serialization;
permission handlers;
capability checks;
dashboard counts;
hooks validation;
tests;
workspace;
possible scheduler jobs;
Flutter task repository.

Current task_read_guard explicitly loads OMC Task.

Replace internally:

OMC Task query
→ ERP Task adapter query

Keep endpoint compatibility initially:

omc_app.api.mobile.get_tasks
omc_app.api.mobile.get_task

Those methods may internally route to the new ERP Task adapter.

This means Flutter does not need immediate changes while backend migration is occurring.

Phase 8 — Backend parity validation

Before touching Flutter, validate:

Customer
profile links correct ERP Customer;
no duplicate customers;
internal users excluded;
existing users still work.
Service request
request created;
ERP Customer resolved;
ERP Service created/linked correctly;
duplicate submission protected;
failure does not leave half-created records.
Task
ERP Task created by existing ERP workflow;
correct Service link;
correct Customer link;
correct assignment;
manager access;
assigned staff access;
unrelated staff denied;
customer denied;
status mapping correct.
Cancellation
ERP cancellation reflected in OMC;
OMC request cancellation follows business policy;
Task cancellation does not leave request falsely completed.
Completion
ERP Task completion alone does not prematurely close request;
all closure gates evaluated.
Existing OMC functionality
service documents;
referrals;
assisted requests;
notifications;
payments;
support;
permissions;
dashboard.

No phase is marked passed without your terminal output.

Phase 9 — Flutter migration

Only after backend is stable.

Task module

Keep the existing Flutter task UI where practical.

Modify:

parsing for ERP-backed fields;
task details;
status actions;
assignment display;
service/request link;
customer name;
timeline;
permissions.

The task repository already consumes a generic backend contract rather than requiring the underlying DocType name.

That reduces Flutter migration risk.

Service tracking

Add display for:

OMC request status
ERP Service reference where useful
assigned staff
ERP Task progress
documents
payment state
timeline

Customers should never see raw internal ERP notes or sensitive Task fields.

Customer profile

Expose relevant linked ERP Customer information as read-only where appropriate.

Phase 10 — OMC Task retirement

Only after:

no API reads OMC Task;
no API writes OMC Task;
Flutter no longer depends on its shape internally;
dashboard uses ERP Task;
hooks no longer validate OMC Task;
permissions no longer reference it;
tests are migrated;
no active OMC Task data remains unmapped;
existing OMC Tasks are migrated or archived;
production record count is reconciled.

Then:

remove hooks
remove permissions
remove APIs
remove workspace references
remove tests
remove DocType through approved migration

Do not simply delete its source folder.

Phase 11 — EPG and remaining lead_app migration

After Customer, Service and Task integration is stable:

move EPG settings into OMC;
move gateway transaction handling;
move callback route;
move Sales Invoice button hook;
move Payment Entry integration;
move notifications;
identify remaining legacy callers;
reconcile transactions;
retire lead_app.

This should remain later because Service/Task/Customer authority must be settled first.

Recommended implementation batches
Batch 1 — Inspection scripts only

Generate read-only inspection scripts for:

installed apps;
ERP Customer schema;
ERP Service schema;
ERP Task schema;
workflows;
custom fields;
links;
record counts;
sample sanitized records.
Batch 2 — Customer link foundation
normalize ERP Customer link;
customer resolver;
duplicate review;
profile linking migration;
tests.
Batch 3 — ERP Service adapter
read/create/link ERP Service;
idempotency;
request reference;
tests.
Batch 4 — ERP Task read adapter
task list;
task detail;
permissions;
stable API shape;
tests.
Batch 5 — ERP Task mutation adapter
assignment;
status update;
notes if needed;
workflow validation;
tests.
Batch 6 — Request status projection
service/task/document/payment mapping;
timeline;
cancellation;
closure gates;
tests.
Batch 7 — Notifications and dashboard
ERP Task assignment notifications;
ERP-backed task counts;
operational summaries;
tests.
Batch 8 — Flutter migration
tasks;
service tracking;
customer profile;
permissions;
testing.
Batch 9 — OMC Task retirement
migrate records;
remove dependencies;
remove DocType safely.
Batch 10 — EPG migration and lead_app retirement
payment gateway;
final dependency audit;
uninstall rehearsal;
production retirement.
Final recommendation

Your proposed final direction is correct:

Use ERP Task in Flutter
Retire OMC Task
Keep OMC Service Request for customer tracking
Link OMC Customer Profile to existing ERP Customer
Link OMC Service Request to existing ERP Service
Do not modify ERP source

But the implementation order must be:

Inspect
→ adapt backend
→ validate backend
→ update Flutter
→ migrate old data
→ delete OMC Task
→ migrate EPG
→ remove lead_app