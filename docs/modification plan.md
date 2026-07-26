# OMC App Referral & Assisted Service Request Plan

## 1. Objective

OMC App mein secure referral and assisted-service system add karna hai jahan:

* Har eligible internal staff user ka unique referral code ho.
* Customer signup ke waqt referral source capture ho.
* Referral code use hone par customer automatically referrer ke saath link ho.
* Internal staff customer ka password use kiye baghair uske behalf par service request create kar sake.
* Service request customer ki app mein bhi exactly normal request ki tarah show ho.
* Authorised internal users same request ko track, update aur manage kar saken.
* Walk-in/non-app customers ke liye bhi service request create ki ja sake.
* Har action role-based, consent-based aur audit logged ho.

---

# 2. Core Business Scenarios

Internal service request create karte waqt three customer modes available honge.

## Mode A — My Referrals

Current logged-in internal user sirf apne referral code se linked customers ko select karega.

Flow:

1. Staff service select kare.
2. `Start for Customer` choose kare.
3. `My Referrals` select kare.
4. Apne referred customers mein search kare.
5. Customer select kare.
6. Customer profile data request form mein auto-fill ho.
7. Staff request submit kare.
8. Request customer aur referrer dono ko accessible ho.

Access:

* Referral owner
* Assigned authorised staff
* Admin/manager
* Customer himself

---

## Mode B — Existing Customer

Authorised senior internal staff system ke kisi existing registered customer ke behalf par request create kar sakega.

Flow:

1. Staff `Existing Customer` select kare.
2. Search by name, CNIC, mobile, email or customer ID.
3. Customer profile select kare.
4. Available customer data auto-fill ho.
5. Request selected customer ke account ke against create ho.
6. Customer ko request app mein show ho.
7. Request creator and authorised staff usay manage kar saken.

Access restriction:

* Basic referral staff ko all-customer access nahi milega.
* Sirf capability wale roles use kar saken:

  * System Manager
  * OMC Admin
  * OMC Manager
  * Selected consultants or authorised staff

---

## Mode C — New / Walk-in Customer

Internal staff kisi aise person ke liye request create karega jo abhi app user nahi hai.

Flow:

1. Staff `New / Walk-in Customer` select kare.
2. Manual customer information enter kare:

   * Full name
   * CNIC
   * Mobile
   * Email
   * Address
   * City
   * Optional notes
3. System manual customer profile or prospect record create kare.
4. Service request us record se link ho.
5. Staff request track and manage kare.
6. Future mein customer signup kare to existing manual profile ko verified identity ke through app account se link kiya ja sake.

This mode relevant internal staff ke liye available hoga, subject to permissions.

---

# 3. Referral Code System

## 3.1 Referral Code Ownership

Har eligible internal staff profile mein fields add hongi:

* `referral_code`
* `referral_enabled`
* `referral_code_created_at`
* `referral_code_last_regenerated_at`
* `referred_customer_count`
* `converted_referral_count`
* optional `referral_status`

Referral code:

* Unique hoga.
* Uppercase hoga.
* Human-readable hoga.
* Case-insensitive validation use karega.
* Direct database uniqueness constraint hogi.
* User email/name expose nahi karega.

Example format:

```text
OMC-A7K9Q2
```

Code predictable employee ID ya username par directly based nahi hona chahiye.

---

## 3.2 Referral Code Generation

Code automatically generate hoga jab:

* eligible internal profile create ho;
* referral capability enable ho;
* existing internal profiles migrate hon.

Rules:

* Secure random generation
* Collision check
* Maximum retry limit
* Unique database index
* Disabled user ka code reject ho
* Deactivated code new signup ke liye use na ho

Admin optionally code regenerate kar sake, lekin old referral relationships preserve rahengi.

---

## 3.3 Referral Code Display

Internal user's app profile mein dedicated section:

### My Referral Code

Display:

* Referral code
* Copy button
* Share button
* Active/inactive badge
* Total referrals
* Optional converted customers
* Optional referral service-request count

Sensitive customer list profile summary mein expose nahi hogi. Customer details separate authorised screen mein hongi.

---

# 4. Signup Source Capture

Signup form mein new section add hoga:

## How did you hear about OMC?

Options:

* Referral
* Website
* Social Media
* Advertisement
* Existing Customer
* Event / Seminar
* Other

Backend values standardised enum honge.

Suggested values:

```text
Referral
Website
Social Media
Advertisement
Existing Customer
Event
Other
```

---

## 4.1 Conditional Referral Field

Agar user `Referral` select kare:

* Referral code field show ho.
* Code uppercase transform ho.
* Leading/trailing spaces remove hon.
* Submit se pehle backend validation ho.
* Valid code par minimal confirmation show ho:

```text
Referral code verified.
```

Referrer ka full internal profile, staff list, email ya other private details customer ko show nahi kiye jayenge.

Optional safe confirmation:

```text
Referred by an authorised OMC representative.
```

---

## 4.2 Other Source Detail

Agar user `Other` select kare:

* `Please specify` text field show ho.

Additional fields:

* `acquisition_source`
* `acquisition_source_detail`
* `submitted_referral_code`

---

# 5. Referral Consent

Signup par referral-related consent checkbox add hoga.

Suggested wording:

```text
I allow my assigned OMC representative to assist with service requests, upload required information, and view the progress of services handled on my behalf.
```

Consent mandatory sirf tab ho jab:

* referral code provided ho; or
* assisted-service relationship activate karni ho.

Store:

* `referral_assistance_consent`
* `referral_consent_timestamp`
* `referral_consent_version`
* `referral_consent_ip` where appropriate
* `referral_consent_user_agent` where appropriate

Customer later profile/settings se assistance access revoke kar sakega.

Revocation ke baad:

* Referrer new request customer ke behalf par create nahi kar sakega.
* Existing cases mein access policy configured rule ke mutabiq restricted hogi.
* Admin compliance or operational access preserve reh sakta hai.
* Historical audit records delete nahi honge.

---

# 6. Data Model

## 6.1 New DocType — OMC Referral

Recommended separate DocType:

### `OMC Referral`

Fields:

* `referral_code`
* `referrer_user`
* `referrer_employee_profile`
* `referred_customer_profile`
* `referred_app_user`
* `source`
* `status`
* `consent_granted`
* `consent_timestamp`
* `signup_date`
* `approved_date`
* `converted_date`
* `revoked_date`
* `notes`
* `is_active`

Status examples:

```text
Registered
Pending Review
Approved
Converted
Inactive
Revoked
```

Purpose:

* Referral relationship history
* Reporting
* Reassignment
* Commission support later
* Consent tracking
* Audit-safe historical data

---

## 6.2 Internal Profile Fields

Relevant internal staff profile/employee mapping mein:

* `referral_code`
* `referral_enabled`
* `can_manage_own_referrals`
* optional `referral_team`
* optional `referral_manager`

Code ownership should map to an internal app identity, not only display name.

---

## 6.3 Customer Profile Fields

Customer profile mein:

* `acquisition_source`
* `acquisition_source_detail`
* `referral_record`
* `referred_by`
* `referral_code_used`
* `referral_assistance_consent`
* `referral_consent_timestamp`
* `customer_origin`

  * App Signup
  * Walk-in
  * Imported
  * Staff Created
* `linked_app_user`
* `manual_customer_status`

Customer should have one active primary referrer by default, while historical relationships remain in `OMC Referral`.

---

## 6.4 Service Request Fields

OMC Service Request mein new fields:

* `requested_for_customer`
* `customer_profile`
* `manual_customer`
* `customer_mode`
* `submission_mode`
* `submitted_by_user`
* `submitted_by_internal_user`
* `referral_owner`
* `referral_record`
* `created_on_behalf`
* `customer_consent_reference`
* `assigned_staff`
* optional `source_channel`

Enums:

### Customer mode

```text
My Referral
Existing Customer
Walk-in Customer
Self
```

### Submission mode

```text
Customer Self-Service
Staff on Behalf
Admin on Behalf
Walk-in Assisted
```

---

# 7. Manual / Walk-in Customer Model

Recommended new DocType:

### `OMC Manual Customer`

Fields:

* Full name
* CNIC
* Mobile
* Email
* Address
* City
* Date of birth where needed
* Created by
* Created at
* Referral owner where applicable
* Linked customer profile
* Linked app user
* Verification status
* Conversion status
* Notes

Statuses:

```text
Unregistered
Invited
Signup Pending
Linked
Duplicate Review
Archived
```

Do not automatically create full Frappe website users for every walk-in customer.

First create manual customer/business record. App login account only create/link after verification.

---

# 8. Customer Identity Matching

Walk-in customer later signup kare to system potential matches detect kare:

Priority:

1. Verified CNIC
2. Verified mobile
3. Verified email
4. Manual admin review

Automatic linking only strong verified match par ho.

Ambiguous or duplicate cases:

* Auto-merge nahi honge.
* `Duplicate Review` queue mein jayenge.
* Admin confirms merge/link.
* Service requests and documents preserve rahenge.

CNIC normalisation:

* Dashes/spaces remove for comparison
* Secure masked display
* Server-side validation
* Restricted access

---

# 9. Internal UI Flow

## 9.1 Service Detail Screen

Internal user ke liye actions:

```text
Start for Myself
Start for Customer
```

Customer users ko sirf normal customer action show hoga.

---

## 9.2 Customer Mode Selector

`Start for Customer` par:

```text
Who is this service for?

My Referral
Existing Customer
New / Walk-in Customer
```

Visibility capability-based hogi.

### Referral Agent

* My Referral
* New / Walk-in Customer, if allowed

### Consultant

* My Referral
* Assigned Customers
* New / Walk-in Customer

### Manager/Admin

* My Referral
* Existing Customer
* New / Walk-in Customer

---

## 9.3 My Referrals Selector

Features:

* Search
* Pagination
* Name
* Masked CNIC
* Mobile
* Customer status
* Consent status
* Active cases count

Only current referrer's linked customers returned by backend.

Client-side filtering security ke liye sufficient nahi hogi.

---

## 9.4 Existing Customer Selector

Features:

* Server-side search
* Minimum search length
* Debounce
* Pagination
* Exact CNIC/mobile search support
* Name/email search
* Approval status
* Duplicate-safe selection

Backend verifies current staff capability before returning records.

---

## 9.5 Walk-in Form

Fields service requirements ke mutabiq dynamic honge.

Base fields:

* Full name
* CNIC
* Mobile
* Email
* Address
* City
* Acquisition source
* Referral association if applicable
* Consent acknowledgement

Duplicate check before customer creation:

* CNIC exists
* Mobile exists
* Email exists

Possible match ho to staff ko options:

```text
Use Existing Customer
Continue as New After Review
Cancel
```

Authorisation required for duplicate override.

---

# 10. Request Form Auto-fill Rules

## Registered Referral or Existing Customer

Profile fields auto-fill:

* Name
* CNIC
* Mobile
* Email
* Address
* City
* Other available profile details

Rules:

* Identity fields read-only by default.
* Request-specific fields editable.
* Profile data change request separate workflow se ho.
* Missing profile fields authorised staff fill kar sake based on permission.
* Updated values clearly distinguish hon:

  * profile value
  * request-only value

---

## Walk-in Customer

Fields manually editable honge.

Once submitted:

* Manual customer snapshot preserve ho.
* Future profile changes historical request data silently alter na karein.
* Request should retain submitted identity snapshot.

---

# 11. Shared Request Access

## Customer Access

Registered customer apni app mein:

* Request list
* Request details
* Timeline
* Status
* Required documents
* Uploads
* Payment status
* Messages
* Missing information
* Allowed edits

exactly self-created request ki tarah access karega.

UI label optionally show kare:

```text
Created on your behalf by an OMC representative.
```

---

## Referrer Access

Referrer apne customer ki request par:

* View status
* View timeline
* Upload permitted documents
* Add missing information
* Respond to operational requirements
* Track payments where permitted
* Create additional requests
* Communicate through allowed workflow

