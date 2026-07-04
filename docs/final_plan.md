1. Final App Concept
App Name Direction

Working title:

OMC TAXting / OMC Filer / OMC Services

App Type

A premium ERP-connected mobile app for:

Customers
Signup/login
Service catalogue
NTN / GST / IRIS / tax filing requests
Document upload
Service tracking
Tax calculator
WhatsApp support
Knowledge/news/videos
Profile management
Internal / partner users
Leads
Customers
Services/cases
Tasks
Payment entries
Dashboard analytics
Notifications
Utility users
Salary tax calculator
Expense tracker
FAQ/blogs/videos
2. What We Will Keep From Old OMC App

The old app already has real Frappe/ERPNext connectivity, so we should preserve the logic, not the messy structure.

Keep / Rebuild Cleanly
Area	Current Status	Final Plan
ERPNext login	Exists	Rebuild with secure storage
Google login	Exists	Keep, improve flow
Signup	Exists	Keep, improve UI/validation
Lead creation	Exists	Rebuild as proper lead module
Service request	Exists	Keep as main workflow
Customer management	Exists	Keep for internal users
File upload	Exists	Keep and centralize
Dashboard	Exists	Keep, redesign premium
Tax calculator	Exists	Keep backend-driven
Knowledge/news	Exists	Keep, redesign cards
WhatsApp support	Exists	Keep, improve support center
Firebase notifications	Exists	Keep foundation
Main Old App Problems To Fix
Problem	Risk	Fix
Files have confusing names	Future bugs	Rename modules properly
API URLs hardcoded	Bad for staging/prod	Use config/env
API logic inside screens	Hard to maintain	Repository/service layer
Password stored in SharedPreferences	Security issue	Use flutter_secure_storage
Repeated API helpers	Code duplication	One Dio/Frappe client
UI inconsistent	Not premium	New design system
No clean feature modules	Scaling issue	Feature-first architecture
3. What We Will Add From Bfiler Reference

Bfiler has the customer-facing service flow we need.

Add These Modules
Bfiler Feature	Final OMC Version
Service catalogue cards	OMC service marketplace
NTN registration flow	Wizard + document upload
IRIS profile update	Wizard + income source selection
GST registration	Business form + document checklist
Business incorporation	Service subtype flow
Salary tax calculator	Use OMC backend slabs, better UI
Expense tracker	Local-first premium utility
FAQ/blogs/videos	Use OMC Knowledge/News backend
Cart	Optional service request basket
Settings/preferences	App settings + expense settings
Profile tabs	Personal info, password, delete account
4. Final Module Structure

We will build it like this:

lib/
 ├── app/
 │   ├── app.dart
 │   ├── router.dart
 │   ├── theme.dart
 │   └── bootstrap.dart
 │
 ├── core/
 │   ├── config/
 │   │   ├── api_config.dart
 │   │   └── env.dart
 │   ├── network/
 │   │   ├── dio_client.dart
 │   │   ├── frappe_client.dart
 │   │   └── api_error.dart
 │   ├── storage/
 │   │   ├── secure_storage_service.dart
 │   │   └── preferences_service.dart
 │   ├── utils/
 │   │   ├── validators.dart
 │   │   ├── phone_formatter.dart
 │   │   └── file_utils.dart
 │   └── widgets/
 │       ├── app_button.dart
 │       ├── app_text_field.dart
 │       ├── app_dropdown.dart
 │       ├── loading_view.dart
 │       ├── empty_state.dart
 │       └── premium_card.dart
 │
 ├── features/
 │   ├── splash/
 │   ├── auth/
 │   ├── onboarding/
 │   ├── home/
 │   ├── service_catalogue/
 │   ├── service_requests/
 │   ├── documents/
 │   ├── dashboard/
 │   ├── leads/
 │   ├── customers/
 │   ├── tasks/
 │   ├── payments/
 │   ├── tax_calculator/
 │   ├── expense_tracker/
 │   ├── knowledge/
 │   ├── news/
 │   ├── support/
 │   ├── notifications/
 │   ├── profile/
 │   └── settings/
 │
 └── main.dart
5. Recommended Flutter Stack
Core Packages
Purpose	Package
State management	flutter_riverpod
Routing	go_router
API client	dio
Secure session	flutter_secure_storage
Simple local settings	shared_preferences
Local DB for expense tracker	drift or isar
File picker	file_picker
Camera/gallery	image_picker
WhatsApp/call/email links	url_launcher
Date/number formatting	intl
Charts	fl_chart
Firebase push	firebase_messaging, flutter_local_notifications
SVG/icons	flutter_svg
Cached media	cached_network_image

