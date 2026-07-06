Backend direction:

Standalone-first Frappe app.
ERPNext integration is optional/hybrid only.
Flutter must use backend APIs as source of truth.
No fake/local bypass in real app mode.
Mock mode may remain isolated behind OMC_USE_MOCK_AUTH=true.
1. Auth / Session
Flutter Module	Backend Method	Path
Sign up	sign_up	/api/method/omc_app.api.mobile.sign_up
Current session user	get_session_user	/api/method/omc_app.api.mobile.get_session_user

Expected Flutter wiring:

AuthRepository
SessionController
Secure cookie/session persistence
Logout should clear local secure session only unless backend logout API is added later.
2. Profile
Flutter Module	Backend Method	Path
Get profile	get_profile	/api/method/omc_app.api.mobile.get_profile
Update profile	update_profile	/api/method/omc_app.api.mobile.update_profile
Update contact info	update_contact_info	/api/method/omc_app.api.mobile.update_contact_info

Flutter screens:

Profile screen
Settings profile section
Contact info editor
3. Dashboard / Home
Flutter Module	Backend Method	Path
Dashboard data	get_dashboard_data	/api/method/omc_app.api.mobile.get_dashboard_data

Known tested dashboard counts:

open_services: 2
documents: 1
payments_due: 0
notifications: 0
recent_activity: real timeline rows

Flutter screens:

Home dashboard cards
Recent activity section
Quick status summaries
4. Service Catalogue
Flutter Module	Backend Method	Path
Catalogue list	get_service_catalogue	/api/method/omc_app.api.mobile.get_service_catalogue
Service detail	get_service_detail	/api/method/omc_app.api.mobile.get_service_detail
Create service	create_service	/api/method/omc_app.api.mobile.create_service

Flutter screens:

Service catalogue screen
Service detail screen
New service request flow
5. Service Cases / Requests
Flutter Module	Backend Method	Path
Case list	get_service_cases	/api/method/omc_app.api.mobile.get_service_cases
Case detail	get_service_case	/api/method/omc_app.api.mobile.get_service_case
Update case status	update_service_case_status	/api/method/omc_app.api.mobile.update_service_case_status
Add comment	add_service_case_comment	/api/method/omc_app.api.mobile.add_service_case_comment

Last tested case:

OMC-SR-2026-00002

Flutter screens:

My Services
Service case detail
Timeline/comments section
Internal/admin case status actions if exposed in app
6. Service Documents
Flutter Module	Backend Method	Path
Upload service document	upload_service_document	/api/method/omc_app.api.mobile.upload_service_document
Update document status	update_service_document_status	/api/method/omc_app.api.mobile.update_service_document_status
Documents list	get_documents	/api/method/omc_app.api.mobile.get_documents
Document detail	get_document	/api/method/omc_app.api.mobile.get_document

Last tested document:

0sv0ppf1c9

Flutter screens:

Documents screen
Case document upload section
Document detail/status view
7. Payments
Flutter Module	Backend Method	Path
Payments list	get_payments	/api/method/omc_app.api.mobile.get_payments
Payment detail	get_payment	/api/method/omc_app.api.mobile.get_payment
Upload receipt	upload_payment_receipt	/api/method/omc_app.api.mobile.upload_payment_receipt

Last tested payment:

37vlks7eu0

Flutter screens:

Payments screen
Payment detail
Receipt upload flow
8. Notifications
Flutter Module	Backend Method	Path
Notification list	get_notifications	/api/method/omc_app.api.mobile.get_notifications
Notification detail	get_notification_detail	/api/method/omc_app.api.mobile.get_notification_detail
Mark read	mark_notification_read	/api/method/omc_app.api.mobile.mark_notification_read

Last tested notification:

4lbitvud1c

Flutter screens:

Notifications screen
Notification detail
Unread badge state
9. Support Tickets
Flutter Module	Backend Method	Path
Create support ticket	create_support_ticket	/api/method/omc_app.api.mobile.create_support_ticket
Support ticket list	get_support_tickets	/api/method/omc_app.api.mobile.get_support_tickets
Support ticket detail	get_support_ticket	/api/method/omc_app.api.mobile.get_support_ticket

Last tested support ticket:

OMC-ST-2026-00001

Flutter screens:

Support screen
Create ticket screen
Ticket detail screen
10. Settings / Preferences
Flutter Module	Backend Method	Path
Get preferences	get_settings_preferences	/api/method/omc_app.api.mobile.get_settings_preferences
Update preferences	update_settings_preferences	/api/method/omc_app.api.mobile.update_settings_preferences

Flutter screens:

Settings screen
Notification preferences
Customer preferences
11. Internal Workspace / CRM
Flutter Module	Backend Method	Path
Internal workspace summary	get_internal_workspace_summary	/api/method/omc_app.api.mobile.get_internal_workspace_summary
Leads list	get_leads	/api/method/omc_app.api.mobile.get_leads
Lead detail	get_lead	/api/method/omc_app.api.mobile.get_lead
Customers list	get_customers	/api/method/omc_app.api.mobile.get_customers
Customer detail	get_customer	/api/method/omc_app.api.mobile.get_customer
Tasks list	get_tasks	/api/method/omc_app.api.mobile.get_tasks
Task detail	get_task	/api/method/omc_app.api.mobile.get_task

Known tested internal summary:

leads: 1
customers: 2
tasks: 2
open_services: 2
support_tickets: 1
documents: 1
payments_due: 0
unread_notifications: 0

Last tested records:

Lead: OMC-LEAD-2026-00001
Tasks:
- OMC-TASK-2026-00001
- OMC-TASK-2026-00002

Flutter screens:

Internal dashboard/workspace
Leads screen
Lead detail
Customers screen
Customer detail
Tasks screen
Task detail
12. Tax Calculator
Flutter Module	Backend Method	Path
Tax calculator	calculate_tax	/api/method/omc_app.api.mobile.calculate_tax

Status:

API may still be simple/static.
Wire only after confirming final tax calculation logic.
Keep Flutter calculator prepared for backend response but avoid hard business assumptions.
Flutter Integration Order
Phase 1 — Core Client
Confirm ApiConfig base URL.
Confirm FrappeClient handles:
GET/POST
Frappe /message response wrapper
cookies/session
upload/multipart
error normalization
Confirm repositories use /api/method/omc_app.api.mobile.<method> only.
Phase 2 — Customer App Modules
Auth/session
Profile/settings
Dashboard
Service catalogue
Service cases
Documents
Payments
Notifications
Support
Phase 3 — Internal Modules
Internal workspace summary
Leads
Customers
Tasks
Phase 4 — Polish / Error States
Loading states
Empty states
Error banners
Session expiry handling
Upload progress
Pull-to-refresh
Retry actions
Known Backend Test Records
Service case: OMC-SR-2026-00002
Document: 0sv0ppf1c9
Payment: 37vlks7eu0
Notification: 4lbitvud1c
Support ticket: OMC-ST-2026-00001
Tasks: OMC-TASK-2026-00001, OMC-TASK-2026-00002
Lead: OMC-LEAD-2026-00001
Signup test user/profile: mobile.test.customer@example.com
Integration Rule

Flutter must not invent backend fields blindly.

For each module:

Inspect existing Flutter model/repository.
Compare with backend response.
Patch model parsing safely.
Patch repository endpoint.
Patch UI only if model shape requires it.
Run flutter analyze.
Move to next module.

EOF