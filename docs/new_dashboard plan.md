Dashboard redesign plan
Rule

Customer dashboard = personal client portal
Internal dashboard = operations + customer overview combo

Customer ko internal stats bilkul nahi dikhne chahiye. Internal user ko customer-style summary bhi aa sakti hai, plus internal operations.

1. Customer Dashboard design

Customer ke liye dashboard ka purpose:

“Mere OMC kaam ka current status kya hai, mujhe kya karna hai, payment/document/service mein next step kya hai?”

Layout
Top compact header

No huge red hero.

Good evening
Your OMC workspace

[2 active services] [1 action needed]

Small premium card, not giant gradient.

Primary action card

Most important customer action first:

Examples:

Action required
2 documents pending for Tax Filing 2026
[Upload documents]

or

Payment pending
PKR 25,000 due for NTN Registration
[View payment]

or

All caught up
No action needed right now
[Browse services]
My services snapshot

Compact cards/list:

Tax Filing 2026
In Review · SR-00012
Documents: 3/5 approved
Payment: Pending
[Open]

Show 2–3 latest active services only.

Documents block

Instead of just “Documents: 4”:

Documents
2 missing · 1 under review · 4 approved
[View documents]
Payments block
Payments
1 pending · receipt under review
[View payments]
Support + notifications
Support
1 open ticket · last reply today
[Open support]
Useful shortcuts

Small row/list, not big tiles:

Start new service
Upload document
Tax calculator
Support
2. Internal Dashboard design

Internal dashboard ka purpose:

“Aaj OMC team ko kya handle karna hai?”

Internal user ko dashboard mein dono sections mil sakte hain:

Operations overview
Customer-style live workspace summary
Layout
Operations header
Operations Dashboard
Today’s work across customers, services, documents and payments.
Priority queue summary

Top cards/chips:

Needs document review
Pending payments
Active services
Waiting customer
Open leads
Pending tasks
Today’s action queue

Most important:

Ali Khan · Tax Filing 2026
2 documents need review
[Open workspace]

Hassan Traders · Company Registration
Payment receipt uploaded
[Review payment]

This can reuse internal workspace service queue provider later.

Internal work areas

Small compact list:

Service Requests
Customers
Document Review
Payment Review
Leads
Tasks
Customer health snapshot

This is useful for internal:

Customer services
2 active customers
0 pending approvals
1 waiting customer
Recent internal activity
Document uploaded
Payment receipt submitted
Status changed
Support ticket updated

If backend doesn’t expose activity yet, show clean placeholder.

3. Backend/data approach

Current dashboard repository is too thin. It only reads generic dashboard fields from ApiConfig.dashboardDataMethod.

Phase 1 — UI-only improvement using existing data

No backend changes first.

Use existing:

HomeDashboardSummary
AuthCapabilities
internalWorkspaceSummaryProvider
internalServiceCasesProvider

Customer dashboard uses homeDashboardSummaryProvider.

Internal dashboard uses:

homeDashboardSummaryProvider
internalWorkspaceSummaryProvider
internalServiceCasesProvider

This is safest and quick.

Phase 2 — backend richer dashboard API

Later add richer response:

Customer dashboard API
{
  "next_action": {},
  "active_services": [],
  "document_summary": {},
  "payment_summary": {},
  "support_summary": {},
  "recent_activity": []
}
Internal dashboard API
{
  "operations_summary": {},
  "priority_queue": [],
  "document_review_queue": [],
  "payment_review_queue": [],
  "customer_health": {},
  "recent_activity": []
}
4. Files to change first
Main file
omc_app/lib/features/dashboard/presentation/dashboard_screen.dart

This should split into:

DashboardScreen
  -> CustomerDashboardBody
  -> InternalDashboardBody

Use auth:

final authState = ref.watch(authControllerProvider);
final isInternal = authState.capabilities.canAccessInternalWorkspace ||
                   authState.capabilities.isInternal;
Existing data file
omc_app/lib/features/home/data/home_dashboard_repository.dart

Leave it for Phase 1.

Optional later cleanup

Create widgets split later if file gets too big:

features/dashboard/presentation/widgets/customer_dashboard_body.dart
features/dashboard/presentation/widgets/internal_dashboard_body.dart
features/dashboard/presentation/widgets/dashboard_action_card.dart

But first patch single file to avoid overengineering.

Dashboard ka sab se upar sirf ek intelligent card ho:

Next action
Upload 2 missing documents to continue your Tax Filing service.
[Upload now]

Logic simple:

pendingDocuments > 0  → Upload documents
paymentsDue > 0       → View payment
activeCases > 0       → Track services
else                  → Browse services

Internal ke liye:

Next action
3 service cases need document review.
[Open review queue]
2. Progress-based service health

Customer ko sirf count nahi, service progress feel honi chahiye:

Tax Filing 2026
In Review
Documents 60% complete
Payment pending

Agar backend detailed service list abhi nahi deta, Phase 1 mein generic placeholder/snapshot se kaam chalega. Phase 2 mein real progress.

3. “Attention needed” section

Customer:

Needs your attention
• 2 documents missing
• 1 payment pending
• 1 unread notification

Internal:

Needs team attention
• Documents waiting review
• Payments waiting approval
• Customers waiting response

This is better than boring cards.

4. Recent activity as timeline

Abhi recent activity hai, but design ko zyada useful bana sakte hain:

Today
Document uploaded
CNIC Front uploaded for Tax Filing 2026

Yesterday
Payment receipt submitted
Receipt waiting for review

If empty:

No recent activity yet.
Your updates will appear here once services start moving.
5. Role-aware shortcuts

Customer shortcuts:

Start service
Upload document
View payments
Support
Tax calculator

Internal shortcuts:

Service queue
Document review
Payment review
Customer 360
Leads
Tasks

No big tiles. Compact rows/chips.

Best final dashboard structure
Customer dashboard
Compact header
Next action card
My services snapshot
Documents + Payments mini cards
Recent activity
Quick actions
Internal dashboard
Operations header
Priority metrics strip
Today action queue
Internal work areas compact list
Customer workspace summary
Recent activity / placeholder
Internal + customer combo

Internal dashboard ke bottom mein ek section aa sakta hai:

Customer workspace view
Open services: 2
Documents pending: 1
Payments due: 0

But customer ko internal section bilkul nahi.