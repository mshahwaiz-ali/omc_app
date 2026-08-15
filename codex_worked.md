# Codex Work Report — OMC Production Workflow

Date: 2026-08-16

Branch inspected: `feature/customer-home-dashboard`

Audited HEAD: `2fdaa632d71ba0f94396c2089c2c52ac8cb006bd`

Work mode: Local checkout only. No branch creation, commit, push, pull request,
or publication was performed.

## 1. Purpose of this work

The implementation plan was to production-harden the OMC customer workflow,
introduce a referral commission ledger and settlement workflow, centralize
notifications, prepare the app for a future push provider, standardize bounded
pagination, and improve affected Flutter user journeys without changing
Frappe or ERPNext core.

The business lifecycle kept as the authority was:

1. A public applicant starts a pending registration.
2. Email/token verification activates the customer account.
3. An approved customer or an authorized referral owner creates a service
   request.
4. Required documents are uploaded against that request.
5. Payment proof is uploaded and reviewed.
6. Finance creates and submits the ERP Sales Invoice and Payment Entry.
7. The invoice must have zero outstanding balance.
8. The commission snapshot, OMC Paid state, and ERP Service/Task activation are
   completed together.
9. The customer and any consented referral owner see the same backend-authorized
   request, document, and payment state.

`OMC Service Request` remains the customer lifecycle authority. ERPNext Sales
Invoice and Payment Entry remain the accounting authority. ERP Service and Task
remain operational records, with Task exposed to the mobile app as read-only.

## 2. Initial inspection and contract inventory

The first planned task was to refresh `inspection.md` before changing behavior.
It now documents:

- the canonical lifecycle;
- UI action to route, capability, backend scope, endpoint, and refresh mapping;
- guest, customer, referral, operational, finance, manager, and admin scopes;
- commission authority and eligibility;
- notification events and their exact deep links;
- pagination response contracts;
- registered route and affected UI inventories;
- removed dead code and retained compatibility adapters;
- empty-state and preview-only fallback behavior;
- test limitations and protected-core boundaries.

The inspection records 57 registered Flutter routes, including the new
commission list and detail routes. It also records the existing UI census of
216 ellipsis uses, 764 explicit font-size sites, and 1,247 direct color
references. Changes were made to affected workflow surfaces where semantics,
readability, or responsiveness required them; this was not a blind global
rewrite of intentional styling.

## 3. Existing contract failures repaired

The starting contract drift was repaired before the new workflows were treated
as complete:

- removed a stale Flutter route inventory expectation;
- updated the expected authenticated payment-proof method name;
- made the payment serializer fixture tolerate the current document shape;
- corrected the invoice PDF test to use authenticated byte/base64 behavior;
- replaced the obsolete finance-failure expectation of `Receipt Submitted`
  with the retryable `Under Review` state.

## 4. Signup and verification hardening

Public signup now always begins the pending-registration flow. Account
activation was extracted into a private helper that is called only after a
verification token has been consumed successfully.

Legacy public signup endpoints remain as compatibility delegates, but they can
only start verification. They cannot directly activate a user or bypass token
validation.

Duplicate pending-registration declarations and duplicate decorators were
removed. The Flutter client no longer exposes the obsolete direct-signup API
constant.

Tests cover canonical pending signup, direct compatibility signup, duplicate
safety, referral linkage, token verification, and role normalization.

## 5. Backend authorization and shared referral access

Backend capabilities and record-level scope remain authoritative. Flutter route
visibility is only a user-experience aid and cannot grant access.

Self-service and consented-referral access are derived from backend customer,
request, referral, consent, and ownership records. A client-provided `assisted`
flag is not accepted as proof of access.

The implementation retains focused provider invalidation so the customer and
authorized referral owner refresh the same request, document, and payment
authority after mutations.

Mixed roles receive only the union of explicitly granted backend capabilities.
Revoked consent and unrelated records remain inaccessible through direct API
calls.

## 6. Atomic finance finalization

Payment review now uses one savepoint around the complete finance and activation
operation:

- create or reuse the ERP Sales Invoice;
- submit the invoice;
- create or reuse and submit the Payment Entry;
- require zero invoice outstanding;
- create the immutable referral commission snapshot when eligible;
- move OMC payment/request state to Posted/Paid;
- activate the ERP Service and Task operation.

An exception in finance or operational activation rolls the attempt back. The
payment is reloaded and retained as `Under Review`, with failed finance status
and diagnostic details for a safe retry. The failed attempt does not leave a
task or duplicate accounting/commission record behind.

