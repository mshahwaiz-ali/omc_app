# OMC App — Frappe Backend Master Implementation Guide

_Last updated: 2026-07-05_  
_Target repo: `omc_app` Flutter mobile app_  
_Target backend: Frappe / ERPNext custom app_

---

## 1. Final Locked Backend Recommendation

The OMC mobile app should be connected to the existing OMC Frappe / ERPNext system through a small custom backend app, recommended name:

```text
omc_mobile
```

or, if the team wants naming consistency with the Flutter repo:

```text
omc_app
```

This backend app will expose secure mobile APIs, manage customer-profile linking, handle service requests, documents, notifications, payments, and internal workspace APIs.

### Locked decision

Mobile app users should be real Frappe `User` records.

However, a newly signed-up mobile user must **not** automatically receive access to existing customer data until the user is verified and linked to the correct ERPNext `Customer`.

The safe identity chain is:

```text
Frappe User
    ↓
OMC Customer Profile
    ↓
ERPNext Customer / Lead / Contact
    ↓
Allowed services, documents, invoices, payments, notifications
```

### Why this approach

This matches the client requirement:

- App user can download the app and sign up.
- Signup creates a user/profile in Frappe.
- Existing OMC customers can log in and see their own services.
- New users can request services even if they are not existing customers yet.
- Admin can control access from Frappe through roles, profile status, and customer linking.
- Customer data never depends on app-side filtering.
- Existing ERPNext records remain the source of truth.

---

## 2. Non-Negotiable Backend Rules

1. **Backend-first architecture**
   - Production app must use Frappe APIs.
   - Mock/sample data can only exist behind development/testing mode.

2. **No mobile-side permission trust**
   - Flutter must never fetch all records and filter locally.
   - Every API must filter records using `frappe.session.user`.

3. **No automatic sensitive customer access**
   - Email or phone match can create a suggested match.
   - Full access should require verified linking or admin approval.

4. **Existing ERPNext data stays source of truth**
   - Use ERPNext `Customer`, `Lead`, `Contact`, `Sales Invoice`, `Payment Entry`, `File`, and `Communication` wherever possible.
   - Create custom DocTypes only where the mobile app needs app-specific workflow.

5. **Stable JSON responses**
   - Flutter repositories already expect predictable response shapes.
   - Backend should return empty arrays instead of `null`.
   - Backend should return clean user-safe error messages.

6. **Role-aware internal workspace**
   - Customer users must not see internal modules.
   - Internal modules should appear only for users with internal OMC roles.

---

## 3. User Types and App States

| User Type | Backend Condition | App Access |
|---|---|---|
| Guest | Not logged in | Login, signup, service catalogue, public support if enabled |
| New Signup | Frappe User exists, `OMC Customer Profile.status = Pending Verification` | Limited dashboard, profile, new service request, support |
| New Prospect | User linked to `Lead`, no `Customer` yet | New service requests, support, profile, limited tracking |
| Existing Customer | Profile linked to ERPNext `Customer`, status `Active` | My Services, documents, payments, notifications, dashboard |
| Internal Staff | Has internal OMC roles | Internal workspace, leads, customers, tasks, assigned service cases |
| Blocked User | User disabled or profile status `Blocked` | No app access except contact support message |

---

## 4. Recommended Frappe App Structure

Create a custom Frappe app:

```text
apps/omc_mobile/
  omc_mobile/
    __init__.py
    hooks.py
    api/
      __init__.py
      mobile.py
      auth.py
      permissions.py
      serializers.py
      validators.py
    omc_mobile/
      doctype/
        omc_customer_profile/
        omc_service_category/
        omc_service/
        omc_service_request/
        omc_service_request_document/
        omc_service_timeline/
        omc_mobile_device/
        omc_notification/
        omc_knowledge_article/
        omc_customer_document/
        omc_support_ticket/
```

Recommended API method namespace:

```text
omc_mobile.api.mobile.<method_name>
```

Flutter currently points to placeholder names such as:

```text
omc_app.api.mobile.get_service_cases
omc_app.api.mobile.get_documents
omc_app.api.mobile.get_payments
```

Two options are acceptable:

### Option A — Rename Flutter API paths later

Use backend namespace:

```text
omc_mobile.api.mobile.get_service_cases
```

Then update Flutter `ApiConfig`.

### Option B — Keep Flutter paths stable

Name the Frappe app/package:

```text
omc_app
```

Then backend methods can exactly match current Flutter placeholders:

```text
omc_app.api.mobile.get_service_cases
```

### Recommendation

Use:

```text
omc_app
```

for the Frappe app package if possible, because the Flutter app already uses `omc_app.api.mobile...` placeholders. This reduces frontend changes.

---

## 5. Core Roles

Create these roles in Frappe:

| Role | Purpose |
|---|---|
| `OMC Customer` | Normal mobile customer user |
| `OMC Mobile Admin` | Can manage mobile users, customer profiles, service configuration |
| `OMC Support Agent` | Can view/handle support tickets and customer service requests |
| `OMC Sales User` | Can view assigned leads/customers and create follow-ups |
| `OMC Accounts User` | Can view payment/invoice related mobile data |
| `OMC Operations User` | Can handle service execution tasks |
| `System Manager` | Full administrative control |

### Role behavior

- `OMC Customer`
  - Can only see records linked to their own active customer profile.
  - Cannot see other customers, leads, internal tasks, or staff-only dashboards.

- Internal roles
  - Can access internal workspace endpoints.
  - Access can be restricted further by assigned user, branch, territory, or team if needed.

- System Manager / OMC Mobile Admin
  - Can approve customer profile linking.
  - Can configure services and document requirements.
  - Can review all mobile records.

---

## 6. Identity and Customer Linking Model

### 6.1 Main identity chain

```text
User.email
    ↓
OMC Customer Profile.user
    ↓
OMC Customer Profile.customer
    ↓
ERPNext Customer.name
```

### 6.2 Supporting links

```text
OMC Customer Profile.contact → Contact
OMC Customer Profile.lead    → Lead
```

### 6.3 Matching rules

When a user signs up:

1. Create or find `User`.
2. Create `OMC Customer Profile`.
3. Search matching `Contact` by:
   - email
   - mobile number
   - phone number
4. Search matching `Customer` through Contact links if available.
5. Search by NTN/CNIC only if those fields exist and the client wants them.
6. If exact match confidence is high:
   - set `verification_status = Auto Matched`
   - keep `status = Pending Verification` or optionally `Active` only if client explicitly approves auto activation.
7. If no match:
   - create/link `Lead`
   - keep profile as `Pending Verification` or `Prospect`.

### 6.4 Security rule

Do **not** unlock customer invoices, documents, services, or payments only because the user entered an email/phone that matches ERP.

Access should unlock only when:

```text
OMC Customer Profile.status = Active
AND OMC Customer Profile.customer is set
AND User is enabled
```

---

## 7. Required DocTypes

---

# 7.1 OMC Customer Profile

## Purpose

Bridge mobile `User` to ERPNext `Customer`, `Lead`, and `Contact`.

## Naming

