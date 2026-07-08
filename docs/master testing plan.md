Master Testing Plan — OMC App


Phase 1 — Authentication and access testing

This is first real test. Ismein hum wrong login, correct login, guest, signup, pending, approval, and role assignment test karenge.

1A — Wrong login test
User action

Login screen par:

wrong email / wrong password
Expected UI
Clean error message.
App crash nahi.
Button loading ke baad normal ho.
Debug/API raw error customer ko na dikhe.
Backend/API check

No backend record should be created.

1B — Guest mode test

Routes mein guest ko allowed hai:

/home
/services
/knowledge
/tax-calculator
/support
/services/:serviceId

Guest ko service request route block hona chahiye:

/services/:serviceId/request

Router code mein guest allowed routes clearly defined hain.

User action

Login screen → Continue as Guest

Expected UI
Home open ho.
Guest banner/status visible ho.
Services preview open ho.
Knowledge open ho.
Tax calculator open ho.
Service detail open ho.
“Create request” ya protected action par login/signup prompt ya lock state aaye.
Backend check

Guest session create/update API should not block UI. Guest tracking non-blocking hai according to progress doc.

1C — Signup test

Signup UI has:

Customer
Consultant
Business Partner
Tax Associate

Role list code mein present hai.

User action

Create new customer:

Full name
Email
Mobile
WhatsApp
CNIC
Register as: Customer
Address
Password
Terms checkbox
Create account
Expected UI
Signup success message.
User login screen par redirect ho.
No full app access yet.
Backend expected

Backend should create:

User
OMC Customer Profile
customer_status = Pending
approval_status = Pending Review
role = OMC Customer Applicant if role exists

Signup backend sets pending statuses and saves profile fields.

1D — Pending user login test
User action

Signup ke baad same user se login.

Expected UI
Login successful.
Protected route access blocked.
Under review screen/message show ho.
Service request create nahi ho.
Document upload nahi ho.
Customer dashboard nahi open ho.

Router pending user ko protected route par /under-review bhejta hai.

1E — Backend approval test
Backend action

Frappe desk ya bench console se:

OMC Customer Profile
customer_status = Active
approval_status = Approved
Assign role = OMC Customer
Expected API

get_session_user / get_profile should return:

access_state = approved
can_create_service_request = true
can_upload_documents = true
can_track_requests = true

Backend capability flags present hain.

1F — Approved customer login test
User action

Logout → login again as approved customer.

Expected UI
Home dashboard open.
Services available.
Service request button enabled.
My Services available.
Documents available.
Support ticket creation available.
Notifications available.
Settings/Profile accessible.
Phase 2 — Customer service flow test

This is the main business flow.

2A — Service catalogue
User action

Approved customer → Services tab.

Expected UI
Services load from backend.
Search works.
Category/filter works if present.
Service cards readable.
No overflow on small screen.
Backend check
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
Pass condition

Service list UI matches backend data.

2B — Service detail
User action

Open one service.

Expected UI
Title/description.
Fee label.
Completion time.
Required documents.
Request button.

Backend service detail supports required documents and service metadata.

2C — Dynamic service request form
User action

Tap create/request service.

Expected UI
Dynamic fields from backend appear if configured.
If backend fields not configured, fallback request details field appears.
Required validation works.
Submit button works.

Progress doc says dynamic form rendering and form_data_json submission are wired.

Backend check

After submit, check:

OMC Service Request created
customer linked correctly
service linked correctly
form data saved
status initial/pending
2D — Customer sees request in My Services
User action

Go to My Services / Track.

Expected UI
Newly created request appears.
Status chip visible.
Detail page opens.
Timeline/progress visible if backend has timeline data.
2E — Admin updates service request
Backend/admin action

In Frappe:

Open OMC Service Request
Change status
Add timeline/update if supported
Save
Customer expected

Refresh app / reopen My Services:

Updated status visible.
Timeline/next step visible.
No internal admin controls visible to customer.
Phase 3 — Documents flow
3A — Required documents check
User action

Open Documents or service case detail.

Expected UI
Required/missing documents visible.
Submitted/approved/rejected states clear.
Upload action only for approved customer.
Permission expectation

Pending/guest cannot upload documents.

Backend approved customer helper blocks unauthorized users.

3B — Upload document
User action

Upload valid PDF/image.

Expected UI
File picked.
Upload loading state.
Success state.
Document appears as submitted.
Backend check
OMC Service Document created
attached file private if required
linked to correct service request/customer
3C — Admin review document
Backend/admin action

Approve/reject document.

Customer expected
Approved document shows approved.
Rejected document shows reason.
Re-upload option appears if rejected.
Phase 4 — Payments flow

Payment module is not direct payment gateway by default. It is receipt/status tracking unless enabled.

4A — Payment visibility / feature flag
User action

Open Payments.

Expected UI
If payment feature enabled: payment list visible.
If disabled: hidden or clean disabled state.
No fake payment gateway.

