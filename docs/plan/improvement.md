1. Executive assessment
Overall verdict

The app is much further along than a normal redesign candidate.

The backend redesign is architecturally strong:

canonical customer identity/account separation;
canonical Staff Access/capabilities;
no implicit System Manager authority;
scoped break-glass;
payment-first service lifecycle;
idempotency;
accounting/receipt/settlement separation;
ERP activation bridge;
document review;
reconciliation;
referral attribution and commission allocation;
backend-authoritative role and workflow enforcement.

The Flutter app already has:

good feature-oriented structure;
strong login/security foundations;
strong service catalogue;
good request creation;
canonical service-case modelling;
customer documents;
payments;
support;
notifications;
profile/self-service;
internal workspace;
reviewers;
admin operations;
leads/customers/tasks;
referrals/commissions.

So I do not recommend a giant Flutter rewrite.

I recommend:

Repair P0/P1 contract gaps first → normalize role/capability navigation → establish the final design system → then modernize each journey incrementally.

The main weaknesses are not “the app looks bad.” They are:

two P0 integration/security gates;
backend capabilities that Flutter doesn't yet understand/expose;
pagination/list completeness gaps;
a few role-routing mistakes;
generic internal UX instead of persona-specific UX;
production placeholders and ERP terminology;
visual components that are individually polished but not yet governed by one strict design system.
2. Two P0 blockers before UI work
P0-01 — Internal dashboard scope violates capability scoping
Files
backend.../omc_app/api/dashboard.py
backend.../omc_app/api/dashboard_read_guard.py
backend.../omc_app/api/capabilities.py
compare with internal_workspace.py
Backend truth

Canonical authorization explicitly distinguishes:

all customers / relevant customers;
all service cases / relevant / assigned;
payment queue;
document queue;
support;
finance;
etc.

System Manager is not OMC authority.

But get_dashboard_data() treats an approved internal workspace user as an internal/global dashboard consumer and can build global service/customer/payment/document snapshots—including customer data—without preserving those narrower capability scopes.

The internal workspace endpoint itself is much more careful about assigned/scoped cases.

Risk

Security / least privilege.

A narrow persona such as Document Reviewer or Consultant should not receive organization-wide data simply because they can enter the internal workspace.

Required fix

Before Flutter home redesign:

make dashboard sections capability-aware;
apply all/relevant/assigned scope independently per domain;
omit unauthorized datasets completely;
derive action cards from authorized queues only;
add explicit cross-persona backend tests.

Priority: P0.

P0-02 — Protected apps are not actually untouched relative to main

A current GitHub comparison shows the feature branch is 201 commits ahead of main but also contains changes under protected paths:

ERPNext supplier.json
ERPNext customer.json
lead_app entry

The Supplier source contains the added custom_gst_category field.

The ERPNext Customer customization file also contains a substantial set of custom fields.

I did not find a Frappe-framework diff in the branch comparison.

Important nuance

I am not saying the latest backend redesign introduced those changes. They may predate it.

I am saying:

The current feature branch, as it stands today, does not satisfy the “ERPNext / lead_app untouched” rule relative to current main.

Required fix

Before product implementation:

establish why those protected diffs exist;
preserve anything genuinely required;
move OMC-owned customization to OMC fixtures/patches/custom-field provisioning where possible;
bring protected upstream paths back in line with the intended repository policy;
verify lead_app status deliberately rather than blindly deleting/resetting it.

Priority: P0 release/integration gate.

3. Actual architecture found
Backend authority model

The current architecture is correctly moving toward:

Frappe / ERPNext
    │
    ├── authoritative ERP identities / records
    │
OMC custom backend
    │
    ├── Customer Account
    ├── Customer Profile
    ├── Staff Profile
    ├── Staff Access
    ├── Staff Capabilities
    ├── Break Glass Grant
    │
    ├── Service Catalogue
    ├── Service Request
    ├── Service Documents
    ├── Service Payments
    ├── Service Timeline
    │
    ├── Accounting Link
    ├── Bridge Operation
    ├── Customer Activation
    ├── Reconciliation
    ├── Technical Quarantine
    │
    ├── Referral Attribution
    └── Commission Allocation
             │
           Flutter

This is the correct direction.

The lifecycle implementation explicitly prevents operational completion from becoming authoritative business completion unless activation is actually complete.

Flutter's ServiceCase model also preserves the important separation rather than reducing everything to a single status. That is one of the strongest parts of the frontend.

4. Actual persona / authority model

Backend source establishes these important identities:

Persona	Canonical mobile authority
Guest	Public endpoints only
Customer	Customer Account/Profile + customer capabilities
Consultant	ERP persona → Staff Profile → Staff Access
Tax Associate	ERP persona → Staff Profile → Staff Access
Business Partner	ERP persona → Staff Profile → Staff Access
Employee	Recognized ERP persona, but no broad implicit authority
Document Reviewer	Staff Access capabilities
Finance Reviewer	Staff Access capabilities
Support Agent	Staff Access capabilities
Manager	Staff Access capabilities
OMC Admin	Staff Access capabilities
Combined-role staff	Effective capability set, not hard-coded screen role
Disabled/suspended staff	No OMC staff authority
System Manager	Not OMC authority