```text
OMC-PROF-.YYYY.-.#####
```

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `user` | User | Link | User | Yes | Frappe login user |
| `customer` | Customer | Link | Customer | No | Existing ERPNext customer |
| `lead` | Lead | Link | Lead | No | Prospect user if not customer yet |
| `contact` | Contact | Link | Contact | No | Matching ERPNext contact |
| `full_name` | Full Name | Data | — | Yes | Display name |
| `email` | Email | Data | — | Yes | Should match user email |
| `mobile_no` | Mobile No | Data | — | No | Used for verification/matching |
| `phone` | Phone | Data | — | No | Optional |
| `cnic` | CNIC | Data | — | No | Optional Pakistan identity field |
| `ntn` | NTN | Data | — | No | Optional tax identity field |
| `company_name` | Company Name | Data | — | No | For business customers |
| `city` | City | Data | — | No | Profile display/filter |
| `status` | Status | Select | Pending Verification\nActive\nRejected\nBlocked\nProspect | Yes | Controls app access |
| `verification_status` | Verification Status | Select | Unverified\nAuto Matched\nManually Approved\nRejected | Yes | Explains linking state |
| `match_confidence` | Match Confidence | Select | None\nLow\nMedium\nHigh\nExact | No | Internal review |
| `source` | Source | Select | Mobile Signup\nGoogle Login\nAdmin Created\nERP Existing | Yes | Origin |
| `linked_by` | Linked By | Link | User | No | Admin who approved |
| `linked_on` | Linked On | Datetime | — | No | Approval timestamp |
| `last_login` | Last Login | Datetime | — | No | Updated by login/session API |
| `notes` | Notes | Small Text | — | No | Admin notes |

## Permissions

| Role | Read | Create | Write | Delete |
|---|---:|---:|---:|---:|
| OMC Customer | Own only | No | Limited via API | No |
| OMC Mobile Admin | Yes | Yes | Yes | Yes |
| OMC Support Agent | Yes | No | Limited | No |
| System Manager | Yes | Yes | Yes | Yes |

## Important logic

- One active profile per user.
- One user should not be linked to multiple customers unless family/company-user support is explicitly required.
- If multi-customer support is needed later, add child table `OMC Customer Profile Link`.

---

# 7.2 OMC Mobile Device

## Purpose

Track logged-in devices for push notifications, security, and logout/session tracking.

## Naming

```text
OMC-DEV-.YYYY.-.#####
```

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `user` | User | Link | User | Yes | Device owner |
| `customer_profile` | Customer Profile | Link | OMC Customer Profile | No | Linked profile |
| `device_id` | Device ID | Data | — | Yes | App-generated stable id |
| `platform` | Platform | Select | Android\niOS\nWeb | Yes | Mobile platform |
| `fcm_token` | FCM Token | Small Text | — | No | Push notification token |
| `app_version` | App Version | Data | — | No | App build version |
| `build_number` | Build Number | Data | — | No | App build number |
| `last_seen` | Last Seen | Datetime | — | No | Updated on app open/session |
| `is_active` | Is Active | Check | — | Yes | Disable old devices |
| `ip_address` | IP Address | Data | — | No | Optional audit |
| `user_agent` | User Agent | Small Text | — | No | Optional audit |

---

# 7.3 OMC Service Category

## Purpose

Group customer-facing services.

## Example categories

- Tax
- Corporate
- Accounting
- Compliance
- Registration
- Advisory

## Fields

| Fieldname | Label | Type | Options / Link | Required |
|---|---|---|---|---|
| `category_name` | Category Name | Data | — | Yes |
| `slug` | Slug | Data | — | Yes |
| `description` | Description | Small Text | — | No |
| `icon` | Icon | Data | — | No |
| `sort_order` | Sort Order | Int | — | No |
| `is_active` | Is Active | Check | — | Yes |

---

# 7.4 OMC Service

## Purpose

Define services visible in Flutter service catalogue.

## Naming

```text
OMC-SERVICE-.#####
```

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `service_title` | Service Title | Data | — | Yes | App card title |
| `service_id` | Service ID | Data | — | Yes | Stable ID used by Flutter routing |
| `category` | Category | Link | OMC Service Category | Yes | Catalogue grouping |
| `short_description` | Short Description | Small Text | — | Yes | App list text |
| `long_description` | Long Description | Text Editor | — | No | Detail page |
| `icon` | Icon | Data | — | No | Flutter icon key |
| `price_type` | Price Type | Select | Free\nFixed\nStarting From\nCustom Quote | No | Optional |
| `base_price` | Base Price | Currency | — | No | Optional |
| `currency` | Currency | Link | Currency | No | Default PKR |
| `requires_documents` | Requires Documents | Check | — | No | Enables requirements |
| `allow_mobile_request` | Allow Mobile Request | Check | — | Yes | Hide from app if false |
| `is_featured` | Featured | Check | — | No | Home/catalogue highlight |
| `sort_order` | Sort Order | Int | — | No | App order |
| `is_active` | Is Active | Check | — | Yes | Active service only |

## Child table: required_documents

Child DocType: `OMC Service Required Document`

| Fieldname | Label | Type | Required | Notes |
|---|---|---|---|---|
| `document_type` | Document Type | Data | Yes | CNIC, NTN Certificate, Bank Statement, etc. |
| `description` | Description | Small Text | No | User-facing instructions |
| `is_required` | Required | Check | Yes | Hard requirement |
| `allowed_file_types` | Allowed File Types | Data | No | pdf,jpg,png |
| `max_file_size_mb` | Max File Size MB | Int | No | Default 10 |
| `sample_file` | Sample File | Attach | No | Optional example |

---

# 7.5 OMC Service Request

## Purpose

Customer service case created from the app or by staff.

## Naming

```text
OMC-SR-.YYYY.-.#####
```

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `title` | Title | Data | — | Yes | Display title |
| `service` | Service | Link | OMC Service | Yes | Requested service |
| `customer_profile` | Customer Profile | Link | OMC Customer Profile | No | Mobile profile |
| `customer` | Customer | Link | Customer | No | Existing customer |
| `lead` | Lead | Link | Lead | No | Prospect if no customer |
| `contact` | Contact | Link | Contact | No | Customer contact |
| `requested_by` | Requested By | Link | User | Yes | `frappe.session.user` |
| `assigned_to` | Assigned To | Link | User | No | Internal handler |
| `status` | Status | Select | Draft\nSubmitted\nOpen\nIn Review\nWaiting for Documents\nIn Progress\nCompleted\nCancelled\nRejected | Yes | App status |
| `priority` | Priority | Select | Low\nNormal\nHigh\nUrgent | No | Internal |
| `description` | Description | Text | — | No | Customer message |
| `customer_notes` | Customer Notes | Text | — | No | App-submitted details |
| `internal_notes` | Internal Notes | Text | — | No | Staff only |
| `progress` | Progress | Percent | — | No | App progress bar |
| `due_date` | Due Date | Date | — | No | SLA/client expected date |
| `completed_on` | Completed On | Datetime | — | No | Completion timestamp |
| `source` | Source | Select | Mobile App\nDesk\nWebsite\nWhatsApp | Yes | Origin |
| `external_reference` | External Reference | Data | — | No | Optional integration ref |

## Child table: documents

Child DocType: `OMC Service Request Document`

## Child table: timeline

Child DocType: `OMC Service Timeline`

## Permissions

| Role | Read | Create | Write | Delete |
|---|---:|---:|---:|---:|
| OMC Customer | Own only | Via API | Limited own fields via API | No |
| OMC Support Agent | Assigned/allowed | Yes | Yes | No |
| OMC Operations User | Assigned/allowed | No | Yes | No |
| OMC Mobile Admin | Yes | Yes | Yes | Yes |
| System Manager | Yes | Yes | Yes | Yes |

---

# 7.6 OMC Service Request Document

## Purpose

Track required, submitted, approved, or missing documents for each service request.

## Parent

Usually child table under `OMC Service Request`.

