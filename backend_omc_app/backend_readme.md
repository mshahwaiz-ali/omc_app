# OMC App — Product & Client Workflow Guide

## Introduction

OMC App is a customer service and compliance portal for OMC House.

Customers use the mobile app to explore OMC services, create an account, submit service requests, upload documents, track request status, view payment/receipt updates, receive notifications, contact support, use a tax calculator, and manage basic expense tracking.

OMC staff use the Frappe Desk/backend to manage the business operation behind the app. Staff can review new customer profiles, approve or reject users, manage services, update service requests, review uploaded documents, review payment receipts, handle support tickets, manage leads, assign tasks, and maintain customer history.

The main goal is simple:

```text
Customer uses mobile app.
OMC team manages everything from Frappe Desk.
Both sides stay connected through the same backend records.
```

---

## Simple Client-Facing Explanation

OMC House mobile app is a digital service portal where customers can:

* Browse OMC services
* Create an account
* Wait for OMC approval
* Request services
* Upload required documents
* Track service progress
* View payment instructions/status
* Upload payment receipt/proof
* Raise support tickets
* Receive notifications
* Use tax calculator and expense tracker
* Read knowledge/news/help content

OMC staff can manage the full backend workflow from Frappe Desk:

* Customer profiles
* Signup approvals
* Service catalogue
* Service requests
* Required documents
* Uploaded files
* Payment/receipt tracking
* Support tickets
* Leads
* Tasks
* Notifications
* Knowledge/news content

---

## Main User Types

### 1. Guest User

A guest is anyone who opens the app without login/signup.

Guest users can:

* Open the app
* Browse public home content
* View services catalogue
* Open service details
* Read knowledge/news/help content
* Use tax calculator
* View support/contact information
* Go to login/signup

Guest users cannot:

* Create service requests
* Upload documents
* View customer dashboard
* Track personal service cases
* View customer documents
* View customer payments
* Create customer-specific support tickets
* View customer-specific notifications
* Access internal workspace

When a guest tries to open a locked feature, the app should show a clear message:

```text
Please create an account or subscribe to access this feature.
```

---

### 2. Signup / Pending Review User

A pending user is someone who has created an account but is not yet approved by OMC.

During signup, the customer may provide:

| Field                        | Purpose                                                   |
| ---------------------------- | --------------------------------------------------------- |
| Full name                    | Customer/applicant identity                               |
| Email                        | Login ID                                                  |
| Mobile number                | Contact                                                   |
| WhatsApp number              | Communication                                             |
| CNIC                         | Verification                                              |
| Register as                  | Customer, Consultant, Business Partner, or Tax Associate  |
| Address                      | Contact/address record                                    |
| Password                     | App login                                                 |
| Education/experience/remarks | Extra review info for Tax Associate or partner-type users |

After signup, the account is not automatically approved.

Initial status:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending users can:

* Login
* View limited profile/status
* Browse public services
* Read knowledge/news
* Use tax calculator
* See that account is under review

Pending users cannot:

* Create service request
* Upload documents
* Track My Services
* Access customer dashboard
* Create customer-specific support ticket
* Access internal workspace

Recommended message:

```text
Your account is under review. OMC team will verify your profile before enabling service access.
```

---

### 3. Approved Customer

An approved customer is a verified customer whose profile has been approved by OMC staff.

Approved status:

```text
customer_status = Active
approval_status = Approved
```

Approved customers can:

* View dashboard
* Browse services
* Create service requests
* Upload required documents
* Track service progress
* View documents
* View payment instructions/status
* Upload payment receipt/proof if payment tracking is enabled
* Receive notifications
* Create support tickets
* View support ticket replies/status
* Update profile/settings
* Use tax calculator
* Use expense tracker
* Read knowledge/news content

---

### 4. Consultant / Business Partner / Tax Associate

These users can apply through signup, but they should not get automatic full access.

Recommended workflow:

```text
User signs up as Consultant / Business Partner / Tax Associate
  ↓
Profile is created as Pending Review
  ↓
OMC team reviews from Frappe Desk
  ↓
OMC team verifies role and documents
  ↓
OMC team approves, rejects, or changes user type
  ↓
Approved access is given according to role
```

Example:

* User selects “Consultant”
* OMC team checks profile
* If user is actually a customer, OMC can change role/type to Customer
* After approval, customer features unlock

---

### 5. OMC Admin / Staff

OMC staff use Frappe Desk or internal workspace to manage backend work.

