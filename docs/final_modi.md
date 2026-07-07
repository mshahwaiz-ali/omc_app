# OMC House App — Merged Structure, Upgrade Plan & Local Patch Steps

Last merged: **2026-07-07**  
Target workflow: **local work only, single branch: `main`**  
Source docs merged safely:

- `omc_detailed_explanation(1).md`
- `gpt_text.md`
- `modi_for_codex(1).md`

---

## 0. Purpose of This File

This file is the clean single source of truth for the next OMC House app work.

It merges:

1. Existing client-facing explanation and app workflow.
2. Guest mode + signup approval + backend-driven content plan.
3. Existing roadmap and technical status notes.
4. New UI/UX/backend upgrade ideas requested for a more premium app.
5. Local-only Git workflow using only the `main` branch.
6. Step-by-step patches to apply safely.

This file does **not** claim that code has already been changed. It is a structured implementation plan.

---

## 1. Final Product Direction

OMC House mobile app should be a premium customer service and compliance portal.

### One-line pitch

**OMC House App is a customer service + compliance portal where users can explore OMC services, sign up, submit service requests, upload documents, track progress, manage support, view notifications, use tax/expense tools, and where the OMC team controls operations from the Frappe backend.**

### Core principle

```text
Flutter app = clean customer experience
Frappe backend = real business rules, permissions, content, service data, staff operations
```

The app must not depend on hardcoded production behavior. The backend should control services, roles, permissions, feature flags, content, support topics, payments, announcements, and customer access.

---

## 2. Safe Merge Summary

### What was kept

- Client-facing explanation of app modules.
- Guest mode plan.
- Signup approval model.
- Consultant / Tax Associate / Business Partner approval rules.
- Role-based backend permission requirement.
- Backend-driven services, knowledge, news, tax alerts, subscription content.
- Existing app/module status.
- Local verification steps.
- UI/UX upgrade ideas.
- Backend hardening plan.
- Patch order.

### What was corrected

The earlier roadmap referenced `chatgpt-work`. For this new workflow, ignore that branch. The user wants only:

```text
main
```

So all new local work should happen on `main`.

### What must not happen

- Do not create new branches.
- Do not keep two active planning files with conflicting content.
- Do not enable full access for pending users.
- Do not rely on Flutter UI hiding for security.
- Do not silently upload private expense data.
- Do not enable Google login without secure backend ID-token verification.
- Do not make services/content hardcoded in production.

---

## 3. Repository Structure Direction

Expected repo structure:

```text
app_omc/
  README.md
  docs/
    omc_house_merged_structure_upgrade_plan.md

  omc_app/
    Flutter mobile app
    lib/
      app/
      core/
      features/
    assets/
      images/
      data/
    pubspec.yaml

  backend_omc_app/
    apps/
      sync_apps.sh
      omc_app/
        omc_app/
          api/
            mobile.py
            secured_mobile.py
          omc_app/
            doctype/
            workspace/
          fixtures/
          public/
          hooks.py
        pyproject.toml

    frappe-bench/
      apps/
        omc_app/
      sites/
```

### Important backend path check

Before editing backend code, verify the active import path inside Frappe:

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site <site-name> console
```

Inside console:

```python
import omc_app.api.mobile
import omc_app.api.secured_mobile
print(omc_app.api.mobile.__file__)
print(omc_app.api.secured_mobile.__file__)
```

Only edit the source path that is actually imported.

If backend source is edited under:

```text
backend_omc_app/apps/omc_app
```

then sync it into bench using:

```bash
cd ~/data_drive/app_omc/backend_omc_app/apps
./sync_apps.sh
```

---

## 4. Final User Types and Access Rules

### 4.1 Guest User

Guest can explore public content only.

Allowed:

- Public home/intro
- Service catalogue preview
- Knowledge/news/tax awareness
- Tax calculator
- Support contact information
- Public announcements
- Subscription/package preview

Blocked:

- Service request creation
- My Services / tracking
- Document upload/view
- Payments
- Customer dashboard
- Support ticket creation
- Customer-specific notifications
- Internal workspace

Locked feature message:

```text
Please create an account or subscribe to access this feature.
```

### 4.2 Pending Signup User

After signup:

```text
customer_status = Pending
approval_status = Pending Review
```

Pending user can:

- Login
- View basic profile
- View public services
- View knowledge/news
- Use tax calculator
- See verification status

Pending user cannot:

- Create service request
- Upload documents
- Track My Services
- Upload payment receipts
- Create customer support tickets
- Access customer dashboard
- Access internal workspace

Pending message:

```text
Your account is under review. OMC team will verify your profile before enabling service access.
```

### 4.3 Approved Customer

After backend approval:

```text
customer_status = Active
approval_status = Approved
role = OMC Customer
```

Approved customer can:

- Create service request
- Track service cases
- Upload required documents
- View documents
- View payments
- Upload payment receipts if payment feature is enabled
- Create support tickets
- Receive notifications
- Update settings/profile
- Use tax calculator and expense tracker

### 4.4 Consultant / Tax Associate / Business Partner

These users must not receive full customer access just by signup.

Flow:

```text
Signup
  ↓
