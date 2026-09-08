# OMC Flutter production-readiness implementation plan

Approved plan, incorporating all five mandatory amendments and the subsequent explicit prohibition on firebase-admin. Saved before implementation on main. Baseline: b1f2b6f60572920d2341ab206f1aa910223ab4b2. Existing flutter_results.md is historical audit evidence and must be preserved.

## Scope and completion

Fix F001–F009 and collect release evidence. Work on main only; no branch, PR, commit, push, production deployment or production business-data mutation. Preserve local changes, canonical authentication, capabilities, ownership, payment-first lifecycle, accounting and mutation idempotency. Do not edit ERPNext/Frappe core or unrelated dependencies. Reuse audit indexes and inspect only active custom contracts. Continue independent work when external gates block another package. Say “Its done boss...” only when implementation and required acceptance are complete; otherwise distinguish code completion and blocked release gates honestly.

## Dependency order

1. Receipts, catalogue/detail/templates, expenses and directories.
2. Notification preferences and delivery eligibility.
3. Backend FCM HTTP v1, Android transport and secure taps.
4. Configuration, maintenance and update gates.
5. Android hardening, release configuration and formatting.
6. Integrated acceptance and evidence.

Backend additive changes precede client consumers. Push remains operationally disabled until configured and accepted.

## Phase 1: request and data contracts

### A. Expense receipts — F002, P1

Files: expense_tracker_repository.dart, api/expense_guard.py and focused tests. Flutter sends canonical entry_id in multipart extra fields. Active guard accepts legacy docname for older callers, rejects missing/conflicting identifiers and delegates unchanged ownership/private-file validation. Arbitrary file_url is not a substitute. A saved expense survives attachment failure and offers receipt retry. Additive argument only; no schema migration. Test actual repository payload, active override, owned successful multipart attachment, foreign/missing/conflicting IDs and invalid files. Rollback retains compatible alias. Done when client, guard and local HTTP evidence agree.

### B. Catalogue, independent detail and authoritative templates — F007 P2 / F009 P1

Files: catalogue repository/providers/screens, service_detail_screen_impl.dart, template repository/controller, request-draft screen/helpers/repository, ApiConfig, api/public_catalogue.py and api/service_templates.py.

Preserve every field in get_service_catalogue's default response. Add optional lightweight query mode, explicitly requested by new Flutter; do not silently remove default fields. Remove sequential per-card template enrichment and silent template failure fallback. Catalogue uses 50-row pages, additive server search/category filters, 300 ms debounce and stale-response rejection. Detail calls existing get_service_detail(service_id) independently of list pages. Request entry fetches authoritative selected template before enabling fields/submission. Loading, unavailable, malformed and retry states are explicit; no generic request_context replacement. Valid explicitly empty schema differs from failed schema. Add service/pricing version metadata; refresh mismatches and block persistent conflict. Preserve draft values, reconcile changed fields and explain changes. Public template memory cache: canonical ID/version, five-minute TTL, maximum 32 entries, no cached failure; revalidate request entry. Preserve server pricing/validation.

API: additive lightweight/search/category parameters and template metadata; existing detail method in central config; no duplicate service API/schema. Tests: one catalogue HTTP call and zero template calls on list load; later-page search/direct links; slow/error/malformed/empty/inactive/version-conflict templates; no generic submittable form. Rollback retains additive server response. Done when performance and valid/failed request journeys pass.

### C. Expense history, totals and export — F006, P2

Files: expense repository/controller/screens/export, api/expense.py and api/expense_read_guard.py. Account mode uses paged cloud history; local mode retains identity-scoped storage. Add deterministic pagination with unique-ID tie-breaker, 100-row client pages / 200-row maximum and continuation metadata. Scope every page to current owner/filters. Server summaries aggregate complete authorized account/month, independently of visible page. Preserve response compatibility. Display pagination/month scope; never call a subset the whole account. Stop cloud refresh replacing local/pending collection. Show local pending data separately. Bound cloud view/cache to five pages, reload evicted pages, deduplicate and reject old session/filter generations. Export sequentially to temporary file with progress/cancel; publish only complete success, discard partial failures. Offline cache is labelled incomplete and is not a full-account export. Budget uses full-month totals.

MANDATORY AMENDMENT: no new persistent revision DocType/subsystem absent concrete code/test evidence. Prefer stable deterministic paging, authoritative totals and complete paged export. Do not claim point-in-time snapshot semantics without proof. No local database redesign merely to fix truncation. Test 0/1/200/201/thousands, date ties/month boundaries, failure/cancel/concurrent changes, pending local records, account switch, export count/totals. Rollback preserves local records/additive API. Done when records remain discoverable and summaries/export cannot silently represent a page as complete.

