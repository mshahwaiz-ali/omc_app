# OMC App — Complete Feature Catalogue

This document lists the features currently present in the OMC App project in simple, non-technical language.

It is based on the current Flutter app routes, screens, repositories, backend workflows, permissions, and project documentation. Features that are not present in the source code are not included.

Last source cross-check: **3 August 2026**.

> **Important distinction:** a feature is listed as implemented only when an app or backend path exists for it. Hardware-dependent behaviour, external delivery services, and production deployment are called out separately where they still require environment or real-device verification.

---

## 1. App Entry and General Experience

- Branded splash screen
- First-time onboarding screens
- Guest access without creating an account
- Role-aware home screen
- Different app experience for:
  - Guests
  - Customers waiting for approval
  - Approved customers
  - OMC internal staff
- Bottom navigation for main areas
- “More” menu for secondary features
- Safe back navigation
- App links for email verification and password-reset entry
- Friendly recovery screen for broken or unavailable routes
- Access-denied notice when a user opens a restricted page
- Loading states and skeleton screens
- Empty-state messages when no records are available
- Retry actions when data fails to load
- User-friendly error messages instead of technical errors
- Duplicate-tap protection for important actions
- Protection against submitting the same form multiple times
- Responsive layouts for mobile screens
- Modern cards, filters, tabs, dialogs, sheets, and action menus

---

## 2. Login and Account Access

- Login using:
  - Email
  - Username
  - Mobile number
  - CNIC
- Password-based sign-in
- Show or hide password
- Keyboard submit support
- System password autofill support
- Secure session storage on the device
- Session restoration when the app is reopened
- Automatic routing after login
- Pending customers are sent to the approval-review screen
- Approved users are sent to the main app
- Continue as guest option
- Helpful login error messages
- Duplicate login attempt prevention
- Login help sheet
- OMC support email shown on login
- OMC phone or WhatsApp contact shown on login
- OMC business hours shown on login
- Logout from the main app
- Logout from settings
- Logout duplicate-action protection
- Session cleanup on logout
- Failed logout recovery message
- Optional device lock for an already signed-in session
- Fingerprint, Face ID, or the device credential can unlock the app where the operating system supports it
- Device-lock setting stored in encrypted device storage
- Device lock re-engages when the app is paused, hidden, or moved to the background
- Locked screen with a manual retry action when authentication is cancelled or fails
- Unsupported or unconfigured device authentication is detected without enabling the lock
- Device lock is removed during logout and session cleanup

> Device lock protects a restored signed-in session; it is not a replacement for the initial OMC username/password login. There is no separate “Remember password” switch.

---

## 3. Signup and Registration

- Multi-step signup process
- Account type selection
- Supported signup roles:
  - Customer
  - Consultant
  - Business Partner
  - Tax Associate
- Full-name field
- Email field
- Username field
- Mobile number field
- WhatsApp number field
- “WhatsApp same as mobile” option
- CNIC field
- Address field
- Education details
- Experience details
- Additional remarks
- Password field
- Confirm-password field
- Show or hide both password fields
- Terms and conditions acceptance
- Username formatting
- Automatic username suggestion
- Live username availability check
- Prevention of already-used usernames
- Signup input validation
- Duplicate signup prevention
- Signup success state
- Signup failure recovery
- Verification email sent immediately after an eligible registration starts
- Verification email contains app and browser-compatible verification paths
- Browser verification redirects the user back to the app login state when the custom app scheme is available
- Invalid or expired verification links return a safe failure state
- Resend cooldown and verification-token rotation
- Account approval workflow after registration

---

## 4. Referral During Signup

- Referral acquisition-source option
- Referral code field
- Referral code normalisation
- Referral code validation
- Invalid or inactive referral warning
- Referral assistance consent
- Referral source details
- Other acquisition sources:
  - Website
  - Social media
  - Advertisement
  - Existing customer
  - Event
  - Other

---

## 5. Email and Password Recovery

- Forgot-password screen
- Password reset request
- Reset-password screen
- Reset token support
- Email verification screen
- Verification-token support
- Resend or retry behaviour where supported
- Change-password screen for signed-in users
- Password validation
- Friendly failure messages
- Safe routing between login, verification, reset, and home screens

---

## 6. Customer Approval and Account Status

- Pending-review screen
- Clear account review status
- Approval-status messaging
- Retry account-status check
- Contact support while waiting
- Logout from the review screen
- Failed logout recovery
- Approved-customer access activation
- Guest-safe access while full features remain locked
- Backend-controlled approval status