Typical staff roles:

| Role                  | Main Work                                          |
| --------------------- | -------------------------------------------------- |
| OMC Admin             | Full OMC control, users, roles, services, settings |
| OMC Manager           | Service cases, customer follow-up, operations      |
| OMC Support Agent     | Support tickets and replies                        |
| OMC Document Reviewer | Uploaded document review                           |
| OMC Finance Reviewer  | Payment receipt review                             |
| OMC Consultant        | Assigned customer/service work                     |
| OMC Business Partner  | Partner workflow                                   |
| OMC Tax Associate     | Tax-related workflow                               |
| System Manager        | Frappe/system administration                       |

---

## User Approval Model

This is the recommended approval model for client explanation:

```text
Signup
  ↓
OMC Customer Profile: Pending Review
  ↓
OMC Admin reviews in Frappe Desk
  ↓
Decision:
  ├── Keep Pending → user sees under-review/limited access
  ├── Reject → user remains blocked or receives rejection notice
  ├── Approve as Customer → services/docs/payments/support unlock
  ├── Approve as Consultant / Partner / Tax Associate → role-specific access
  └── Approve as OMC Staff → internal role/workspace access
```

This protects OMC from random users creating service requests without verification.

---

## Final Access Rules

| User Type                            | Service Catalogue | Service Request   | Documents     | Payments        | Support Ticket    | Internal Workspace |
| ------------------------------------ | ----------------- | ----------------- | ------------- | --------------- | ----------------- | ------------------ |
| Guest                                | Yes               | No                | No            | No              | No / contact only | No                 |
| Pending User                         | Yes               | No                | No            | No              | No / limited      | No                 |
| Approved Customer                    | Yes               | Yes               | Yes           | Yes, if enabled | Yes               | No                 |
| Consultant / Partner / Tax Associate | Role-specific     | Role-specific     | Role-specific | Role-specific   | Role-specific     | If approved        |
| OMC Staff                            | Backend/internal  | Internal workflow | Review/manage | Review/manage   | Manage            | Yes                |

---

## Main App Navigation

The customer app can be explained with five main navigation areas:

| Area                | Purpose                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| Home                | Main entry point, shortcuts, public/customer summary                                            |
| Services            | Browse OMC services and request service                                                         |
| Track / My Services | Track service requests and progress                                                             |
| Docs                | View/upload customer documents                                                                  |
| More                | Profile, settings, payments, support, notifications, knowledge, tax calculator, expense tracker |

The exact visibility depends on user status:

* Guest sees public options.
* Pending user sees limited access.
* Approved customer sees full customer features.
* Staff sees internal features if role allows.

---

## Full Customer Journey

```text
Guest opens app
  ↓
Explores services, knowledge/news, tax calculator, support contact
  ↓
Tries to create service request
  ↓
App asks user to signup/login
  ↓
User signs up
  ↓
Profile is created as Pending Review
  ↓
OMC team reviews user in Frappe Desk
  ↓
OMC team approves customer
  ↓
Customer gets full app access
  ↓
Customer selects a service
  ↓
Customer submits service request
  ↓
Customer uploads documents
  ↓
OMC team processes case
  ↓
OMC team updates status/timeline
  ↓
Customer receives notifications
  ↓
Payment/receipt tracking if required
  ↓
Support ticket if customer needs help
  ↓
Service completed
```

---

# Feature-by-Feature Product Guide

## 1. Home

Home is the main entry point of the mobile app.

For guests, Home works like a public preview of OMC services and useful tools.

For approved customers, Home works like a customer dashboard with quick access to:

* Services
* Track / My Services
* Documents
* Payments
* Notifications
* Support
* Profile
* Settings
* Knowledge/news
* Tax calculator
* Expense tracker

OMC staff can control much of the content from Frappe Desk if services, banners, knowledge articles, FAQs, and announcements are backend-driven.

---

## 2. Services

Services should be controlled from Frappe Desk, not hardcoded in the app.

OMC staff can manage service records from Frappe Desk, including:

| Service Field          | Purpose                          |
| ---------------------- | -------------------------------- |
| Service title          | Name shown in app                |
| Description            | Service explanation              |
| Category               | Service grouping                 |
| Price/fee label        | Fee or “Contact OMC for pricing” |
| Completion time        | Expected processing time         |
| Required documents     | Documents customer must upload   |
| Service icon           | Visual identity                  |
| Featured status        | Highlight service in app         |
| Active/inactive status | Show/hide service                |
| Sort order             | Control display order            |
| Instructions           | Customer guidance                |