Can also be standalone if team wants each document row independently searchable.

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `document_type` | Document Type | Data | — | Yes | CNIC, NTN, etc. |
| `description` | Description | Small Text | — | No | User instructions |
| `status` | Status | Select | Required\nSubmitted\nApproved\nRejected\nMissing\nExpired | Yes | App document status |
| `is_required` | Required | Check | — | Yes | Required document |
| `file` | File | Link | File | No | Uploaded file |
| `file_url` | File URL | Data | — | No | Convenience for API |
| `uploaded_by` | Uploaded By | Link | User | No | App/staff user |
| `uploaded_on` | Uploaded On | Datetime | — | No | Upload timestamp |
| `reviewed_by` | Reviewed By | Link | User | No | Staff reviewer |
| `reviewed_on` | Reviewed On | Datetime | — | No | Review timestamp |
| `review_notes` | Review Notes | Small Text | — | No | Rejection/approval notes |
| `allowed_file_types` | Allowed File Types | Data | — | No | pdf,jpg,png |
| `max_file_size_mb` | Max File Size MB | Int | — | No | Default 10 |

---

# 7.7 OMC Service Timeline

## Purpose

Show user-friendly tracking in app.

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `event_title` | Event Title | Data | — | Yes | Example: Request Submitted |
| `event_message` | Event Message | Small Text | — | No | User-facing message |
| `event_type` | Event Type | Select | Info\nSuccess\nWarning\nError\nInternal | Yes | App icon/color |
| `status` | Status | Select | Pending\nCompleted\nSkipped | No | Timeline state |
| `visible_to_customer` | Visible To Customer | Check | — | Yes | Hide internal events |
| `created_by_user` | Created By User | Link | User | No | Actor |
| `created_on` | Created On | Datetime | — | Yes | Event time |

---

# 7.8 OMC Notification

## Purpose

Show mobile notifications and optionally send push notifications.

## Naming

```text
OMC-NOTIF-.YYYY.-.#####
```

## Fields

| Fieldname | Label | Type | Options / Link | Required | Notes |
|---|---|---|---|---|---|
| `user` | User | Link | User | Yes | Target user |
| `customer_profile` | Customer Profile | Link | OMC Customer Profile | No | Optional |
| `title` | Title | Data | — | Yes | Notification title |
| `message` | Message | Small Text | — | Yes | Notification body |
| `type` | Type | Select | Service\nDocument\nPayment\nSupport\nSystem\nKnowledge | Yes | App grouping |
| `reference_doctype` | Reference DocType | Data | — | No | Related doctype |
| `reference_name` | Reference Name | Dynamic Link | reference_doctype | No | Related doc |
| `action_route` | Action Route | Data | — | No | App route, e.g. `/services/SR-0001` |
| `action_url` | Action URL | Data | — | No | External URL |
| `is_read` | Is Read | Check | — | Yes | Mark-read state |
| `read_on` | Read On | Datetime | — | No | Timestamp |
| `send_push` | Send Push | Check | — | No | Push requested |
| `push_sent` | Push Sent | Check | — | No | Push delivered to provider |
| `created_at` | Created At | Datetime | — | Yes | API display |

---

# 7.9 OMC Customer Document

## Purpose

Customer-level document vault independent of one service request.

Use this for reusable documents like:

- CNIC front/back
- NTN certificate
- Company incorporation certificate
- Bank details
- Tax documents
- Authorization letters

## Fields

| Fieldname | Label | Type | Options / Link | Required |
|---|---|---|---|---|
| `customer_profile` | Customer Profile | Link | OMC Customer Profile | Yes |
| `customer` | Customer | Link | Customer | No |
| `document_title` | Document Title | Data | — | Yes |
| `document_type` | Document Type | Select/Data | — | Yes |
| `file` | File | Link | File | Yes |
| `file_url` | File URL | Data | — | No |
| `status` | Status | Select | Active\nExpired\nRejected\nArchived | Yes |
| `expiry_date` | Expiry Date | Date | — | No |
| `uploaded_by` | Uploaded By | Link | User | No |
| `uploaded_on` | Uploaded On | Datetime | — | No |
| `notes` | Notes | Small Text | — | No |

---

# 7.10 OMC Knowledge Article

## Purpose

Backend-driven knowledge/news module.

## Fields

| Fieldname | Label | Type | Options / Link | Required |
|---|---|---|---|---|
| `title` | Title | Data | — | Yes |
| `slug` | Slug | Data | — | Yes |
| `category` | Category | Data/Link | — | No |
| `summary` | Summary | Small Text | — | No |
| `content` | Content | Text Editor | — | No |
| `cover_image` | Cover Image | Attach Image | — | No |
| `external_url` | External URL | Data | — | No |
| `published_on` | Published On | Datetime | — | No |
| `is_published` | Is Published | Check | — | Yes |
| `sort_order` | Sort Order | Int | — | No |
| `visibility` | Visibility | Select | Public\nCustomers\nInternal | Yes |

---

# 7.11 OMC Support Ticket

## Purpose

Support requests from mobile app.

Can alternatively map to ERPNext `Issue` if OMC already uses it.

## Recommended approach

If ERPNext `Issue` is already used by OMC support, use `Issue` and add mobile-specific fields.

If not, create `OMC Support Ticket`.

## Fields

| Fieldname | Label | Type | Options / Link | Required |
|---|---|---|---|---|
| `subject` | Subject | Data | — | Yes |
| `message` | Message | Text | — | Yes |
| `category` | Category | Select | General\nService\nPayment\nDocument\nTechnical | Yes |
| `user` | User | Link | User | Yes |
| `customer_profile` | Customer Profile | Link | OMC Customer Profile | No |
| `customer` | Customer | Link | Customer | No |
| `service_request` | Service Request | Link | OMC Service Request | No |
| `status` | Status | Select | Open\nIn Progress\nClosed | Yes |
| `priority` | Priority | Select | Low\nNormal\nHigh | No |
| `assigned_to` | Assigned To | Link | User | No |
| `source` | Source | Select | Mobile App\nDesk\nWebsite | Yes |

---

## 8. Existing ERPNext DocTypes to Reuse

Do not duplicate these unless there is a strong reason:

| ERPNext/Frappe DocType | Use |
|---|---|
| `User` | Login identity |
| `Role` | Access control |
| `Customer` | Existing OMC customer |
| `Lead` | New prospect from app |
| `Contact` | Email/phone/person info |
| `Address` | Customer address |
| `Sales Invoice` | Customer invoices/payables |
| `Payment Entry` | Payments received |
| `File` | Uploaded documents/receipts |
| `Communication` | Comments/emails/support communication |
| `ToDo` or `Task` | Internal follow-up tasks |
| `Issue` | Support tickets if already used |

---

## 9. API Response Standard

Flutter should receive consistent JSON.

### General success response

```json
{
  "message": {
    "success": true,
    "data": {}
  }
}
```

### List response

```json
{
  "message": {
    "items": []
  }
}
```

Module-specific list aliases are also okay because the current Flutter repositories already accept some aliases:

```json
{
  "message": {
    "services": []
  }
}
```

```json
{
  "message": {
    "cases": []
  }
}
```

```json
{
  "message": {
    "documents": []
  }
}
```

```json
{
  "message": {
    "payments": []
  }
}
```

### Error response

Raise user-safe Frappe errors:

```python
frappe.throw("You do not have permission to view this record.")
```

Avoid exposing raw SQL/Python errors to the app.

---

## 10. API Methods Required by Flutter

Base path:

```text
/api/method/<method_name>
```

Recommended final namespace if backend app is named `omc_app`:

```text
omc_app.api.mobile
```

---

# 10.1 Auth APIs

## `omc_app.api.mobile.sign_up`