---

## 7. Role and Permission System

- Guest access rules
- Pending-customer access rules
- Approved-customer access rules
- Internal-staff access rules
- Capability-based navigation
- Capability-based buttons and actions
- Route-level access checks
- Backend-level permission enforcement
- Ownership-based customer data access
- Assignment-based internal data access
- Fail-closed behaviour for unknown protected routes
- Effective capability authority shared across routing and navigation
- Profile capabilities used when available
- Session capabilities used as a safe fallback
- Restricted internal tools hidden from customers
- Restricted customer tools hidden from internal users where appropriate

Supported internal roles include:

- OMC Admin
- OMC Manager
- OMC Support Agent
- OMC Document Reviewer
- OMC Finance Reviewer
- OMC Consultant
- OMC Tax Associate
- OMC Business Partner

---

## 8. Home Dashboard

### Customer and Guest Home

- Time-aware welcome area
- Personalised customer greeting
- Guest welcome experience
- Quick access to services
- Quick access to tracked requests
- Quick access to documents
- Quick access to support
- Quick access to tax tools
- Quick access to expense tools
- Notifications shortcut
- Profile shortcut
- Current account or approval status
- Service-request summaries
- Outstanding-action summaries
- Data-loading error feedback
- Retry support for failed dashboard sections

### Internal Staff Home

- Internal operations overview
- Role-aware work shortcuts
- Assigned work summaries
- Customer queues
- Service-case queues
- Document-review queues
- Payment-review queues
- Lead shortcuts
- Task shortcuts
- Support shortcuts
- Capability-aware visibility
- Failure notices and retry actions

---

## 9. Service Catalogue

- Browse available OMC services
- View active service categories
- Search services
- Filter service catalogue
- Public service browsing for guests
- Service cards with useful summary information
- Service-detail page
- Service description
- Service requirements
- Required-document information
- Service instructions
- Service pricing information where configured
- Service availability checks
- Start-service-request action
- Login or approval prompts when required
- Backend-managed catalogue content
- Inactive services hidden from public request creation

---

## 10. Service Request Creation

- Start a request from a service
- Compact service-request form
- Request title
- Request description
- Contact phone
- Contact email
- Priority selection where supported
- Customer and internal assisted-request modes
- Required-field validation
- Access and approval checks
- Active-service validation
- Existing active request warning
- Resume an existing request
- Start a new request when allowed
- Request draft flow
- Attachment selection
- Document upload support
- Safe request submission
- Duplicate submission prevention
- Submission loading indicator
- Friendly submission failure message
- Navigation to the created request

---

## 11. Service Request Tracking

- “My Services” or tracking screen
- Customer-owned request list
- Request-status filters
- Request progress display
- Current stage
- Next required action
- Request timeline
- Assigned staff information where allowed
- Service information
- Request details
- Required-document status
- Payment status
- Customer assistance details
- Open individual case details
- Retry failed case loading
- Cancel eligible service requests
- Cancellation confirmation
- Cancellation duplicate-action protection
- Cancellation success and failure feedback
- Start another request when appropriate

---

## 12. Automated Service Workflow

- Automatic assignee resolution
- Referral-owner assignment where valid
- Service-default assignee support
- Role-based fallback assignment
- Least-loaded eligible staff selection
- Manager fallback assignment
- Duplicate-safe internal ToDo creation
- Assigned-staff notification
- Customer-visible progress updates
- Audit timeline entries
- Request movement to “Waiting for Customer”
- Request movement to “Waiting for Payment”
- Request movement to “In Progress”
- Request completion checks
- Open task closure during completion
- Completion date recording
- Customer completion notification
- Prevention of completion while blockers remain

---

## 13. Documents

### Customer Documents

- View document list
- Open document details
- View required documents for a service request
- Select files from the device
- Upload PDF and image files
- Upload supported office-document files where enabled
- File-size validation
- Empty-file validation
- Missing-file-data validation
- Upload progress state
- Prevent duplicate upload taps
- Replace or re-upload rejected documents
- View document status
- View rejection remarks
- View re-upload instructions
- Link documents to the correct service request
- Protection against cross-request file reuse

### Internal Document Review

- Internal document-review queue
- Filter documents needing review
- Filter by service request
- Open linked service case
- Open document detail
- Approve document
- Reject document
- Add rejection reason
- Add re-upload instruction
- Review loading state
- Duplicate-review prevention
- Reviewer permission checks
- Friendly review failure message
- Automatic request-state update after rejection
- Automatic payment-eligibility check after all required approvals