Invoice actions are available only when a linked Sales Invoice exists and is
submitted. PDF content continues to be served as authenticated bytes.

## 7. Mobile task writes retired

The plan required ERP Desk to be the only task editor. The implementation
therefore removed obsolete Flutter task mutation constants, models, and
repository methods, and retired unreachable mobile task-write endpoints.

ERP-side request synchronization and task-assignment adapters were preserved.
The mobile contract retains only backend-scoped task list and detail reads.

## 8. Referral commission service configuration

`OMC Service` now owns:

- `referral_commission_enabled`;
- `referral_commission_percent`.

The percentage is validated server-side from 0 through 100. When commission is
disabled, the configured rate is normalized to zero so an inactive rate cannot
be mistaken for an active entitlement.

## 9. Immutable referral commission ledger

The new `OMC Referral Commission` DocType records:

- referrer user;
- referral record;
- customer profile;
- service request and service;
- qualifying OMC payment and ERP invoice;
- finalized invoice-paid basis;
- frozen percentage and commission amount;
- currency and earned period/date;
- Earned, Settled, or Reversed state;
- settlement reference/date;
- reversal reason/date;
- the unique finance event key.

The financial snapshot cannot be edited after creation. Settlement and reversal
history can change only through controlled workflows. Ledger rows cannot be
deleted; an audited reversal is required instead.

The unique event key is:

`payment:<payment>:finance-posted`

This makes finance retries idempotent and prevents duplicate earnings.

## 10. Commission eligibility and calculation

Commission is calculated only after successful finance posting, from the
submitted and fully cleared Sales Invoice `grand_total`, not from the service
list price.

Decimal-safe rounding is used for the monetary basis and commission amount.
The percentage, basis, amount, currency, invoice, payment, service, customer,
and referral links are frozen into the earning.

No ledger row is created for:

- a non-referral request;
- disabled commission;
- a zero rate;
- an inactive or revoked referral;
- missing or revoked customer consent;
- an ownership mismatch;
- an unsubmitted or outstanding invoice;
- an amount that rounds to zero.

Historical earnings do not recalculate when the current service rate changes.

## 11. Commission settlement and reversal

The new submittable `OMC Commission Settlement` and its child rows provide the
manager/admin settlement workflow.

A settlement must contain eligible Earned entries belonging to one referrer and
one currency. Submission atomically marks the included earnings Settled and
records the settlement reference/date. Submitted settlements cannot be
cancelled or silently deleted.

Managers and administrators may reverse an earning only through the audited
reversal API. A reason is mandatory, the reversal date is stored, the original
financial amount remains unchanged, and the prior settlement reference remains
part of the history.

Referral owners receive read-only access limited to their own earnings.

## 12. Commission APIs and Flutter screens

The following authenticated APIs were added:

- `get_my_commission_summary`;
- `get_my_commissions`;
- `get_my_commission`;
- the manager/admin reversal operation.

Two new capabilities were added:

- `can_view_referral_commissions`;
- `can_manage_referral_commissions`.

The Flutter app now registers:

- `/my-commissions`;
- `/my-commissions/:earningId`.

The commission list displays authoritative per-currency outstanding and settled
totals from the summary endpoint. It supports bounded load-more pagination and
server-backed filters for earned month, status, customer profile, and service.
The detail screen shows immutable basis, percentage, amount, source request,
customer, service, settlement, and reversal information.

The More menu exposes Commission only when the effective backend capability
allows it.

## 13. Notification event authority

Notification creation was centralized so recipient selection, category
preferences, deduplication, route validation, persistence, and optional push
dispatch do not drift across modules.

`OMC Notification` now has a recipient-qualified unique dedupe key and supports
the Commission category.

The exact route matrix includes:

| Event | Category | Destination |
|---|---|---|
| Service state or escalation | Service Request | `/my-services/:id` |
| Document review | Document | `/documents/:id` |
| Payment review | Payment | `/payments/:id` |
| Task assignment | Service Request | `/tasks/:id` |
| Support reply | Support | `/support-tickets/:id` |
| Commission earned, settled, or reversed | Commission | `/my-commissions/:id` |

The durable inbox retains bounded pagination, unread count, read, unread,
dismiss, restore, and mark-all-read behavior.

## 14. Notification preferences and push readiness

Global in-app notification enablement and global push enablement are now
separate from category preferences. Email and WhatsApp controls are not shown
as available channels when no genuine delivery provider is configured.

The backend push boundary provides:

- queued delivery after database commit;
- active-token filtering scoped to the current owner;
- site-configured provider lookup;
- a maximum of three delivery attempts;
- invalid-token deactivation;
- no checked-in provider credentials.