Referrer by default access nahi karega:

* Customer password
* Login session
* Password reset
* Authentication settings
* Unrelated private data
* Other staff's referral customers
* Restricted financial credentials
* Account deletion
* Customer identity changes without approval

---

## Admin / Assigned Staff Access

Admins and role-authorised operational staff:

* All relevant cases
* Reassignment
* Referral correction
* Consent review
* Duplicate resolution
* Manual customer linking
* Access revocation
* Operational status changes

---

# 12. Permissions and Capabilities

New capabilities:

```text
can_view_own_referrals
can_create_request_for_own_referral
can_view_all_customers
can_create_request_for_any_customer
can_create_walk_in_customer
can_manage_walk_in_customer
can_reassign_referral
can_override_referral_consent
can_link_manual_customer
can_view_referral_reports
```

Backend endpoints must independently check these capabilities.

UI hiding alone must never provide security.

---

# 13. API Plan

## Referral APIs

* `get_my_referral_code`
* `validate_referral_code`
* `get_my_referral_summary`
* `get_my_referred_customers`
* `get_referral_detail`
* `revoke_referral_assistance`
* admin-only `regenerate_referral_code`
* admin-only `reassign_referral`

---

## Customer Selection APIs

* `search_my_referrals`
* `search_existing_customers`
* `check_manual_customer_duplicates`
* `create_manual_customer`
* `get_customer_service_prefill`

---

## Assisted Request APIs

Prefer extending canonical service-request creation API rather than creating completely separate logic.

Request payload includes:

```text
customer_mode
customer_profile
manual_customer
submission_mode
referral_record
service_id
form_data
attachments
```

Backend performs:

1. Authentication check
2. Capability check
3. Customer relationship check
4. Consent check
5. Service availability check
6. Form validation
7. Document validation
8. Request creation
9. Audit log creation
10. Customer notification
11. Referrer/internal notification

---

# 14. Notifications

## Customer Notifications

When staff creates request:

```text
A service request has been created on your behalf.
```

Other notifications:

* Document uploaded by representative
* Information updated
* Status changed
* Payment required
* Consent/access changed

---

## Internal Notifications

Referrer receives:

* Referral signup completed
* Referral approved
* Customer request update
* Customer uploaded document
* Consent revoked
* Case requires action

Notification content should respect privacy and role permissions.

---

# 15. Audit Trail

Every important action log hoga:

* Referral code generated
* Referral code validated
* Customer linked
* Referral reassigned
* Consent granted/revoked
* Staff viewed customer profile
* Request created on behalf
* Fields updated
* Document uploaded
* Payment receipt uploaded
* Status changed
* Manual customer linked to app user
* Duplicate records merged

Audit data:

* Acting user
* Acting role
* Customer
* Request
* Action
* Timestamp
* Previous value
* New value
* Source device/session where appropriate

Customer-facing timeline mein safe labels use hon:

```text
Request created by your OMC representative.
Document uploaded by customer.
Information updated by OMC staff.
```

Internal audit details customer ko unnecessarily expose na hon.

---

# 16. Security Rules

The following are explicitly prohibited:

* Master password
* Shared customer credentials
* Password visibility
* Password impersonation
* Direct login as customer
* Storing plaintext passwords
* Staff using customer sessions
* Referral staff seeing all customers
* Client-side-only access checks

Required protections:

* Server-side permissions
* Rate limiting for code validation
* Search result limits
* Masked CNIC
* Sensitive-field restrictions
* Session-based audit
* Consent enforcement
* Duplicate detection
* CSRF/auth protections
* Secure attachment permissions
* Record-level permission queries

---

# 17. Reporting and Dashboard

Future-ready referral dashboard:

* Total referred signups
* Pending referrals
* Approved customers
* Converted referrals
* Requests created
* Active cases
* Completed cases
* Revenue attributed, if later required
* Referral conversion rate

Admin reports:

* Referrals by staff
* Referrals by source
* Walk-in conversions
* Unlinked manual customers
* Duplicate-review queue
* Consent revoked
* Inactive referral codes

Commission or incentives are not part of first implementation unless explicitly added later, but data model should support them.

---

# 18. Migration Plan

Existing users need safe backfill.

## Internal Users

* Identify eligible referral-capable roles.
* Generate unique codes.
* Do not enable referral access for every internal role automatically.
* Admin review eligible users.

## Existing Customers

* Set source to `Unknown` or `Existing`.
* Do not fabricate referral relationships.
* Allow admin to manually link genuine historical referrals.
* Record relationship creation as migration/admin action.

## Existing Service Requests

Set:

```text
submission_mode = Customer Self-Service
```

where creator is customer.

Internal-created existing records should be classified based on reliable evidence only.

---

# 19. Implementation Batches

## Batch 1 — Architecture and Data Model

* Finalise roles and capabilities
* Add referral fields
* Create OMC Referral DocType
* Create OMC Manual Customer DocType
* Extend customer profile
* Extend service request
* Add indexes and constraints
* Add migration patches

Deliverable: backend schema ready without changing current user flow.

---

## Batch 2 — Referral Code Backend

* Secure code generator
* Existing staff backfill
* Code validation API
* Referral relationship creation
* Referral summary APIs
* Permission queries
* Unit tests

Deliverable: referral codes and relationships functional.

---

## Batch 3 — Signup Integration

* Acquisition source selector
* Conditional referral code field
* Code validation UX
* Consent checkbox
* Signup payload update
* Backend signup integration
* Pending/approved profile linking
* Validation tests

Deliverable: new customers can safely join through referral codes.

---

## Batch 4 — Internal Profile Referral UI

* Referral code card
* Copy/share actions
* Referral statistics
* My referrals list
* Search and detail access
* Empty/error/loading states

Deliverable: internal staff can view and manage their referral relationship scope.

---

## Batch 5 — Assisted Request Customer Selector

* Start for customer action
* Three-mode selector
* My Referrals search
* Existing Customer search
* Walk-in customer form
* Duplicate detection
* Permission-controlled visibility

Deliverable: staff can select the correct customer context.

