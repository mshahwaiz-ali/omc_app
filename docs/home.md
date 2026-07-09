Recommended final Home redesign
1. Customer Home design

Customer home should feel like a personal OMC command center, not admin dashboard.

Layout

A. Premium header

“Good evening, Shahwaiz”
Profile avatar/logo
Notification bell
Small status badge: Approved, Pending Review, or Guest

B. Smart hero card
Different by account state:

User	Hero
Guest	“Start with OMC” + Browse services + Tax calculator
Pending	“Profile under review” + What unlocks after approval
Approved	“Your OMC workspace is active” + next action

Use backend next_action for approved customer because backend already returns title, subtitle, route, button label.

C. Action required card
Show only when needed:

Documents missing
Payment due
Receipt rejected
Support reply waiting
Service waiting for customer

This should become the most important card on customer home.

D. Service progress preview
Instead of generic “Service work is in progress”, show actual active services from serviceSnapshots:

service title
status chip
progress bar
document summary
payment summary
tap to detail

Frontend already maps serviceSnapshots with id, title, status, customer name, document/payment summary, progress.

E. Quick actions
Backend-driven grid:

Start service
Tax calculator
My documents
Payments
Support
Expense tracker
Knowledge

For customer, keep 6 max on homepage. “View all” can go to More.

F. Recent activity
Timeline mini-card:

last 3 updates
no activity empty state
tap to Track
2. Internal Home design

Internal home should feel like OMC operations cockpit.

Layout

A. Internal header

“Operations Center”
role badge: Admin / Manager / Support / Reviewer
notification/action bell

B. Operations hero
Use backend operations_summary and next_action.

Examples:

“12 documents need review”
“4 payments need review”
“8 open leads”
“5 tasks pending”

Backend already creates internal next action based on documents/payment/operations.

C. KPI grid
Internal KPI cards:

KPI	Route
Open services	/internal-workspace/service-cases
Waiting customer	/internal-workspace/service-cases filtered later
Documents review	/internal-workspace/documents
Payments review	/internal-workspace/payments
Open leads	/leads
Pending tasks	/tasks
Customers	/customers

Backend already calculates open leads, active customers, pending tasks, payment review, documents waiting review, active services, waiting customer.

D. Priority queue
Show priority_queue service snapshots:

customer name
case title
status
doc/payment health
tap opens internal service case workspace

Backend already returns priority_queue for internal users.

E. Internal quick actions
Backend quick actions should control this:

Add lead
Create task
Review documents
Review payments
Open service cases
Customers

No hardcoding except fallback.

Backend changes I recommend
Keep existing OMC Mobile Quick Action, but improve it

It already supports good fields, but for professional home design I’d add/confirm these backend-configurable fields:

Field	Why
placement	home_primary, home_secondary, more, internal_home
access_level	Already exists conceptually
required_capability	Already supported
badge_type	Already supported
style	normal/highlighted/urgent
layout_size	small / wide / hero
is_featured	Promote important actions
starts_on, ends_on	Temporary campaign actions
description_long	For larger action cards
group	Services, Work, Finance, Support

Current backend already filters enabled quick actions and returns sort order/access/capability/style/badge.

Dashboard API additions

Current dashboard.py already has good foundation. I’d extend response with:

Customer
home_mode: customer
hero
next_action
service_snapshots
document_summary
payment_summary
support_summary
recent_activity
Internal
home_mode: internal
operations_summary
priority_queue
customer_health
next_action
recent_activity

Most of this already exists; frontend just needs to use it more intelligently.

Frontend implementation plan
Phase 1 — Structure cleanup

Split current big home_screen.dart into role-based widgets:

home_screen.dart
customer_home_view.dart
internal_home_view.dart
home_header.dart
home_hero_card.dart
home_quick_actions.dart
home_metric_cards.dart
home_activity_card.dart

HomeScreen becomes only a router:

if (capabilities.canAccessInternalWorkspace) {
  return InternalHomeView(...);
}
return CustomerHomeView(...);
Phase 2 — Customer Home UI

Build:

smart hero from nextAction
2x2 status cards
active service preview
action required card
backend quick actions
recent activity
Phase 3 — Internal Home UI

Build:

operations hero
KPI grid
priority queue
internal quick actions
recent activity
Phase 4 — Backend quick action seeding

Add default records for:

Customer quick actions
Start Service
Tax Calculator
Documents
Payments
Track
Support
Expense Tracker
Knowledge
Internal quick actions
Service Cases
Review Documents
Review Payments
Leads
Tasks
Customers

Access levels properly:

customer actions: Approved Customer or Public
internal actions: Internal Staff
Phase 5 — Final polish
Better spacing
Premium gradients
modern cards
no clutter
role-aware empty states
no fake counts
no admin card on customer side
backend-driven quick actions wherever possible