# OMC App Client Guide

## Introduction

OMC App is a digital service portal for OMC House customers and staff. Customers can use the app to explore OMC services, create an account, wait for profile approval, submit service requests, upload documents, track progress, view payment/receipt status, receive notifications, use support, and access helpful tax or finance tools.

OMC staff use the backend/Frappe side to review customer profiles, approve users, manage service requests, check documents, review payments, handle support tickets, manage leads, and follow internal tasks.

The app is designed to reduce manual WhatsApp/file handling and keep customer service work centralized, traceable, and easier to manage.

---

## Main User Types

### Guest

A guest is a user who opens the app without login or signup.

Guests can:

- Open the app
- Browse public services
- View service details
- Read knowledge/news content
- Use the tax calculator
- View support/contact information
- Go to login or signup

Guests cannot:

- Create service requests
- Upload documents
- View customer dashboard
- Track personal service cases
- View payments
- Create customer-specific support tickets
- Access internal workspace

### Customer / Applicant

A customer/applicant is a user who signs up and creates an OMC profile.

After signup, the user is placed under review:

```text
customer_status = Pending
approval_status = Pending Review
```

Until OMC approves the profile, the user has limited access. Protected customer features remain locked.

### Approved Customer

An approved customer is a verified user whose backend profile is active and approved.

Approved customers can:

- View dashboard
- Create service requests
- Upload documents
- Track service progress
- View payment dues/status
- Upload payment receipts when enabled
- Receive notifications
- Create support tickets
- Use profile/settings
- Use tax calculator and expense tracker
- Read knowledge/news content

### Admin / OMC Staff

Admin/staff users work from the internal side. Depending on assigned role, staff can:

- Review customer/applicant profiles
- Approve or manage customers
- Manage service requests
- Update service status
- Review documents
- Review payments/receipts
- Reply to support tickets
- Manage leads
- Manage tasks
- View internal workspace summaries

Internal access is role-based and protected from the backend, not only hidden from the app UI.

---

## Guest Workflow

1. Open the app.
2. Continue as Guest.
3. Browse the home/public app areas.
4. View available OMC services.
5. Open service details and required document information.
6. Read knowledge/news/help content.
7. Use the tax calculator.
8. Open support/contact information.
9. When trying a locked feature, the app asks the user to login/signup.
10. User creates an account or logs in.

Guest locked message example:

```text
Please create an account or subscribe to access this feature.
```

---

## Customer Workflow

1. Open the app.
2. Tap signup.
3. Enter name, email, mobile, WhatsApp, CNIC, address, password, and register-as type.
4. Select register-as type:
   - Customer
   - Consultant
   - Business Partner
   - Tax Associate
5. Submit signup.
6. Backend creates or updates:
   - Frappe User
   - OMC Customer Profile
   - Customer preferences
7. Profile is marked as pending review.
8. User logs in.
9. If profile is still pending, the app shows limited access/under-review state.
10. OMC team reviews the profile in backend.
11. OMC team approves the customer.
12. Customer logs in again or refreshes session.
13. Approved customer sees dashboard and unlocked customer features.
14. Customer selects a service.
15. Customer creates a service request.
16. Customer uploads required documents.
17. Customer tracks request progress from Track/My Services.
18. OMC staff updates request status from backend/internal side.
19. Customer receives timeline/notification updates.
20. If payment tracking is enabled, customer views payment due/instructions.
21. Customer uploads payment receipt/proof.
22. OMC staff reviews receipt and updates payment status.
23. Customer contacts support if help is needed.
24. Service is completed and history remains available.

---

## Admin / Staff Workflow

1. Staff user logs in.
2. Backend checks assigned roles and capabilities.
3. Staff opens internal workspace or Frappe backend.
4. Staff reviews new customers/applicants.
5. Staff approves, rejects, or keeps profiles pending.
6. Staff reviews open service requests.
7. Staff updates service status and timeline.
8. Staff reviews uploaded documents.
9. Staff approves/rejects document records.
10. Staff reviews payment receipt submissions.
11. Staff marks payment status as under review, paid, rejected, or cancelled.
12. Staff handles support tickets and replies.
13. Staff manages leads and follow-up tasks.
14. Customer sees updated status from the app.

