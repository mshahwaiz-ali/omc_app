# OMC Production Workflow Inspection

Date: 2026-08-16
Branch: `feature/customer-home-dashboard`
Audited HEAD: `2fdaa632d71ba0f94396c2089c2c52ac8cb006bd`
Site: `omc.local`

This is the current route/action/API, role, lifecycle, dead-code, fallback,
pagination, and UI inventory. Backend authorization and record scope are
authoritative; Flutter visibility is only a navigation aid.

## Source boundaries

- Backend: `backend_omc_app/frappe-bench/apps/omc_app/omc_app`.
- Flutter: `omc_app/`.
- ERPNext Sales Invoice/Payment Entry remain accounting authority. ERP Service
  and Task remain operational records. No checked-in core source is edited.
- `OMC Service Request` remains customer-lifecycle authority; ERP Task is
  mobile read-only.
- Work is local only: no branch creation, commit, push, or publication.

## Canonical lifecycle

1. Public signup creates a pending registration and verification token.
2. Only token consumption calls the private activation helper; legacy signup
   endpoints delegate to pending registration and cannot activate an account.
3. An approved customer or backend-authorized referral owner creates a request.
4. Required documents come only from configured OMC Service templates.
5. The customer or consented referral owner uploads payment proof against the
   same backend-scoped request.
6. Finance review uses one savepoint for submitted Sales Invoice, submitted
   Payment Entry, zero outstanding, commission snapshot, OMC Paid state, and
   ERP Service/Task activation.
7. Finance or activation failure rolls back the attempt, persists diagnostic
   `Under Review` state, and remains safe to retry.
8. Both authorized actors refresh the same request/document/payment authority.

## Action contract map

| UI action | Route | Capability | Backend scope | Endpoint | Success/refresh |
|---|---|---|---|---|---|
| Register | `/signup` | public | submitted identity | `pending_registration.start_registration` | verify screen; no active user |
| Verify | `/verify-email` | token | exact pending token | `pending_registration.verify_registration` | activation/session refresh |
| Create request | `/services/:serviceId/request` | create request or assisted equivalent | own/eligible customer | `service_requests.create_service` | request/case/dashboard |
| Upload document | document/case detail | upload documents | own/consented request | `document_upload.upload_service_document` | document/case |
| Upload proof | `/payments/:paymentId` | upload receipt | own/consented payment | authenticated payment-proof APIs | payment/case |
| Review payment | payment queue/detail | review payments | scoped queue payment | `payments.review_payment_receipt` | atomic finance/activation; payment/case/dashboard |
| Download invoice | `/payments/:paymentId` | payment read | linked payment plus submitted invoice | `payment_read_guard.download_invoice_pdf` | authenticated bytes |
| Read tasks | `/tasks`, `/tasks/:taskId` | assigned/all task read | exact assignment or all | task read guard | read-only list/detail |
| View referrals | `/my-referrals` | relevant customers | owned referrals | referral list/detail APIs | scoped list/detail |
| View commissions | `/my-commissions`, detail | view referral commissions | current referrer | commission summary/list/detail | paginated list/detail |
| Settle commissions | ERP Desk | manage referral commissions | same referrer/currency, eligible earnings | submit settlement DocType | atomic Settled status |
| Reverse commission | manager/admin | manage referral commissions | exact earning | `reverse_commission` | reason/date/history plus alert |
| Notification actions | notification list/detail | notification read | exact owner | read/unread/dismiss/restore/all-read | list/detail/count and exact route |
| Push token lifecycle | authentication hooks | authenticated | current user/device | register/unregister token | ownership refresh/deactivation |

## Role and object scope

| Persona | Scope |
|---|---|
| Guest | public catalogue/content and pending registration only |
| Pending/rejected customer | account status and self-service only |
| Approved customer | own requests, documents, payments, inbox, support |
| Consultant / Tax Associate / Business Partner | owned referrals and commission ledger; consent rechecked server-side |
| Assigned operational staff | explicitly assigned cases/tasks only |
| Finance reviewer | payment queue/detail/review as explicitly granted |
| OMC Manager | operational scopes plus commission settlement/reversal |
| OMC Admin / System Manager | administrative scopes plus commission management |