---

## Batch 6 — Shared Service Request Creation

* Extend canonical request creation
* Auto-fill registered customer data
* Manual customer snapshots
* Consent verification
* Referral relationship verification
* Request ownership
* Customer notifications
* Internal notifications
* Audit events

Deliverable: staff can create valid requests on behalf of customers.

---

## Batch 7 — Shared Request Management

* Customer request visibility
* Referrer request visibility
* Assigned staff access
* Upload permissions
* Edit permissions
* Timeline labels
* Access revocation behaviour
* Sensitive-action restrictions

Deliverable: customer and authorised staff manage the same canonical case.

---

## Batch 8 — Manual Customer Conversion

* Signup identity matching
* Duplicate review
* Manual-to-app customer linking
* Historical request transfer/linking
* Admin approval workflow
* Audit preservation

Deliverable: walk-in customers can later become app customers without losing history.

---

## Batch 9 — Reporting and Admin Controls

* Referral reports
* Reassignment
* Code deactivate/regenerate
* Consent status
* Duplicate review queue
* Manual customer conversion queue
* Operational filters

Deliverable: management-level control and visibility.

---

## Batch 10 — Validation and Rollout

Test:

* Guest signup without referral
* Signup with valid referral
* Invalid/disabled code
* Duplicate referral submission
* Referral consent
* Consent revocation
* Own referral request
* Unauthorised referral access
* All-customer access
* Walk-in customer creation
* Duplicate CNIC/mobile/email
* Customer request visibility
* Referrer request visibility
* Document permissions
* Payment permissions
* Audit events
* Migration compatibility
* Existing routes and flows
* Guest/customer/internal access policies

Rollout:

1. Database migration
2. Backend deployment
3. Staff-code generation
4. Feature flag enable for test staff
5. Controlled internal testing
6. Production mobile release
7. Full capability enablement

---

# 20. Final Product Flow

```text
Internal staff receives referral code
        ↓
Customer signs up and enters code
        ↓
Referral relationship and consent recorded
        ↓
Staff opens a service
        ↓
Start for Customer
        ↓
My Referral / Existing Customer / Walk-in
        ↓
Customer data selected or entered
        ↓
Canonical service request created
        ↓
Customer sees request in their app
        ↓
Authorised staff and customer manage same case
        ↓
All actions remain permission-controlled and audited
```

# 21. Final Decisions

* No master-password system.
* No customer-password access.
* No customer impersonation.
* One canonical service request used by both customer and staff.
* Three customer modes supported.
* Referral ownership enforced server-side.
* Existing-customer access capability restricted.
* Walk-in customers supported through manual records.
* Customer profile information auto-filled where available.
* Consent required for referral-assisted access.
* Every important action audit logged.
* Walk-in records can later link to verified app users.



# OMC App Security, Stability, Accessibility & Home UI Improvement Plan

## 1. Objective

Is phase mein app ke following issues improve karne hain:

* Device biometric login
* Secure credential storage
* Saved login/session behaviour
* Back navigation assertion crash
* Home quick-action layout
* Text overflow and responsive wrapping
* Pinch-to-zoom accessibility
* Device-time-based greeting
* Duplicate/trimmed startup branding
* Guest/customer-specific home fixes
* Full navigation stability audit

Existing backend behaviour, permissions, routes and business workflows preserve rahenge.

---

# 2. Biometric Login

## 2.1 Required Behaviour

App device ke existing security system ko use karegi:

### Android

* Fingerprint
* Face unlock, where Android/device exposes it through biometric authentication
* Device PIN/pattern/password fallback only if explicitly supported by selected implementation

### iOS

* Face ID
* Touch ID
* Device-supported biometric authentication

Biometric lock default mein:

```text
Off
```

User manually Settings/Profile se enable karega.

---

## 2.2 Important Security Rule

Biometric authentication customer ka actual password retrieve ya expose nahi karegi.

Correct flow:

1. User normal email/password se successful login kare.
2. App user se biometric login enable karne ki permission mange.
3. Secure session credential/token encrypted device storage mein save ho.
4. Next launch par user biometric verify kare.
5. Verification successful ho to secure stored session restore/refresh ho.
6. Authentication fail ho to normal login screen show ho.

Do not:

* Store plaintext password
* Store password in SharedPreferences
* Display saved password
* Create a universal/master login
* Bypass backend session validation

---

## 2.3 Biometric Settings

Profile or Settings screen mein section:

### App Security

* Enable biometric login
* Biometric type detected

  * Fingerprint
  * Face ID
  * Touch ID
  * Device biometrics
* Lock app when reopened
* Optional lock delay:

  * Immediately
  * After 1 minute
  * After 5 minutes
  * After 15 minutes
* Disable biometric login
* Clear saved login

First implementation can keep only:

* Enable biometric login
* Disable biometric login
* Saved session status

Lock-delay feature later add ho sakta hai.

---

## 2.4 Unsupported Device Behaviour

Agar biometric hardware/enrolment available na ho:

* Setting disabled ho.
* Clear helper text show ho:

```text
Biometric authentication is not available or configured on this device.
```

App normal email/password login use kare.

No error dialog on every launch.

---

## 2.5 Biometric Failure Handling

Handle:

* User cancelled
* Too many failed attempts
* Biometric lockout
* Device security changed
* Fingerprint/Face ID removed
* Stored secure token missing
* Backend session expired
* Device changed
* App data restored from backup

Fallback:

```text
Use email and password
```

---

# 3. Secure Credential and Session Storage

## 3.1 Current Problem

Passwords/login session reliably persist nahi ho rahe, ya unsafe storage use hone ka risk hai.

Exact implementation se pehle inspect karna hoga:

* Login controller
* Auth repository
* API client
* Cookie/session storage
* SharedPreferences usage
* Token/password fields
* Logout cleanup
* App startup session restoration

---

## 3.2 Correct Storage Model

Use encrypted native secure storage:

* Android Keystore
* iOS Keychain

Store only what is required:

* Secure session token/cookie material
* Logged-in user identifier
* Biometric enabled flag
* Session refresh metadata where supported

