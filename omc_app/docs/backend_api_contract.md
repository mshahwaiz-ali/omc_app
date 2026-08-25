# OMC Flutter ↔ Frappe Backend API Contract

Source cross-check: **25 August 2026**, branch `main`.

This document describes the current API contract used by the Flutter application. Method-name source of truth is:

```text
lib/core/config/api_config.dart
```

> The backend remains authoritative for identity, capabilities, ownership, workflow state, pricing, document requirements, payment eligibility and protected mutations. Flutter must not infer authority from a route or local role label.

---

## 1. Base transport

Flutter calls Frappe method APIs through:

```text
/api/method/<method_name>
```

Production origin currently resolves to:

```text
https://erp.omchouse.com
```

Build-time configuration:

```text
OMC_ENV
OMC_API_BASE_URL
OMC_LINK_BASE_URL
OMC_SENTRY_DSN
```

Release builds are validated by `ApiConfig.validateBuildProfile()` and must satisfy the production-origin/HTTPS/diagnostics requirements implemented in code.

---

## 2. General response rules

Frappe method responses normally arrive under `message`.

Repositories may accept legacy aliases for compatibility, but new backend work should prefer stable explicit objects and arrays.

Guidelines:

- list endpoints return arrays, not `null`;
- IDs/names are stable strings;
- user-facing date/time strings should be consistently parseable;
- protected endpoints return permission errors rather than filtered fake success;
- backend errors exposed to customers must be safe and non-sensitive;
- pagination metadata should be returned where the endpoint supports paging;
- compatibility aliases should not broaden permission or semantic authority.

---

# 3. Authentication and account security

Current methods include:

```text
login
omc_app.api.auth_login.login
logout
omc_app.api.mobile.google_mobile_login
omc_app.api.password_reset.request_reset
omc_app.api.password_reset.reset_password
omc_app.api.customer_activation.request_activation
omc_app.api.customer_activation.complete_activation
omc_app.api.account_security.verify_current_password
omc_app.api.account_security.change_password
```

Pending registration:

```text
omc_app.api.pending_registration.start_registration
omc_app.api.pending_registration.resend_verification
omc_app.api.pending_registration.verify_registration
omc_app.api.access.suggest_username
omc_app.api.access.check_username_availability
omc_app.api.referrals.validate_referral_code
```

Session/customer capability context:

```text
omc_app.api.access_v2.get_session_user
omc_app.api.access_v2.get_profile
```

Public signup is customer-only; internal staff access is not granted by a public registration account type.

---

# 4. Guest sessions

```text
omc_app.api.guest_session.create_guest_session
omc_app.api.guest_session.update_guest_activity
```

Guest endpoints must not expose customer or internal records.

---

# 5. Dashboard and quick actions

```text
omc_app.api.dashboard.get_dashboard_data
omc_app.api.quick_actions.get_mobile_quick_actions
omc_app.api.mobile.get_mobile_app_config
```

Dashboard data should reflect backend access/capability state. Missing backend sections should be represented as unavailable/empty states rather than invented customer data.

---

# 6. Service catalogue and templates

```text
omc_app.api.mobile.get_service_catalogue
omc_app.api.service_templates.get_service_template
```

Service IDs are stable backend identities. Flutter must not derive the canonical service identity from a display title.

The production catalogue is source controlled and currently maps only to exact existing ERP Task Types.

---

# 7. Service request creation

Canonical create method:

```text
omc_app.api.service_requests.create_service
```

Assisted customer selection:

```text
omc_app.api.assisted_service.get_customer_selection_options
```

The backend is responsible for:

- caller/customer authority;
- active service validation;
- pricing snapshot;
- duplicate/parallel-request rules;
- referral/assistance scope;
- service form validation;
- idempotency where applicable;
- initial request/payment state.

Flutter must not directly create ERP Service/Task records.

---

# 8. Customer service cases

Canonical secured endpoints:

```text
omc_app.api.secured_mobile.get_service_cases
omc_app.api.secured_mobile.get_service_case
omc_app.api.secured_mobile.update_service_case_status
omc_app.api.secured_mobile.cancel_service_request
```