The role/capability setup explicitly reflects that model.

This is the rule Flutter should follow

Capabilities drive UI. Roles provide persona context.

Do not write:

if (role == 'OMC Finance Reviewer') ...

when the actual decision is:

can_review_payments
can_reconcile_settlement
can_approve_commissions
...

Role can determine home composition and language, while capability determines authorization-dependent visibility/actions.

5. Backend → Flutter coverage matrix
Capability / workflow	Flutter state	Audit
Login/session	Implemented	GOOD
Secure signup/verification	Implemented	GOOD, staff application wording needs work
Existing customer activation	Implemented	GOOD
Customer profile/self-service	Implemented	GOOD
Service catalogue	Implemented	GOOD
Service detail	Implemented	GOOD
Customer request creation	Implemented	GOOD / polish
Assisted staff request creation	Implemented	GOOD / polish
Canonical case lifecycle	Implemented	GOOD
Customer tracking	Implemented	GOOD / redesign opportunity
Case cancellation	Implemented	GOOD
Document list/upload/replacement	Implemented	P1 pagination
Document review	Implemented	P1 pagination
Customer payment	Implemented	GOOD
Finance payment review	Implemented	GOOD
Settlement reconciliation	Backend exists	P1 mobile coverage decision required
Post-paid approval	Capability exists	P1 Flutter contract incomplete
Referral read	Implemented	GOOD
Beneficiary commission read	Implemented	GOOD
Finance commission approval	Backend exists	P1 MISSING
Commission payable/paid lifecycle	Backend exists	P1 MISSING
Support customer flow	Implemented	GOOD
Support agent read/reply/status	Implemented	P1 role/pagination issues
Support assignment	Backend capability exists	P1 MISSING
Notifications	Implemented	P1 retry/read-state issues
Lead mobile workflow	Implemented	GOOD where capability exists
OMC Lead	Removed / no longer canonical	SHOULD NOT REINTRODUCE
Task read	Implemented	GOOD
Assigned task status update	Backend exists	P1 MISSING
Task assignment/planning	Backend exists	P1 MISSING for managers
Customer management	Implemented	GOOD / role review
Service reassignment	Implemented	GOOD
Failed ERP sync retry	Implemented	GOOD, admin/technical UI polish
Discount decision	Implemented	GOOD, presentation polish
Reconciliation queues	Backend exists	MISSING selectively
Break-glass	Backend authoritative	Desk/admin controlled; don't make normal mobile flow
Full accounting internals	Backend/ERP	KEEP DESK-FIRST
Bridge internals/quarantine	Backend/admin	Mostly Desk-first

Flutter ApiConfig currently confirms several of the missing pieces: commission lifecycle, reconciliation operations, support assignment, and task mutation endpoints are not represented there.

6. Critical Flutter capability drift — P1
Files
features/auth/application/auth_state.dart
app/providers/effective_capabilities_provider.dart
app/route_access_policy.dart
core/config/api_config.dart

The canonical backend has capabilities including:

can_reconcile_settlement
can_approve_post_paid
can_approve_commissions
can_mark_commissions_paid

The current Flutter capability object does not represent the full contract cleanly and still carries older composite/legacy-style capability concepts.

Effect

This creates two classes of bug:

backend allows workflow but mobile never exposes it;
mobile shows/gates screens using an approximation rather than the canonical capability.
Fix

Introduce one Flutter capability model that mirrors backend keys 1:1.

No synthesized security authority.

Derived convenience getters are fine:

canUseFinanceWorkspace =
  canReviewPayments ||
  canReconcileSettlement ||
  canApproveCommissions

but the raw canonical keys must remain available.

Priority: P1.

7. Role-aware UX matrix
Customer

Home

next required action;
active service;
recent requests;
service discovery;
documents/payment reminders;
support.

Primary nav

Home
Services
My Services
More

Current bottom-nav architecture is already close to this.

Guest

Home

value proposition;
services;
useful public content;
tax calculator if strategically desired;
support/contact;
sign up / sign in.

Guest should not see empty representations of authenticated features.

Consultant / Tax Associate / Business Partner

Their home should principally answer:

“What work needs me today?”

Recommended:

assigned/active cases;
customer action blockers;
assigned tasks;
relevant customers;
start assisted request;
commissions/referrals where authorized;
recent activity.

Not global organizational KPI tiles.

Document Reviewer

Home:

documents awaiting review;
oldest/action-critical reviews;
rejected/replacement loop;
linked case/customer context;
assigned tasks if applicable.

No payment-review noise.

Finance Reviewer

Home:

receipts awaiting decision;
settlement exceptions;
financial holds;
commission allocations requiring review;
payable/paid actions;
relevant case/customer context.

Current payment review exists, but commission lifecycle and reconciliation coverage do not.

Support Agent

Home:

unassigned/assigned open tickets;
waiting-customer tickets;
high-priority customer cases;
relevant customer lookup;
leads if that remains an intended responsibility.

Support must not inherit every internal tool merely because it has workspace access.

Manager

Home:

operational exceptions;
service workload;
unresolved document/payment queues;
assignment pressure;
holds/failures;
staff work distribution;
reconciliation exceptions;
selected management controls.

Manager should get overview + intervention, not every Admin configuration toggle.

OMC Admin

Home:

operational risks;
pending registrations/staff access;
failed integration/reconciliation;
workload/queue summaries;
management settings.

Not a giant ERP dashboard.

Disabled staff

No staff dashboard.

No stale cached internal data.

Route to a clear:

“OMC staff access is currently unavailable for this account.”

with safe customer capability fallback only if the same identity legitimately also has customer access.

8. Navigation audit
Actual high-level route graph
PUBLIC / AUTH
/
├─ onboarding
├─ login
├─ signup
├─ forgot-password
├─ reset-password
├─ verify-email
├─ activate-existing-account
├─ activate-account
└─ under-review


MAIN SHELL
├─ /home
├─ /services
├─ /track
├─ /my-services   (alias/current compatibility)
├─ /documents
└─ /more


CUSTOMER / SHARED
├─ /services/:id
├─ /services/:id/request
├─ /my-services/:caseId
├─ /documents/:id
├─ /payments
├─ /payments/:id
├─ /notifications
├─ /support
├─ /support-tickets/:id
├─ /profile
├─ /profile/edit
├─ /settings
├─ /change-password
├─ /referrals
├─ /commissions
├─ knowledge
├─ tax
└─ expense


INTERNAL
├─ workspace
├─ service cases
├─ case workspace
├─ customers
├─ documents/review
├─ payments/review
├─ leads
├─ tasks
├─ support
├─ admin control
└─ admin operations

The routing system itself is sophisticated: StatefulShellRoute, auth redirects, token link handling and capability routing already exist.

Navigation findings
P1 — Support visible too broadly

SupportScreen treats general internal workspace access as sufficient to surface staff ticket functionality, while the backend has explicit support capabilities.

Fix: use can_view_support_tickets, can_reply_support_tickets, etc., exactly.

P1 — Support-ticket linked case route

Internal support users can be sent to the customer-style:

/my-services/<case>

instead of the internal case workspace.

Fix: choose destination based on actual case access/capability.

P1 — Legacy route gates

/my-services and related logic still contain older composite capability concepts.

Move route policy to canonical capabilities.

P2 — More sheet becomes a capability dumping ground

The capability-driven More sheet is technically useful but combined-role employees can receive too many equal-weight icons.

Recommended hierarchy:

MY WORK
Cases • Tasks • Customers


REVIEW
Documents • Payments • Support


BUSINESS
Referrals • Commissions • Leads


TOOLS
Tax • Expenses • Knowledge


MANAGE
Staff • Operations • Settings

Only render sections that contain at least one authorized action.

P2 — Pending/rejected account experience

Non-guest authenticated users can still receive shell utilities that later become forbidden.

The shell should feel deliberately limited rather than like the app is broken.

9. Customer journey audit
Current journey
Launch
→ Login / Signup
→ Email verification
→ Password creation
→ Customer account
→ Home
→ Catalogue
→ Service
→ Request
→ Required information
→ Service request
→ Documents
→ Payment / Payment Not Required
→ Review
→ Activation
→ Operational service
→ Completion
→ Receipt/accounting
→ Support

This journey is fundamentally sound.

Strong areas
password is not collected pre-verification;
validation is server-backed;
duplicate submission/idempotency exists;
dynamic service forms are backend driven;
customer case model carries canonical lifecycle state;
documents and payments are separate;
cancellation is confirmed;
profile/security are available.
Main customer UX issue

The app currently has the raw pieces of a great service journey, but they are presented as several related screens rather than one coherent service narrative.

The customer should never need to understand:

settlement;
bridge state;
ERP task;
reconciliation run;
accounting link.

Instead:

“We have verified your payment and are preparing your service.”

or:

“We need one corrected document from you.”

or:

“Your service is active. OMC is currently processing it.”

10. Service request experience — key redesign recommendation

I do recommend a premium lifecycle visualisation, but it must be a projection of canonical state—not a second lifecycle engine.

Recommended customer journey rail

Conceptually:

Request received
      ↓
Documents
      ↓
Payment
      ↓
OMC review / activation
      ↓
Service in progress
      ↓
Completed

But individual nodes must adapt.

For a no-charge service:

Request
Documents
Ready
Service
Completed

For an early no-document service:

Request
Payment
Activation
Service
Completed

For a financial hold:

Current step
⚠ Payment issue needs attention

Do not blindly set the progress from the above labels.

Use:

backend milestones;
request_state;
document summary;
settlement;
activation;
operational state;
timeline history.

The current backend and ServiceCase model already give us a strong basis for this.

11. Request creation/forms audit

service_request_draft_screen.dart already has:

backend dynamic fields;
assisted customer selection;
pricing;
discount handling;
dirty-state protection;
idempotency;
validation;
duplicate awareness.
P2 — document sequencing copy

The screen displays required documents and tells users to keep them ready, but final create currently sends no attachments and upload occurs afterward.

That backend sequencing is valid.

The copy is the problem.

Better:

Documents needed after submission
Once your request is created, we'll guide you through uploading these documents.

Not:

keep these ready before submitting

when they cannot actually be submitted there.

P2 — progress metric

Current completion counting can make optional/general fields look like a formal required-progress indicator.

Use:

required completed / required total;
optional separately;
no artificial progress when a form is trivially short.
P2 — final confirmation

Backend requires final confirmation and Flutter sends it.

For meaningful requests, the premium UX should become:

Details
→ Review
→ Submit request

where the review page/sheet shows:

service;
customer;
final price;
payment expectation;
required documents;
important entered values;
final CTA.

Do not make every tiny form a multi-step wizard.

12. My Services audit

my_services_screen.dart is already comparatively polished:

search;
filter;
sort;
action awareness;
canonical fields included in search;
empty/error/loading;
case navigation.
Recommended changes

NEEDS POLISH rather than redesign.

Prioritize cards by:

You need to act
OMC is reviewing
In progress
Completed
archived/cancelled

The strongest information on every card should be:

Service name
Current human-readable state
Next step / owner
Progress

Reference number should be secondary.

13. Documents UX audit
Customer Documents

Visually one of the strongest areas:

grouped by service request;
search;
filters;
action/review/approved counts;
status-aware presentation.
P1 — pagination lost

Backend document API supports:

limit_start
limit_page_length
has_more
next_start

Flutter's documents repository reduces this to a simple list.

Result:

customer/reviewer can silently see only the first page.

That is unacceptable before release.

P1 — assisted retry bug

On the assisted document list, the error retry invalidates the generic customer provider rather than the assisted provider.

Fix provider-targeted retry.

P2 — fake Document Timeline

Document Detail contains:

uploads/reviews/etc. “will appear here when activity data is available.”

That is a production placeholder.

Either:

implement real document history; or
remove the component.

Do not redesign a fake timeline.

P2 — excessive hero styling

The Document Detail gradient is heavier than the desired final OMC aesthetic.

Recommendation:

neutral white/near-white hero;
small semantic status accent;
less full-card brand gradient.
14. Payments / finance audit
Customer payments

Current Payments screen is strong:

action-required sorting;
amount hierarchy;
due/paid information;
receipt review states;
replacement flow;
meaningful CTA.

Payments repository also handles pagination much better than Documents.

P2 copy issue

Empty state currently says:

a payment will appear after all required documents are uploaded.

That is not universally correct because Payment Not Required / no-charge services exist.

Better:

“No payments need your attention.”

with no prediction that one will necessarily appear.

Finance Reviewer

Payment approval/rejection exists.

What is incomplete is the wider finance persona.

Missing
commission approval;
payable transition;
mark paid;
settlement/reconciliation views/actions;
canonical capability keys for those workflows.

Commission backend lifecycle is already implemented and audited.

Flutter commission repository is beneficiary read-only.

P1.

Payment detail placeholder

Payment Detail also contains a future activity/timeline placeholder.

Same policy:

implement real history or remove it.

No production placeholders.

15. Support audit

Support is functionally substantial:

create ticket;
ticket list;
detail;
messages;
attachments;
reply;
status changes;
dirty composer protection.
P1 — pagination

Backend paginates support tickets; Flutter discards pagination.

A Support Agent with more than the first page can silently miss tickets.

P1 — role visibility

Internal workspace access is broader than support capability.

Staff should see ticket functionality only according to:

view support;
reply;
change status;
assignment.
P1 — support assignment missing

Backend models can_assign_support_tickets.

Flutter does not currently provide the assignment workflow.

Add an assignment surface for the persona(s) actually granted that capability.

P1 — wrong internal case navigation

Linked service request from a staff support ticket should go to staff case workspace, not customer My Services.

P2 — 4-second polling

Ticket detail refreshes on a short periodic cycle.

Prefer:

only while page/app is active;
foreground-aware polling;
sensible backoff;
notification/push invalidation where possible.

Avoid constant mobile network/battery churn.

16. Notifications audit

This implementation already has proper paging/load-more.

Two concrete problems remain.

P1 — Retry targets wrong provider

The displayed screen watches the paginated provider but the error CTA invalidates another provider.

Fix.

P1/P2 — opening Notifications marks everything read

The list opening currently invokes mark-all-read.

That means:

“I opened notifications” == “I read every notification.”

Those are different actions.

Recommended:

mark an item read when opened;
explicit “Mark all as read” control;
maintain server unread total independent of currently loaded page.
17. Authentication / security audit
GOOD

Login is already strong:

username/email/mobile/CNIC style identifier support;
generic credential failure;
double-submit prevention;
biometric option;
guest;
forgot password;
account activation.

Secure registration correctly delays password creation until verification.

Change Password:

validates current password;
validates new password;
dirty-state protection;
clears biometric credentials;
logs user out;
returns to login.

No major auth rewrite is justified.

P1/P2 — public “staff account type” onboarding

Signup currently exposes:

Customer
Consultant
Business Partner
Tax Associate

as if all are equivalent self-service accounts.

But canonical staff activation requires the Staff Access model and ultimately an existing Frappe System User. Admin APIs explicitly preserve that boundary.