Do not store:

* Raw password
* Unencrypted API secret
* Full sensitive customer data
* Frappe credentials in normal local preferences

---

## 3.3 Remember Login Flow

Recommended behaviour:

### First Login

1. User enters credentials.
2. Backend validates.
3. Session securely saved.
4. App restores session after restart.
5. Biometric remains optional.

### App Restart

1. Splash checks secure session.
2. Backend session validity checked.
3. Valid session → home.
4. Expired session → login.
5. Biometric enabled → authenticate before opening protected app content.

### Logout

Clear:

* Secure session
* Cookies
* Biometric session reference
* Cached private profile data
* Sensitive request data

Biometric preference may either reset automatically or require re-enablement after next login. Safer initial behaviour:

```text
Logout disables biometric login for that account.
```

---

# 4. Back Navigation Assertion Crash

Observed Flutter error:

```text
Failed assertion:
'_dependents.isEmpty': is not true
```

This usually points toward widget lifecycle, inherited dependencies, provider/listener disposal, overlay, controller or navigation-state misuse.

We must not assume exact cause without inspecting affected screens and reproducing it.

---

## 4.1 Primary Investigation Areas

Inspect these patterns across Tasks, Leads and similar screens:

* `ref.listen` inside improper lifecycle locations
* `context.watch` or inherited dependency usage during dispose
* Provider invalidation while widget is unmounting
* Calling `setState` after route pop
* Using `context` after async gaps
* Disposing controllers still used by descendants
* Shared `TextEditingController` or `FocusNode`
* Overlay/menu/dialog still open during back navigation
* TabController/AnimationController disposal order
* GlobalKey reuse
* Navigator pop during build
* Route refresh triggered during widget disposal
* Auto-open create form/query actions
* Nested shell navigation replacement
* Bottom-sheet/dialog closing after parent disposal

---

## 4.2 Reproduction Matrix

Test every affected screen with:

* Open then immediately back
* Open detail then back
* Open create dialog then cancel
* Open search then back
* Open filter then back
* Start typing then back
* Open keyboard then system back
* Open dropdown then back
* API loading then back
* API error then back
* Rapid double back
* Bottom-navigation switch during loading
* App background/foreground then back

Priority screens:

* Tasks
* Task Detail
* Leads
* Lead Detail
* Customers
* Customer Detail
* Service Request
* Internal workspace
* Support
* Documents
* Payments

---

## 4.3 Safe Fix Rules

* Check `mounted` after every awaited operation before UI updates.
* Cancel active subscriptions on dispose.
* Do not manually dispose Riverpod-managed resources.
* Keep controllers owned by one widget only.
* Close overlays before route disposal.
* Avoid provider mutation during build/dispose.
* Use route-aware state where screen lifecycle matters.
* Preserve existing API and route behaviour.

---

## 4.4 Global Stability Audit

Search entire Flutter app for:

```text
dispose(
setState(
ref.listen(
addPostFrameCallback(
showDialog(
showModalBottomSheet(
OverlayEntry(
Navigator.pop(
context.go(
context.push(
```

Each occurrence should be checked for lifecycle safety.

Deliverable:

* Reproducible root cause
* Focused fix
* Regression tests
* Similar-risk locations fixed only where evidence supports it

---

# 5. Home Quick Actions Redesign

This issue currently affects:

* Guest home
* Customer home

Internal/admin home layout should remain unchanged unless shared component changes require safe adjustment.

---

## 5.1 Current Problems

* Tiles are too tall
* Text gets trimmed
* Content feels bulky
* Labels do not wrap properly
* Grid wastes vertical space
* Different screen widths create awkward alignment

---

## 5.2 Recommended Design

Use a compact responsive grid.

### Mobile

```text
4 columns where width permits
3 columns on narrow screens
```

Each action:

* Compact icon container
* One short label
* Maximum two lines
* Center aligned
* No descriptive paragraph
* Consistent tile dimensions
* Small touch-safe spacing

Recommended structure:

```text
Icon
Label
```

No large card body.

---

## 5.3 Tile Behaviour

* Fixed minimum touch area
* Adaptive width
* Content determines safe height
* Label wraps to maximum two lines
* No hard clipping
* No ellipsis unless label is genuinely too long
* Text scales with accessibility settings
* Selected/primary actions may use accent colour
* Other actions remain neutral

Possible alternative:

Use icon-only compact circular/squircle buttons with label underneath instead of full cards. This is likely the cleanest premium option.

---

## 5.4 Guest and Customer Actions

Guest actions should only show public features.

Customer actions should show authorised customer features.

Do not duplicate:

* Services
* Track request
* Documents
* Payments

when same action is already clearly available in primary navigation, unless it is intentionally a frequently used shortcut.

---

# 6. Text Overflow and Responsive Layout

## 6.1 Current Problem

Home and some other screens use text containers with restricted height or improper row constraints, causing:

* Cut-off text
* Ellipsis in important content
* Overflow warnings
* Broken layout at larger text sizes
* Labels not moving to next line

---

## 6.2 App-wide Rules

For descriptive text:

* Allow wrapping
* Avoid fixed-height parent containers
* Use `Flexible` or `Expanded` correctly inside rows
* Use `Wrap` for dynamic labels/chips
* Use safe max lines only where content is secondary
* Important messages should expand vertically
* Use `TextOverflow.ellipsis` only for list-preview content

Headers and cards:

* Height should adapt to text
* Buttons must remain visible
* Cards should grow vertically
* Long names/email/service titles should wrap safely

---

## 6.3 Accessibility Text Scaling

Test at:

* 100%
* 120%
* 150%
* Device maximum reasonable accessibility scale

Do not globally disable device text scaling.

Any controlled cap should only prevent destructive layout, not block accessibility.

---

# 7. Pinch-to-Zoom Accessibility

## 7.1 Scope Clarification

Global pinch-to-zoom on every application screen can conflict with:

* Vertical scrolling
* Horizontal carousels
* Swipe gestures
* Buttons
* Forms
* Text fields
* Navigation gestures

