# OMC App — Full Custom Frappe Backend App Plan

*Target backend: Frappe / ERPNext*
*Target mobile app: OMC Flutter App*
*Final strategy: build a complete reusable custom Frappe backend app, then install it on the client’s ERPNext site.*

---

## 1. Final Direction Change

Earlier plan:

```text
Create scripts/installers that generate backend structure.
```

New locked plan:

```text
Build the complete OMC backend as a proper Frappe custom app.
Test it fully on our own test site.
Then deliver/install that app on the client’s ERPNext site.
Use mapping + validation to connect it safely with client data.
```

So we are **not building a backend installer as the main product**.

We are building:

```text
omc_app
```

as a complete Frappe app.

---

## 2. What We Are Skipping

We will not focus on:

```text
❌ Frappe installer script
❌ Bench installer script
❌ Site setup installer script
❌ Blind backend generator script
❌ One mega script that creates everything directly inside client ERP
```

Those parts are already handled separately or are not needed for the mobile backend product.

---

## 3. What We Are Building

We will build a full production-safe Frappe app:

```text
apps/omc_app/
  omc_app/
    __init__.py
    hooks.py
    patches.txt

    api/
      __init__.py
      mobile.py
      setup.py
      mapping.py
      permissions.py
      serializers.py
      validators.py

    omc_app/
      doctype/
        omc_mobile_settings/
        omc_customer_profile/
        omc_mobile_device/
        omc_service_category/
        omc_service/
        omc_service_required_document/
        omc_service_request/
        omc_service_request_document/
        omc_service_timeline/
        omc_notification/
        omc_customer_document/
        omc_support_ticket/
        omc_knowledge_article/

    patches/
      v1_0/
        create_roles.py
        create_mobile_settings.py
        create_core_doctypes.py
        create_permissions.py
        add_safe_custom_fields.py
        seed_default_mobile_services.py
```

---

## 4. Why App Name Should Stay `omc_app`

The Flutter app already expects backend method paths like:

```text
omc_app.api.mobile.get_service_cases
omc_app.api.mobile.get_documents
omc_app.api.mobile.get_payments
omc_app.api.mobile.get_profile
```

So backend Frappe app/package name should remain:

```text
omc_app
```

This avoids unnecessary frontend API path changes.

---

## 5. Final Development Flow

### Phase A — Build App Locally

On our own Frappe bench/test site:

```text
bench new-app omc_app
bench --site omc-test.local install-app omc_app
bench --site omc-test.local migrate
```

Then we build all backend features inside this app.

---

### Phase B — Build App-Owned Backend

The app will create its own safe backend structure:

```text
OMC Mobile Settings
OMC Customer Profile
OMC Mobile Device
OMC Service Category
OMC Service
OMC Service Required Document
OMC Service Request
OMC Service Request Document
OMC Service Timeline
OMC Notification
OMC Customer Document
OMC Support Ticket
OMC Knowledge Article
```

These are app-owned DocTypes.

They are safe because they do not overwrite client ERP data.

---

### Phase C — Add APIs Expected By Flutter

Main API file:

```text
omc_app/api/mobile.py
```

Required methods:

```text
sign_up
get_session_user
get_profile
update_profile
get_dashboard_data
get_service_catalogue
get_service_detail
create_service
get_service_cases
get_service_case
upload_service_document
get_documents
get_document
get_payments
get_payment
upload_payment_receipt
get_notifications
get_notification_detail
mark_notification_read
get_knowledge
get_knowledge_article
create_support_ticket
get_settings_preferences
update_settings_preferences
get_internal_workspace_summary
get_leads
get_lead
get_customers
get_customer
get_tasks
get_task
calculate_tax
```

Goal:

```text
Flutter app should call backend without 404 errors.
All private APIs must be permission-safe.
```

---

## 6. Mapping System Still Required

Even though we are building the full app ourselves, the client’s existing ERP data may use different fields.

So we still need:

```text
OMC Mobile Settings
Auto Detect Mapping
Manual Mapping Review
Validate Mapping
Activate Mobile Backend
```

This is not optional.

Reason:

```text
Customer mobile field may be mobile_no
or custom_whatsapp_number
or custom_mobile
or something else.

Invoice customer field may be customer
but service request link may be custom_omc_service_request
or missing entirely.
```

So APIs must not blindly hardcode client-specific fields.

---

## 7. Hardcoded Defaults + Dropdown Mapping

Best approach:

```text
Use hardcoded standard ERPNext defaults
+
Allow dropdown/manual override
+
Validate before activation
```

Example default mappings:

```text
customer_doctype = Customer
customer_name_field = customer_name
customer_email_field = email_id
customer_mobile_field = mobile_no

invoice_doctype = Sales Invoice
invoice_customer_field = customer
invoice_total_field = grand_total
invoice_outstanding_field = outstanding_amount
invoice_status_field = status
invoice_due_date_field = due_date

payment_doctype = Payment Entry
payment_party_field = party
payment_amount_field = paid_amount
payment_date_field = posting_date
```

If client fields differ, admin can adjust them in `OMC Mobile Settings`.

---