The Flutter side provides a push abstraction and contracts for:

- registration after authentication;
- unregistration during logout/account changes;
- token refresh;
- notification-open deep-link handling;
- an explicit unavailable provider implementation.

No Firebase package or platform configuration was fabricated. Because valid
Firebase/APNs files and credentials are absent, the app does not claim live
push delivery and does not expose production push as operational.

## 15. Bounded pagination

Affected unbounded APIs were standardized around:

```text
items
start
limit
has_more
next_start
```

Legacy collection keys and paging parameter aliases remain temporarily where
needed for compatibility, but they do not bypass authorization.

Bounded contracts cover commissions, service requests, customers, documents,
payments, tasks, notifications, support tickets, and existing referral/admin
queues. Scope and filters are applied before returning the page.

Dashboard previews remain limited to at most five actionable entries per
domain, with full queues reachable through their capability-gated routes.

## 16. Dashboard and affected Flutter UX

Needs Attention continues to use typed domain references and registered exact
routes rather than generic or fake case actions.

The Material 3 foundation and restrained palette were preserved. New and
affected financial/workflow surfaces use theme typography and semantic color
schemes. Important commission text wraps instead of depending on fixed content
heights.

The More menu remains approximately four items per normal phone row with
responsive wrapping and capability-derived items. The new commission screen was
tested at 320px width with 2x text scaling.

OS text scaling remains unrestricted.

## 17. Hardcoded business fallbacks removed

The implementation stopped substituting invented business data for missing
configuration, including:

- payment WhatsApp/contact fallback values;
- support topics and channels;
- expense categories;
- the unused service-to-knowledge fallback;
- required-document business configuration.

Missing configuration now produces an empty or unavailable state. Support
preview content exists only behind the explicit non-release
`OMC_ALLOW_SUPPORT_PREVIEW` configuration.

## 18. Important new source areas

Backend additions include:

- `omc_app/api/referral_commissions.py`;
- `omc_app/api/notification_events.py`;
- `omc_app/api/notification_delivery.py`;
- `OMC Referral Commission` DocType;
- `OMC Commission Settlement` DocType;
- `OMC Commission Settlement Item` child DocType;
- focused commission and notification delivery tests.

Flutter additions include:

- `lib/features/commissions/`;
- `lib/core/push/`;
- commission route and capability integration;
- commission contract and accessibility tests;
- push registration contract tests.

## 19. Verification completed

The final local evidence was:

- Frappe migration for the OMC-owned schema: passed;
- Python compilation: passed;
- focused backend commission tests: 9 passed;
- focused backend expense tests: 2 passed;
- focused backend notification delivery tests: 3 passed;
- complete serial OMC backend suite with `--skip-test-records`: 618 of 618
  passed in 90.138 seconds;
- Flutter formatting check: 236 files checked, 0 changes required;
- Flutter analyzer: no issues found;
- complete Flutter test suite: 326 of 326 passed;
- Linux workflow integration test: 1 of 1 passed;
- Flutter web debug build: passed, output at `omc_app/build/web`;
- Android debug build: passed, output at
  `omc_app/build/app/outputs/flutter-apk/app-debug.apk`;
- public service-catalogue HTTP smoke: HTTP 200;
- guest access to commission, task, and notification protected endpoints:
  HTTP 403 as expected;
- `git diff --check`: passed;
- protected Frappe/ERPNext core diff: empty.

The Android build emits a future Flutter/Kotlin Gradle Plugin migration warning,
but the current debug APK builds successfully.

## 20. Known external prerequisites and unverified hardware integrations

The ordinary Frappe test-record bootstrap remains blocked by the installed
client schema missing `GST Category`. This was intentionally not “fixed” by
editing ERPNext core or external client metadata. The complete OMC suite was
therefore run using the documented `--skip-test-records` mode.

Chrome integration could not run because the installed Flutter runner reports
that web devices are not supported for integration tests. The Linux integration
workflow passed instead, and the web build completed successfully.

The following require external devices or credentials and remain explicitly
unverified:

- physical biometric behavior;
- real Firebase Cloud Messaging delivery;
- Apple APNs-token readiness and delivery;
- production push-provider credentials.

## 21. Source-control and core boundary

All work remains in the local working tree. No Git publishing action was taken.

No introduced file change exists under:

- `backend_omc_app/frappe-bench/apps/frappe`;
- `backend_omc_app/frappe-bench/apps/erpnext`.

ERPNext/Frappe core modified by this task: **NO**