Therefore zoom should be implemented deliberately.

---

## 7.2 Recommended Approach

Add zoom support primarily to:

* Document/image preview
* Uploaded receipts
* CNIC/document images
* Knowledge images
* Attachments
* Any full-screen visual preview

Use focal-point zoom so the content zooms around the exact place where the user pinches.

Required gestures:

* Pinch out to zoom in
* Pinch in to zoom out
* Pan while zoomed
* Double-tap optional
* Reset zoom
* Minimum and maximum scale

Suggested scale:

```text
1.0x to 4.0x
```

---

## 7.3 Zoom Indicator

On zoomable preview screen, show a small unobtrusive indicator:

```text
1.0×
1.5×
2.0×
```

Position:

* Corner overlay
* Only visible during interaction, or
* Small persistent label with reset action

Also add:

* Reset icon
* Optional `Fit to screen`

---

## 7.4 Text Readability

For normal text screens, use:

* Device text scaling
* Wrapping
* Larger-text accessibility option where needed

Do not make the whole interactive app canvas zoomable initially. It can create serious gesture and navigation conflicts.

If a dedicated “reading mode” is later required, it should be a separate accessibility feature.

---

# 8. Device-Time-Based Greeting

Greeting must use the device's current local time.

Do not use:

* Backend timezone
* Hardcoded Pakistan timezone
* UTC hour directly
* Cached startup time for the whole day

Use current device local time whenever home is built/resumed.

---

## 8.1 Greeting Rules

### 07:00–11:59

```text
Good morning ☀️
```

### 12:00–15:59

```text
Good afternoon 🌤️
```

### 16:00–19:59

```text
Good evening 🌇
```

### 20:00–06:59

```text
Good night 🌙
```

Exact implementation boundaries:

```text
hour >= 7 && hour < 12
hour >= 12 && hour < 16
hour >= 16 && hour < 20
otherwise
```

---

## 8.2 Refresh Behaviour

Greeting should update when:

* App launches
* Home opens
* App resumes from background
* Day/time changes while app remains active

No continuous timer is necessary unless home stays open across boundary for long periods. App lifecycle resume plus a lightweight boundary refresh is sufficient.

---

# 9. Startup and Splash Cleanup

## 9.1 Current Problem

App startup appears to show two OMC branding/loading states:

1. First OMC header/logo is trimmed or visually incorrect
2. Second smaller OMC loading view with spinner is acceptable

---

## 9.2 Investigation

Inspect:

* Native Android launch theme
* Android 12+ splash configuration
* Flutter SplashScreen
* App initialization screen
* Main shell loading state
* Image fit and safe-area configuration
* Duplicate logo widgets

---

## 9.3 Desired Flow

```text
Native splash
    ↓
Single clean Flutter loading screen
    ↓
Correct destination
```

Remove the extra broken/trimmed OMC branding state.

Keep:

* Small clean OMC logo
* Loading spinner
* Neutral background
* No duplicate header
* No abrupt scaling
* No stretched logo

Android native launch screen should visually match the Flutter loading state to reduce flicker.

---

# 10. Home Screen Content Refinement

Home content should become more compact and responsive.

Review:

* Greeting header
* Welcome message
* Long descriptive copy
* Quick actions
* Status cards
* Notifications preview
* Service cards
* Internal/customer-specific sections

Rules:

* Short headings
* Supporting text wraps
* Avoid fixed heights
* No duplicated “OMC Operations Hub” style oversized text
* Primary information appears first
* Secondary detail moves below naturally
* Cards use consistent padding
* Empty states remain compact

---

# 11. Platform Behaviour

## Android

Test:

* Fingerprint
* Android face biometric where available
* System back button
* Gesture back
* Keyboard back
* Android 12+ splash
* Small-screen devices
* Large font settings

## iOS

Test:

* Face ID
* Touch ID
* Keychain storage
* Swipe-back gesture
* App resume lock
* Native launch screen
* Dynamic Type text scaling

Flutter should use one shared authentication abstraction with platform-specific capability detection.

---

# 12. New Configuration and State

Suggested security state:

```text
biometricAvailable
biometricType
biometricEnabled
secureSessionAvailable
authenticationRequired
lastAuthenticatedAt
```

Do not mix this directly into every screen.

Use a dedicated security/session service and controller.

---

# 13. Implementation Batches

## Batch 1 — Inspection and Root-Cause Audit

Inspect:

* Auth flow
* Credential storage
* Splash flow
* Home layout
* Greeting logic
* Tasks/Leads lifecycle
* Navigation and provider disposal patterns
* Existing document/image viewers

Deliverable:

* Exact affected files
* Confirmed causes
* Safe implementation map

No major behaviour changes in this batch.

---

## Batch 2 — Secure Session Storage

* Replace unsafe storage
* Add Android Keystore/iOS Keychain-backed secure storage
* Restore valid sessions
* Clear secure state on logout
* Handle expired sessions
* Add storage migration if old credentials exist

Deliverable:

* Login remains saved securely
* No plaintext password persistence

---

## Batch 3 — Biometric Authentication

* Device capability detection
* Enable/disable setting
* Biometric prompt
* Secure session unlock
* Failure fallback
* Lockout handling
* Logout reset
* Android/iOS platform configuration

Deliverable:

* Optional fingerprint/Face ID login

---

## Batch 4 — Navigation Crash Fix

* Reproduce Tasks/Leads issue
* Trace widget/provider lifecycle
* Fix confirmed cause
* Audit similar patterns
* Add navigation regression tests

Deliverable:

* No assertion on back navigation in tested flows

---

## Batch 5 — Home Quick Actions

Only guest/customer home:

* Replace oversized tiles
* Responsive compact grid
* Icon and label layout
* Proper wrapping
* Small-screen support
* Large-text support

Deliverable:

* Clean premium quick-action section

---

## Batch 6 — Responsive Text Audit

* Home text wrapping
* Card height fixes
* Row/Flexible fixes
* Long labels
* Service titles
* User names/emails
* Error and empty-state messages
* Accessibility scaling tests