Customer flow:

```text
Open Services
  ↓
Select service
  ↓
Read details, fees, time, required documents
  ↓
Create request if approved
```

OMC benefit:

* Services can be updated from Desk.
* App redeploy is not required for normal service updates.
* New/seasonal services can be added quickly.
* Pricing and instructions stay controlled by OMC.

---

## 3. Service Request

Service request is the core business workflow.

Customer side:

```text
Customer selects service
  ↓
Fills request form/details
  ↓
Submits request
  ↓
Request appears in Track/My Services
```

Frappe Desk side:

OMC staff can open the created service request and manage:

* Customer
* Service
* Request title/details
* Status
* Priority
* Assigned staff
* Expected completion
* Internal notes
* Customer-visible notes
* Required documents
* Timeline updates
* Payment records
* Support references

Recommended service statuses:

| Status               | Meaning                                |
| -------------------- | -------------------------------------- |
| Open                 | Request created                        |
| Waiting for Customer | OMC needs documents/info from customer |
| In Progress          | OMC team is working                    |
| Under Review         | Case is being checked/finalized        |
| Completed            | Service completed                      |
| Cancelled            | Request cancelled                      |

Customer should see simple tracking status, not internal complexity.

---

## 4. Track / My Services

Track/My Services lets customers follow their submitted service requests.

Customer can see:

* Service title
* Request status
* Priority
* Created date
* Expected completion
* Progress
* Next step
* Required documents
* Missing documents
* Timeline/history
* Customer action required

OMC staff updates status from Frappe Desk. Customer sees updates in the app.

Recommended progress mapping:

| Status               | Approx. Progress |
| -------------------- | ---------------: |
| Open                 |              10% |
| Waiting for Customer |              35% |
| In Progress          |              60% |
| Under Review         |              80% |
| Completed            |             100% |
| Cancelled            |               0% |

---

## 5. Documents

Documents are linked to service requests and customer profiles.

Customer side:

```text
Open document section
  ↓
View required/missing documents
  ↓
Upload PDF/image/document
  ↓
Wait for OMC review
  ↓
See approved/rejected/uploaded status
```

OMC Desk side:

Staff can review uploaded documents and mark:

* Pending
* Uploaded
* Approved
* Rejected

If rejected, OMC should provide a reason so the customer can upload the corrected file.

Recommended rules:

* Files should be private.
* Files should be linked to the correct customer and service request.
* Only approved customers should upload service documents.
* Staff should review documents from Desk/internal workflow.

Supported document examples:

* CNIC
* NTN certificate
* Business registration
* Tax documents
* Forms
* Receipts
* Supporting evidence
* PDFs/images/documents required by a service

---

## 6. Payments

Payment module should be explained carefully.

The app is not a direct payment gateway by default.

Current intended use:

```text
OMC creates payment/due record
  ↓
Customer sees amount/instructions/status
  ↓
Customer uploads receipt/proof
  ↓
OMC staff reviews receipt in Desk
  ↓
Payment status is updated
```

Payment statuses can include:

* Pending
* Receipt Submitted
* Under Review
* Paid
* Rejected
* Cancelled

OMC Desk side:

Staff can manage:

* Customer
* Service request
* Amount
* Currency
* Due date
* Payment instructions
* Receipt/proof
* Review status
* Rejection reason if any
* Internal remarks

If OMC does not want payment tracking now, the Payments section can remain hidden/disabled.

---

## 7. Support

Support gives customers a structured help channel instead of scattered WhatsApp messages.

Customer side:

```text
Open Support
  ↓
View contact channels / FAQs
  ↓
Create support ticket
  ↓
Select topic and priority
  ↓
Add message
  ↓
Track replies/status
```

OMC Desk side:

Staff can manage:

* Support ticket subject
* Customer
* Service request reference, if any
* Topic
* Priority
* Status
* Replies
* Internal notes
* Assigned support person

Support statuses:

* Open
* Waiting for Customer
* Resolved
* Closed
* Cancelled

Support topics can include:

* Income Tax
* POS & Digital Invoicing
* Sales Tax
* Technical Support
* Payment Support
* General Support

---

## 8. Notifications

Notifications keep customers updated.

Notifications can be related to:

* Service request updates
* Document approval/rejection
* Payment receipt status
* Support ticket replies
* General announcements
* Tax alerts
* Reminders

Customer side:

* View notification list
* Open notification detail
* Read update
* Tap related action if available

OMC Desk side:

Notifications can be created or triggered when staff updates:

* Service status
* Document status
* Payment receipt status
* Support ticket status
* Announcement/tax alert

Recommended behavior:

* Customer should only see notifications relevant to their own profile.
* Staff/internal notifications should not leak to customers.
* Customer-visible flag should control what appears in the app.

---

## 9. Knowledge, News, FAQs, and Tax Alerts

Knowledge/news content should be backend-driven.

OMC staff can manage content from Frappe Desk, such as:

| Content Type        | Purpose                                     |
| ------------------- | ------------------------------------------- |
| Knowledge Article   | Tax guides, service education, help content |
| Tax Alert           | FBR/tax updates and reminders               |
| App Banner          | Home screen promotional/info banner         |
| Announcement        | General OMC updates                         |
| FAQ                 | Frequently asked questions                  |
| Service Category    | Service grouping                            |
| Subscription Plan   | Paid/locked packages if needed              |
| Feature Access Rule | Which user/role can access which feature    |

Customer/guest side:

* Read public articles
* View tax awareness content
* See app banners
* Read FAQs
* Learn about services before signup

OMC benefit:

* Content can be changed from Desk.
* App update is not required for normal content changes.
* OMC can use the app as an authority/news channel.

---

## 10. Tax Calculator

Tax calculator is a customer utility.

Guest and customers can use it to get a quick estimate.

Important client explanation:

```text
Tax calculator gives an estimate only.
Final filing/advice should be verified by OMC team.
```

OMC benefit:

* Useful free tool for customer engagement.
* Helps users understand tax impact.
* Can lead customers toward OMC tax services.

---

## 11. Personal Expense Tracker

Expense tracker is a customer utility feature.

Customer can track:

* Income
* Expenses
* Categories
* Monthly summary
* Balance

Client explanation:

```text
Expense tracker helps customers maintain simple personal finance records inside the app.
```

Future premium option:

* Advanced reports
* Export
* Business expense categories
* Subscription-based finance tools

---

## 12. Profile

Profile stores customer identity and verification data.

Customer profile can include:

* Full name
* Email
* Phone
* WhatsApp
* CNIC
* NTN
* Company name
* Address
* Register-as type
* Customer type
* Approval status
* Customer status
* Notes/remarks
* Verification decision

OMC Desk side:

Staff uses customer profile to:

* Review new signup
* Verify identity
* Approve/reject customer
* Change user type/role
* View linked service requests
* View linked documents
* View support history
* View payment history
* View activity/notes

---

## 13. Settings

Settings are customer-specific preferences.

Customer can manage:

* Service update notifications
* Document reminders
* Payment alerts
* Tax alerts
* Email notifications
* WhatsApp notifications
* Theme
* Language

OMC benefit:

* Better customer communication control
* Customer can choose what alerts they want
* Preferences remain linked to the customer profile

---

## 14. Internal Workspace / Frappe Desk

Internal workspace is for OMC staff only.

It can show operational summaries such as:

* Leads
* Customers
* Tasks
* Open service requests
* Pending documents
* Payment dues
* Support tickets
* Unread notifications

Frappe Desk is the main backend control area where OMC staff can open lists/forms and update records.

Main Desk modules/records:

| Desk Record                   | What Staff Does                          |
| ----------------------------- | ---------------------------------------- |
| OMC Customer Profile          | Review, approve, reject, update customer |
| OMC Service                   | Create/update service catalogue          |
| OMC Service Required Document | Define required docs per service         |
| OMC Service Request           | Process customer requests                |
| OMC Service Document          | Review uploaded documents                |
| OMC Service Payment           | Track dues and review receipts           |
| OMC Notification              | Send/view customer updates               |
| OMC Support Ticket            | Reply and update support cases           |
| OMC Support Channel           | Manage WhatsApp/phone/email              |
| OMC Support Topic             | Manage support categories                |
| OMC Lead                      | Track potential customers                |
| OMC Task                      | Assign follow-ups                        |
| OMC Knowledge Article         | Manage guide/help content                |
| OMC FAQ                       | Manage FAQs                              |
| OMC App Banner                | Manage home banners                      |
| OMC Announcement              | Publish announcements                    |

---

# Frappe Desk Operating Flow

## A. Managing New Signup Requests

When a user signs up:

1. Open Frappe Desk.
2. Go to `OMC Customer Profile`.
3. Open profiles with `Pending Review`.
4. Check:

   * Name
   * Email
   * Phone
   * WhatsApp
   * CNIC
   * NTN
   * Address
   * Register-as type
   * Education/experience if applicable
5. Verify customer/applicant.
6. Decide:

   * Keep Pending
   * Approve as Customer
   * Approve as Consultant
   * Approve as Business Partner
   * Approve as Tax Associate
   * Reject / request more information
7. Save profile.
8. Customer access updates in app.

Recommended approval statuses:

| Status             | Meaning                      |
| ------------------ | ---------------------------- |
| Pending Review     | Waiting for OMC verification |
| Approved           | Customer/user verified       |
| Rejected           | User not approved            |
| More Info Required | OMC needs more details       |

---

## B. Managing Services

OMC staff can manage services from Desk.

Steps:

1. Open `OMC Service`.
2. Create or edit service.
3. Fill:

   * Title
   * Description
   * Category
   * Fee label
   * Completion time
   * Instructions
   * Featured status
   * Active status
   * Sort order
4. Add required document rules in `OMC Service Required Document`.
5. Save.
6. App service catalogue updates from backend.

This lets OMC add/edit services without releasing a new app version.

---

## C. Managing Service Requests

When an approved customer creates a service request:

1. Staff opens `OMC Service Request`.
2. Finds new/open requests.
3. Reviews:

   * Customer
   * Service
   * Request details
   * Priority
   * Documents
   * Contact information
4. Assigns staff if needed.
5. Updates status:

   * Open
   * Waiting for Customer
   * In Progress
   * Under Review
   * Completed
   * Cancelled
6. Adds customer-visible note/timeline update if needed.
7. Saves.
8. Customer sees updated tracking in app.

---

## D. Managing Documents

When a customer uploads a document:

1. Staff opens `OMC Service Document`.
2. Filters by:

   * Pending
   * Uploaded
   * Service request
   * Customer
3. Opens uploaded document.
4. Reviews file.
5. Sets status:

   * Approved
   * Rejected
   * More Info Required
6. Adds rejection/review remarks if needed.
7. Saves.
8. Customer sees updated document status.

---

## E. Managing Payments / Receipts

If payment tracking is enabled:

1. Staff creates `OMC Service Payment` against a service request.
2. Adds:

   * Amount
   * Currency
   * Due date
   * Payment instructions
   * Remarks
3. Customer sees payment due in app.
4. Customer uploads receipt/proof.
5. Staff opens payment record.
6. Reviews receipt.
7. Updates status:

   * Under Review
   * Paid
   * Rejected
   * Cancelled
8. Adds remarks/rejection reason if needed.
9. Saves.
10. Customer sees payment status update.

Important:

```text
Payment module is for tracking dues and receipts.
It is not direct payment gateway collection unless OMC decides to add that later.
```

---

## F. Managing Support Tickets

When customer creates a ticket:

1. Staff opens `OMC Support Ticket`.
2. Filters open tickets.
3. Opens ticket.
4. Reviews:

   * Customer
   * Subject
   * Message
   * Topic
   * Priority
   * Related service request
5. Replies to customer.
6. Updates status:

   * Open
   * Waiting for Customer
   * Resolved
   * Closed
   * Cancelled
7. Saves.
8. Customer sees reply/status in app.

---

## G. Managing Leads and Tasks

OMC can use leads/tasks for internal follow-up.

Leads:

* New potential customer
* Service interest
* Phone/email/company
* Source
* Notes

Tasks:

* Assigned staff
* Due date
* Priority
* Linked customer
* Linked service request
* Linked support ticket
* Status

Example:

```text
Customer requests tax filing service
  ↓
OMC Manager creates task for Tax Associate
  ↓
Tax Associate follows up
  ↓
Task marked completed
```

---

## H. Managing Content

OMC can manage public app content from Desk.

Content types:

* Knowledge articles
* Tax alerts
* FAQs
* App banners
* Announcements
* Service categories
* Subscription/package content if used

Flow:

```text
OMC staff creates/updates content in Desk
  ↓
Marks content active/public
  ↓
Customer app fetches latest content
  ↓
Guest/customer sees updated content
```

---

# Complete 0-to-100 Business Flow