### Purpose

Create a Frappe user and customer profile from mobile signup.

### Request

```json
{
  "full_name": "Customer Name",
  "email": "customer@example.com",
  "password": "strong-password",
  "mobile_no": "03001234567",
  "company_name": "ABC Pvt Ltd",
  "cnic": "",
  "ntn": ""
}
```

### Backend behavior

1. Validate email/password.
2. Create disabled or limited Frappe `User`.
3. Assign role `OMC Customer`.
4. Create `OMC Customer Profile`.
5. Attempt Contact/Customer match.
6. If match found:
   - Store possible customer/contact link.
   - Keep pending unless auto-approval is explicitly enabled.
7. If no match:
   - Create/link `Lead`.
8. Return profile status and next step.

### Response

```json
{
  "message": {
    "success": true,
    "user": "customer@example.com",
    "profile": "OMC-PROF-2026-00001",
    "status": "Pending Verification",
    "verification_status": "Unverified",
    "next_step": "Your account is created. OMC team will verify your profile."
  }
}
```

---

## `omc_app.api.mobile.get_session_user`

### Purpose

Return current authenticated user and access flags.

### Response

```json
{
  "message": {
    "user": "customer@example.com",
    "full_name": "Customer Name",
    "roles": ["OMC Customer"],
    "profile_status": "Active",
    "customer": "CUST-0001",
    "is_customer": true,
    "is_internal": false,
    "can_access_internal_workspace": false
  }
}
```

---

## `omc_app.api.mobile.logout`

### Purpose

Invalidate device/session if needed.

Frappe already handles session logout, but this can deactivate mobile device tokens.

### Request

```json
{
  "device_id": "android-device-id"
}
```

---

# 10.2 Profile APIs

## `omc_app.api.mobile.get_profile`

### Purpose

Return logged-in user's profile and customer linkage.

### Response

```json
{
  "message": {
    "full_name": "Customer Name",
    "email": "customer@example.com",
    "phone": "03001234567",
    "avatar_url": "",
    "customer_id": "CUST-0001",
    "customer_name": "ABC Pvt Ltd",
    "profile_status": "Active",
    "verification_status": "Manually Approved",
    "cnic": "",
    "ntn": "",
    "city": "Karachi"
  }
}
```

## `omc_app.api.mobile.update_profile`

### Purpose

Allow customer to update safe profile fields.

### Editable fields

- full_name
- mobile_no
- phone
- city
- company_name

Do not allow app user to directly change:

- linked customer
- status
- verification_status
- roles

---

## `omc_app.api.mobile.update_contact_info`

### Purpose

Update phone/email change requests.

### Important

Changing email/mobile should not instantly relink customer data. If email/phone changes, mark profile for re-verification.

---

# 10.3 Dashboard APIs

## `omc_app.api.mobile.get_dashboard_data`

### Purpose

Customer home dashboard.

### Backend filter

```text
current user → active customer profile → linked customer
```

### Response

```json
{
  "message": {
    "open_services": 3,
    "documents": 8,
    "payments_due": 2,
    "notifications": 4,
    "profile_status": "Active",
    "recent_activity": [
      {
        "title": "Tax Filing request updated",
        "message": "Your documents are under review.",
        "date": "2026-07-05",
        "route": "/services/OMC-SR-2026-00001"
      }
    ],
    "pending_actions": [
      {
        "type": "document",
        "title": "Upload CNIC copy",
        "reference": "OMC-SR-2026-00001",
        "route": "/services/OMC-SR-2026-00001"
      }
    ]
  }
}
```

### Pending profile response

If user is not yet linked:

```json
{
  "message": {
    "open_services": 0,
    "documents": 0,
    "payments_due": 0,
    "notifications": 0,
    "profile_status": "Pending Verification",
    "recent_activity": [],
    "pending_actions": [
      {
        "type": "verification",
        "title": "Profile verification pending",
        "message": "OMC team will verify your account before customer records appear."
      }
    ]
  }
}
```

---

# 10.4 Service Catalogue APIs

## `omc_app.api.mobile.get_service_catalogue`

### Purpose

Return active mobile-enabled services.

### Response

```json
{
  "message": {
    "services": [
      {
        "id": "tax-filing",
        "name": "OMC-SERVICE-0001",
        "title": "Tax Filing",
        "description": "Professional tax filing support",
        "category": "Tax",
        "icon": "receipt",
        "is_featured": true,
        "price_type": "Custom Quote",
        "base_price": 0,
        "currency": "PKR"
      }
    ]
  }
}
```

### Rules

- Only return `allow_mobile_request = 1`.
- Only return `is_active = 1`.
- `id` must be stable because Flutter routes and service draft flow depend on it.

---

## `omc_app.api.mobile.get_service_detail`

### Purpose

Return service detail and document requirements.

### Request

```json
{
  "service_id": "tax-filing"
}
```

### Response

```json
{
  "message": {
    "id": "tax-filing",
    "name": "OMC-SERVICE-0001",
    "title": "Tax Filing",
    "description": "Professional tax filing support",
    "long_description": "Detailed service explanation...",
    "category": "Tax",
    "required_documents": [
      {
        "document_type": "CNIC",
        "description": "Upload clear CNIC copy",
        "is_required": true,
        "allowed_file_types": "pdf,jpg,png",
        "max_file_size_mb": 10
      }
    ]
  }
}
```

---

# 10.5 Service Request APIs

## `omc_app.api.mobile.create_service`

### Purpose

Create a new mobile service request.

### Request

```json
{
  "service_id": "tax-filing",
  "title": "Tax Filing Request",
  "description": "Need help with annual tax filing.",
  "customer_notes": "Business filer",
  "cnic": "",
  "ntn": "",
  "metadata": {
    "tax_year": "2026",
    "business_type": "Individual"
  }
}
```

### Backend behavior

1. Require login.
2. Get current customer profile.
3. Allow request even if profile is pending.
4. If profile has linked customer, set `customer`.
5. If profile has linked lead only, set `lead`.
6. Create `OMC Service Request`.
7. Copy required documents from `OMC Service`.
8. Add timeline row: `Request Submitted`.
9. Create notification.
10. Return created request ID.

### Response

```json
{
  "message": {
    "success": true,
    "name": "OMC-SR-2026-00001",
    "status": "Submitted",
    "title": "Tax Filing Request"
  }
}
```

---

## `omc_app.api.mobile.get_service_cases`

### Purpose

Return user's service requests for My Services.

### Customer response

```json
{
  "message": {
    "cases": [
      {
        "name": "OMC-SR-2026-00001",
        "title": "Tax Filing Request",
        "status": "In Progress",
        "service": "Tax Filing",
        "progress": 45,
        "created_at": "2026-07-05",
        "updated_at": "2026-07-05",
        "due_date": "2026-07-20",
        "pending_documents": 1
      }
    ]
  }
}
```

### Rules

For customer users:

```text
Only return service requests where:
requested_by = frappe.session.user
OR customer_profile.user = frappe.session.user
OR customer = active_profile.customer
```

For internal users:

```text
Return assigned / allowed service cases based on role.
```

---

## `omc_app.api.mobile.get_service_case`

### Request

```json
{
  "case_id": "OMC-SR-2026-00001"
}
```

### Response