Deliverable:

* No important text clipping in supported layouts

---

## Batch 7 — Device-Time Greeting

* Device local-time utility
* Exact greeting boundaries
* Emoji mapping
* Lifecycle refresh
* Unit tests for boundary hours

Deliverable:

* Correct greeting based on device time

---

## Batch 8 — Splash Cleanup

* Remove duplicate startup branding
* Fix image fit
* Align native and Flutter splash
* Keep single loading state
* Test cold/warm launch

Deliverable:

* One clean OMC startup experience

---

## Batch 9 — Zoomable Media Viewer

* Shared zoomable preview component
* Focal-point pinch zoom
* Pan support
* Reset control
* Zoom indicator
* Documents/images/receipts integration
* Gesture conflict testing

Deliverable:

* User can inspect visual documents properly

---

## Batch 10 — Full Regression Testing

Test modes:

* Guest
* Pending user
* Approved customer
* Internal staff
* Admin

Test:

* Fresh install
* Existing session
* Biometric enabled
* Biometric unavailable
* Session expiry
* Logout
* Back navigation
* Rapid navigation
* API loading/error states
* Quick actions
* Text scaling
* Device rotation where supported
* Pinch zoom
* Device time boundaries
* Cold launch
* App resume

---

# 14. Testing Requirements

## Authentication

* Password is never stored in plain text
* Session restores correctly
* Biometric cannot unlock another account
* Logout clears access
* Failed biometric returns to login safely
* Device biometric changes invalidate access where needed

## Navigation

* No `_dependents.isEmpty` assertion
* No `setState after dispose`
* No provider disposal assertion
* No overlay left active
* No duplicate route push

## UI

* No text overflow
* No clipped labels
* Quick actions fit narrow screens
* Large fonts remain usable
* Greeting updates correctly
* Splash appears once
* Zoom follows pinch focal point

---

# 15. Final Product Behaviour

```text
App launches
    ↓
Single clean OMC loading screen
    ↓
Secure session checked
    ↓
Biometric enabled?
    ├── Yes → Fingerprint / Face ID / Touch ID
    └── No  → Restore session or normal login
    ↓
Home uses current device time
    ↓
Guest/customer sees compact quick actions
    ↓
Text wraps safely
    ↓
Navigation remains lifecycle-safe
    ↓
Documents and images support pinch zoom
```

# 16. Final Decisions

* Biometric login will be optional and default off.
* Android and iOS device biometrics will be used.
* Plaintext passwords will never be stored.
* Secure session data will use native encrypted storage.
* No master-password or account impersonation system will be added.
* The back-navigation assertion must be reproduced before applying a focused fix.
* Similar lifecycle risks will be audited app-wide.
* Quick-action redesign applies first to guest and customer home.
* Normal text will use accessibility scaling and responsive wrapping.
* Pinch zoom will initially target visual/document preview content.
* Greeting will use the device's local time.
* Duplicate/trimmed startup branding will be removed.
* Existing routes, permissions, API behaviour and business workflows will remain preserved.



# Signup Reliability, Pending Review & Error Handling Plan

## 1. Objective

Signup flow ko transactional, verifiable aur user-friendly banana hai taa-ke:

* False “OMC server unavailable” messages na aayen.
* Successful signup ke baad backend User aur Customer Profile dono confirm hon.
* Pending-review status immediately correct screen par reflect ho.
* Partial or failed account creation success ke taur par display na ho.
* Backend ka actual safe error customer ko samajh aaye.
* Technical details server logs mein available rahen.

---

# 2. Current Confirmed Behaviour

Current signup screen:

1. Form data backend `sign_up` method ko bhejti hai.
2. Request resolve hone par local success boolean set karti hai.
3. Auth controller ko update nahi karti.
4. Session establish nahi karti.
5. Backend se returned `access_state`, `profile` aur `capabilities` consume nahi karti.
6. User ko success screen se login page par bhejti hai.

Backend signup already return karta hai:

* User creation result
* Profile creation result
* Customer status
* Approval status
* Access state
* Capabilities

Lekin frontend currently in values ko verify ya use nahi karta.

---

# 3. Desired Signup Result Contract

Backend signup success tabhi return kare jab all required records successfully exist:

* Frappe User
* OMC Customer Profile
* Correct user/profile link
* Customer role
* Pending customer status
* Pending Review approval status
* Required preference record, where applicable

Expected structured response:

```text
success: true
created: true
user_created: true
profile_created: true
user_email
customer_id
customer_status: Pending
approval_status: Pending Review
access_state: pending
capabilities
```

Frontend generic HTTP success ko account creation proof na samjhe. Required response fields validate kare.

---

# 4. Transaction-Safe Backend Signup

Signup should run as one controlled transaction.

Flow:

1. Validate submitted fields.
2. Check duplicate email, CNIC and mobile rules.
3. Create Frappe User.
4. Assign correct customer role.
5. Create OMC Customer Profile.
6. Link profile to User.
7. Set pending-review state.
8. Create preferences where required.
9. Verify saved records.
10. Commit transaction.
11. Return structured success response.

If any required step fails:

* Entire transaction rollback ho.
* Partial User/Profile record preserve na ho.
* Structured safe error return ho.
* Full technical traceback server logs mein record ho.

Do not call manual commit until all required records and links are verified.

---

# 5. Post-Creation Verification

Before returning success, backend explicitly verify kare:

```text
User exists
Customer Profile exists
profile.user == submitted email
profile.email == submitted email
customer_status == Pending
approval_status == Pending Review
required customer role exists
```

Agar verification fail ho:

```text
success: false
error_code: SIGNUP_VERIFICATION_FAILED
```

Frontend success screen show na kare.

---

# 6. Error Classification Fix

HTTP 500 ka matlab automatically server down nahi hona chahiye.

Separate errors:

## Real connectivity failure

* Host unreachable
* Connection refused
* DNS failure
* Timeout
* Gateway unavailable

Message:

```text
Unable to connect to OMC right now. Check your connection and try again.
```

## Backend processing failure

Server reachable tha lekin signup process fail hua.