Better UX

Customer:

Create an OMC account

Staff-like personas:

Apply for OMC staff access

Then clearly:

“An OMC administrator will review your request. Staff access requires an existing approved OMC/ERP staff identity.”

This removes false expectations.

P2 security hardening — biometrics

Settings explicitly describes keeping the password protected in device secure storage for biometric sign-in.

Current implementation is not automatically unsafe, but longer term the superior architecture would be:

biometrics unlock a revocable device credential/token, not the actual account password,

if/when backend authentication provides such a token contract.

Not a P0/P1 blocker for this redesign.

18. Staff Tasks audit

Flutter Tasks is currently mainly read-oriented.

But backend already permits:

Assigned staff
controlled operation-status update.
Task managers
assignment;
due/planning changes;
other controlled mutations.

Flutter does not expose these APIs.

P1 recommendation

For Consultant / Tax Associate / Business Partner:

Task detail
→ Update status

For Manager/Admin:

Task detail
→ Reassign
→ Update priority/due date
→ Update status

Do not add Task creation unless backend creates a deliberate mobile contract for it.

Also replace:

“ERP task state”

with:

“Work status”

or similar operational language.

19. Leads / OMC Lead

The current branch has retired the old OMC Lead DocType.

Therefore:

Do not rebuild OMC Lead-specific mobile screens.

The current mobile Leads feature should continue to reflect the current backend's ERP Lead authority where authorized.

Leads itself is reasonably mature and should be retained for only the personas that actually have lead capability.

20. Admin audit
Admin Control

Useful functionality exists:

staff/application review;
staff status;
business settings.
P1 — “Invite staff” is misleading

The UI says:

Invite staff / Send invite

but the backend explicitly requires the Frappe System User to already exist.

Rename to something like:

Grant OMC access

and:

“Select an existing staff user.”

If reliable mobile discovery of System Users isn't part of the contract, leave provisioning in Desk.

P1/P2 — staff suspension confirmation

Disabling staff is materially consequential.

It should have a confirmation sheet summarizing:

person;
access being revoked;
session effect;
optional reason.
Admin Operations

This screen already contains:

reassignment;
ERP sync recovery;
discount decisions;
pagination;
confirmations;
assignment options.

Functionally good.

Visually/terminologically it is too technical for the final app:

“ERP Task”
retry counts;
raw sync errors;
“exhausted sync”

These are appropriate for a narrowly authorized Admin/Manager diagnostic surface, but should be rewritten into an intentional Operations / Recovery experience.

Raw technical detail can live behind:

“Technical details”

rather than being the first content.

21. Reconciliation: what should and should not be mobile

Backend has proper reconciliation domains and queues.

The capabilities include domains such as:

accounting;
commission;
bridge;
identity/staff.

I do not recommend porting the entire reconciliation system into Flutter.

Mobile-worthy
Finance Reviewer
accounting exception requiring human review;
commission exception requiring decision;
settlement mismatch that blocks a service.
Manager/Admin
high-level unresolved exception count;
safe retry/resolve actions where designed.
Keep Desk-first
full reconciliation run history;
checkpoints;
technical quarantine administration;
raw accounting evidence;
low-level bridge diagnostics;
system recovery tooling.

That avoids turning the OMC mobile app into ERP Desk.

22. Home/dashboard audit
Customer Home — NEEDS POLISH

Current customer/guest home is visually far beyond a stock Flutter dashboard.

It has:

greeting;
search;
content;
quick actions;
service discovery;
actionable service state;
recent activity.
Improvement

When the customer has an active service:

action required should outrank editorial content.

Recommended order:

Greeting
↓
Needs your attention
↓
Active service / next step
↓
Quick actions
↓
Recommended services
↓
Useful content
↓
Recent activity

For a customer with no active work:

Greeting
↓
Service discovery
↓
Quick actions
↓
Featured / content

Same screen, different composition.

23. Internal Home — NEEDS REDESIGN

This is the most important visual/product redesign candidate.

It currently behaves too much like:

generic internal dashboard + whichever buttons exist.

That doesn't match the sophistication of the backend capability model.

Replace with persona composition

A home-builder should receive:

effectiveCapabilities
primaryPersona
authorized summaries
authorized queues

and compose sections.

Not:

if internal → show internal dashboard
24. Design-system audit
What is already good

theme.dart is not a generic Material demo:

restrained neutral palette;
Material 3;
comfortable inputs;
consistent rounded controls;
mostly flat surfaces;
useful typography.

main.dart uses edge-to-edge system UI and appropriate transparent/light status treatment.

So again:

don't throw the design system away.

What needs improvement

There are effectively multiple design languages:

AppTheme
OmcPremium
screen-specific raw Colors
screen-specific gradients
screen-specific radii
screen-specific status mappings

This is why some screens feel premium individually but not like one product.

Target semantic design layer

Create semantic tokens such as:

OmcColors
  canvas
  surface
  surfaceRaised
  border
  textPrimary
  textSecondary
  brand
  success
  warning
  danger
  info


OmcSpacing
  4 / 8 / 12 / 16 / 20 / 24 / 32


OmcRadius
  small 10
  control 14
  card 18
  sheet 28