```json
{
  "message": {
    "name": "OMC-SR-2026-00001",
    "title": "Tax Filing Request",
    "status": "In Progress",
    "service": "Tax Filing",
    "description": "Need help with annual tax filing.",
    "progress": 45,
    "created_at": "2026-07-05",
    "updated_at": "2026-07-05",
    "due_date": "2026-07-20",
    "timeline": [
      {
        "title": "Request Submitted",
        "message": "Your request has been received.",
        "status": "Completed",
        "created_at": "2026-07-05 10:30:00"
      }
    ],
    "required_documents": [
      {
        "name": "row-id",
        "document_type": "CNIC",
        "status": "Missing",
        "is_required": true,
        "description": "Upload clear CNIC copy",
        "file_url": ""
      }
    ],
    "attachments": [
      {
        "name": "FILE-0001",
        "title": "cnic.pdf",
        "file_url": "/files/cnic.pdf",
        "created_at": "2026-07-05"
      }
    ]
  }
}
```

---

## `omc_app.api.mobile.upload_service_document`

### Purpose

Attach uploaded Frappe `File` to service request document requirement.

### Request

```json
{
  "case_id": "OMC-SR-2026-00001",
  "document_type": "CNIC",
  "file_url": "/files/cnic.pdf",
  "file_name": "FILE-0001"
}
```

### Backend behavior

1. Check user can access service request.
2. Check file belongs to user or was uploaded against the request.
3. Update matching document row.
4. Set status `Submitted`.
5. Add timeline event.
6. Notify assigned staff if required.

---

# 10.6 File Upload Rules

Flutter can use Frappe standard upload method:

```text
/api/method/upload_file
```

Recommended upload parameters:

```text
doctype = OMC Service Request
docname = OMC-SR-2026-00001
fieldname = attachment
is_private = 1
```

### Important

- Customer documents should be private by default.
- File access should be checked through the linked service request/customer profile.
- Do not expose private file URLs unless the user has permission.

---

# 10.7 Documents APIs

## `omc_app.api.mobile.get_documents`

### Purpose

Return customer-level and service-level documents.

### Response

```json
{
  "message": {
    "documents": [
      {
        "name": "OMC-DOC-0001",
        "title": "CNIC Copy",
        "type": "CNIC",
        "status": "Active",
        "file_url": "/private/files/cnic.pdf",
        "service_request": "OMC-SR-2026-00001",
        "created_at": "2026-07-05",
        "expiry_date": ""
      }
    ]
  }
}
```

### Backend filter

For customer:

```text
profile.user = frappe.session.user
AND document.customer_profile = profile.name
```

For internal:

```text
role-based access
```

---

## `omc_app.api.mobile.get_document`

### Request

```json
{
  "name": "OMC-DOC-0001"
}
```

### Response

```json
{
  "message": {
    "name": "OMC-DOC-0001",
    "title": "CNIC Copy",
    "type": "CNIC",
    "status": "Active",
    "file_url": "/private/files/cnic.pdf",
    "uploaded_on": "2026-07-05",
    "service_request": "OMC-SR-2026-00001",
    "notes": ""
  }
}
```

---

# 10.8 Payments APIs

## `omc_app.api.mobile.get_payments`

### Purpose

Return customer invoices/payments from ERPNext.

### Recommended source

Use ERPNext:

```text
Sales Invoice
Payment Entry
Customer
```

### Response

```json
{
  "message": {
    "payments": [
      {
        "name": "ACC-SINV-2026-00001",
        "title": "Tax Filing Fee",
        "amount": 10000,
        "outstanding_amount": 10000,
        "paid_amount": 0,
        "currency": "PKR",
        "status": "Unpaid",
        "due_date": "2026-07-10",
        "invoice_url": "/app/sales-invoice/ACC-SINV-2026-00001",
        "receipt_url": "",
        "service_request": "OMC-SR-2026-00001"
      }
    ]
  }
}
```

### Backend filter

For customer:

```text
Sales Invoice.customer = active_profile.customer
```

Never return invoices for other customers.

---

## `omc_app.api.mobile.get_payment`

### Request

```json
{
  "name": "ACC-SINV-2026-00001"
}
```

### Response

```json
{
  "message": {
    "name": "ACC-SINV-2026-00001",
    "title": "Tax Filing Fee",
    "amount": 10000,
    "outstanding_amount": 10000,
    "paid_amount": 0,
    "currency": "PKR",
    "status": "Unpaid",
    "due_date": "2026-07-10",
    "items": [
      {
        "item_name": "Tax Filing",
        "qty": 1,
        "amount": 10000
      }
    ],
    "transactions": [],
    "attachments": []
  }
}
```

---

## `omc_app.api.mobile.upload_payment_receipt`

### Purpose

Allow customer to upload bank transfer/payment proof.

### Request

```json
{
  "invoice": "ACC-SINV-2026-00001",
  "file_url": "/private/files/payment-proof.jpg",
  "notes": "Paid through bank transfer"
}
```

### Backend behavior

1. Check invoice belongs to active customer.
2. Attach file to `Sales Invoice` or create `OMC Payment Receipt Upload`.
3. Notify Accounts team.
4. Do not mark invoice paid automatically unless client wants manual review bypass.

---

# 10.9 Notifications APIs

## `omc_app.api.mobile.get_notifications`

### Response

```json
{
  "message": {
    "notifications": [
      {
        "name": "OMC-NOTIF-2026-00001",
        "title": "Request updated",
        "message": "Your service request has been updated.",
        "type": "Service",
        "is_read": false,
        "created_at": "2026-07-05 10:30:00",
        "action_route": "/services/OMC-SR-2026-00001",
        "action_url": ""
      }
    ]
  }
}
```

## `omc_app.api.mobile.get_notification_detail`

### Request

```json
{
  "name": "OMC-NOTIF-2026-00001"
}
```

## `omc_app.api.mobile.mark_notification_read`

### Request

```json
{
  "name": "OMC-NOTIF-2026-00001"
}
```

### Response

```json
{
  "message": {
    "success": true
  }
}
```

---

# 10.10 Knowledge APIs

## `omc_app.api.mobile.get_knowledge`

### Response

```json
{
  "message": {
    "articles": [
      {
        "name": "ARTICLE-0001",
        "title": "Tax Filing Deadline",
        "summary": "Important tax filing update.",
        "category": "Tax",
        "cover_image": "/files/tax.jpg",
        "published_on": "2026-07-05",
        "external_url": ""
      }
    ]
  }
}
```

## `omc_app.api.mobile.get_knowledge_article`

### Request

```json
{
  "name": "ARTICLE-0001"
}
```

### Response

```json
{
  "message": {
    "name": "ARTICLE-0001",
    "title": "Tax Filing Deadline",
    "summary": "Important tax filing update.",
    "content": "<p>Article content...</p>",
    "category": "Tax",
    "cover_image": "/files/tax.jpg",
    "published_on": "2026-07-05",
    "external_url": ""
  }
}
```

---

# 10.11 Support APIs

## `omc_app.api.mobile.create_support_ticket`

### Request

```json
{
  "category": "Service",
  "subject": "Need help with my case",
  "message": "Please update me about my tax filing request.",
  "service_request": "OMC-SR-2026-00001"
}
```

### Response

```json
{
  "message": {
    "success": true,
    "name": "OMC-TICKET-2026-00001",
    "status": "Open"
  }
}
```

---

# 10.12 Settings APIs

## `omc_app.api.mobile.get_settings_preferences`

### Response

```json
{
  "message": {
    "push_notifications": true,
    "email_notifications": true,
    "sms_notifications": false,
    "marketing_updates": false
  }
}
```

## `omc_app.api.mobile.update_settings_preferences`

### Request

```json
{
  "push_notifications": true,
  "email_notifications": true,
  "sms_notifications": false,
  "marketing_updates": false
}
```

---

# 10.13 Internal Workspace APIs