Message:

```text
We could not create your account. Your information was not submitted. Please try again or contact OMC support.
```

## Validation failure

Examples:

* Duplicate email
* Duplicate CNIC
* Invalid mobile
* Missing backend field
* Unsupported role

Return exact safe message.

## Configuration/schema failure

Examples:

* Required DocType missing
* Required field missing
* Role not installed
* Migration pending

Customer message:

```text
Account registration is temporarily unavailable. Please contact OMC support.
```

Internal server log actual technical cause preserve kare.

---

# 7. Stable Backend Error Codes

Add signup-specific error codes:

```text
SIGNUP_DUPLICATE_EMAIL
SIGNUP_DUPLICATE_CNIC
SIGNUP_DUPLICATE_MOBILE
SIGNUP_VALIDATION_FAILED
SIGNUP_CONFIGURATION_ERROR
SIGNUP_USER_CREATION_FAILED
SIGNUP_PROFILE_CREATION_FAILED
SIGNUP_LINK_FAILED
SIGNUP_VERIFICATION_FAILED
SIGNUP_TEMPORARILY_UNAVAILABLE
```

Flutter error mapper message text parse karne ke bajaye code-first handling use kare.

---

# 8. Pending Review State Flow

Recommended premium flow:

1. Signup succeeds.
2. Backend creates user/profile.
3. App automatically logs in using submitted email/password.
4. App calls `get_session_user`.
5. Backend returns `access_state = pending`.
6. Auth controller becomes authenticated with pending capabilities.
7. Router automatically opens `/under-review`.

This is better than forcing the user to manually log in immediately after signup.

Expected route:

```text
Signup
  ↓
Backend account creation
  ↓
Automatic login
  ↓
Session/capability refresh
  ↓
Pending Review screen
```

If automatic login cannot be safely completed:

* Success response must still include verified customer ID/status.
* Show verified success screen.
* Then user can manually login.
* Manual login must route pending users to `/under-review`.

---

# 9. Frontend Signup State Integration

Signup submission should use an application-level signup controller rather than a raw repository provider.

Controller responsibilities:

* Submit signup
* Validate structured response
* Establish login session
* Refresh auth state
* Store pending capabilities
* Handle duplicate/configuration/network errors
* Prevent repeated submissions
* Preserve entered data on failure
* Clear password fields where appropriate

Suggested states:

```text
idle
submitting
accountCreated
establishingSession
pendingReview
failed
```

---

# 10. Router Behaviour

After signup/login:

* Pending account → `/under-review`
* Approved customer → `/home`
* Internal staff → authorised home/internal workspace
* Unauthenticated → `/login`

Router already understands pending capabilities, but signup currently does not update the global auth state.

The new flow must update `authControllerProvider`, allowing the router to make the decision.

---

# 11. Pending Review Refresh

Pending Review screen should support:

* Pull/refresh button
* App resume refresh
* Session capability refresh
* Approval-status recheck
* Logout
* Contact support

When admin approves account:

1. User opens/resumes app.
2. Session endpoint is called.
3. New capabilities load.
4. Router redirects from `/under-review` to `/home`.

No reinstall or manual session reset should be required.

---

# 12. Duplicate Submission Protection

Prevent:

* Multiple button taps
* Retry creating a second User after uncertain response
* Duplicate profile after timeout
* User created but client response lost

Use idempotency strategy:

* Normalised email as primary identity
* Optional signup request ID
* Existing matching pending account returns recoverable result
* Duplicate pending signup should say:

```text
Your account already exists and is awaiting review. Please sign in.
```

---

# 13. Server Logging

For every signup attempt log:

* Request ID
* Normalised email
* Selected role
* User creation status
* Profile creation status
* Transaction result
* Safe error code
* Full traceback for technical failures

Never log:

* Password
* Confirm password
* Session token
* Full sensitive form payload unnecessarily

---

# 14. Required Tests

## Backend

* Successful customer signup
* Successful consultant/business-partner/tax-associate application
* User created
* Profile created
* Correct link
* Pending status assigned
* Duplicate email
* Duplicate CNIC/mobile
* User creation failure rollback
* Profile creation failure rollback
* Missing DocType/field
* Preferences failure
* Structured error response
* No plaintext password logging

## Flutter

* Successful signup reaches pending review
* Backend validation error shows correct message
* Actual offline state shows connection message
* Backend 500 does not falsely claim server is down
* Malformed success response is rejected
* Double-submit blocked
* Automatic login success
* Automatic login fallback
* Pending review refresh
* Approval redirects to home
* Back to login works safely

---

# 15. Implementation Order

## Batch A — Reproduce and capture

* Run signup against production-compatible backend
* Inspect HTTP status and response body
* Check Frappe error logs
* Check whether User/Profile records exist
* Identify exact failing backend operation

## Batch B — Backend transaction and response contract

* Add structured result
* Add verification
* Add rollback
* Add error codes
* Add server logging

## Batch C — Flutter error mapping

* Separate connectivity from backend-processing errors
* Handle signup error codes
* Validate successful response

## Batch D — Pending auth integration

* Add signup controller
* Automatic login
* Session/capability refresh
* Route to under-review

## Batch E — Approval refresh and regression tests

* Pending screen refresh
* Resume refresh
* Approval transition
* Full guest/auth/customer regression

# Final Decisions

* A generic HTTP 500 will no longer be labelled automatically as “server down”.
* Signup success requires verified backend User and Customer Profile records.
* Signup will update global authentication state.
* Successful pending users will land on the Pending Review screen.
* Pending approval status will refresh without reinstalling the app.
* Failed signup will not leave partial records.
* Passwords and sensitive authentication data will never be logged.



and we might need to redign its artchitecture to modern stylish way as appp theme casees screens style,,. sign p flow nad style.... 


and all customers account will be approved and active by deault sirf tax assisiate wager internals account eki active approved ki zarurat hai okie... we are not restricting customers any more wo by default approved hon ge and active hon ge okiee
 
taska and leads bhi set hoga but as per custmer erp to jab wo aae ga tab karein ge...!