My recommendation: Riverpod + Dio + GoRouter + SecureStorage + Drift.

6. App Navigation Plan
Bottom Navigation

Final premium bottom nav:

Tab	Purpose
Home	Main customer dashboard
Services	Catalogue + request tracking
Calculator	Tax calculator
Support	WhatsApp/chat/help
More	Profile/settings/internal modules

For internal/partner users, we can show additional dashboard cards inside Home or More, not crowd bottom nav.

7. Page-Wise Final Build Plan
A. Splash + Session Check
Build
Premium splash screen
OMC logo
App version
Session check
Auto-login if valid session/cookie/token exists
Redirect:
logged in → MainShell
not logged in → Login
Improvements
No password in SharedPreferences
Store session/cookie securely
Add graceful “session expired” handling
B. Login
Build
Email/password login
Google login
Forgot password
Secure error handling
Loading states
Clean validation
Backend

Use old OMC login API:

lead_app.lead_app.apis.login
lead_app.lead_app.apis.google_mobile_login
Premium UX
Clean white/dark background
Large heading
Soft cards
Smooth button loading
Proper invalid credential message
C. Signup
Build Fields
Full name
Email
Mobile number
WhatsApp number
CNIC
Register as:
Customer
Consultant
Business Partner
Tax Associate
Address
Password
Confirm password

For Tax Associate:

Education
Experience
Remarks
Backend

Use old OMC signup API:

lead_app.lead_app.apis.sign_up
Improvements
CNIC mask
Phone number formatter
Password strength
Better role explanation cards
Step-based signup instead of one huge form
D. Home Dashboard
Customer Home

Cards:

File Tax Return
NTN Registration
IRIS Profile Update
GST Registration
Business Incorporation
Salary Tax Calculator
My Services
Upload Documents
WhatsApp Support
News / Knowledge
Internal/Partner Home

Cards:

Dashboard
Leads
Customers
Services
Tasks
Payment Entries
Notifications
Reports
Improvements
Role-aware cards
Clean premium header
Search bar
Service shortcut carousel
Recent service status cards
Announcement/news carousel
E. Service Catalogue

This is one of the most important modules.

Build

Service catalogue with categories:

Income Tax Return
NTN Registration
GST / Sales Tax
IRIS Profile
Business Incorporation
PSEB / Freelancer
Company Compliance
Intellectual Property
Other Services
Service Card Fields

Each card should show:

Service title
Fee
Government fee note
Completion time
Requirements checklist
Request button
WhatsApp button
Add to cart / save draft
Data Source

Phase 1:

assets/data/service_catalogue.json

Phase 2:

Move to Frappe doctype/API.

Improvements Over Bfiler
Search services
Filter by category
Sort by popularity/price/time
Favorite services
Recently viewed
Direct “Start Request”
Service detail page before form
F. Service Request Flow

This will connect Bfiler-style service UX with OMC backend.

Generic Flow
Select service
 → Read requirements
 → Fill basic details
 → Upload documents
 → Review
 → Submit
 → Track status
Backend

Use old OMC create service/request logic:

lead_app.lead_app.apis.create_lead
lead_app.lead_app.apis.create_service
ERPNext upload_file
Build
Reusable service wizard engine
Dynamic fields based on service type
Required document checklist
Draft save
Upload progress
Submit confirmation
G. NTN Registration Wizard
Steps
CNIC front/back upload
Basic personal info
Contact info
Review
Submit
Fields
Full name
CNIC
Mobile
Email
Address
Occupation/source of income
CNIC images
Improvements
Clear upload quality instructions
Preview selected files
Replace/remove file
Submit status tracking
H. IRIS Profile Update Wizard
Steps
Select source of income
Enter relevant details
Upload documents
Review
Submit
Income Sources
Salary
Rental Income
Capital Assets
Agriculture
Foreign Income
Business Income
Other Sources
No Source of Income
Improvements
Dynamic form based on source
Explain each income type
Required documents update automatically
I. GST Registration Flow
Fields
Business name
Business type
Business start date
Business nature
Description
Gas/electricity consumer number
Business address
NTN/CNIC
Attach documents
Documents
CNIC
Utility bill
Business proof
Bank proof
Address proof
NTN certificate if available
UX
Multi-step form
Progress indicator
Save draft
Review screen
J. Business Incorporation
Options
AOP / Partnership NTN
Sole Proprietor NTN
Add Business to NTN
Remove Business from NTN
Pvt Ltd Company
Single Member Company
Flow