Internal APIs must require internal roles.

## `omc_app.api.mobile.get_internal_workspace_summary`

### Response

```json
{
  "message": {
    "open_leads": 5,
    "active_customers": 120,
    "pending_tasks": 8,
    "payments_due": 15,
    "assigned_cases": 6
  }
}
```

## `omc_app.api.mobile.get_leads`

### Response

```json
{
  "message": {
    "leads": [
      {
        "name": "LEAD-0001",
        "title": "Website Inquiry",
        "customer_name": "Customer Name",
        "status": "New",
        "phone": "03001234567",
        "email": "lead@example.com",
        "source": "Mobile App",
        "created_at": "2026-07-05"
      }
    ]
  }
}
```

## `omc_app.api.mobile.get_customers`

### Response

```json
{
  "message": {
    "customers": [
      {
        "name": "CUST-0001",
        "customer_name": "ABC Pvt Ltd",
        "company_name": "ABC Pvt Ltd",
        "status": "Active",
        "phone": "03001234567",
        "email": "customer@example.com",
        "city": "Karachi",
        "last_activity": "2026-07-05"
      }
    ]
  }
}
```

## `omc_app.api.mobile.get_tasks`

### Response

```json
{
  "message": {
    "tasks": [
      {
        "name": "TASK-0001",
        "subject": "Follow up with customer",
        "status": "Open",
        "priority": "Normal",
        "due_date": "2026-07-10",
        "assigned_to": "staff@example.com"
      }
    ]
  }
}
```

---

## 11. Permission Helper Design

Create a central permission helper file:

```text
omc_app/api/permissions.py
```

### Required helpers

```python
import frappe

CUSTOMER_ROLE = "OMC Customer"

INTERNAL_ROLES = {
    "System Manager",
    "OMC Mobile Admin",
    "OMC Support Agent",
    "OMC Sales User",
    "OMC Accounts User",
    "OMC Operations User",
}


def current_user():
    user = frappe.session.user
    if not user or user == "Guest":
        frappe.throw("Please login to continue.")
    return user


def has_any_role(roles):
    user_roles = set(frappe.get_roles(frappe.session.user))
    return bool(user_roles.intersection(set(roles)))


def is_internal_user():
    return has_any_role(INTERNAL_ROLES)


def get_customer_profile(required=True, active_required=False):
    user = current_user()

    profile_name = frappe.db.get_value(
        "OMC Customer Profile",
        {"user": user},
        "name",
    )

    if not profile_name:
        if required:
            frappe.throw("Customer profile was not found.")
        return None

    profile = frappe.get_doc("OMC Customer Profile", profile_name)

    if active_required and profile.status != "Active":
        frappe.throw("Your profile is pending verification.")

    return profile


def get_active_customer(required=True):
    profile = get_customer_profile(required=required, active_required=True)
    if not profile:
        return None

    if not profile.customer:
        if required:
            frappe.throw("No customer account is linked to your profile yet.")
        return None

    return profile.customer


def assert_service_case_access(case_name):
    user = current_user()

    if is_internal_user():
        return frappe.get_doc("OMC Service Request", case_name)

    profile = get_customer_profile(required=True, active_required=False)
    doc = frappe.get_doc("OMC Service Request", case_name)

    allowed = (
        doc.requested_by == user
        or doc.customer_profile == profile.name
        or (profile.customer and doc.customer == profile.customer)
    )

    if not allowed:
        frappe.throw("You do not have permission to view this service request.")

    return doc


def assert_invoice_access(invoice_name):
    if is_internal_user():
        return frappe.get_doc("Sales Invoice", invoice_name)

    customer = get_active_customer(required=True)

    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    if invoice.customer != customer:
        frappe.throw("You do not have permission to view this invoice.")

    return invoice
```

---

## 12. Serializer Design

Create:

```text
omc_app/api/serializers.py
```

### Example serializers

```python
def service_case_row(doc):
    return {
        "name": doc.name,
        "title": doc.title or doc.name,
        "status": doc.status or "",
        "service": doc.service or "",
        "progress": doc.progress or 0,
        "created_at": str(doc.creation.date()) if doc.creation else "",
        "updated_at": str(doc.modified.date()) if doc.modified else "",
        "due_date": str(doc.due_date) if doc.due_date else "",
        "pending_documents": count_pending_documents(doc),
    }


def document_row(doc):
    return {
        "name": doc.name,
        "title": doc.document_title or doc.name,
        "type": doc.document_type or "",
        "status": doc.status or "",
        "file_url": doc.file_url or "",
        "created_at": str(doc.creation.date()) if doc.creation else "",
        "expiry_date": str(doc.expiry_date) if doc.expiry_date else "",
    }


def payment_row(invoice):
    return {
        "name": invoice.name,
        "title": invoice.get("title") or invoice.name,
        "amount": invoice.grand_total or 0,
        "outstanding_amount": invoice.outstanding_amount or 0,
        "paid_amount": (invoice.grand_total or 0) - (invoice.outstanding_amount or 0),
        "currency": invoice.currency or "PKR",
        "status": invoice.status or "",
        "due_date": str(invoice.due_date) if invoice.due_date else "",
    }
```

---

## 13. Example `mobile.py` API Skeleton

