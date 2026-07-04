. High-level App Breakdown
App type

OMC House tax/business service CRM mobile app

Ye app 3 cheezon ka mix hai:

Customer-facing tax/service request app
Login / signup
Google login
Add service request
View own services
Tax calculator
News / knowledge
WhatsApp support
Internal / partner CRM app
Leads
Customers
Tasks
Payment entry
Dashboard
Cases status
Customer/service document uploads
Frappe/ERPNext mobile frontend
Backend hardcoded: https://erp.omchouse.com
Uses Frappe REST resources like Lead, Service, Customer, Task Type, Knowledge, News, Tax Calculator
Uses custom API methods under lead_app.lead_app.apis

Main app initializes Firebase, notifications, Provider state, responsive breakpoints, and then starts from SplashScreen. Routes are defined for login, signup, dashboard, home, profile, about, contact, tax calculator, knowledge, news, services, customers, leads, notifications, chat, tasks, and view forms.

2. Screens / Modules Found in Code
A. Splash / Auth Flow
Screens found
SplashScreen
LoginScreen
ForgotPassword
SignUpScreen
Current logic

Login supports:

Normal ERPNext login with email/password
Google login
Saves user email/password/login type/session in SharedPreferences
Stores Frappe cookie/session
Redirects to bottom navigation after login

Normal login calls:

https://erp.omchouse.com/api/method/lead_app.lead_app.apis.login

Google login calls:

https://erp.omchouse.com/api/method/lead_app.lead_app.apis.google_mobile_login

The login code saves user_email, user_password, Google login flag, and session/cookie values locally.

Signup logic

Signup fields include:

Full name
Email
Mobile number
WhatsApp
CNIC
Register as
Consultant
Business Partner
Tax Associates
Address
Password
Confirm password

For Tax Associates, extra fields are shown:

Education
Experience
Remarks

Signup posts to:

https://erp.omchouse.com/api/method/lead_app.lead_app.apis.sign_up
B. Home Dashboard / Main Menu
Screen
Home
Current UI

Home screen has:

Drawer menu
Red curved header
OMC logo
TAXting title
Notification button
User full name
Image slider from backend
Grid menu

Home grid items include:

Item	Opens
Lead	Services screen
Service	Leadlist screen
Dashboard	Dashboard
Tax Calculator	TaxCalculator
Live Chat	ChatList
Customer	Customerlist
Task	Tasklist
Payment Entry	PaymentEntryList
News	News

Social login users hide some internal items like Lead, Customer, Task, and Payment Entry.

Backend data

Home fetches:

User full name from Frappe User
Slider images from Knowledge
Caches slider images in SharedPreferences
C. Lead List Module
Screen
Services

Despite file name services.dart, screen title is Lead List.

Current logic

Fetches Frappe Lead records filtered by logged-in user:

/api/resource/Lead
filters: user_link = userEmail
fields: title, name, workflow_state

It supports:

Search lead
Pull-to-refresh
Empty state
Status color
Lead detail navigation
Floating button: Add Lead
Statuses handled
Pending
Working in Progress
Lead Lost
Converted
D. Add Lead Module
Screen
ServiceForm

Despite name, this is Add Lead screen.

Current fields
Full name
Mobile number
Service type
Service amount
Remarks / comment
Current logic
Loads service types from Frappe Task Type
Reads rate and name
Auto-fills service amount based on selected service type
Uses native contact picker to pick Pakistani mobile number
Normalizes 03xxxxxxxxx into 923xxxxxxxxx
Posts lead to custom endpoint:
https://erp.omchouse.com/api/method/lead_app.lead_app.apis.create_service
E. Service List Module
Screen
Leadlist

This one is actually Service List.

Current logic

Fetches Frappe Service records filtered by logged-in user:

/api/resource/Service
filters: user_link = userEmail
fields: service_type, name, custom_status

It supports:

Search service
Pull-to-refresh
Empty state
View service detail
Add service button
Service statuses
Available
In Progress
Completed
F. Add Service Module
Screen
Leadform

This is a richer service request form.

Current fields

For non-social login users:

Search customer
CNIC / NTN
Customer name
Mobile number