Case detail can include:

- request identity;
- service identity/title;
- canonical lifecycle/operational status;
- pricing/payment contract;
- required documents;
- submitted documents;
- timeline/progress;
- customer next actions;
- assignment context where customer-safe;
- cancellation/action capability.

Backend record ownership is authoritative.

---

# 9. Required-document contract

Required-document entries can include stable identity fields:

```json
{
  "document_key": "cnic_front_image",
  "key": "cnic_front_image",
  "title": "CNIC Front Image",
  "document_title": "CNIC Front Image",
  "type": "Identity",
  "document_type": "Identity",
  "is_required": 1,
  "status": "Required"
}
```

`document_key` is authoritative when both template and upload are keyed.

New requirements may be request-grandfathered by backend `effective_from` logic; Flutter should consume the returned applicable requirement set and must not independently decide whether a requirement applies to an older request.

---

# 10. Documents

List/detail:

```text
omc_app.api.customer_documents.get_documents
omc_app.api.customer_documents.get_document
```

Required service upload:

```text
omc_app.api.document_upload.upload_service_document
```

Internal review/status path:

```text
omc_app.api.customer_documents.update_service_document_status
```

For a required-document upload, Flutter sends the selected requirement identity with the request/file data. The backend validates/canonicalises requirement identity before storage.

A typical returned document can expose both:

```text
document_key
key
```

for compatibility.

Generic `upload_file` remains available for supported non-service-document upload flows, but required service documents should use the canonical service-document endpoint.

---

# 11. Payments

```text
omc_app.api.payments.get_payments
omc_app.api.payments.get_payment
omc_app.api.payment_read_guard.download_invoice_pdf
omc_app.api.mobile.upload_payment_receipt
omc_app.api.payments.upload_payment_receipt_file
omc_app.api.payments.upload_payment_receipt_multipart
omc_app.api.payments.review_payment_receipt
```

Customer payment/receipt state is not itself ERP settlement authority. Full-settlement service activation is gated by backend accounting evidence.

Flutter should render backend-provided payment eligibility/action state and must not assume that a locally uploaded receipt means the service is activated.

---

# 12. Profile and contact

```text
omc_app.api.access_v2.get_profile
omc_app.api.profile_self_service.update_profile
omc_app.api.profile_self_service.update_work_address
omc_app.api.profile_self_service.dismiss_work_address_prompt
omc_app.api.mobile.update_contact_info
omc_app.api.profile.upload_profile_image
```

Writable profile fields are backend controlled. Internal-user self-service does not require pretending the internal user is a customer.

---

# 13. Public content

```text
omc_app.api.mobile.get_knowledge
omc_app.api.mobile.get_knowledge_article
omc_app.api.mobile.get_app_banners
omc_app.api.mobile.get_onboarding_slides
omc_app.api.mobile.get_faqs
```

Public/guest availability is endpoint-specific and backend guarded.

---

# 14. Notifications and push

```text
omc_app.api.mobile.get_notifications
omc_app.api.mobile.get_notification_detail
omc_app.api.mobile.mark_notification_read
omc_app.api.mobile.mark_all_notifications_read
omc_app.api.mobile.dismiss_notification
omc_app.api.mobile.restore_notification
omc_app.api.mobile.mark_notification_unread
omc_app.api.mobile.get_unread_notification_count
omc_app.api.mobile.register_push_token
omc_app.api.mobile.unregister_push_token
```

Notification navigation targets must still pass normal route/capability checks.

---

# 15. Settings

```text
omc_app.api.mobile.get_settings_preferences
omc_app.api.mobile.update_settings_preferences
```

---

# 16. Support

```text
omc_app.api.support_chat.create_support_ticket
omc_app.api.support_chat.get_support_tickets
omc_app.api.support_chat.get_support_ticket
omc_app.api.support_chat.get_active_support_ticket
omc_app.api.support_chat.get_support_unread_count
omc_app.api.support_chat.mark_support_ticket_read
omc_app.api.support_chat.add_support_ticket_reply
omc_app.api.support_chat.update_support_ticket_status
omc_app.api.mobile.get_support_config
```