---

## 14. Payments and Receipts

### Customer Payments

- Payment list
- Payment-detail screen
- Payment amount
- Currency
- Payment status
- Payment instructions
- Receipt status
- Submit payment receipt
- Replace rejected receipt where allowed
- View finance-review state
- Customer-only payment ownership

### Internal Payment Review

- Finance-review queue
- View customer payment context
- View submitted receipt
- Review receipt
- Mark payment paid
- Mark payment rejected
- Mark payment under review
- Role-specific receipt visibility
- Duplicate active-payment prevention
- Automatic payment creation after required documents are approved
- Automatic request-status updates after payment review
- Notifications to Finance Reviewers, Managers, and assigned staff
- Protection against zero or missing service prices

---

## 15. Customer Management

- Internal customer list
- Customer search
- Customer filters
- Customer-detail page
- Customer profile information
- Contact details
- Approval information
- Linked service requests
- Linked documents
- Linked payments
- Referral relationship information where available
- Capability-based customer access
- Restricted customer records hidden from unauthorised staff

---

## 16. Leads and Sales Tracking

- Lead list
- Lead-detail page
- Create lead action
- Lead search and filters
- Lead status tracking
- Lead source information
- Lead contact information
- Lead notes and details
- Internal lead management
- Support-agent and manager access where authorised
- Capability-based lead visibility
- Safe loading and error handling

---

## 17. Tasks and Internal Work

- Task list
- Task-detail page
- Assigned-task view
- Task status
- Task priority
- Due date information
- Linked customer or service context
- Assignment-scoped access
- Internal-user validation before assignment
- Retry failed task loading
- Task completion and update flows where authorised
- Update operational task states through the allowed OMC status list
- “Submitted by QC” completion path for eligible tasks
- Transaction-safe closing of only the ToDos linked to the exact ERP Task
- Rollback protection if ERP Task completion fails
- Assign or reassign a task to an eligible active System User
- Close replaced open assignments during reassignment
- Update task priority and expected completion date
- Keep linked service-request planning fields aligned where configured
- Duplicate-safe no-change responses for repeated status or assignment actions
- Capability-based task access

---

## 18. Internal Operations Workspace

- Dedicated internal workspace
- Service-case operations
- Customer operations
- Document operations
- Payment operations
- Internal service-case detail workspace
- Role-specific queues
- Capability-specific actions
- Assigned-work filtering
- Operational summaries
- Access-denied protection
- Backend-authorised mutations
- Separation between document and finance responsibilities
- Manager and admin oversight
- Searchable and paginated operational queues
- Server-side payment status filtering and search
- Authenticated private receipt opening and sharing

### Admin Control and Recovery Operations

- Pending registration review
- Approve or reject registrations with the appropriate decision context
- Invite internal staff
- Grant only supported OMC staff roles
- Edit staff roles
- Enable or disable eligible staff accounts
- View and update guarded business settings
- Reassignment queue for service cases
- Load eligible assignee options before reassignment
- Require and record a reassignment reason
- Exhausted ERP-sync recovery queue
- Inspect sync status, last error, and retry count
- Retry only eligible failed or exhausted service synchronisations
- Pending-discount review queue
- Review original price, proposed final price, discount type, value, amount, and reason
- Approve or reject a discount
- Require remarks when rejecting a discount
- Capability-specific access to each administration queue
- Focused refresh of cases, tasks, payments, documents, dashboards, and admin data after a successful operation

---

## 19. Notifications

- Notification list
- Notification-detail screen
- Unread notification count
- All-notifications filter
- Unread-only filter
- Open notification-linked content
- Mark notification as read
- Mark a notification as unread
- Mark all as read where supported
- Swipe or dismiss notification behaviour
- Clear-notification confirmation feedback
- Undo cleared notification
- Restore dismissed notification
- Per-notification duplicate-action protection
- Refresh notifications
- Ownership-safe customer notifications
- Backend-generated workflow notifications
- Internal assignment notifications
- Document-review notifications
- Payment-review notifications
- Completion notifications
- Reminder and escalation notifications
- Push-token registration and unregistration contracts
- Notification-category preference enforcement where applicable

> The current app includes in-app notifications. Device-level Firebase/APNs push notification delivery is not confirmed in the current source.

---

## 20. Support Centre