## 8. Setup Wizard UX

Inside Frappe Desk, `OMC Mobile Settings` should have buttons:

```text
Auto Detect Mapping
Validate Mapping
Activate Mobile Backend
Deactivate Mobile Backend
View Setup Report
```

The process:

```text
Open OMC Mobile Settings
  ↓
Click Auto Detect Mapping
  ↓
Review detected DocTypes/fields
  ↓
Change fields manually if needed
  ↓
Click Validate Mapping
  ↓
Fix errors/warnings
  ↓
Click Activate Mobile Backend
```

---

## 9. Activation Lock

Default:

```text
is_mobile_backend_active = 0
```

Private APIs must stay locked until backend is validated and activated.

Locked APIs include:

```text
get_service_cases
get_service_case
get_documents
get_document
get_payments
get_payment
get_customer
get_customers
get_internal_workspace_summary
```

Limited APIs may work before activation depending on settings:

```text
login
sign_up
get_service_catalogue
create_support_ticket
```

---

## 10. Client Delivery Flow

Once app is complete and tested locally:

```text
Copy/get app into client bench/apps
  ↓
Install app on client ERPNext site
  ↓
Run migrate
  ↓
Open OMC Mobile Settings
  ↓
Auto Detect
  ↓
Manual review
  ↓
Validate
  ↓
Activate
  ↓
Connect Flutter app
```

Client commands:

```bash
cd frappe-bench

bench get-app <omc_app_repo_url>
# or copy apps/omc_app manually if no git delivery

bench --site <client-site> install-app omc_app
bench --site <client-site> migrate
bench --site <client-site> clear-cache
```

---

## 11. What Must Never Happen Automatically

The app must never blindly:

```text
Delete existing fields
Delete existing DocTypes
Rename existing fields
Modify existing Customer records
Modify existing User records except app-created users
Auto-approve all matched customers
Change global ERPNext permissions blindly
Expose private files without permission checks
Mark invoices as paid from uploaded receipts automatically
Bulk-link users to customers without review
```

---

## 12. Safe Customer Matching

Customer matching is sensitive.

Flow:

```text
User signs up
  ↓
Create Frappe User
  ↓
Create OMC Customer Profile
  ↓
Try safe match by mapped email/mobile/CNIC/NTN
  ↓
If match found, mark Suggested Match
  ↓
Admin reviews
  ↓
Admin approves
  ↓
Customer profile becomes Active
  ↓
Mobile app can show customer-specific records
```

If approval is required:

```text
Matched user stays pending until admin approves.
```

---

## 13. File and Document Safety

All customer uploads should be private.

Recommended service document upload:

```text
doctype = OMC Service Request
docname = service request id
is_private = 1
```

Payment proof upload:

```text
doctype = Sales Invoice
docname = invoice id
is_private = 1
```

or app-owned safer model:

```text
doctype = OMC Customer Document
docname = document id
is_private = 1
```

Rules:

```text
Do not return private file URLs without permission check.
Customer A must never access Customer B documents.
Uploaded receipt must not mark invoice paid automatically.
Accounts/user review is required.
```

---

## 14. Payment Safety

ERPNext `Sales Invoice` and `Payment Entry` remain source of truth.

Rules:

```text
Only show invoices linked to active mapped customer.
Do not show draft/cancelled invoices unless explicitly allowed.
Do not mark invoice paid from uploaded receipt.
Receipt upload only creates proof/review item.
Payment Entry controls paid status.
```

---

## 15. Internal Workspace Safety

Internal APIs must require internal roles.

Allowed roles:

```text
System Manager
OMC Mobile Admin
OMC Support Agent
OMC Sales User
OMC Accounts User
OMC Operations User
```

Customer role must not access:

```text
get_internal_workspace_summary
get_leads
get_lead
get_customers
get_customer
get_tasks
get_task
```

---

## 16. Testing Before Client Delivery

Before giving this app to client:

```text
App installs on fresh ERPNext site
App installs on existing ERPNext site
bench migrate runs cleanly
OMC Mobile Settings opens
Auto Detect works
Validate works
Activation lock works
Private APIs blocked before activation
Signup works if enabled
Customer linking requires approval
Customer A cannot see Customer B data
Payment receipt upload does not auto-pay invoices
Internal APIs blocked for customer users
Flutter methods respond correctly
No existing ERP data is changed
```

---

## 17. Final Locked Workflow

```text
1. Build full omc_app Frappe backend app ourselves
2. Test it on our own site
3. Keep app reusable and package-ready
4. Do not depend on installer scripts as main backend creation method
5. Client receives app folder/repo
6. Client installs app on existing ERPNext site
7. App creates only its safe app-owned backend structure
8. OMC Mobile Settings maps client fields
9. Validation confirms safety
10. Activation unlocks mobile backend
11. Flutter app uses live ERP data safely
```

---

## 18. Final Principle

The backend app must be complete before client delivery.

The client setup should only be:

```text
Install app
Map fields
Validate
Activate
Use mobile app
```

No blind backend generation on client production site.

No unsafe shortcuts.

Build once properly, test fully, then reuse safely.