```text
1. Guest opens OMC app
2. Guest browses services and public content
3. Guest uses tax calculator/support contact
4. Guest tries locked feature
5. App asks for signup/login
6. User signs up
7. Profile becomes Pending Review
8. OMC staff reviews profile in Frappe Desk
9. OMC approves/rejects/keeps pending
10. Approved customer gets full access
11. Customer creates service request
12. OMC staff opens service request in Desk
13. OMC staff reviews request and required documents
14. Customer uploads documents
15. OMC staff approves/rejects documents
16. OMC staff updates service status/timeline
17. Customer tracks progress in app
18. OMC creates payment/due record if needed
19. Customer uploads receipt/proof
20. OMC reviews receipt
21. Customer receives notifications
22. Customer creates support ticket if needed
23. OMC replies/resolves support ticket
24. Service is completed
25. Customer history remains saved in backend
```

---

# Business Value

## For Customers

| Benefit                | Explanation                               |
| ---------------------- | ----------------------------------------- |
| Easy service request   | Customer can request services from mobile |
| Clear document process | Required documents are visible            |
| Status tracking        | Customer knows where the case stands      |
| Receipt upload         | Payment proof can be submitted from app   |
| Support history        | Tickets and replies stay organized        |
| Notifications          | Customer gets updates                     |
| Tax calculator         | Useful public/customer utility            |
| Expense tracker        | Extra value inside app                    |
| Knowledge/news         | Customer can learn from OMC content       |

## For OMC Team

| Benefit                    | Explanation                                                          |
| -------------------------- | -------------------------------------------------------------------- |
| Less manual WhatsApp chaos | Work moves into structured records                                   |
| Customer data organized    | Profiles and service history stay linked                             |
| Document review workflow   | Uploaded files attach to customer/service                            |
| Payment tracking           | Receipt review becomes traceable                                     |
| Service timeline           | Staff and customer both see progress                                 |
| Support tickets            | Help requests are structured                                         |
| Backend-controlled content | Services/content can change without app update                       |
| Role-based staff work      | OMC can separate admin, support, document, finance, and service work |

---

# Common Client Scenarios

## Scenario 1: Guest wants to request a service

Guest can browse service details, but when they try to create a request, the app asks them to signup/login. Service requests require approval.

## Scenario 2: User signs up and tries to use full app

The user can log in, but full customer features remain locked until OMC approves the profile from Frappe Desk.

## Scenario 3: Consultant applies

Consultant profile is created as pending. OMC reviews the application, verifies the role, and approves/rejects or changes the type before access is given.

## Scenario 4: Customer uploads wrong document

OMC staff rejects the document and adds remarks. Customer sees rejected status and uploads the corrected document.

## Scenario 5: Payment proof is uploaded

Customer uploads receipt. OMC staff reviews it from Desk and marks payment as Paid, Rejected, Under Review, or Cancelled.

## Scenario 6: Customer needs help

Customer opens Support, creates a ticket, and follows replies/status from the app. OMC staff replies from Desk/internal workflow.

## Scenario 7: OMC wants to add a new service

OMC staff creates a new `OMC Service` record in Desk, adds details and required documents, marks it active, and the app can show it without app redeployment.

---

# FAQs

## Is this app only for customers?

No. It has customer-facing mobile features and backend/internal staff workflows.

## Can a guest use the app?

Yes. Guests can browse public services, knowledge/news, tax calculator, and support contact information.

## Can a guest create service requests?

No. Service request creation requires an approved customer profile.

## Does signup immediately approve the customer?

No. Signup creates a pending profile. OMC staff must approve the customer from Frappe Desk.

## Can pending users use customer features?

No. Pending users get limited access until approval.

## Can consultants, partners, or tax associates apply?

Yes. They can apply, but OMC must review and approve their role before access is granted.

## Does the app collect payments directly?

Not by default. Payment module is for payment due/status and receipt/proof tracking. Direct payment gateway collection can be added later if required.

## Can OMC update services without app update?

Yes. Services should be managed from Frappe Desk, so OMC can update service cards/content without releasing a new app version.

## Are uploaded documents public?

No. Customer documents should be private and linked to the correct customer/service request.

## Can customers see staff/internal data?

No. Internal records and workspace are role-gated and should only be visible to authorized OMC staff.

---

# Final Pitch

OMC App is a customer service and compliance portal where customers can request OMC services, upload documents, track progress, submit payment proof, receive updates, and contact support from mobile.

OMC staff manage the full operation from Frappe Desk: customer approvals, service catalogue, service cases, documents, payments, support tickets, leads, tasks, notifications, and content.

The system reduces manual follow-up, centralizes customer history, improves transparency, and gives OMC full backend control over the customer service workflow.