Each option opens:

Requirements
Fee/time
Dynamic form
Documents
Submit
K. My Services / Case Tracking
Build

List of user services from ERPNext.

Statuses
Available
Pending
In Progress
Working in Progress
Completed
Declined
Hold
Lead Lost
Converted
Card Should Show
Service type
Case ID
Status
Date
Amount
Assigned person if available
Documents
Payment status if available
Detail Page
Timeline
Uploaded documents
Remarks
Status history
Payment info
Support button
L. Lead Module

For internal/partner users.

Build
Lead list
Search
Status filter
Add lead
View lead detail
Pull refresh
Fields
Full name
Mobile
Service type
Amount
Remarks
Source/user link
Improvement

Rename properly:

features/leads/
 ├── lead_list_screen.dart
 ├── lead_form_screen.dart
 ├── lead_detail_screen.dart
 ├── lead_repository.dart
 └── lead_model.dart
M. Customer Module

For internal users.

Build
Customer list
Search
Add customer
Customer detail
Attach documents
Fields
Customer name
Contact number
CNIC/NTN
Source
Consultant
Business partner
Employee
Tax associate
Territory
Customer group
Documents
Improvements
Proper CNIC/NTN validation
Document preview
Clean split form sections
Reusable customer picker
N. Dashboard Analytics
Customer Dashboard

Show:

Total services
Completed
In progress
Declined/hold
Total invoice
Paid
Outstanding
Internal Dashboard

Show:

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
Daily jobs/leads
Improvements
Premium statistic cards
Charts using fl_chart
Date filters
Status breakdown
Refresh button
Empty/error states
O. Tax Calculator

Old OMC calculator is better than Bfiler because it fetches slabs from backend.

Build

Income types:

Salary Individual
Rental
Sole Proprietor
Results
Monthly income
Monthly tax
Monthly after tax
Yearly income
Yearly tax
Yearly after tax
Improvements
Better visual result cards
Tax year selector if backend supports it
Save/share result
Explain slab calculation
Backend fallback cache
P. Expense Tracker

This is from Bfiler reference and not in old OMC app.

Build
Accounts
Income categories
Expense categories
Add income
Add expense
Transfer
Transaction list
Balance summary
Category reports
Local backup/export
Storage

Use local database:

drift preferred for structured financial data
Models
Account
 ├── id
 ├── name
 ├── type
 ├── openingBalance
 └── currentBalance

Transaction
 ├── id
 ├── type
 ├── amount
 ├── fromAccountId
 ├── toAccountId
 ├── categoryId
 ├── date
 ├── note
 └── receiptPath
Improvements
Monthly reports
Category charts
Receipt image
Backup/restore
Optional cloud sync later
Q. Knowledge / News / Videos
Build

Use backend resources:

Knowledge
News
Support
Image
Video
Text
File/PDF if needed later
UI
Grid/list toggle
Search
Category filter
Media viewer
Save/share content
R. Support Center

Current old app launches WhatsApp. Keep that.

Build

Support categories:

Income Tax and General Queries
POS and Digital Invoicing
Sales Tax
Technical Support
Payment Support
Actions
WhatsApp
Call
Email
Create ticket later
Improvement

Use a nice support center instead of just chat list.

S. Notifications
Build
Firebase push setup
Notification list screen
Read/unread state
Deep link to service/case if notification has reference
Later

ERPNext/Frappe should send push notification when:

Service status changes
Document required
Payment pending
Case completed
New announcement/news
T. Profile + Settings
Profile
Personal info
CNIC
Email
Phone
WhatsApp
Address
Role
Change password
Delete account request
Settings
Theme mode
Language
Notifications
Expense tracker preferences
Backup settings
Logout
Improvements
Secure logout
Clear session/cookies
Privacy-friendly account deletion flow
8. Backend/Frappe Integration Plan
Existing Frappe Resources

We will structure repositories around these:

Doctype/API	Usage
User	Profile/roles
Lead	Lead list/status
Service	Service tracking
Customer	Customer management
Task Type	Service type/rate
Territory	Customer area
Customer Group	Customer category
Knowledge	Content/media
News	News/media
Tax Calculator	Tax slabs
upload_file	Document upload
Custom APIs
API	Usage
lead_app.lead_app.apis.login	Login
lead_app.lead_app.apis.google_mobile_login	Google login
lead_app.lead_app.apis.sign_up	Signup
lead_app.lead_app.apis.create_service	Lead/service creation
lead_app.lead_app.apis.create_lead	Service request creation
lead_app.lead_app.apis.get_dashboard_data	Dashboard
upload_file	Documents
9. Security Plan

