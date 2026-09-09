# OMC Flutter UI/UX Implementation Progress

Execution ledger for `ui-ux.md`. GitHub `main` is authoritative.

## Five-phase execution map

The approved blueprint scope is retained in full, but the original implementation phases are consolidated into exactly five delivery phases:

1. **Design System V2 + shared primitives** — original Phase 1.
2. **App shell, navigation and global UI** — original Phase 2.
3. **Core customer journey + customer operations** — original Phases 3–4.
4. **Customer tools + Profile/Settings/Auth** — original Phases 5–6.
5. **Internal/Staff + accessibility/responsive/final regression closure** — original Phases 7–8.

No E001–E146 surface is removed by this consolidation.

## Current authority

- Baseline main SHA: `bd2c0d2c704b5ceb9ec7fae00cbf2e3746c94f9b`
- Current implementation main before this ledger update: `f9ec8afa866f59829423a06a973a661e09f52805`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed E IDs / groups |
|---|---|---|
| 1 — Design System V2 + shared primitives | COMPLETE — source implementation; Flutter runtime validation pending | Shared foundation complete; no E ticket marked complete solely from theme/component work |
| 2 — Shell/navigation/global UI | COMPLETE — source implementation; Flutter/runtime/U validation pending | E042, E043, E062, E063, E064, E065, E066, E067 and E090 source-complete; runtime/device acceptance still pending |
| 3 — Customer journey + operations | IN PROGRESS | E005, E006, E007, E008, E009 and E010 source-complete; E011 next; E001–E004 and E012 onward remain in this phase |
| 4 — Customer tools + account/auth | PENDING | — |
| 5 — Internal/staff + final QA closure | PENDING | — |

## Completed Phase 1 batches

### Foundation — `5285f62b3f69c9e882d2fe0e49ad274d6700fd7c`

Commit: `ui: establish mobile design system v2`

Files changed:
- `omc_app/lib/app/design_tokens.dart`
- `omc_app/lib/app/theme.dart`
- `omc_app/lib/app/app.dart`
- `omc_app/lib/features/app_config/presentation/app_brand_registry.dart`
- `omc_app/lib/core/widgets/app_button.dart`
- `omc_app/lib/core/widgets/omc_premium.dart`
- `omc_app/lib/core/widgets/premium_list_header.dart`
- `omc_app/lib/core/widgets/app_state.dart`
- `omc_app/lib/core/widgets/loading_view.dart`
- `omc_app/test/app/accessibility_design_contract_test.dart`

Implemented C1–C5/C7 foundation: semantic typography, spacing/radius/touch targets, neutral + semantic colors, preserved runtime accent with derived `accentInk`/`accentFocus`, calmer surfaces, readable forms/actions, stable loading labels, and large-text component contracts.

### Shared surfaces — `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4`

Commit: `ui: modernize shared mobile primitives`

Files changed:
- `omc_app/lib/core/widgets/premium_card.dart`
- `omc_app/lib/core/widgets/premium_info_chip.dart`
- `omc_app/lib/core/widgets/data_freshness_banner.dart`

Implemented neutral bordered cards, wrapping info chips, and readable stale-data/retry presentation while preserving source/timestamp/retry authority.

### Shared closure — `262b07d69786d5a5bbd826862815bc69cb547399`

Commit: `ui: close shared design system primitives`

Files changed:
- `omc_app/lib/core/widgets/omc_identity_header.dart`
- `omc_app/lib/core/widgets/premium_list_card.dart`
- `omc_app/test/app/accessibility_design_contract_test.dart`

Implemented long-name reflow, 48px identity controls, adaptive legacy list cards and focused 320px/2x source tests. Feature-local search/filter logic remains in owning screens because section F does not mandate a new controller/state abstraction.

## Completed Phase 2 batches

### Shell actions — `c3b5ac36084a6e42ed3b8023ffa632adbd6e6d35`

Commit: `ui: modernize mobile shell actions`

Files changed:
- `omc_app/lib/app/navigation/omc_bottom_nav.dart`
- `omc_app/lib/app/navigation/omc_quick_actions_sheet.dart`

Implemented content-driven bottom navigation with 12px labels, exact historical branch positions, non-selected central Quick action, full semantics and adaptive Quick Actions: two columns on ordinary phones, one column at narrow/large text and three only when genuinely wide enough. Capability order and host callbacks remain unchanged.

