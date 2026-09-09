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
- Current implementation main before this ledger update: `715137d58151d5fa66ee603365bc87cf18732429`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed E IDs / groups |
|---|---|---|
| 1 — Design System V2 + shared primitives | COMPLETE — source implementation; Flutter runtime validation pending | Shared foundation complete; no E ticket marked complete solely from theme/component work |
| 2 — Shell/navigation/global UI | COMPLETE — source implementation; Flutter/runtime/U validation pending | E042, E043, E062, E063, E064, E065, E066, E067 and E090 source-complete; runtime/device acceptance still pending |
| 3 — Customer journey + operations | IN PROGRESS | Begin E001–E017 and E022–E025 plus their owned inline/modal/platform surfaces |
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

## Validation actually run

- GitHub `main` rechecked before each editing batch; no unexpected concurrent source change was present.
- Changed source and representative callers were re-read after commits.
- GitHub combined commit status for Phase 2 implementation heads checked repeatedly, including `715137d5...`: **no status checks reported**.
- Local Flutter/Dart: **NOT RUN — Flutter toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- 320–1024 / 1.0–2.0 rendered matrix: **NOT RUN**.
- Biometric hardware/device flow: **NOT RUN**.
- Final local/device validation remains pending by design.

## Phase 3 current batch

Core customer journey + customer operations. Work from the live E tables rather than broad screen labels:
- E001–E004 Home/dashboard variants
- E005–E008 catalogue, service detail, request draft and assisted customer selector
- E009–E011 requests/tracking/canonical + assisted details
- E012–E015 documents/list/detail/preview/review-owned customer paths
- E016–E017 payments/list/detail/review-owned customer paths
- E022–E025 alerts and support customer/conversation paths
- applicable owned inline/modal/platform tickets such as E073–E080, E083–E085 and E144/E146 when their host surface is reached

## Exact next batch

1. Inspect current E001–E011 source and actual shared/home/service/request callers.
2. Modernize Home → Services → Service Detail → Request Draft → Requests/Tracking without changing provider/payload/lifecycle authority.
3. Preserve `attachments: []` in the request draft and keep required-document collection on post-request document/case surfaces.
4. Add/update focused source/widget contracts where safe, then re-read main and available status evidence before moving into Documents/Payments.