### Customer Support

- Support home screen
- Create support ticket
- Support topic or category selection
- Subject
- Message
- Submit-ticket loading state
- Duplicate submission prevention
- Support-ticket list
- Open ticket detail
- Conversation-style ticket messages
- Send a reply
- Reply with text only
- Reply with attachment only
- Reply with text and attachment
- PDF, image, DOC, and DOCX attachment support
- Attachment-size validation
- Keep reply text and attachment after a failed send
- Retry sending after upload failure
- Closed-ticket restrictions
- Ticket-status display
- OMC contact details

### Internal Support

- Internal support queue
- Reply to customer tickets
- Capability check for ticket replies
- Update ticket status
- Status-selection sheet
- Duplicate status-update protection
- Open customer or service-request context
- Support failure recovery

---

## 21. Knowledge, FAQs, and Content

- Knowledge article list
- Knowledge article detail
- Search or browse customer information
- FAQs
- Announcements
- Onboarding content
- Contact information
- Public customer-safe content
- Backend-managed content
- Separation of public and internal content
- External link opening where configured

---

## 22. Tax Calculator

- Public tax calculator
- Guest access
- Approved-customer access
- Tax-year selection
- Income-type selection
- Filer-status selection
- Income-mode selection
- Income amount entry
- Advanced tax inputs
- Input validation
- Protection against negative or malformed amounts
- Tax calculation result
- Calculation breakdown
- Filer versus non-filer comparison where returned by the backend
- Backend-authored tax insights
- Tax-readiness/health result where configured
- Recommended next steps
- Tax calculation history
- Open previous calculation
- Start a linked tax service from a saved calculation when permitted and configured
- Backend-controlled tax slabs
- Supported-year handling
- Safe error feedback

---

## 23. Expense Tracker

### Transactions

- Personal income tracking
- Personal expense tracking
- Add transaction
- Edit transaction
- Archive transaction
- Clear local tracker
- Transaction date
- Amount
- Income or expense type
- Category
- Account
- Payment method
- Merchant
- Notes
- Tax-relevant flag
- Business-expense flag
- Recurring flag
- Reimbursable flag
- Receipt attachment
- Local guest mode
- Pending-customer local mode
- Approved-customer cloud mode
- Local-to-cloud synchronisation
- Manual cloud sync
- Refresh local data
- Load cloud data
- Duplicate-save prevention
- Save progress indicator
- Persistence-first save behaviour
- Archive confirmation
- Clear-data confirmation
- Success feedback
- Failure feedback without false data removal
- Import backup JSON
- Export backup JSON
- Import validation
- Import progress state
- Duplicate-import prevention
- Import success only after data is saved

### Expense Views and Insights

- Current-month balance
- Total income
- Total expenses
- Transaction count
- This-month filter
- Last-month filter
- All-time filter
- Category summaries
- Tax-relevant total
- Business-expense total
- Receipt count
- Recurring-entry count
- Tax-readiness score
- Tax-readiness label
- Quick-add categories
- Empty-period message

---

## 24. Expense Budget

- Expense-budget screen
- Budget threshold setup
- Validated budget values
- Expense-to-budget comparison
- Budget progress visualisation
- Budget-related customer guidance
- Customer-owned budget data

---

## 25. Profile

- Profile screen
- Personal information
- Contact information
- Business information
- Account status
- Customer status
- Approval status
- Role information
- Edit-profile screen
- Update personal details
- Update contact details
- Update business details
- Protected profile updates
- Account email protected from profile-edit changes
- Profile loading state
- Profile update feedback
- Canonical backend profile authority

---

## 26. Referrals

- “My Referrals” screen
- Referral list
- Referral-detail screen
- Referral customer name
- Referral customer profile link
- Referral status information
- Referral code used during signup
- Referral-code validation
- Referral-owner service assignment where configured
- Referral assistance consent
- Capability-aware access

---

## 27. Settings

- Settings screen
- Profile-preferences shortcut
- Security shortcut
- Change-password shortcut
- Logout
- Delete-account request
- Account-support request forms
- App preferences
- Preference save protection
- Preference failure recovery
- Privacy-policy access
- Terms and conditions access
- App version information
- Backend-driven legal text or URLs
- Retry failed settings loading
- Safe external-link opening

---

## 28. Account Requests

- Delete-account request
- Reason or instructions field
- Submit request to OMC
- Duplicate request prevention
- Success feedback
- Failure feedback
- Support-based account processing rather than unsafe instant deletion