Important production fixes:

Must Do
Move base URL to config
Use HTTPS only
Use flutter_secure_storage for session/cookies/token
Never store password locally
Centralize logout/session clear
Validate files before upload
Limit upload file size
Hide sensitive logs in release
Add proper API error parser
Add timeout/retry for network calls
Add role-based UI guards
Avoid
Hardcoded tokens
Hardcoded passwords
Printing cookies/session
Storing CNIC/docs in plain local cache unnecessarily
Direct API calls inside widgets
10. UI/UX Design Direction
Premium Style
Clean white background
Deep OMC red accent
Soft cards
Rounded 18–24px corners
Large readable text
Proper spacing
Skeleton loaders
Smooth empty states
Minimal icons
Consistent buttons
Bottom sheet forms where useful
Suggested Theme
Primary: OMC deep red
Background: soft off-white
Cards: white
Text: near-black
Success: green
Warning: amber
Error: red
Info: blue
Key UX Improvements
No cluttered screens
No huge unstructured forms
Use stepper/wizard flows
Clear status tracking
Clear upload progress
Search everywhere important
Better empty/error/loading states
Role-based dashboard instead of showing everything to everyone
11. Development Phases
Phase 0 — Project Setup

Goal: clean app foundation.

Build:

New Flutter project
App structure
Theme
Router
Dio client
Secure storage
API config
Shared widgets
Environment setup

Deliverable:

App boots cleanly
Navigation shell ready
No business logic yet
Phase 1 — Auth + Session

Build:

Splash
Login
Google login
Signup
Forgot password placeholder
Secure session save
Auto-login
Logout

Deliverable:

User can login/signup and reach app shell
Phase 2 — Premium Home Shell

Build:

MainShell with bottom nav
Home dashboard
Role-aware menu cards
Drawer/more menu
Profile shortcut
Notification icon
Slider/banner from backend or mock

Deliverable:

App feels complete visually
Phase 3 — Service Catalogue

Build:

Category filters
Search
Service cards
Fee/time/requirements
Service detail screen
WhatsApp/request actions

Deliverable:

Bfiler-style service browsing, but original OMC UI
Phase 4 — Service Requests + Documents

Build:

Add service request
Existing API integration
Customer picker if internal user
CNIC/NTN validation
File picker/image picker
Upload files to ERPNext
Request detail/status

Deliverable:

User can submit and track service request
Phase 5 — Wizards

Build:

NTN registration
IRIS profile update
GST registration
Business incorporation
Dynamic document checklist

Deliverable:

Major customer service flows are polished
Phase 6 — CRM/Internal Modules

Build:

Leads
Customers
Tasks
Payments
Dashboard analytics

Deliverable:

Internal users can manage operational data
Phase 7 — Tax Calculator

Build:

Backend-driven slabs
Income type selector
Results UI
Optional tax year selector
Share/save result

Deliverable:

Premium tax calculator
Phase 8 — Content + Support

Build:

Knowledge
News
Videos/media viewer
FAQ
WhatsApp support center
Notifications list

Deliverable:

Complete customer engagement layer
Phase 9 — Expense Tracker

Build:

Accounts
Categories
Add transaction
Income/expense/transfer
Balance calculation
Reports
Backup/export

Deliverable:

Strong utility feature like Bfiler, but cleaner
Phase 10 — Polish + Production Hardening

Build:

Error handling
Offline states
Loading skeletons
App icons/splash
Release config
Firebase notification finalization
Android build
Performance checks
Security cleanup

Deliverable:

Production-ready app
12. Execution Order I Recommend

Start like this:

Create new Flutter app in ~/data_drive/app_omc
Add clean architecture folders
Add theme/router/shared widgets
Add auth APIs from old OMC app
Add secure session
Build premium home shell
Then add modules one-by-one

We should not start from expense tracker or catalogue first because auth/session/backend foundation must be stable before real flows.

13. Final Decision
Best Strategy
Do not copy Bfiler.
Do not directly continue old OMC app.
Build a new clean premium OMC app.

Use:
- Bfiler for feature inspiration/customer UX
- Old OMC for backend APIs/business logic
- New Flutter architecture for final product
Final App Goal

A luxury, fast, ERP-connected, user-friendly OMC mobile app with:

Premium customer service experience
Real Frappe/ERPNext backend
Role-based CRM features
Secure auth/session handling
Clean service request flow
Document upload
Tax calculator
Knowledge/news/support
Optional expense tracker
Maintainable modular codebase