```python
import frappe
from frappe.utils import now_datetime

from omc_app.api.permissions import (
    current_user,
    get_customer_profile,
    get_active_customer,
    is_internal_user,
    assert_service_case_access,
    assert_invoice_access,
)
from omc_app.api.serializers import service_case_row, document_row, payment_row


@frappe.whitelist()
def get_profile():
    profile = get_customer_profile(required=False)

    user = frappe.get_doc("User", frappe.session.user)

    if not profile:
        return {
            "full_name": user.full_name or "",
            "email": user.email or frappe.session.user,
            "phone": "",
            "avatar_url": user.user_image or "",
            "customer_id": "",
            "customer_name": "",
            "profile_status": "Missing",
            "verification_status": "Unverified",
        }

    customer_name = ""
    if profile.customer:
        customer_name = frappe.db.get_value("Customer", profile.customer, "customer_name") or ""

    return {
        "full_name": profile.full_name or user.full_name or "",
        "email": profile.email or user.email or frappe.session.user,
        "phone": profile.mobile_no or profile.phone or "",
        "avatar_url": user.user_image or "",
        "customer_id": profile.customer or "",
        "customer_name": customer_name,
        "profile_status": profile.status or "",
        "verification_status": profile.verification_status or "",
        "cnic": profile.cnic or "",
        "ntn": profile.ntn or "",
        "city": profile.city or "",
    }


@frappe.whitelist()
def get_service_catalogue():
    services = frappe.get_all(
        "OMC Service",
        filters={"is_active": 1, "allow_mobile_request": 1},
        fields=[
            "name",
            "service_id",
            "service_title",
            "short_description",
            "category",
            "icon",
            "is_featured",
            "price_type",
            "base_price",
            "currency",
        ],
        order_by="sort_order asc, service_title asc",
    )

    return {
        "services": [
            {
                "id": row.service_id or row.name,
                "name": row.name,
                "title": row.service_title or row.name,
                "description": row.short_description or "",
                "category": row.category or "",
                "icon": row.icon or "",
                "is_featured": bool(row.is_featured),
                "price_type": row.price_type or "",
                "base_price": row.base_price or 0,
                "currency": row.currency or "PKR",
            }
            for row in services
        ]
    }


@frappe.whitelist()
def create_service(service_id, title=None, description=None, customer_notes=None, metadata=None, **kwargs):
    user = current_user()
    profile = get_customer_profile(required=True, active_required=False)

    service_name = frappe.db.get_value(
        "OMC Service",
        {"service_id": service_id, "is_active": 1, "allow_mobile_request": 1},
        "name",
    )

    if not service_name:
        frappe.throw("Selected service is not available.")

    service = frappe.get_doc("OMC Service", service_name)

    doc = frappe.new_doc("OMC Service Request")
    doc.title = title or service.service_title
    doc.service = service.name
    doc.customer_profile = profile.name
    doc.customer = profile.customer or None
    doc.lead = profile.lead or None
    doc.contact = profile.contact or None
    doc.requested_by = user
    doc.status = "Submitted"
    doc.description = description or ""
    doc.customer_notes = customer_notes or ""
    doc.source = "Mobile App"
    doc.progress = 0

    for req in service.get("required_documents", []):
        doc.append("documents", {
            "document_type": req.document_type,
            "description": req.description,
            "status": "Missing" if req.is_required else "Required",
            "is_required": req.is_required,
            "allowed_file_types": req.allowed_file_types,
            "max_file_size_mb": req.max_file_size_mb,
        })

    doc.append("timeline", {
        "event_title": "Request Submitted",
        "event_message": "Your request has been received.",
        "event_type": "Success",
        "status": "Completed",
        "visible_to_customer": 1,
        "created_by_user": user,
        "created_on": now_datetime(),
    })

    doc.insert(ignore_permissions=True)

    return {
        "success": True,
        "name": doc.name,
        "status": doc.status,
        "title": doc.title,
    }


@frappe.whitelist()
def get_service_cases():
    user = current_user()

    if is_internal_user():
        filters = {}
    else:
        profile = get_customer_profile(required=True, active_required=False)
        filters = {"customer_profile": profile.name}

    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=["name"],
        order_by="modified desc",
        limit_page_length=100,
    )

    cases = []
    for row in rows:
        doc = frappe.get_doc("OMC Service Request", row.name)
        cases.append(service_case_row(doc))

    return {"cases": cases}


@frappe.whitelist()
def get_service_case(case_id):
    doc = assert_service_case_access(case_id)

    timeline = []
    for row in doc.get("timeline", []):
        if not row.visible_to_customer and not is_internal_user():
            continue
        timeline.append({
            "title": row.event_title or "",
            "message": row.event_message or "",
            "status": row.status or "",
            "created_at": str(row.created_on) if row.created_on else "",
        })

    required_documents = []
    for row in doc.get("documents", []):
        required_documents.append({
            "name": row.name,
            "document_type": row.document_type or "",
            "status": row.status or "",
            "is_required": bool(row.is_required),
            "description": row.description or "",
            "file_url": row.file_url or "",
        })

    return {
        "name": doc.name,
        "title": doc.title or doc.name,
        "status": doc.status or "",
        "service": doc.service or "",
        "description": doc.description or "",
        "progress": doc.progress or 0,
        "created_at": str(doc.creation.date()) if doc.creation else "",
        "updated_at": str(doc.modified.date()) if doc.modified else "",
        "due_date": str(doc.due_date) if doc.due_date else "",
        "timeline": timeline,
        "required_documents": required_documents,
        "attachments": [],
    }


@frappe.whitelist()
def get_payments():
    customer = get_active_customer(required=True)

    invoices = frappe.get_all(
        "Sales Invoice",
        filters={"customer": customer, "docstatus": ["!=", 2]},
        fields=[
            "name",
            "title",
            "grand_total",
            "outstanding_amount",
            "currency",
            "status",
            "due_date",
        ],
        order_by="posting_date desc",
        limit_page_length=100,
    )

    return {
        "payments": [
            {
                "name": inv.name,
                "title": inv.title or inv.name,
                "amount": inv.grand_total or 0,
                "outstanding_amount": inv.outstanding_amount or 0,
                "paid_amount": (inv.grand_total or 0) - (inv.outstanding_amount or 0),
                "currency": inv.currency or "PKR",
                "status": inv.status or "",
                "due_date": str(inv.due_date) if inv.due_date else "",
            }
            for inv in invoices
        ]
    }


@frappe.whitelist()
def mark_notification_read(name):
    user = current_user()

    notification = frappe.get_doc("OMC Notification", name)

    if notification.user != user and not is_internal_user():
        frappe.throw("You do not have permission to update this notification.")

    notification.is_read = 1
    notification.read_on = now_datetime()
    notification.save(ignore_permissions=True)

    return {"success": True}
```

---

## 14. Signup Flow

### 14.1 New user signup

```text
Mobile App
  ↓
sign_up API
  ↓
Create User
  ↓
Assign OMC Customer role
  ↓
Create OMC Customer Profile
  ↓
Try Contact/Customer match
  ↓
If no customer: create/link Lead
  ↓
Return status Pending Verification / Prospect
```

### 14.2 Existing customer signup/login

```text
User signs up or logs in
  ↓
Backend detects matching Contact/Customer
  ↓
OMC Customer Profile stores suggested match
  ↓
Admin approves
  ↓
Profile.status = Active
  ↓
App unlocks customer-specific modules
```

### 14.3 Existing Frappe user login

```text
User logs in
  ↓
get_session_user
  ↓
Check roles
  ↓
Check OMC Customer Profile
  ↓
Return access flags
  ↓
Flutter shows correct dashboard/modules
```

---

## 15. Service Request Workflow

```text
Customer selects service
  ↓
Flutter opens service draft
  ↓
Customer fills form
  ↓
create_service API
  ↓
OMC Service Request created
  ↓
Required document rows copied from service setup
  ↓
Timeline event added
  ↓
Notifications created
  ↓
Customer uploads files
  ↓
Files attached to service request
  ↓
Staff reviews documents
  ↓
Status moves through workflow
  ↓
Customer sees tracking updates
```

### Recommended statuses

| Status | Meaning |
|---|---|
| Draft | Created but not submitted |
| Submitted | Submitted by customer |
| Open | Accepted by OMC |
| Waiting for Documents | Customer action required |
| In Review | OMC reviewing documents/details |
| In Progress | Service execution active |
| Completed | Service completed |
| Cancelled | Cancelled by customer/admin |
| Rejected | OMC rejected request |

---

## 16. Document Workflow

```text
Service has required documents
  ↓
Service request copies required documents
  ↓
Customer uploads file
  ↓
File attaches to service request
  ↓
Document row status = Submitted
  ↓
Staff approves/rejects
  ↓
If rejected, customer uploads replacement
  ↓
Timeline and notifications update
```

### Document statuses

| Status | Meaning |
|---|---|
| Required | Document is listed but optional or not yet requested |
| Missing | Required and not uploaded |
| Submitted | Uploaded, waiting review |
| Approved | Accepted |
| Rejected | Needs replacement |
| Expired | Old document no longer valid |

---

## 17. Payment Workflow

```text
ERPNext Sales Invoice created for Customer
  ↓
Mobile get_payments returns invoice
  ↓
Customer sees pending amount
  ↓
Customer pays externally / bank transfer
  ↓
Customer uploads receipt
  ↓
Receipt attaches to invoice or payment upload doctype
  ↓
Accounts reviews
  ↓
Payment Entry posted in ERPNext
  ↓
Invoice status/outstanding updates
  ↓
App shows updated payment status
```

### Important

Do not automatically mark invoices as paid based only on uploaded receipt unless client explicitly wants this and has fraud controls.

---

## 18. Notification Workflow

Create `OMC Notification` when:

- Service request is created.
- Service request status changes.
- Staff requests missing documents.
- Document is approved/rejected.
- Invoice/payment is created or updated.
- Support ticket receives reply.
- Important tax/knowledge update is published.