---

## Feature-by-Feature Guide

### Home

Home is the main entry point. It gives customers quick access to services, tracking, documents, payments, knowledge, support, profile, and settings.

For guests, Home acts as a public preview area. For approved customers, it becomes a customer dashboard shortcut area.

### Services

Services shows OMC service catalogue cards. Services are intended to be backend-driven through `OMC Service` records so OMC staff can manage service titles, categories, descriptions, pricing labels, completion times, required documents, and active/inactive status from backend.

Customer flow:

1. Open Services.
2. Select a service.
3. Read service details.
4. Check fee/completion/document information.
5. Create service request if approved.

Guest flow:

1. Open Services.
2. Browse public service information.
3. Open service detail.
4. Login/signup if trying to create a request.

### Dashboard

Dashboard is for approved customer data. It shows customer-related service, document, payment, notification, and activity summaries where data exists.

Pending users and guests should not get full customer dashboard access.

### Track / My Services

Track/My Services lets approved customers see their submitted service requests.

Typical statuses/progress:

| Status | Approx. Progress |
|---|---:|
| Open | 10% |
| Waiting for Customer | 35% |
| In Progress | 60% |
| Under Review | 80% |
| Completed | 100% |
| Cancelled | 0% |

Customer can open a service case detail page to view status, progress, required/missing documents, timeline, next step, and customer action required.

### Documents

Documents stores and tracks customer/service documents.

Document states can include:

- Pending
- Uploaded
- Approved
- Rejected

Upload flow:

1. Customer selects document/file.
2. App uploads file through Frappe upload.
3. Backend links file to service/document record.
4. OMC staff reviews the document.
5. Customer sees updated status.

Supported document upload types are intended to include common business files such as PDF, JPG, JPEG, PNG, DOC, and DOCX, with private file handling and size/file count limits controlled by backend rules.

### Payments

Payments is not a direct payment gateway by default. It is primarily for payment due/status and receipt/proof tracking.

Flow:

1. OMC staff creates payment/due record against a service request.
2. Customer views payment instruction/status in app.
3. Customer uploads receipt/proof if enabled.
4. Receipt status becomes submitted/under review.
5. OMC staff reviews receipt.
6. Staff marks payment as paid, rejected, under review, or cancelled.
7. Customer sees latest payment status.

If OMC does not want payment tracking active, the payment module can be hidden or disabled cleanly.

### Knowledge & News

Knowledge/news is public content for customers and guests. It can be used for:

- Tax guides
- Service explanations
- FBR/tax updates
- Announcements
- FAQs
- Help articles

The intended direction is backend-driven content so OMC can update articles without rebuilding the app.

### Tax Calculator

Tax Calculator is a public utility. Guests and customers can use it for quick estimates.

Important note: calculator results are estimates only. Final tax filing/advice should be verified by OMC or a qualified tax professional.

### Personal Expense Tracker

Expense Tracker is a customer utility for tracking personal income, expenses, categories, and summaries.

Typical actions:

- View expense categories
- Add income/expense entry
- Update entry
- Delete entry
- View income/expense/balance summary

### Support

Support helps users contact OMC.

Guest support:

- View support/contact channels
- View public help topics/FAQs where available

Approved customer support:

- Create support ticket
- Select topic/priority
- View ticket list/detail
- Add replies
- Track ticket status

Staff support:

- View ticket queue
- Reply/update ticket
- Mark status such as Open, Waiting for Customer, Resolved, Closed, or Cancelled

### Profile

Profile shows customer information such as:

- Full name
- Email
- Phone
- WhatsApp number
- Company name
- CNIC
- NTN
- Register-as type
- Customer status
- Approval status

Customers can update allowed profile/contact fields.

### Settings

Settings stores customer preferences such as:

- Service updates
- Document reminders
- Payment alerts
- Tax alerts
- Email notifications
- WhatsApp notifications
- Theme
- Language

Settings are linked to the customer profile and saved in backend preferences.

### Notifications

Notifications show service, document, payment, support, or general updates.

Customers can:

- View notification list
- Open detail
- Mark one notification as read
- Mark all notifications as read

### Internal Workspace