OmcTypography
OmcStatusStyle
OmcMotion

Exact numbers can be refined during implementation; the important requirement is one system.

25. Premium visual direction

The target should be closer to:

Apple-quality discipline

than:

Apple-looking widgets.

Meaning:

more whitespace;
fewer competing surfaces;
fewer gradients;
fewer dashboard tiles;
one strong action per context;
excellent typography hierarchy;
subtle borders;
nearly invisible shadows;
bottom sheets instead of unnecessary new pages;
consistent status vocabulary;
natural transitions;
human language.

OMC red should become a brand/action accent, not a decorative fill everywhere.

26. Accessibility / mobile usability
Already positive
many 44–52px controls;
SafeArea widely used;
keyboard-aware forms;
dirty-form protection;
scrolling sheets;
loading/empty/error components.
Work still needed

P2

audit every 10–11px label at large text scale;
guarantee important information is not color-only;
VoiceOver/TalkBack labels for custom clickable cards;
semantic status descriptions;
44px minimum interactive hit areas;
test 200% text scaling;
test small Android devices;
test notched devices;
test keyboard + bottom sheets;
test landscape only where supported;
avoid fixed-height content containing translated/dynamic text;
add reduced-motion consideration to future animations.
27. State-design audit

The project already handles more states than most Flutter apps.

Still, every feature should converge onto the same vocabulary:

Initial
Loading
Refreshing
Loaded
Empty
Action required
Submitting
Success
Recoverable failure
Offline/stale
Forbidden
Unauthenticated
Partial failure
Major state gap — P1

home_dashboard_repository.dart catches some dashboard failures and produces an empty fallback instead of surfacing the failure.

That means a backend outage can look like:

“0 services / nothing to do”

rather than:

“We couldn't refresh your account.”

That is a data-integrity UX failure.

Fix

Allow:

fresh data;
cached/stale data with explicit indicator;
real error.

Never convert availability errors into legitimate zero business data.

28. Pagination / scale audit

This is one of the most actionable technical themes.

Domain	Backend	Flutter
Service cases	paginated	Good
Payments	paginated	Good
Notifications	paginated	Good
Tasks	multiple pages consumed	Good
Documents	paginated	Dropped
Support tickets	paginated	Dropped
Internal workspace cases	backend bounded/default list	Can silently truncate at scale
P1 principle

Every backend list contract should return a common frontend shape:

Page<T> {
  items
  start
  hasMore
  nextStart
  total?
}

Then one reusable paging controller pattern should be used.

29. Technical frontend architecture
GOOD
Riverpod;
feature directories;
repository separation;
centralized Frappe client;
API configuration;
dirty form controller;
mutation invalidation helpers;
upload coordinator;
failure classification;
route-access policy.

Very good base.

P2 — several screen files are too large

Current examples include roughly:

home_screen_role_aware.dart: very large;
service_case_detail_screen.dart: ~100 KB;
internal_operations_center_screen.dart: >100 KB;
leads_screen.dart: large;
expense tracker: very large.

This isn't a reason to rewrite them.

During each redesign phase, extract:

presentation/
  screen.dart
  sections/
  widgets/
  controllers/
  state/

only for the part being changed.

P3 — stale compatibility wrappers

Examples in the current tree include tiny alias files such as:

home_screen.dart
home_screen_v2.dart
service_catalogue_screen.dart
service_catalogue_screen_modern.dart
service_catalogue_screen_premium.dart

These should eventually collapse once call sites are verified.

P3 — dormant dark-mode architecture

The app currently forces ThemeMode.light, so dark-mode inconsistency is not a live defect.

Either:

intentionally build dark mode later; or
remove dormant controller/theme complexity for now.

Do not half-support it.

30. Complete screen inventory status
Surface	Status
Splash	GOOD
Onboarding	NEEDS POLISH
Login	GOOD
Forgot password	GOOD
Reset password	GOOD
Signup	NEEDS REDESIGN for staff-app distinction
Email verification	GOOD
Existing customer activation	GOOD
Under review	NEEDS POLISH
Guest Home	NEEDS POLISH
Customer Home	NEEDS POLISH
Internal Home	NEEDS REDESIGN
Service catalogue	GOOD
Service detail	GOOD / POLISH
Request creation	GOOD / POLISH
My Services	GOOD / POLISH
Service case detail	GOOD / MAJOR POLISH
Documents	P1 data fix + polish
Document detail	NEEDS POLISH, remove placeholder
Internal document review	P1 pagination + polish
Payments	GOOD / POLISH
Payment detail	GOOD / remove placeholder
Finance payment review	GOOD
Customers	GOOD / POLISH
Customer detail	GOOD / POLISH
Leads	GOOD
Lead detail	GOOD / POLISH
Tasks	P1 functionality missing
Task detail	P1 actions + remove ERP language
Support	P1 role/pagination
Ticket detail	P1 routing + P2 polling
Notifications	P1 state fixes
Notification detail	GOOD / POLISH
Profile	GOOD
Edit profile	GOOD
Change password	GOOD
Settings	GOOD / POLISH
Referrals	GOOD
Referral detail	GOOD
My Commissions	GOOD beneficiary view
Commission detail	GOOD beneficiary view
Finance commission workspace	MISSING
Internal workspace	NEEDS ROLE RECOMPOSITION
Internal case queue	GOOD / scale fix
Internal case detail	GOOD / polish
Admin Control	P1 workflow wording
Admin Operations	GOOD functionality / redesign presentation
Reconciliation mobile surface	SELECTIVELY MISSING
Tax calculator	KEEP as utility
Expense tracker	KEEP if product requirement
Knowledge	GOOD public/customer utility
OMC Lead screens	SHOULD NOT ADD
31. Prioritized finding register
P0
P0-01 Dashboard authorization scope
Files: backend dashboard/capabilities/internal workspace.
Current: internal user can receive overly global dashboard data.
Truth: all/relevant/assigned scopes differ.
Fix: per-domain capability/scoping.
Roles: all staff.
Risk: privacy/security.
P0-02 Protected-app branch contamination
Files: ERPNext Customer/Supplier, lead_app branch entry.
Current: current branch differs from main.
Truth: OMC development policy says protected upstream apps untouched.
Fix: reconcile/migrate customizations before implementation.
Risk: deployment/update/integration.
P1
P1-01 Flutter canonical capability model incomplete