### D. Customer and lead directories — F008, P2

Files: customer/lead repositories/providers/screens, api/mobile.py:get_customers, api/lead_read_guard.py:get_leads and active wrappers. Add server search and deterministic pagination (50 client, max100 server), retaining legacy calls/fields. Apply canonical capabilities/relevance/ownership before search/count/page; parameterize query. Debounce300ms and reject stale responses. Preserve known-ID detail authorization. No thousands-record client download. Index only with query evidence. Test >100 authorized records, foreign records/counts, direct detail, rapid searches, empty/failure states. Done when continuation/search work without expanding scope; rollback retains legacy response.

## Phase 2: notification preferences — F003, P2

Files: settings model/repository/provider/screen; backend settings serializer/update wrappers, canonical notification creator and preference/notification DocTypes. Independent in_app_notifications_enabled and push_notifications_enabled masters; category preferences apply on top for each channel independently.

| Types | Category preference |
|---|---|
| Service Request / Service Update | service_updates_enabled |
| Support | service_updates_enabled |
| Task / Task Assignment / Task Update | service_updates_enabled |
| General | service_updates_enabled |
| Document | document_reminders_enabled |
| Payment | payment_alerts_enabled |
| Tax | tax_alerts_enabled |

Masters suppress new channel delivery, retain history, never replay suppressed events. Internal events bypass customer preferences; staff see device state rather than fake customer controls. Preserve Tax compatibility but hide advertised active delivery without a producer. Email/WhatsApp remain inactive compatibility fields. Add master fields/defaults without resetting categories; remove push-to-service alias. Return saved canonical values and show success only on persistence. Add per-notification in-app eligibility, existing rows visible. Push-only records remain authoritatively owned but absent from inbox/counts. Detail/tap always verifies current ownership/access. Expose provider configuration separately from permission/registration. Additive idempotent migration. Test category/channel truth table, relaunch, history, no replay, staff/customer and save failures. Rollback keeps columns/history, disables push. Done when settings and event eligibility agree.

## Phase 3: Android and backend FCM — F001, P1

Files: core/push/push_registration.dart, concrete transport/display helpers, main.dart, auth teardown, link coordinator, Android Gradle/manifest/resources, backend notification creator/controller/token APIs, dispatcher/scheduler and delivery DocType.

Flutter dependencies: compatible firebase_core, firebase_messaging and flutter_local_notifications, narrowly locked. Backend: DO NOT use firebase-admin. Verified environment Python3.10.20/Frappe14.96.12/ERPNext14.87.0; Frappe PyJWT~=2.4.0 conflicts with inspected Admin SDK >=2.10.1. pip check already reports ten baseline mismatches, including google-auth; do not repair unrelated packages. Document this conflict before choosing least-invasive FCM HTTP v1 using existing compatible authentication/HTTP capabilities; verify both declared Frappe constraints and actual installed APIs without unrelated upgrades.

Retain OMC Notification as business event. Add OMC Push Delivery attempt ledger linked to notification/token binding/intended owner; unique delivery key, status, attempts, retry time, lease, provider ID and sanitized error code. No raw token/credentials in ledger/logs. Durable local work, enqueue after commit and scheduler recovery; provider calls only background workers and never synchronously fail business actions. Recheck current recipient authority, referenced-record scope, token binding/ownership, expiry and preferences before send. Unique token hash and binding generation prevent stale reassigned sends. Retry transient errors with jitter/exponential delay/Retry-After, max8 attempts/24h. Revoke confirmed UNREGISTERED; distinguish payload/config/auth errors. Operational kill switch, counters, scrubbed diagnostics; no historic replay.

Android acquires/refreshes real token after canonical auth with generation guards. Contextual permission prompt, denial tracking/settings recovery. Attempt unregister before auth teardown; logout completes during outage, clears listeners/notifications and rotates/deletes token appropriately. Channel omc_updates, monochrome icon, private lock-screen visibility. Generic text plus opaque notification/binding IDs only; no business details/secrets/arbitrary routes. Android displays background notification payloads; foreground local display only after binding validation. Stable IDs/tags resist duplicate display; no exactly-once promise.

One tap coordinator handles local/foreground/background/cold start, waits for config/auth/device lock, fetches authoritative notification with current credentials and applies existing route policy. Explicit task/internal destinations, no arbitrary URLs. Wrong account/revoked/missing/expired references recover safely; push-only records do not enter inbox counts. Android Settings force-stop requires reopening; do not promise bypass. iOS/web delivery outside scope, retain other target builds.

Additive token/ledger migration with idempotent dedup; external Firebase configuration/service identity/workers needed. Test mocked errors/concurrency/rotation/taps plus physical matrix. Rollback disables dispatch first, retains ledger/in-app/business operations. Done only after real configured Android delivery/tap evidence.