Mixed roles receive the union of explicit backend capabilities. A Flutter
`assisted` flag is never proof of access.

## Commission authority

- `OMC Service` owns enabled/rate fields; rate is validated from 0 through 100.
- `OMC Referral Commission` freezes cleared Sales Invoice `grand_total`, rate,
  amount, currency, and all source links under unique key
  `payment:<payment>:finance-posted`.
- Disabled, zero-rate, non-referral, inactive, mismatched, or consent-revoked
  relationships create no ledger row.
- Financial fields and deletion are blocked. Status transitions occur only via
  settlement or audited reversal.
- `OMC Commission Settlement` is submittable, validates one referrer/currency,
  and cannot be cancelled or deleted after submission.

## Notification matrix and push readiness

| Event | Category | Exact route |
|---|---|---|
| Service state/escalation | Service Request | `/my-services/:id` |
| Document review | Document | `/documents/:id` |
| Payment review | Payment | `/payments/:id` |
| Task assignment | Service Request | `/tasks/:id` |
| Support reply | Support | `/support-tickets/:id` |
| Commission earned/settled/reversed | Commission | `/my-commissions/:id` |

`OMC Notification` has a unique recipient-qualified dedupe key. Its durable
inbox supports bounded paging, read, unread, dismiss, restore, all-read, and
unread count. Global in-app, global push, and category preferences are separate.

Push uses an optional queued after-commit provider interface, active owned-token
filtering, three bounded attempts, and invalid-token deactivation. Provider
configuration comes from site config only. Firebase/APNs files and credentials
are absent, so Flutter installs `UnavailablePushTokenSource` and live delivery
is not advertised. Auth registration/unregistration, refresh, and opened-route
contracts are ready for a future valid adapter.

## Pagination and dashboard

Bounded responses expose `items`, `start`, `limit`, `has_more`, and
`next_start`, retaining legacy collection/parameter aliases temporarily. This
covers commissions, requests, customers, documents, payments, tasks,
notifications, support, and existing referral/admin queues. Search/filtering is
applied after backend object scope and before page projection.

Dashboard service previews stay below five items. Needs Attention actions use
typed backend references and registered capability-gated destinations.

## Flutter UI inventory

- Registered routes: 57, including commission list/detail.
- More sheet: four columns on normal phones, scrollable/responsive layout, and
  capability-derived Commission visibility.
- New financial detail text wraps and is selectable; screens use theme text and
  semantic color schemes without fixed content heights.
- Current census: 216 ellipsis uses, 764 explicit `fontSize` sites, and 1,247
  direct `Color`/`Colors` references. The audit changes violations on affected
  workflow surfaces instead of mechanically rewriting intentional decoration.
- OS text scaling is not capped; Material controls preserve at least 48dp taps.

## Dead code, compatibility, and fallbacks

- Removed duplicate pending-registration declarations/decorators.
- Removed obsolete Flutter task mutation constants/models/repository methods.
- Retired all mobile task write endpoints; ERP `sync_request` and assignment
  adapters remain.
- Removed unused service-to-knowledge fallback and stopped substituting
  hardcoded support contacts, payment WhatsApp numbers, and expense categories.
- Compatibility adapters translate legacy endpoint/parameter names only; they
  cannot bypass verification, consent, finance, or object scope.
- Missing required-document/support/payment/category configuration returns an
  empty/unavailable state rather than invented business data.

## External prerequisites and validation rules

- Ordinary Frappe test-record bootstrap remains blocked by the external client
  schema dependency `GST Category`; OMC does not edit ERPNext/client metadata.
- Physical biometric behavior and real Firebase/APNs delivery require devices
  and credentials and remain explicitly unverified.
- Final command evidence is recorded in the handoff after serial backend tests,
  Flutter tests/builds, HTTP smoke checks, diff check, and protected-core proof.
- Frappe 14 can exit zero while unittest text reports failures, so logs—not exit
  code alone—are the acceptance authority.

## Protected-core boundary

Final proof is an empty `git diff -- apps/frappe apps/erpnext`. A local database
migration synchronizes installed schemas but does not modify checked-in core.