Service section:

Select service type
Service amount
Remarks
Attach documents
Current logic
Fetches service types from Task Type
Auto-fills service amount
Supports CNIC/NTN validation
CNIC: 13 chars
NTN: 7 chars
Shows confirmation dialog when 7-character NTN is entered
Uses contact picker
Attaches selected documents
Posts to:
https://erp.omchouse.com/api/method/lead_app.lead_app.apis.create_lead

Then uploads files against Service doctype.

G. Customer List Module
Screen
Customerlist
Current logic

Fetches Frappe Customer records filtered by logged-in user:

/api/resource/Customer
filters: user_link = userEmail
fields: customer_name, name, status

It supports:

Customer search
Pull-to-refresh
Empty state
View customer detail
Add customer button
H. Add Customer Module
Screen
CustomerForm
Current fields
Customer name
Contact number
Source
Consultant
Business Partner
Employee
Tax Associate
CNIC / NTN
Area / territory
Category / customer group
Attach documents
Current logic
Loads territories from Frappe Territory
Loads customer groups from Frappe Customer Group
Creates Frappe Customer
Default company is hardcoded as Omc House
Uploads selected documents against the created customer
Uses CNIC/NTN validation and NTN confirmation
I. Dashboard Module
Screen
Dashboard
Current logic

Dashboard fetches:

User roles from Frappe User
Dashboard data from custom endpoint:
https://erp.omchouse.com/api/method/lead_app.lead_app.apis.get_dashboard_data

It separates dashboard view for:

Customer
Employee / Consultant / Partner / Tax Associate
Data shown

For non-customer/internal users:

Total referred cases
Completed
In progress
Declined
Employee count
Consultant count
Partner count
Tax associate count
Total earn
Paid
Unpaid
Daily job count / total leads

For customer users:

Total service requests
Completed
In progress
Declined / hold
Total invoice
Total payment
Outstanding

It also uses fl_chart, so chart-based dashboard visuals are present.

J. Tax Calculator
Screen
TaxCalculator
Current logic

Supports income types:

Salary Individual
Rental
Sole Proprietor

It fetches tax slab data from:

/api/resource/Tax Calculator/{incomeType}

Then reads child table tax_details with:

from_range
to___range
tax_percentage
fixed_charges

It calculates:

Monthly income
Monthly tax
Salary after tax
Yearly income
Yearly tax
Yearly income after tax
Difference from Befiler screenshots

Befiler screenshot had salary tax year dropdown.
This repo instead uses income type buttons and dynamic slabs from ERPNext. That is actually better long-term.

K. Live Chat / WhatsApp Support
Screen
ChatList
Current logic

It is not real in-app chat. It is a WhatsApp support launcher.

Support categories:

Category	Number
Income Tax and General Queries	+923122114116
POS and Digital Invoicing	+923182133314
Sales Tax	+923182133318

It tries:

Normal WhatsApp deep link
WhatsApp Business deep link
Android intent fallback for WhatsApp
Android intent fallback for WhatsApp Business
L. Knowledge Module
Screen
KnowledgeScreen
Current logic

Fetches Frappe Knowledge records with:

Image
Video
Text file
Titles
Descriptions

It builds media cards in grid and opens MediaViewerScreen.

Supported media types:

Image
Video
Text
M. News Module
Screen
News
Current logic

Almost same as Knowledge, but reads from Frappe News resource instead of Knowledge.

Supported media:

Image
Video
Text

Uses same MediaItem provider/list pattern.

N. Notification Module
Current setup

App initializes Firebase, calls FirebaseApi().initNotifications(), and has route /NotiScreen. Dependencies include:

firebase_core
firebase_messaging
flutter_local_notifications
cloud_firestore

So push notification foundation is present.

O. API / Backend Layer
Current model

There is a shared ApiHelper for:

POST requests
postAndReturn
Frappe error parsing
HTML stripping from Frappe messages
Cookie storage
ERPNext file upload
Optional API token via environment variable OMC_API_TOKEN

This is good foundation, but code still has repeated GetApiHelper classes inside several screen files, which should be centralized.