Pending Review
  ↓
OMC admin verifies role
  ↓
Admin approves/rejects/changes role
  ↓
Approved access depends on assigned role
```

If user selects the wrong role, OMC admin can change it before approval.

### 4.5 Internal OMC Users

Recommended roles:

| Role | Purpose |
|---|---|
| OMC Admin | Full OMC business control |
| OMC Manager | Service cases, tasks, customer follow-up |
| OMC Support Agent | Support tickets and customer replies |
| OMC Document Reviewer | Document approval/rejection |
| OMC Finance Reviewer | Payment/receipt review |
| OMC Consultant | Approved consultant workflow |
| OMC Business Partner | Partner workflow |
| OMC Tax Associate | Tax associate workflow |
| System Manager | Frappe system administration only |

System Manager should remain admin override, but normal OMC operations should use OMC-specific roles.

---

## 5. Final Security Rules

Security must be enforced from backend, not only from Flutter.

### Required backend checks

| Action | Who can do it |
|---|---|
| View public service catalogue | Guest / all |
| Create service request | Approved customer only |
| Upload service document | Owner approved customer only |
| View service case | Owner customer or authorized OMC staff |
| Update service status | OMC staff/manager/admin only |
| Approve/reject documents | Document reviewer/manager/admin only |
| Review payment receipt | Finance reviewer/manager/admin only |
| Create support ticket | Approved customer only |
| Reply to support ticket | Ticket owner or authorized staff |
| View internal workspace | Authorized OMC role only |
| View internal remarks | Authorized OMC staff only |

### Capability flag model

Backend should return capability flags like:

```json
{
  "can_create_service_request": true,
  "can_upload_documents": true,
  "can_access_internal_workspace": false,
  "can_update_service_status": false,
  "can_review_documents": false,
  "can_review_payments": false
}
```

Flutter should render screens/buttons based on these flags.

---

## 6. App Modules — Final Structure

### Customer-facing modules

```text
Authentication
Guest Mode
Home
Services
Service Detail
Service Request Wizard
My Services / Tracking
Documents
Payments / Receipt Tracking
Notifications
Support
Knowledge / News
Tax Calculator
Expense Tracker
Profile
Settings
Subscriptions / Locked Features
```

### Internal/staff modules

```text
Internal Workspace
Customers
Leads
Tasks
Open Service Cases
Document Review Queue
Payment Review Queue
Support Ticket Queue
Notifications
Reports / Dashboards
```

### Backend/Frappe DocTypes

Existing/planned DocTypes:

```text
OMC Customer Profile
OMC Customer Preference
OMC Service
OMC Service Category
OMC Service Required Document
OMC Service Request
OMC Service Document
OMC Service Payment
OMC Service Timeline
OMC Notification
OMC Support Ticket
OMC Support Channel
OMC Support Topic
OMC Lead
OMC Task
OMC Expense Entry
OMC Push Token
OMC Mobile Settings
OMC Branding Settings
```

Recommended additional DocTypes:

```text
OMC Guest Session
OMC Knowledge Article
OMC Tax Alert
OMC App Banner
OMC Announcement
OMC FAQ
OMC Subscription Plan
OMC Customer Subscription
OMC Feature Access Rule
OMC Service Form Field
OMC Service Stage Template
OMC Tax Year
OMC Tax Slab
```

---

## 7. Backend-Driven Content Plan

### 7.1 Services

Services must come from Frappe `OMC Service`.

Backend should control:

- Service title
- Description
- Short description
- Category
- Icon
- Price/fee label
- Government fee label
- Completion time
- Required documents
- Featured status
- Active/inactive status
- Sort order
- Instructions
- Dynamic form schema
- Availability status

### 7.2 Knowledge / News / Tax Alerts

Use backend DocTypes instead of hardcoding.

Recommended:

```text
OMC Knowledge Article
OMC Tax Alert
OMC Announcement
OMC App Banner
OMC FAQ
```

### 7.3 Branding and App Config

Backend should control:

- Logo URL
- Company name
- Tagline
- Support contacts
- Business hours
- Office address
- Feature flags
- Minimum app version
- Force update
- Maintenance mode
- Payment feature enabled/disabled
- Internal workspace enabled/disabled

---

## 8. UI/UX Upgrade Plan

This section converts the improvement ideas into proper patchable tasks.

### 8.1 Logo Quality Fix

Problem:

```text
Logo/payment logo pixel down ho raha hai.
Logo par unwanted effect/filter nahi hona chahiye.
```

Fix:

- Use high-resolution PNG or SVG logo.
- Do not apply blur, opacity, shadow, color filter, or scaling effects on main logo.
- Use `BoxFit.contain`.
- Keep fixed max height/width.
- Add separate light/dark logo if needed.
- Replace low-resolution payment logo assets.
- Use vector assets where possible.

Implementation target:

```text
omc_app/assets/images/
omc_app/lib/features/auth/
omc_app/lib/features/payments/
omc_app/lib/features/home/
```

Acceptance:

- Login/signup logo sharp.
- Payment logo sharp.
- No pixelation.
- No unwanted visual effect on logo.

---

### 8.2 Login Page Polish

Current direction:

- Login works, but UI can be premium.

Upgrade:

- Clean top logo.
- Clear welcome heading.
- Email/password fields with proper validation.
- Password visibility toggle.
- Friendly error messages.
- Loading state on login button.
- Forgot password entry.
- Continue as Guest button.
- Signup CTA.
- No backend/debug text on customer UI.

Acceptance:

- Wrong credentials show clean message.
- Button disables while loading.
- Guest flow visible.
- UI not crowded.

---

### 8.3 Signup Page Polish

Upgrade:

- Role dropdown:
  - Customer
  - Consultant
  - Business Partner
  - Tax Associate
- CNIC formatting/validation.
- Phone/WhatsApp validation.
- Tax Associate conditional fields:
  - Education
  - Experience
  - Remarks
- Clear under-review explanation.
- Terms/privacy checkbox.
- Loading state.
- Signup success screen:
  - “Your account is under review.”

Backend must save:

```text
full_name
email
mobile
whatsapp_no
cnic
register_as
customer_type
address
education
experience
remarks
company_name
ntn
```

Acceptance:

- All signup fields sent by Flutter are saved by backend.
- Pending user does not get full app access.
- Consultant/Tax Associate does not bypass approval.

---

### 8.4 Guest Mode UI

Add:

- Continue as Guest on login.
- Guest banner on Home.
- Locked cards for restricted features.
- Signup/login prompt on locked click.
- Public services preview.
- Public knowledge/news/tax calculator.

Acceptance:

- Guest can open public screens.
- Guest cannot create request/upload/view customer data.
- Direct protected route redirects or shows lock state.

---

### 8.5 Home Page Premium Upgrade

Add backend-driven home sections:

1. Greeting + customer status.
2. Announcement/banner carousel.
3. Quick actions:
   - New Service
   - My Services
   - Upload Document
   - Support
   - Tax Calculator
4. Status cards:
   - Open services
   - Pending documents
   - Payments due
   - Unread notifications
5. Next action card:
   - Missing document
   - Payment due
   - Waiting for customer
6. Latest timeline update.
7. Featured services.
8. Knowledge/tax alert preview.

Acceptance:

- Home does not feel empty.
- Cards are not crowded.
- Pending/guest/approved users see correct content.
- Feature flags hide disabled modules.

---

### 8.6 Services Page Upgrade

Problem:

```text
Services page should not feel crowded.
```

Upgrade:

- Search bar.
- Category chips.
- Featured services horizontal section.
- Clean service cards with:
  - Icon
  - Title
  - Short description
  - Fee label
  - Completion time
  - Required docs count
- Empty state.
- Loading skeleton.
- Error retry.
- Category filtering.
- Active/inactive services hidden from users.

Acceptance:

- Page readable on small screens.
- No long text overflow.
- Cards use backend icons/categories.
- Search/filter works.

---

### 8.7 Service Detail + Request Wizard

Upgrade:

- Service hero header.
- Required documents checklist.
- Fee/completion time block.
- Step-by-step request wizard.
- Backend-driven form fields.
- Save draft later if needed.
- Confirm before submit.
- Submit success screen with tracking reference.

Backend future:

```text
OMC Service Form Field
```

Acceptance:

- Each service can have custom fields.
- Flutter does not hardcode every service form.
- Request creates correct `OMC Service Request`.

---

### 8.8 My Services / Tracking Upgrade

Upgrade:

- Status chips.
- Progress bar.
- Timeline with clean vertical design.
- Next step card.
- Missing document alert.
- Payment due alert.
- Support/contact action.
- Customer action required badge.
- Empty state for no services.

Acceptance:

- Customer sees exactly what to do next.
- Internal buttons hidden from customer.
- Internal controls only appear with backend capability flags.

---

### 8.9 Documents Upgrade

Upgrade:

- Required / Submitted / Approved / Rejected tabs or sections.
- Missing documents first.
- Upload per required document.
- Rejected reason display.
- Re-upload rejected file.
- PDF/image preview.
- File size/type validation before upload.
- Private file enforcement backend-side.

Acceptance:

- Customer knows what document is missing.
- Wrong file type blocked.
- Rejected reason visible.
- Customer cannot access other user files.

---

### 8.10 Payments Upgrade

Important business decision:

```text
No direct payment collection unless explicitly required.
Payments can remain disabled or used only for receipt/status tracking.
```

Upgrade if enabled:

- Payment due list.
- Payment detail with instructions.
- Bank/JazzCash/EasyPaisa info from backend.
- Receipt upload with preview.
- Receipt status:
  - Pending
  - Receipt Submitted
  - Under Review
  - Paid
  - Rejected
- Rejected reason.
- Invoice PDF later.
- Payment due badge on Home/More.

Acceptance:

- Payment feature can be hidden by backend feature flag.
- Receipt upload does not imply payment gateway.
- Reviewer can approve/reject from backend.

---

### 8.11 Notifications Upgrade

Backend already has notification base.

Add Flutter polish:

- Notification bell badge.
- Notification icon in Home/More.
- Mark all read.
- Tap notification to open related service/payment/document/support ticket.
- Optional notification sound preference.
- Notification type icons:
  - Service
  - Document
  - Payment
  - Support
  - Announcement
  - Tax alert
- Respect user preferences.

Future push:

- Firebase Messaging.
- Register push token after login.
- Unregister on logout.
- Deep link handling.

Acceptance:

- Unread count visible.
- Notification opens correct detail screen.
- Sound only works if enabled by user/device.

---

### 8.12 Support Upgrade

Upgrade:

- Chat-like ticket detail.
- Support topic dropdown.
- Priority display.
- WhatsApp click-to-chat.
- Attachments in support ticket.
- Staff reply unread badge.
- Reopen ticket option.
- Clean status chips.

Acceptance:

- Customer can clearly see support history.
- Closed ticket blocks replies unless reopened.
- Staff status update creates customer notification.

---

### 8.13 Settings Upgrade

Keep customer-safe. Do not show backend/debug info.

Add:

- Profile shortcut.
- Notification preferences.
- Theme mode:
  - System
  - Light
  - Dark
- Language setting.
- Privacy policy link.
- Terms link.
- Delete account request.
- App version/build.
- Logout.
- Support/contact section.

Acceptance:

- Normal customer never sees API URL/debug flags.
- Preferences save to backend.
- App version visible.

---

### 8.14 Expense Tracker Upgrade

Decision:

```text
Default local-only.
Cloud sync optional.
Never silently upload old expense data.
```

Add:

- Local/sync toggle.
- Clear warning before sync.
- Monthly summary cards.
- Category filter.
- Charts.
- Export CSV/PDF later.
- Receipt attachment later.

Acceptance:

- Local mode keeps data on device.
- Sync requires explicit user action.
- Backend mode links data to user profile.

---

### 8.15 Internal Workspace Upgrade

Add role-based queues:

- Open Service Cases
- Pending Documents
- Pending Payments
- Open Support Tickets
- Leads
- Tasks
- Customers
- Overdue items

Add workspace charts:

- Cases by status
- Payments due
- Documents pending review
- Support tickets open
- Lead pipeline

Acceptance:

- OMC Staff sees only allowed work.
- System Manager is not required for daily OMC work.
- Customer cannot access internal APIs.

---

## 9. Backend Patch Plan

### Patch B1 — Signup field saving + pending enforcement

Files likely:

```text
backend_omc_app/apps/omc_app/omc_app/api/mobile.py
backend_omc_app/apps/omc_app/omc_app/omc_app/doctype/omc_customer_profile/
```

Tasks:

- Save all signup fields.
- Set profile status pending.
- Assign pending/customer applicant role.
- Return profile access state.
- Add helper:
  - `get_current_customer_profile`
  - `assert_approved_customer`
  - `get_mobile_capabilities`

Block pending users from:

- `create_service`
- `upload_service_document`
- `upload_payment_receipt`
- `create_support_ticket`
- customer-specific dashboards

Keep allowed for pending:

- public services
- knowledge
- tax calculator
- profile status

### Patch B2 — Role and capability model

Tasks:

- Add OMC roles through fixtures/patch.
- Replace System Manager-only internal gate with OMC roles.
- Keep System Manager as override.
- Return capability flags in `get_session_user` and `get_profile`.
- Use server-side checks for internal actions.

### Patch B3 — Guest mode backend

Tasks:

- Add `OMC Guest Session` DocType if needed.
- Add API:
  - `create_guest_session`
  - `update_guest_activity`
- Store:
  - device_id
  - platform
  - app_version
  - interested services
  - first/last active
  - conversion status

Guest must not create business records.

### Patch B4 — Mobile settings / feature flags

Tasks:

- Create/complete:
  - `OMC Mobile Settings`
  - `OMC Branding Settings`
- Move hardcoded app config to backend settings.
- Add feature flags:
  - payments_enabled
  - support_enabled
  - expense_tracker_enabled
  - knowledge_enabled
  - guest_mode_enabled
  - subscriptions_enabled
  - internal_workspace_enabled
- Add branding:
  - logo
  - company name
  - tagline
  - support details

### Patch B5 — Backend-driven content

Tasks:

- Add DocTypes:
  - `OMC Knowledge Article`
  - `OMC Tax Alert`
  - `OMC Announcement`
  - `OMC App Banner`
  - `OMC FAQ`
- Add list/detail APIs.
- Replace service-based fake knowledge fallback in production.
- Add publish/status fields.

### Patch B6 — Service templates

Tasks:

- Add:
  - `OMC Service Form Field`
  - `OMC Service Stage Template`
- Add service detail API fields:
  - form schema
  - stages
  - required documents
- Flutter renders request form dynamically.

### Patch B7 — Payment tracking hardening

Tasks:

- Feature flag to hide/show payment module.
- Backend payment instructions config.
- Receipt review reason.
- Payment notification on approval/rejection.
- No gateway unless explicitly requested.

### Patch B8 — Notification improvements

Tasks:

- Add notification type.
- Add deep link target:
  - reference_doctype
  - reference_name
  - mobile_route
- Respect notification preferences.
- Prepare Firebase push token usage later.

---

## 10. Flutter Patch Plan

### Patch F1 — App access model

Tasks:

- Add access state:
  - guest
  - pending
  - approved customer
  - internal user
- Add capability provider from backend.
- Route guards based on access/capabilities.
- Add Under Review screen.

### Patch F2 — Auth UI polish

Tasks:

- Logo quality fix.
- Login premium layout.
- Signup role-based fields.
- Continue as Guest.
- Forgot password placeholder or flow.
- Signup success/under-review screen.

### Patch F3 — Home redesign

Tasks:

- Backend-driven announcement banner.
- Status cards.
- Quick actions.
- Next action card.
- Featured services.
- Notification/payment/document badges.

### Patch F4 — Services redesign

Tasks:

- Search.
- Category chips.
- Featured carousel.
- Less crowded cards.
- Clean loading/empty/error states.

### Patch F5 — Tracking/detail polish

Tasks:

- Better progress UI.
- Timeline component.
- Customer action required alert.
- Missing document/payment due cards.
- Hide internal controls unless capability true.

### Patch F6 — Documents polish

Tasks:

- Checklist UI.
- Upload per required document.
- Rejected reason.
- Preview.
- Clear states.

### Patch F7 — Payments polish

Tasks:

- Payment feature flag handling.
- Payment detail redesign.
- Receipt preview upload.
- Rejected reason.
- Payment badge.

### Patch F8 — Notifications polish

Tasks:

- Bell badge.
- Type icons.
- Deep links.
- Mark all read.
- Optional sound setting.

### Patch F9 — Settings polish

Tasks:

- App version.
- Privacy/terms.
- Delete account request.
- Notification preferences.
- Theme/language.
- No debug/backend text for customers.

### Patch F10 — Expense tracker sync toggle

Tasks:

- Local-only default.
- Sync toggle.
- Explicit consent before upload.
- Backend sync mode.
- Summary cards/charts.

---

## 11. Local Main-Only Git Workflow

The user wants only one branch:

```text
main
```

### 11.1 Check current branch

```bash
cd ~/data_drive/app_omc
git branch --show-current
```

If not on main:

```bash
git checkout main
```

### 11.2 Pull latest main

```bash
git pull origin main
```

### 11.3 Remove old planning file and add merged file

If old docs exist and should be replaced:

```bash
mkdir -p docs
rm -f docs/modification.md docs/modi_for_codex.md
```

Copy this merged file into repo:

```bash
cp /mnt/data/omc_house_merged_structure_upgrade_plan.md docs/omc_house_merged_structure_upgrade_plan.md
```

### 11.4 Check status

```bash
git status
```

Expected:

```text
deleted: docs/modification.md
new file: docs/omc_house_merged_structure_upgrade_plan.md
```

or only new file if old files were not present.

### 11.5 Stage safely

```bash
git add docs/omc_house_merged_structure_upgrade_plan.md
git add -u docs
```

### 11.6 Commit

```bash
git commit -m "docs: merge OMC roadmap and upgrade plan"
```

### 11.7 Push to main

```bash
git push origin main
```

---

## 12. Local Verification Steps Before Coding

### 12.1 Backend

```bash
cd ~/data_drive/app_omc/backend_omc_app/frappe-bench
bench --site all migrate
bench --site all clear-cache
bench restart
```

### 12.2 Verify backend import path

```bash
bench --site <site-name> console
```

Inside console:

```python
import omc_app.api.mobile
import omc_app.api.secured_mobile
print(omc_app.api.mobile.__file__)
print(omc_app.api.secured_mobile.__file__)
```

### 12.3 Flutter

```bash
cd ~/data_drive/app_omc/omc_app
flutter pub get
flutter analyze
```

Run local app:

```bash
flutter run --dart-define=OMC_API_BASE_URL=http://127.0.0.1:8000
```

---

## 13. Manual Testing Checklist

### Guest

- Open app.
- Continue as Guest.
- View public home.
- View services preview.
- View knowledge/news.
- Use tax calculator.
- Try locked service request.
- Confirm login/signup prompt.

### Pending user

- Signup.
- Login after signup.
- See under-review status.
- Cannot create service request.
- Cannot upload documents.
- Cannot access customer dashboard.
- Cannot create support ticket.

### Approved customer

- Login.
- View home dashboard.
- Browse services.
- Create service request.
- Track My Services.
- Upload document.
- View notification.
- Create support ticket.
- Update settings.
- Logout.

### Internal user

- Login as OMC role.
- See internal workspace only if allowed.
- Update service status.
- Review document.
- Review payment receipt.
- Update support ticket.
- Confirm customer-only users cannot access these APIs.

---

## 14. Recommended Commit Batches

### Commit 1 — Documentation merge

```text
docs: merge OMC roadmap and upgrade plan
```

Includes only this file.

### Commit 2 — Verification fixes

```text
fix: resolve local backend and flutter verification issues
```

Only fix real errors from:

```text
bench migrate
flutter analyze
manual smoke tests
```

### Commit 3 — Signup approval and access guard

```text
feat: enforce signup approval and customer access rules
```

Includes:

- Pending enforcement.
- Signup fields saved.
- Capability flags.
- Under review state.

### Commit 4 — Premium auth/home UI

```text
feat: polish auth and home experience
```

Includes:

- Logo fix.
- Login/signup polish.
- Guest mode.
- Home dashboard improvements.

### Commit 5 — Service tracking/docs/payments polish

```text
feat: improve service tracking documents and payment UX
```

Includes:

- Timeline UI.
- Document checklist.
- Payment receipt flow.

### Commit 6 — Roles and internal workspace hardening

```text
feat: add OMC roles and internal workspace permissions
```

Includes:

- OMC roles.
- Capability checks.
- Internal workspace gates.

---

## 15. Priority Order

### P0 — Must do first

1. Merge this roadmap into docs.
2. Confirm only `main` branch workflow.
3. Verify backend import path.
4. Run backend migrate/cache/restart.
5. Run `flutter analyze`.
6. Fix only actual errors.
7. Test customer/internal permission boundaries.

### P1 — Important app quality

1. Signup approval enforcement.
2. Guest mode.
3. Logo quality fix.
4. Login/signup UI polish.
5. Home dashboard premium redesign.
6. Services page less crowded redesign.
7. Documents checklist.
8. Tracking timeline.
9. Payment receipt UX.
10. Notification badges.

### P2 — Backend-driven premium system

1. Mobile settings/branding DocTypes.
2. Knowledge/tax alerts/announcement DocTypes.
3. Service dynamic form fields.
4. Service stage templates.
5. Proper OMC roles.
6. Subscription/locked feature system.

### P3 — Future

1. Push notifications.
2. Firebase deep links.
3. Expense tracker sync.
4. Tax slabs backend.
5. Reports/dashboards.
6. Online payment gateway, only if required.

---

## 16. Final Decision List

These are final product decisions from the merged docs:

- Guest mode will exist.
- Guest can explore but cannot create service requests.
- Signup users stay pending until backend approval.
- Pending users get limited/guest-like access.
- Approved customers can use customer workflows.
- Consultant/Partner/Tax Associate users require backend approval.
- Flutter hides/locks features.
- Backend enforces real permissions.
- Services must be backend-driven.
- Knowledge/news/tax alerts must be backend-driven.
- Subscription content can be backend-driven.
- User data must link through `OMC Customer Profile`.
- Email notifications should be added for signup, review, approval/rejection.
- Payment collection is not active by default.
- Payment module can be hidden or used only for receipt/status tracking.
- Expense tracker is local-only by default.
- Expense sync requires explicit user consent.
- Google login stays disabled until backend token verification exists.
- Only `main` branch will be used for this local workflow.

---

## 17. What To Tell Client

Use this polished explanation:

> OMC House App will work as a digital service portal for customers and a backend operations system for OMC staff. Customers can explore services, sign up, submit requests after approval, upload documents, track service progress, manage support, receive notifications, and use tax/expense tools. OMC staff will manage customer profiles, service requests, documents, payments, leads, tasks, support tickets, and approvals from Frappe. The system will use backend-driven permissions, so pending users, guests, customers, and staff each get the correct access level securely.

---

## 18. Next Local Action

Run these first:

```bash
cd ~/data_drive/app_omc
git checkout main
git pull origin main
mkdir -p docs
rm -f docs/modification.md docs/modi_for_codex.md
cp /mnt/data/omc_house_merged_structure_upgrade_plan.md docs/omc_house_merged_structure_upgrade_plan.md
git status
```

Then review status before commit.