Internal Workspace is only for staff/internal roles.

It can show:

- Leads
- Customers
- Tasks
- Open services
- Support tickets
- Documents
- Payments due
- Unread notifications

Normal customers should not see or access internal workspace data.

---

## Full 0-to-100 Business Flow

```text
Guest opens app
  -> Browses public services/content
  -> Uses tax calculator/support contact
  -> Tries locked customer action
  -> Signup/login prompt
  -> User signs up
  -> Backend creates pending OMC Customer Profile
  -> OMC team reviews profile
  -> OMC team approves user
  -> Customer gets full access
  -> Customer creates service request
  -> Customer uploads required documents
  -> OMC team processes service case
  -> OMC team updates status/timeline
  -> Customer tracks progress
  -> Payment due/receipt tracking if enabled
  -> Customer uploads receipt/proof
  -> OMC team reviews payment
  -> Customer receives notifications
  -> Support ticket if needed
  -> Service completed
```

---

## Common Scenarios

### Scenario 1: Guest wants to request a service

The guest can view services and service details. When the guest tries to create a service request, the app should ask the user to login/signup. Service request creation requires an approved customer profile.

### Scenario 2: New signup tries to use full app immediately

The user can log in, but protected customer features remain blocked until OMC approves the profile. The app shows an under-review message.

### Scenario 3: Customer uploads wrong document

OMC staff can reject the document from backend/internal side. Customer should see rejected status and upload the corrected document if allowed.

### Scenario 4: Payment receipt is submitted

Customer uploads receipt/proof. OMC staff reviews it. Payment status changes to under review, paid, rejected, or cancelled based on backend decision.

### Scenario 5: Customer needs help

Customer opens Support, creates ticket, and follows replies/status from ticket detail.

### Scenario 6: Staff user opens internal workspace

Backend checks the staff role. If allowed, staff sees internal modules. If not allowed, access is blocked.

---

## Troubleshooting

### Wrong email or password

Check that the email/password are correct and the backend is reachable. The app should show a clean error and should not crash.

### Signup done but features still locked

This is expected if the profile is still pending. OMC team must approve the profile in backend before full customer features unlock.

### Service catalogue not loading

Possible causes:

- Backend is not running
- App is pointing to the wrong backend URL
- Service records are missing/inactive
- Network/CORS configuration issue

### Cannot create service request

Possible causes:

- User is Guest
- User is Pending Review
- User is not approved
- Backend permission check blocked the action
- Selected service is invalid/inactive

### Document upload failed

Possible causes:

- File type is not allowed
- File is too large
- User is not approved
- Backend upload endpoint is not reachable
- Service request/document record is invalid

### Payment upload not available

Possible causes:

- Payment feature is disabled
- No payment record exists for the service request
- User is not approved
- Backend receipt upload permission blocked it

### Internal workspace not visible

Possible causes:

- User is not an internal/staff user
- Required OMC staff role is missing
- Backend capability response does not allow internal access
- Internal workspace feature/config is disabled

---

## FAQs

### Is this app only for customers?

No. It has customer-facing features and internal/staff workflow foundations.

### Can a guest use the app?

Yes. Guests can browse public services, knowledge/news, support contact information, and tax calculator. Sensitive customer features require login and approval.

### Does signup immediately approve the customer?

No. Signup creates a pending profile. OMC team reviews and approves the user from backend.

### Can a pending user create service requests?

No. Pending users have limited access until approved.

### Can consultants, business partners, or tax associates sign up?

Yes. They can select their register-as type during signup, but access should be approved and role-controlled by OMC.

### Does the payment module collect money directly?

Not by default. The current business model is payment due/status and receipt/proof tracking. Direct payment gateway collection can be added later if required.

### Are documents public?

No. Uploaded customer/service documents should be treated as private and linked to the correct service/customer records.

### Can customers see internal staff data?

No. Internal workspace and internal actions are role-gated from the backend.

### Can OMC update services without app update?

Yes, the intended design is backend-driven service catalogue management through Frappe DocTypes.

### What is the main business value?

Customers get a clear app-based service journey, and OMC gets centralized service requests, customer profiles, documents, payments, support, and follow-up operations.