Support attachment upload may use Frappe `upload_file` where configured.

Customer ticket visibility is ownership scoped; internal support actions require capability.

---

# 17. Tax calculator

```text
omc_app.api.tax_calculator.get_tax_calculator_config
omc_app.api.tax_calculator.calculate_tax
omc_app.api.tax_calculator.get_tax_calculation_history
omc_app.api.tax_calculator.download_tax_estimate_pdf
omc_app.api.tax_calculator.share_tax_estimate_with_consultant
omc_app.api.tax_calculator.start_service_from_calculation
```

Tax configuration/calculation authority remains backend controlled.

---

# 18. Expense tools

Current `ApiConfig` includes backend methods for expense configuration, categories, entries, CRUD/bulk sync, summaries and related budget flows.

Flutter repositories should use the centralised constants rather than hardcoding method names.

---

# 19. Customers, leads and tasks

```text
omc_app.api.mobile.get_customers
omc_app.api.mobile.get_customer
omc_app.api.mobile.get_leads
omc_app.api.mobile.get_lead
omc_app.api.mobile.get_tasks
omc_app.api.mobile.get_task
omc_app.api.mobile.create_lead
```

ERPNext Customer/Lead/Task remain ERP business records. OMC endpoints apply guarded mobile/internal access around them.

---

# 20. Internal workspace and admin operations

```text
omc_app.api.mobile.get_internal_workspace_summary
omc_app.api.internal_workspace.get_service_cases
omc_app.api.internal_workspace.create_service_request_for_customer
omc_app.api.admin_control.get_admin_overview
omc_app.api.admin_control.get_admin_operations
omc_app.api.admin_control.review_registration
omc_app.api.admin_control.invite_staff
omc_app.api.admin_control.update_staff_account
omc_app.api.admin_control.reassign_service_request
omc_app.api.admin_control.get_case_admin_options
omc_app.api.admin_control.retry_service_sync
omc_app.api.admin_control.get_business_settings
omc_app.api.admin_control.update_business_settings
omc_app.api.admin_control.review_discount
```

Endpoint existence does not imply permission. Each protected method must enforce canonical capability/scope.

---

# 21. Referrals and personal commissions

Referral-owner analytics:

```text
omc_app.api.referral_analytics.get_my_referral_summary
omc_app.api.referral_analytics.get_my_referrals
omc_app.api.referral_analytics.get_my_referral_detail
```

Personal commission views:

```text
omc_app.api.referral_commissions.get_my_commission_summary
omc_app.api.referral_commissions.get_my_commissions
omc_app.api.referral_commissions.get_my_commission
```

Referral ownership and personal commission visibility are self-scoped capabilities and do not grant finance commission authority.

Finance commission operations use separate guarded endpoints/capabilities in the backend.

---

# 22. Compatibility policy

The backend may preserve legacy aliases for older clients, but new Flutter code should use canonical `ApiConfig` constants.

Compatibility must not:

- widen access;
- change identity authority;
- allow title-only matching when stable document keys are present;
- let a legacy referral flag imply commission approval/payment authority;
- bypass payment/accounting activation gates.

---

# 23. Error and retry behavior

Flutter should distinguish:

- authentication failure;
- permission/access denial;
- validation failure;
- not-found/ownership-safe absence;
- temporary network/server failure;
- backend unavailable/partial section failure.

Do not convert a protected 403 into a fabricated empty success merely to keep a screen populated.

Mutating retry behavior must respect backend idempotency rules.

---

# 24. Contract maintenance

When a new backend endpoint is added or renamed:

1. add/update the method constant in `lib/core/config/api_config.dart`;
2. update the relevant repository/model;
3. preserve backend authority and safe response parsing;
4. add/adjust contract tests;
5. update this document if the public contract materially changed.

The code is the final source of truth if this document ever diverges.