### More navigation — `a0e13620a64235e596ca56cb7734044e0f08920f` + acceptance correction `f157e0246bf49bac95c2502781f46a183a67457d`

Files changed:
- `omc_app/lib/app/navigation/omc_more_sheet.dart`
- `omc_app/lib/app/navigation/omc_navigation_ia.dart`
- `omc_app/test/app/omc_navigation_ia_test.dart`

Implemented Profile header → My OMC → Tax & knowledge → Tools & help → Account for customer variants while retaining internal capability grouping. Alerts remain discoverable; labels are exactly `Tax calculator` and `Knowledge & news`; rows are neutral, min56 and readable. All existing callback/capability authority remains host-owned.

### Device lock presentation — `50c377b87adfbe0a436e2049522f9eb167471079`

File changed:
- `omc_app/lib/features/device_lock/presentation/device_lock_gate.dart`

E042 source-complete. The router subtree remains mounted; while locked, underlying pointer input, keyboard focus, semantics and animations are excluded. Biometric/auth/logout/account-switch state logic is unchanged.

### Readiness/update presentation — `71a4216e0d8df245e2bd2e295370d00011174f64`

File changed:
- `omc_app/lib/features/app_config/presentation/app_readiness_gate.dart`

E043/E090 source-complete. Retry schedule, maintenance/feature policy, forced/recommended update distinction, dismissal storage, Play Store launch and saved-form retention are unchanged. Blocking UI now uses the mobile type/action hierarchy and semantic errors.

### Global recovery — `f76831d6af7abd557d9652458e71fed5710ef44d` + acceptance correction `f157e0246bf49bac95c2502781f46a183a67457d`

Files changed:
- `omc_app/lib/core/widgets/route_failure_screen.dart`
- `omc_app/lib/core/forms/dirty_form_controller.dart`

E066/E067 source-complete. Safe route recovery still comes from the existing router policy. Dirty-form registration, PopScope and non-dismissible Stay/Discard contract remain unchanged; Discard is now visually destructive.

### Adaptive shared page header — `715137d58151d5fa66ee603365bc87cf18732429`

File changed:
- `omc_app/lib/core/widgets/app_back_header.dart`

Header title26/supporting15 now wrap without important-text ellipsis. `preferredSize` measures the native platform text scaler and actual available width; back/action targets stay >=48. Every existing fallback-route mapping and NavigationCoordinator callback remains unchanged.

## Phase 2 source closure evidence

- `main_shell.dart` and `shell_nav_scaffold.dart` were re-read after the shared migrations.
- Exact shell order/index authority remains Home / Services / central action / Requests-or-Cases / More.
- Documents remains an actual shell branch/index for restoration/deep-link compatibility even though it is surfaced through More.
- `/more` still opens the sheet and dismisses to `/home` when no action is selected.
- Service request draft remains outside `ShellNavScaffold`; it owns only its existing submit bar and cannot create a nested shell bottom bar.
- Dirty-form checks remain before shell movement.
- Route names, parameters, query parameters and shell restoration IDs were not changed.
- Access-denied feedback and capability checks remain in their existing owners.
- Global sheet/dialog geometry is supplied by the Phase 1 theme; feature-specific sheets remain owned by their later surface phases so their state/callback contracts can be inspected locally.

## Completed Phase 3 batches

### E005 Service catalogue — `426ab8cf5d5893ae28aecb9402a07ebe95248fad`

Commit: `ui: redesign service catalogue`

File changed:
- `omc_app/lib/features/service_catalogue/presentation/service_catalogue_screen_impl.dart`

Source-complete presentation migration: full-width search and readable filters, result/pager hierarchy, two natural-height columns on ordinary phones and a one-column list at narrow/large text. Debounced query, category, pagination provider state, assisted customer parameters and service routes remain unchanged.

### E006 Service detail — `2ad6114ce65e6a56c29a0f94084b821ae7bec52d`

Commit: `ui: redesign service detail journey`

File changed:
- `omc_app/lib/features/service_catalogue/presentation/service_detail_screen_impl.dart`

Source-complete hierarchy: service identity → price/time → overview → requirements/documents → process → support → Start. Active-request duplicate lookup, resume/new-request choice, guest/pending routing, assisted query parameters and service-case destinations remain unchanged.