File upload goes to:

https://erp.omchouse.com/api/method/upload_file

with doctype, docname, and selected file.

3. Complete Feature List Found
Module	Exists?	Current status
Splash screen	Yes	Routed
Login	Yes	ERPNext custom API
Google login	Yes	ERPNext Google token API
Signup	Yes	Role-based signup
Forgot password	Yes	Routed
Home dashboard	Yes	Drawer + slider + grid
Bottom navigation	Yes	Present
Drawer menu	Yes	Present
Profile	Yes	Routed
About us	Yes	Routed
Contact us	Yes	Routed
Lead list	Yes	Frappe Lead
Add lead	Yes	Custom API
Service list	Yes	Frappe Service
Add service	Yes	Custom API + document upload
Customer list	Yes	Frappe Customer
Add customer	Yes	Frappe Customer + files
Customer detail	Yes	Routed
Lead/service detail	Yes	Routed
Task list	Yes	Routed
Task detail	Yes	Routed
Cases list	Yes	Used from dashboard
Payment entry list	Yes	Used from home
Dashboard analytics	Yes	Role-aware dashboard
Tax calculator	Yes	Dynamic ERP tax slabs
Knowledge/media	Yes	Image/video/text
News/media	Yes	Image/video/text
WhatsApp support	Yes	Deep links
Notifications	Yes	Firebase base
File/document upload	Yes	ERPNext upload_file
Local session storage	Yes	SharedPreferences
4. Existing Backend Entities Used

Code shows these Frappe resources / doctypes:

User
Lead
Service
Customer
Task Type
Territory
Customer Group
Knowledge
News
Tax Calculator

Custom API methods:

lead_app.lead_app.apis.login
lead_app.lead_app.apis.google_mobile_login
lead_app.lead_app.apis.sign_up
lead_app.lead_app.apis.generate_cookies
lead_app.lead_app.apis.create_service
lead_app.lead_app.apis.create_lead
lead_app.lead_app.apis.get_dashboard_data
upload_file
5. How This Repo Compares With Befiler Screenshot App
Similar features
Befiler screenshots	Current repo
Tax service app	Yes
Service request	Yes
Tax calculator	Yes
Profile/auth	Yes
WhatsApp/chat support	Yes
News/knowledge content	Yes
Document upload	Yes
Dashboard/home grid	Yes
Missing from current repo compared to Befiler
Befiler feature	Current repo status
Expense tracker	Not found
Cart	Not found
Service charges catalogue cards	Not same; current app has service type dropdown/list
NTN registration wizard	Not explicit
IRIS profile update wizard	Not explicit
GST registration form	Not explicit
Business incorporation menu	Not explicit
FAQ screen	Not found
Videos dedicated screen	Knowledge/News media exists, but not same
Language selector Urdu/English	Not found
App-wide service catalogue like Befiler	Not found
Features this repo has that Befiler screenshot report did not show clearly
Feature	Current repo
CRM customer management	Yes
Internal task list	Yes
Payment entry module	Yes
Role-based dashboard	Yes
Frappe/ERPNext integration	Yes
Google login into ERP	Yes
Dynamic tax slabs from backend	Yes
Customer document upload	Yes
Service document upload	Yes
Social-login onboarding form	Yes
6. Main Technical Observations
Good things already present
Real backend integration exists.
Auth is already connected to ERPNext.
Google login exists.
Firebase notification setup exists.
Document upload exists.
Service/customer/lead/task flows exist.
Dashboard has role-aware logic.
Tax calculator uses backend tax slabs instead of hardcoded frontend slabs.
App already uses reusable widgets like custom header, dropdown, text field, loading button.
Issues / risks
1. Naming confusion

Files and screens are confusing:

File	Actual purpose
services.dart	Lead list
leadList.dart	Service list
service_form.dart	Add Lead
leadForm.dart	Add Service

This will confuse future development badly.

2. API URLs are hardcoded

Many screens directly use:

https://erp.omchouse.com

This should move to:

lib/core/config/api_config.dart
3. Business logic is inside UI screens

API calls, validation, formatting, state, navigation, and UI are mixed inside big screen files.