final_modi says payment collection is not active by default; receipt/status tracking only.

4B — Payment receipt upload
User action

Open payment → upload receipt.

Expected UI
Bank/payment instructions visible if backend has them.
Receipt preview before/after upload.
Status becomes submitted/under review.
Backend/admin action

Approve/reject receipt.

Customer expected
Paid/rejected status visible.
Rejected reason visible.
Phase 5 — Support flow
5A — Support screen as guest

Guest route allows support.

Expected UI
Support contact info visible.
FAQs visible if backend configured.
Guest should not create customer ticket unless allowed intentionally.

Progress doc says support screen reads backend FAQs.

5B — Approved customer support ticket
User action

Approved customer → Support → Create ticket.

Expected UI
Topic dropdown.
Priority/status visible.
Ticket detail chat/history style.
Submit success.
Backend check
OMC Support Ticket created
linked to customer
status Open
5C — Staff reply / status update
Backend/admin action

Reply/update ticket.

Customer expected
Ticket detail shows reply.
Status updates.
Notification created if implemented.
Phase 6 — Notifications flow
6A — Notification list
User action

Approved customer → Notifications.

Expected UI
Notification list.
Unread count/badge if data exists.
Detail opens.
Backend check

Progress doc says notification repository supports:

mobile_route / action_url
mark-one-read
mark-all-read
6B — Notification deep link
User action

Tap notification.

Expected UI
Related service/payment/document/support route opens if mobile_route exists.
Invalid route should not crash.
Phase 7 — Knowledge / banners / public content
7A — Home banners
User action

Open Home.

Expected UI
Backend app banners/announcements show if configured.
No crash if no banners.

Progress doc confirms Home watches backend banners provider.

7B — Knowledge articles
User action

Open Knowledge.

Expected UI
Articles/tax alerts load.
Detail page opens.
Guest can access public content.
Phase 8 — Tax calculator
8A — Guest tax calculator
User action

Guest → Tax Calculator.

Expected UI
Calculator opens.
Input works.
Result works.
No login required.

Guest route allows /tax-calculator.

8B — Approved customer tax calculator

Same test as guest, plus verify no customer data leakage or unexpected backend upload.

Phase 9 — Expense tracker
9A — Local-only expense test
User action

Approved customer → Expense Tracker.

Expected UI
Local-only banner/message.
Add expense.
Monthly summary updates.
Filter works.
Export/import JSON if present.

Progress doc says expense tracker is local-first with no automatic cloud upload path found.

Phase 10 — Settings / profile
10A — Profile
User action

Open Profile.

Expected UI
Customer info visible.
Update allowed fields.
Save works.
Backend profile updates.
10B — Settings
User action

Open Settings.

Expected UI
Notification preferences.
Theme/language if present.
Privacy policy.
Terms.
Delete account request.
Logout.

Progress doc says settings actions are updated and no customer-visible API/debug flags intentionally shown.

Phase 11 — Internal workspace / staff role testing

This is important. We test separate users, not one admin only.

11A — Normal customer should not access internal workspace
User action

Approved customer tries internal workspace route/action.

Expected
Blocked or redirected.
No internal cards.
No internal API access.

Router gates /internal-workspace using canAccessInternalWorkspace.

11B — OMC staff user

Create/assign staff role:

OMC Manager
OMC Support Agent
OMC Document Reviewer
OMC Finance Reviewer
OMC Consultant
OMC Business Partner
OMC Tax Associate

Backend has internal role groups and capability checks.

Expected UI
Internal workspace visible only for allowed roles.
Staff queues visible according to permission.
Customer-only routes do not leak private customer data unless staff role allows.
11C — Role-specific checks
Role	Test
OMC Manager	View cases, update service status
OMC Support Agent	Support ticket queue/reply
OMC Document Reviewer	Document review
OMC Finance Reviewer	Payment review
OMC Consultant	Internal workspace if allowed
Customer	No internal workspace
Phase 12 — Regression / final smoke test

After each fix, we repeat quick smoke:

Login
Guest
Signup
Approved customer home
Services load
Create request
My Services load
Support load
Settings logout

Then final commands:

cd ~/data_drive/app_omc/omc_app
flutter analyze
flutter test

Backend:

cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site omc.local migrate
bench --site omc.local execute omc_app.api.mobile.get_session_user
bench --site omc.local execute omc_app.api.mobile.get_service_catalogue
bench --site omc.local execute omc_app.api.mobile.get_mobile_app_config
Our actual execution order

We will not jump randomly. We follow this order:

0. Local readiness
1. Wrong login
2. Guest mode
3. Signup as Customer
4. Pending user restrictions
5. Backend approval
6. Approved customer login
7. Full service request flow
8. Documents flow
9. Support flow
10. Notifications
11. Payments if enabled
12. Settings/profile
13. Internal staff roles
14. Final analyze/test/backend smoke