Finance/commission/reconciliation capabilities missing or approximated.

P1-02 Finance commission lifecycle missing

Approve/reject → payable → paid has no mobile flow.

P1-03 Task mutations missing

Assigned status + manager assignment/planning.

P1-04 Document pagination missing

20 documents can disappear.

P1-05 Support pagination missing

20 tickets can disappear.

P1-06 Internal workspace list scalability

Large queues can be truncated.

P1-07 Support UI visible with wrong capability

Workspace != support authority.

P1-08 Support → service request routes staff incorrectly

Customer route used by staff.

P1-09 Support assignment missing

Backend capability has no control.

P1-10 Notification retry bug

Invalidates wrong provider.

P1-11 Notification read semantics

Opening list marks all read.

P1-12 Home failure appears as zero data

Network/backend error can look legitimate.

P1-13 Staff registration UX contract

Self-service appearance vs Staff Access/System User reality.

P1-14 Admin “Invite staff” contract

Doesn't actually provision identity.

P1-15 Assisted document retry

Invalidates wrong provider.

P1-16 Finance reconciliation coverage

At least human finance actions need deliberate mobile-vs-Desk decision.

P2
Internal role-aware home redesign.
Customer home prioritization.
Service lifecycle visualisation.
Request review/final-confirmation UX.
Required-document sequencing copy.
Payment no-charge copy.
Remove fake payment/document timelines.
More menu information architecture.
Admin-control design.
ERP terminology removal.
Design token consolidation.
Consistent success confirmation.
Better stale/offline presentation.
Support polling strategy.
Screen decomposition.
Accessibility pass.
P3
subtle motion;
haptics;
shimmer/skeleton unification;
alias/wrapper cleanup;
dormant theme cleanup;
debug logging cleanup;
micro-copy;
transition polish.
32. What should remain ERP Desk-only

This is important.

I would not force the following into Flutter simply because the APIs/backend objects exist:

System User creation;
low-level break-glass administration;
complete reconciliation run management;
raw accounting reconciliation evidence;
direct Sales Invoice administration;
full bridge-operation management;
raw technical quarantine;
arbitrary ERP Task administration;
ERPNext setup/master configuration;
developer/system recovery controls.

Mobile should surface the business consequence and safe action where useful.

Example:

“Activation needs administrator attention”

not a screen dumping bridge outbox records to a Consultant.

33. Recommended final navigation architecture
Customer
Home
Services
My Services
[Action]
More
Internal
Home
Cases
Work
[Action]
More

Where Work becomes persona-aware:

Consultant → Tasks
Document Reviewer → Documents
Finance Reviewer → Payments/Review
Support Agent → Support
Manager/Admin → Workspace

An alternative is retaining Services as the second internal tab if staff frequently initiate assisted requests. We should choose this after role usage testing rather than changing it immediately.

The current bottom-nav component is technically good enough to evolve rather than replace.

34. Final premium service-case composition

This should eventually become the flagship OMC screen:

< Service name


Current status
"Waiting for your payment receipt"
[primary CTA]


Progress
────●────○────○────
Request   Payment   Service...


Needs attention
[Upload payment receipt]


Service summary
• Requested date
• Current step
• Expected next step


Documents
3 approved · 1 needs attention


Payment
PKR xx,xxx · Receipt required


Recent activity
• Request created
• Documents approved
• Payment requested


Help with this service

For staff, the same underlying domain can become:

Customer + service
Business lifecycle
Operational status


Action required
Assignment


Documents
Payment/finance
Tasks
Internal notes
Timeline


Authorized controls

This is one canonical domain with two presentations, not duplicate business logic.

35. Recommended implementation plan

I would change your tentative phase order because correctness/permissions need to precede visual redesign.

Phase 0 — Repository + authorization gates

Goal: establish a clean, trustworthy base.

Backend/files