4. Repeated API helper classes

Some screens define their own GetApiHelper. This should be centralized.

5. Session storage risk

Email/password are saved in SharedPreferences. That is not ideal for production. Better: store token/session securely using flutter_secure_storage.

6. No clean feature architecture

Current structure is:

lib/
 ├── models/
 ├── screens/
 └── widgets/

For the new app, this should become modular.

7. Recommended Flutter Architecture for New App

Use repo as reference, but rebuild cleaner:

lib/
 ├── app/
 │   ├── app.dart
 │   ├── router.dart
 │   └── theme.dart
 │
 ├── core/
 │   ├── config/
 │   ├── network/
 │   ├── storage/
 │   ├── errors/
 │   ├── utils/
 │   └── widgets/
 │
 ├── features/
 │   ├── auth/
 │   ├── home/
 │   ├── dashboard/
 │   ├── leads/
 │   ├── services/
 │   ├── customers/
 │   ├── tasks/
 │   ├── payments/
 │   ├── tax_calculator/
 │   ├── knowledge/
 │   ├── news/
 │   ├── chat_support/
 │   ├── notifications/
 │   └── profile/
 │
 └── main.dart

Recommended state/backend stack:

State: Riverpod or Provider
Routing: go_router
HTTP: Dio
Secure storage: flutter_secure_storage
Local cache: shared_preferences only for non-sensitive settings
Files: file_picker + image_picker
Notifications: Firebase Messaging
Backend: Frappe/ERPNext API
8. Build Plan If We Combine This Repo + Befiler Screenshots

Best product direction:

App identity

Not clone Befiler. Build:

OMC TAXting / OMC Filer App
Combined app modules
Priority	Module	Source
P1	Auth + Google login	Current repo
P1	Home dashboard	Current repo + Befiler style
P1	Service catalogue	Befiler screenshots
P1	Add service request	Current repo
P1	Document upload	Current repo
P1	Service status tracking	Current repo
P1	Tax calculator	Current repo, improve UI like Befiler
P2	Customer management	Current repo
P2	Dashboard analytics	Current repo
P2	WhatsApp support	Current repo
P2	Knowledge/news/media	Current repo
P3	Expense tracker	Befiler screenshots
P3	FAQ / blogs / videos	Befiler screenshots + current Knowledge
P3	Cart	Befiler screenshots, optional
P3	NTN/IRIS/GST/business wizards	Befiler screenshots
9. Recommended Development Phases
Phase 1 — Stabilize Existing App Base
Rename confusing files/classes.
Centralize API config.
Centralize API helper.
Move credentials/session to secure storage.
Keep existing features working.
Phase 2 — Rebuild UI Shell
Premium OMC theme
New bottom navigation
Clean home dashboard
Drawer cleanup
Reusable service cards
Better empty states/loading states
Phase 3 — Service Catalogue Like Befiler
Add category-based service catalogue
Add fee/time/requirements cards
Add request/call/WhatsApp actions
Link each service card to current Add Service form
Phase 4 — Service Request Wizards
NTN registration
IRIS profile update
GST registration
Business incorporation
Document upload checklist
Phase 5 — CRM/Internal Modules
Customers
Leads
Tasks
Payments
Dashboard analytics
Role-based access
Phase 6 — Expense Tracker
Accounts
Categories
Income/expense/transfer
Transaction list
Local DB
Backup/export
10. Final Recommendation

Boss, repo ko discard nahi karna. Ismein backend-connected working logic already hai. Lekin new app ke liye isko direct continue karna risky hai because naming, architecture, API mixing, and screen-level logic messy hai.

Best approach:

Use this repo as functional reference.
Use Befiler screenshots as product/UI reference.
Build new app from scratch with clean architecture.
Port working API logic module-by-module.

New app ka target hona chahiye:

Befiler-style service UX
+
OMC repo ka real ERPNext backend
+
clean Flutter architecture
+
better original premium UI

Next step mein main tumhare liye combined master app structure bana sakta hoon: Befiler screenshot features + current repo features merge karke final modules, routes, folders, backend doctypes, and phase-wise coding checklist.