### Notification routes

| Reference | Route |
|---|---|
| Service Request | `/services/<case_id>` |
| Payment | `/payments/<invoice_id>` |
| Document | `/documents/<document_id>` |
| Knowledge | `/knowledge/<article_id>` |
| Support | `/support/<ticket_id>` |

---

## 19. Security Checklist

### Authentication

- Use Frappe login/session.
- Do not store password.
- Flutter should store session/token only in secure storage.
- Production API base URL must use HTTPS.

### Authorization

Every whitelisted method must call one of:

```python
current_user()
get_customer_profile()
get_active_customer()
assert_service_case_access()
assert_invoice_access()
is_internal_user()
```

### Data access

- Customer APIs must filter by active linked customer/profile.
- Internal APIs must require internal roles.
- Private files must not be exposed without permission check.

### Signup safety

- Do not activate customer data access only through email/phone match.
- Use pending verification or admin approval.
- Log linking decisions.

### Error safety

- Return clean messages.
- Do not expose tracebacks, SQL errors, or internal table names to app users.

### Audit

Track:

- signup
- login/device registration
- customer linking
- service request creation
- file upload
- payment receipt upload
- admin approval/rejection
- status changes

---

## 20. Flutter Mapping

Current Flutter config already centralizes method names in:

```text
lib/core/config/api_config.dart
```

Backend should implement or Flutter should map these methods:

| Flutter Config Method | Backend Method |
|---|---|
| `signUpMethod` | `omc_app.api.mobile.sign_up` |
| `dashboardDataMethod` | `omc_app.api.mobile.get_dashboard_data` |
| `serviceCatalogueMethod` | `omc_app.api.mobile.get_service_catalogue` |
| `createServiceMethod` | `omc_app.api.mobile.create_service` |
| `serviceCasesMethod` | `omc_app.api.mobile.get_service_cases` |
| `serviceCaseDetailMethod` | `omc_app.api.mobile.get_service_case` |
| `documentsMethod` | `omc_app.api.mobile.get_documents` |
| `documentDetailMethod` | `omc_app.api.mobile.get_document` |
| `paymentsMethod` | `omc_app.api.mobile.get_payments` |
| `paymentDetailMethod` | `omc_app.api.mobile.get_payment` |
| `profileMethod` | `omc_app.api.mobile.get_profile` |
| `updateProfileMethod` | `omc_app.api.mobile.update_profile` |
| `knowledgeMethod` | `omc_app.api.mobile.get_knowledge` |
| `knowledgeDetailMethod` | `omc_app.api.mobile.get_knowledge_article` |
| `notificationsMethod` | `omc_app.api.mobile.get_notifications` |
| `notificationDetailMethod` | `omc_app.api.mobile.get_notification_detail` |
| `markNotificationReadMethod` | `omc_app.api.mobile.mark_notification_read` |
| `settingsPreferencesMethod` | `omc_app.api.mobile.get_settings_preferences` |
| `updateSettingsPreferencesMethod` | `omc_app.api.mobile.update_settings_preferences` |
| `createSupportTicketMethod` | `omc_app.api.mobile.create_support_ticket` |
| `internalWorkspaceSummaryMethod` | `omc_app.api.mobile.get_internal_workspace_summary` |
| `leadsMethod` | `omc_app.api.mobile.get_leads` |
| `leadDetailMethod` | `omc_app.api.mobile.get_lead` |
| `customersMethod` | `omc_app.api.mobile.get_customers` |
| `customerDetailMethod` | `omc_app.api.mobile.get_customer` |
| `tasksMethod` | `omc_app.api.mobile.get_tasks` |
| `taskDetailMethod` | `omc_app.api.mobile.get_task` |

---

## 21. Implementation Phases

### Phase 1 — Backend app skeleton

- Create Frappe app `omc_app` or `omc_mobile`.
- Add roles.
- Add API module.
- Add permission helpers.
- Add serializer helpers.
- Add empty/test-safe endpoints.

Exit:

- All method paths respond.
- Flutter can call endpoints without 404.
- Unauthorized calls fail safely.

---

### Phase 2 — Identity and signup

- Create `OMC Customer Profile`.
- Implement `sign_up`.
- Implement profile matching.
- Implement admin approval workflow.
- Implement `get_profile`.
- Implement `get_session_user`.

Exit:

- New user signup creates Frappe user/profile.
- Existing customer can be linked.
- Pending users do not see private customer data.

---

### Phase 3 — Service catalogue and requests

- Create `OMC Service Category`.
- Create `OMC Service`.
- Create `OMC Service Request`.
- Create document/timeline child tables.
- Implement catalogue/list/detail/create APIs.

Exit:

- User can browse services.
- User can submit a real service request.
- My Services shows real records.

---

### Phase 4 — Documents and uploads

- Wire Frappe `upload_file`.
- Add `upload_service_document`.
- Add `OMC Customer Document`.
- Implement documents list/detail.

Exit:

- User can upload required docs.
- Staff can review docs.
- App shows missing/submitted/approved/rejected states.

---

### Phase 5 — Payments

- Connect `Sales Invoice`.
- Connect `Payment Entry`.
- Add payment receipt upload.
- Implement payment list/detail.

Exit:

- Customer sees only own invoices/payments.
- Receipt upload notifies accounts.

---

### Phase 6 — Notifications and settings

- Create `OMC Notification`.
- Implement notification list/detail/read.
- Implement settings preferences.
- Add mobile device registration if push notifications are needed.

Exit:

- App receives and shows backend notifications.
- Mark-read works.

---

### Phase 7 — Internal workspace

- Implement role-gated internal summary.
- Implement leads/customers/tasks APIs.
- Add assigned-case/task filters.

Exit:

- Customer cannot access internal endpoints.
- Internal staff sees only allowed operational data.

---

### Phase 8 — Production hardening

- Review permissions.
- Review private file access.
- Review rate limiting/sign-up abuse controls.
- Remove debug logs.
- Add server logs/audit.
- Test all Flutter flows with real backend.

Exit:

- App works end-to-end against real Frappe.
- No production mock data.
- No customer data leakage.

---

## 22. Recommended First Backend Milestone

Build these first:

1. Roles
2. `OMC Customer Profile`
3. `OMC Service Category`
4. `OMC Service`
5. `OMC Service Request`
6. `OMC Service Request Document`
7. `OMC Service Timeline`
8. API helpers:
   - `permissions.py`
   - `serializers.py`
9. APIs:
   - `sign_up`
   - `get_profile`
   - `get_dashboard_data`
   - `get_service_catalogue`
   - `create_service`
   - `get_service_cases`
   - `get_service_case`

This unlocks the main app journey:

```text
signup/login
  ↓
profile
  ↓
service catalogue
  ↓
create service request
  ↓
track My Services
  ↓
upload missing documents
```

Payments, notifications, knowledge, support, and internal workspace can be layered after this without breaking architecture.

---

## 23. Final Approval Summary

This guide locks the correct backend model:

```text
Frappe User for login
+ OMC Customer Profile for identity bridge
+ ERPNext Customer/Lead/Contact for business identity
+ Custom OMC Service Request flow for mobile services
+ ERPNext Sales Invoice/Payment Entry/File reuse for finance/files
+ Strict role/profile/customer-based filtering on every API
```

This is the safest and cleanest design for OMC:

- Existing customers see their own ERP-backed data.
- New users can sign up and request services.
- Admin controls linking and access from Frappe.
- Flutter remains backend-connected and production-ready.
- Backend stays modular, maintainable, and scalable.