protected ERPNext/lead_app branch differences;
dashboard.py;
dashboard scope guards;
capability tests.

Roles: all.

Tests

protected-path diff check;
Consultant dashboard;
Document Reviewer dashboard;
Finance dashboard;
Support dashboard;
Manager/Admin;
combined caps;
disabled staff.

Risk: High.

Must be first.

Phase 1 — Canonical Flutter capability contract

Goal: Flutter mirrors backend authorization exactly.

Files

auth_state.dart
effective_capabilities_provider.dart
route policy
navigation action access
ApiConfig

Add canonical finance/commission/reconciliation/task/support capabilities.

Retire security decisions based on old aggregate flags.

Risk: High-medium.

Phase 2 — Data reliability / pagination / routing

Goal: no silently missing records and no wrong-role navigation.

Fix:

documents pagination;
reviewer pagination;
support pagination;
internal case pagination;
notification retry;
notification read semantics;
assisted-document retry;
internal support-case route;
home error masking.

Tests: repository pagination + widget load-more + permission-routing tests.

Risk: Medium.

Phase 3 — Missing staff functional workflows

Goal: expose backend capabilities that genuinely belong on mobile.

Implement:

assigned Task status;
manager Task assignment/edit;
Support assignment;
Finance commission review/payable/paid;
selected settlement/reconciliation workflow.

Do not add full ERP administrative functionality.

Risk: Medium-high.

Phase 4 — Navigation + persona architecture

Goal: app feels intentional for each staff persona.

Files:

main_shell.dart
bottom nav
More sheet
route access
home-action access
internal home composition.

Deliver:

Customer nav;
Consultant nav;
Reviewer nav;
Finance nav;
Support nav;
Manager/Admin nav;
combined-cap behaviour.

Risk: Medium.

Phase 5 — Design-system foundation

Goal: one premium OMC visual language.

Refine:

semantic colors;
typography;
spacing;
radii;
status presentation;
cards;
app headers;
buttons;
form controls;
sheets;
list rows;
state views;
timeline components.

Then migrate screens gradually.

Do not redesign all screens in this phase.

Risk: Low-medium.

Phase 6 — Authentication / onboarding

Modernize:

onboarding;
login;
signup;
customer vs staff-application distinction;
verification;
activation;
under-review;
reset.

Functionality should largely stay untouched because it is already strong.

Risk: Medium because auth regression is expensive.

Phase 7 — Customer Home

Build the adaptive hierarchy:

action required;
active service;
quick actions;
service discovery;
editorial content;
recent activity.

No global/generic dashboard cards.

Risk: Medium.

Phase 8 — Catalogue + request creation

Refine:

catalogue;
service detail;
request form;
review & submit;
assisted request;
required-document messaging;
pricing/no-charge clarity.

Risk: Medium.

Phase 9 — My Services + flagship case detail

This is the main customer product phase.

Introduce backend-derived:

lifecycle rail;
next action;
documents;
payment;
hold state;
activation;
service progress;
activity;
completion.

Remove technical/internal language.

Risk: Medium-high because lifecycle presentation must stay canonical.

Phase 10 — Documents + Payments

Documents:

premium list/detail;
replacement UX;
real history or no timeline.

Payments:

customer payment journey;
receipt submission/rejection;
invoice/receipt terminology;
no-charge behaviour;
remove placeholders.

Risk: Medium.

Phase 11 — Staff workspaces

Role compositions:

Consultant / Tax / Partner

cases + tasks + customers + assisted service.

Document Reviewer

document queue + review.

Finance Reviewer

payment + settlement + commissions.

Support

tickets + assignment + customer context.

Manager/Admin

operations and exception management.

Risk: Medium-high.

Phase 12 — Leads / referrals / commissions / admin

Polish:

Leads;
referrals;
beneficiary commission experience;
Finance commission management;
Admin staff/application controls;
Admin operations terminology.

No OMC Lead revival.

Phase 13 — Support / profile / settings / security

Polish remaining flows.

Profile/security functionality is already good, so this is mostly visual consistency and accessibility.

Phase 14 — State / accessibility / responsive audit

Systematically test:

loading;
refreshing;
empty;
error;
stale;
unauthorized;
forbidden;
submitting;
partial failure;
offline;
action-required;
success.

Then:

large font;
TalkBack;
small screen;
keyboard;
rotation as applicable;
safe areas;
low network conditions.
Phase 15 — Motion / premium polish

Only after functional UX is stable:

subtle entrance transitions;
shared status transitions;
button feedback;
haptics;
bottom-sheet motion;
skeleton consistency;
reduced-motion support.

No decorative animation.

Phase 16 — Full regression + real-device acceptance

Run:

Backend
entire OMC suite;
persona tests;
dashboard least-privilege tests;
lifecycle;
documents;
finance;
reconciliation;
concurrency/idempotency.
Flutter
analyze;
entire suite;
route matrix;
golden/component tests for key design primitives;
workflow widget tests.
Devices
physical Android;
Chrome/web if supported;
low-width phone;
large phone;
keyboard/form;
file upload;
camera/gallery;
biometric;
deep links;
session expiry;
network loss.

Only after this should we call the Flutter product redesign complete.