### E007 + E008 Request draft and assisted customer selector — `c79f01ea840b4e798ca11c8d6088e62b324bfbd7`

Commit: `ui: redesign request draft and assisted customer flow`

Files changed:
- `omc_app/lib/features/service_requests/presentation/assisted_customer_card.dart`
- `omc_app/lib/features/service_requests/presentation/service_request_draft_service_sections.dart`
- `omc_app/lib/features/service_requests/presentation/service_request_draft_form_sections.dart`

Source-complete one-form presentation migration: service summary → customer context → contact details → service information → review/document guidance → expandable post-submit stages → sticky Submit request action. Assisted selection keeps mode/search/customer/consent authority and distinguishes loading/error/empty. Long customer/service names and controls reflow at large text.

`service_request_draft_screen.dart` submission/state code was deliberately not modified. Source re-read after the commit confirms identical `ServiceRequestPayload` construction including `attachments: const []`, identical discount/assisted validation, `MutationIntent` idempotency, repository call, dirty-form state, tracking invalidation and returned-request navigation.

### E009 My requests / tracking — `1c533efa00b22aff1ad595331fbbea99fc810194`

Commit: `ui: redesign customer request tracking`

File changed:
- `omc_app/lib/features/service_requests/presentation/my_services_screen.dart`

Source-complete request list hierarchy: service → status → next step/summary → date/reference/action. Search corpus, filter matching, sort behavior, lifecycle/operational state derivation, historical/terminal safeguards and internal assisted route parameters remain unchanged. Status/actions stack at narrow/large text instead of compressing into 10–11px metadata.

### E010 Canonical customer request detail — `f9ec8afa866f59829423a06a973a661e09f52805`

Commit: `ui: redesign customer request detail`

Files changed:
- `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart`
- `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_sections.dart`
- `omc_app/lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart`

Source-complete hierarchy now prioritizes service/status → backend-authoritative next action → lifecycle → required documents → payment evidence → activity → secondary cancellation. Existing document upload identity/picker/repository payload and invalidations are unchanged. Payment preparation remains distinct from payment availability/pay-now, and rejected-document remarks are visibly readable. Cancellation still calls the same repository and invalidates canonical detail, tracking and Home summary; only its presentation is now explicitly destructive and large-text safe.

## Validation actually run

- GitHub `main` rechecked before each editing batch; no unexpected concurrent source change was present.
- Changed source and representative callers were re-read after commits.
- GitHub combined commit status for Phase 2 implementation heads checked repeatedly, including `715137d5...`: **no status checks reported**.
- E007 submission source was re-read after the UI commit and confirmed to retain `attachments: const []`, MutationIntent/idempotency, payload fields and repository call.
- E010 required-document upload source was re-read after the UI commit and confirmed to retain `serviceRequestId`, `documentKey`, `documentTitle`, `documentType`, attachment data and dependent invalidations.
- E010 cancellation source was re-read after the UI commit and confirmed to retain the same cancellation repository call and canonical detail/tracking/Home invalidations.
- Local Flutter/Dart: **NOT RUN — Flutter toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024 / 1.0–2.0 rendered matrix: **NOT RUN**.
- Biometric hardware/device flow: **NOT RUN**.
- Final local/device validation remains pending by design.

## Phase 3 current batch

Core customer journey + customer operations. Work from the live E tables rather than broad screen labels:
- E001–E004 Home/dashboard variants
- E005–E010 source-complete as recorded above
- E011 assisted / operational request detail — next
- E012–E015 documents/list/detail/preview/review-owned customer paths
- E016–E017 payments/list/detail/review-owned customer paths
- E022–E025 alerts and support customer/conversation paths
- applicable owned inline/modal/platform tickets such as E073–E080, E083–E085 and E144/E146 when their host surface is reached

## Exact next batch

1. Complete E011 assisted/operational detail while preserving all historical safeguards, document upload/review authority, administrative reassignment/sync/discount mutations and their existing invalidations.
2. Replace the compressed horizontal operational progress presentation with readable non-clipping progression and move administrative controls after customer/evidence context.
3. Then enter E012–E017 Documents and Payments, preserving authenticated preview/download, ownership, upload cancellation, status-to-action mapping and payment verification semantics.
4. E001–E004 Home/dashboard variants remain Phase 3 work and must be closed before Phase 3 is marked complete.
