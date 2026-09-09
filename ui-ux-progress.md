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
- Current implementation main before this ledger update: `262b07d69786d5a5bbd826862815bc69cb547399`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed E IDs / groups |
|---|---|---|
| 1 — Design System V2 + shared primitives | COMPLETE — source implementation; Flutter runtime validation pending | Shared foundation only; no E ticket marked complete solely from theme/component work |
| 2 — Shell/navigation/global UI | IN PROGRESS | Shell/global surface tickets to be marked only after each actual surface is inspected and migrated |
| 3 — Customer journey + operations | PENDING | — |
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

Implemented:
- Long account names reflow instead of one-line ellipsis.
- Identity controls remain 48px and avatar treatment uses the runtime theme instead of decorative module colors.
- Legacy shared list card now uses radius16, 20px padding, neutral icon treatment, no ordinary shadow, and stacks trailing actions at narrow/large text.
- Focused source tests added for 320px / 2x identity and list-card reflow.
- Remaining search/filter implementations were inspected. They are feature-local and own debounce/filter state; section F explicitly does not mandate a new wrapper per row, so their visual migration stays with their owning screen phases rather than introducing an unused generic controller layer.

## Validation actually run

- GitHub `main` rechecked before each editing batch; no unexpected concurrent change was present.
- GitHub source was re-read for affected primitives and representative callers.
- Combined GitHub commit status for `5285f62b...`: no status checks reported.
- Combined GitHub commit status for `262b07d6...`: no status checks reported.
- Local Flutter/Dart: **NOT RUN — Flutter toolchain unavailable in this execution environment.**
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- Device/render matrix: **NOT RUN**; final device validation remains pending by design.

## Phase 2 current batch

Inspect and modernize both shell implementations plus:
- `omc_bottom_nav.dart`
- `omc_more_sheet.dart`
- `omc_quick_actions_sheet.dart`
- `app_back_header.dart`
- global sheet/dialog framing
- route/access/readiness/lock presentation

Preserve exact shell indices, routes, dirty-form protection, capability gates and callback authority. Central Quick Actions remains an action sheet, and the Documents shell branch remains intact.

## Exact next batch

1. Modernize bottom navigation with readable 12px labels and content-driven height.
2. Replace tiny fixed 3-column Quick Actions with adaptive 2-column / 1-column presentation.
3. Simplify More to neutral icon rows while keeping Tax, Knowledge and Alerts clearly discoverable.
4. Migrate shared page header and global sheet frame without changing back/cancel/navigation authority.