## Phase 4: config and release controls — F004/F005, P2

Files: app-config model/repository/provider, root/router gate, More/Quick Actions, gate UI; backend config/admin validation. Distinguish loading/current/stale/unavailable. Unknown flags never enable business features. Validated public config cache by API origin, TTL5min, revalidate startup/resume/retry. Retain disabled/blocked state during outage; expired enabled config cannot unlock workflows. Bounded retry/backoff and honest recovery; fallback never cached as success. Central gate covers direct/restored routes/shortcuts.

Maintenance blocks everyone including mobile admins; allow retry/exit/logout, recover through existing Desk. Semantic minimum_app_version via direct comparison dependency, ignore build metadata, honor prerelease. Below minimum+force: nondismissible; below minimum without force: prompt dismissible24h per installed/minimum pair. Equal/newer continues. Reject invalid admin values/force without minimum; malformed required controls show recoverable config gate. Play URL derived com.wajid.omc_house with HTTPS fallback. Preserve links/drafts while gated and reauthorize resume. No migration enables maintenance/raises minimum. Mobile gate not a replacement for backend authorization or enforcement on old clients.

Tests: cold/outage/stale/all-disabled/maintenance/direct-links, 9.10 vs9.9, invalid metadata and unavailable store. Rollback through Desk before app rollback; retain fail-closed origin/Sentry. Done when entry routes honor controls.

## Phase 5: Android hardening/release

Files: main/debug/profile manifests, backup XML, narrow Gradle/release dependencies, six audit formatting files and touched Dart files. Release cleartext false; preserve narrow development host allowances. Backup choice: exclude all app data from cloud and device transfer with allowBackup=false plus legacy/Android12+ rules; verify merged manifest/device behavior, retain explicit expense export/sync recovery. Do not claim encryption. Keep signing identity/routes and fail-closed production HTTPS/origin/Sentry. Real Firebase configuration only, server credentials never in app/repo. No unrelated formatting churn.

Play acceptance MUST verify applicationId com.wajid.omc_house; versionCode greater than previous Play12; planned versionName9.0.0/versionCode13 unless intentionally bumped; certificate matches existing Play application (distinguish upload/app-signing identity where applicable). NEVER regenerate or replace release key. Signed/installed release and Play continuity remain external gates; no publication authorized.

Tests: merged permissions/backup/network; dev connectivity; release HTTP/config rejection; signing/build/install. Rollback never replaces key or removes backup protections; push independently disabled.

## Phase 6: efficient acceptance

Focused tests after every package. Final formatting/static script, flutter analyze, full Flutter tests, Linux constructed integration (label accurately), one clean full serial custom-backend suite after Redis/DB prerequisites, local HTTP journeys using approved isolated actors, genuine signed Android checks when configured, git diff --check/review/status. Do not recycle prior462/963 counts or trust exit code alone. Preserve canonical session/capability/ownership/payment/lifecycle/accounting regressions; source tests do not equal renderer/HTTP tests. Repeat broad tests only after relevant changes/failure.

Physical: foreground/background/terminated/force-stop, grant/deny/settings/channel, refresh/offline logout/A-to-B/stale messages/revocation, cold/warm case/document/payment/support/task taps, retries/missing/push-only preferences, >50services/>100directories/>200expenses, template retry/receipts, representative sizes/text/keyboard/back/resume, picker/share/PDF/biometrics. Record build/device/actor/trigger/result. Provider acceptance is not panel/tap proof.

External gates: Firebase package/project/credentials, secure server identity/workers, genuine scrubbed Sentry event, isolated customer/staff actors, physical Android, Play signing/version continuity, assetlinks and activation/reset email journey, signed installed release. No fake credentials or delivery receipts.

## Rollout, rollback and evidence

Local additive migrations first; production deployment requires separate authorization. Backend compatibility before client; push off until accepted; minimum version unchanged until compatible distributed build. Retain history/local expense/delivery evidence, avoid destructive down-migration. Observe queue age/failures/token/template/config errors with scrubbing. Generic payload and authenticated taps limit content exposure from already-accepted stale OS messages; cannot recall provider-accepted notifications reliably.

Preserve historical flutter_results.md and append dated implementation evidence or separate clearly linked implementation section with exact files, migrations/config, actual tests/results, external/device/Play gates and final git status --short. Production-ready means all nine defects corrected, applicable tests/HTTP green, actual Android delivery/taps and release/signing/config verified, no unresolved blocker. Code completion alone is not release readiness. Never alter ERPNext/Frappe core, unrelated metadata/payment/accounting/authority/package identity or Git publication state.