---

## 29. Data Safety and Reliability

- Secure session storage
- Backend-first authentication
- Backend-first authorisation
- CSRF-aware API communication
- Ownership checks
- Assignment checks
- Capability checks
- Input-length limits
- Numeric-value validation
- File-type validation
- File-size validation
- Bulk-operation limits
- Duplicate request prevention
- Duplicate payment prevention
- Duplicate ToDo prevention
- Duplicate notification prevention
- Duplicate button-tap prevention
- Mounted-state safety after async actions
- Persistence-first local data changes
- Friendly retry states
- Safe fallback when profile capabilities cannot load
- Fail-closed protected routes
- Sensitive files excluded from source control

### Deliberate Fallback and Recovery Behaviour

- Offline, timeout, unauthorised, forbidden, missing-record, configuration, validation, server, malformed-response, and unknown failures are converted into user-safe messages
- Retry is offered only where repeating the action is meaningful
- Session expiry returns the user to authentication instead of exposing protected screens
- Unknown authenticated routes fail closed
- Broken back-stack navigation uses a safe route fallback
- App branding, legal text, support channels, and application configuration have packaged safe defaults
- Onboarding uses packaged slides if backend content is unavailable or empty
- Mobile quick actions use capability-filtered packaged defaults when backend actions are unavailable
- Profile identity can fall back to the authenticated user ID while protected profile data remains unavailable
- Service templates fail soft: the base backend service remains usable if optional template enrichment fails
- Development can explicitly enable local service preview or catalogue fallback; production never substitutes fake catalogue data
- Empty backend catalogues remain honest empty states rather than fabricated services
- Guest and pending-user expense records remain local; approved-customer records use guarded cloud APIs
- Expense import reports success only after local persistence succeeds
- Clearing the expense tracker removes local cache only and does not claim to delete cloud records
- Failed support replies retain the selected attachment reference and message for retry where possible
- Failed uploads, reviews, mutations, and settings changes do not show false success
- Images and avatars have visual placeholders when remote assets fail
- Partial internal-dashboard queue failures show unavailable indicators instead of misleading zero counts

---

## 30. Backend Automation and Reminders

- Hourly unreviewed-document checks
- Hourly pending-receipt-review checks
- Hourly unassigned-request alerts
- Daily waiting-for-customer reminders
- Daily waiting-for-payment reminders
- Daily overdue escalation
- Notifications to assigned staff
- Notifications to managers and admins
- Notification deduplication window
- Human approval required for documents
- Human approval required for payment receipts
- Automatic workflow movement only after authorised decisions

---

## 31. Technical Platform Capabilities

- Flutter mobile application
- Android application support
- Flutter web build support
- iOS-compatible Flutter codebase
- Frappe Framework backend
- REST and whitelisted API integration
- Riverpod state management
- GoRouter navigation
- Dio networking
- Flutter Secure Storage
- Shared Preferences
- File Picker
- Image Picker
- Cached network images
- Charts
- URL launcher
- Share support
- Local OS authentication through `local_auth`
- Fingerprint, Face ID, and device-credential session lock support
- Android biometric permission
- iOS Face ID usage declaration
- `omchouse://auth/...` custom-scheme authentication links
- Backend DocTypes
- Backend permission hooks
- Backend scheduled jobs
- Production nginx and Supervisor deployment support

---

## 32. Features Not Confirmed in Current Source

The following should not be presented as completed features unless they are added later:

- Passwordless fingerprint or Face ID login to the OMC backend (the implemented biometric feature is a local post-login device lock)
- A separate “Remember password” toggle
- Production Google sign-in (the current backend explicitly rejects it until verified token validation is configured)
- Firebase Cloud Messaging push notifications
- Apple Push Notification Service integration
- In-app payment gateway or card charging
- Real-time chat through sockets
- Offline synchronisation for every module
- Fully offline service, document, payment, support, tax, or staff workflows
- A customer-facing tax-estimate PDF download/share screen (repository/backend contracts alone are not presented as a completed UI feature)

---

## Summary

OMC App is a role-aware customer service and internal operations platform. It combines customer onboarding, service discovery, request processing, document collection, payments, referrals, support, notifications, tax tools, expense management, customer management, leads, tasks, and internal review workflows in one Flutter application backed by Frappe.

The app keeps the customer experience simple while the backend controls ownership, permissions, approvals, assignment, workflow automation, and audit-safe operations.
