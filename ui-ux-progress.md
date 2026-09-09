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
- Current implementation main before this ledger update: `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4`
- Blueprint source-audit parent: `b42ed754fdb58dcd672497ba2e2e612658e1b882`
- Backend: out of scope unless a genuine blocking defect is proven.
- Functional/navigation/provider/payload authority: frozen per `ui-ux.md` J1/J2 and lifecycle clarification.

## Phase status

| Phase | Status | Completed E IDs / groups |
|---|---|---|
| 1 — Design System V2 + shared primitives | IN PROGRESS | No E IDs yet; shared foundation itself does not complete a surface ticket |
| 2 — Shell/navigation/global UI | PENDING | — |
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

Implemented:
- C1 semantic typography hierarchy and reading/financial roles.
- C2 spacing/radius/touch-target/layout tokens with 320/phone/tablet page insets.
- C3 neutral/semantic colors; exact runtime accent preserved; presentation-only contrast-safe `accentInk`/`accentFocus` derived without backend/schema changes.
- C4 12/16/20/24 radius family and no-shadow default bounded surfaces.
- C5 56 primary / 52 secondary actions, readable form styling and stable loading label behavior.
- Shared status, section, metric, state and list-header primitives migrated toward C1-C7.
- Focused contract tests added/expanded for semantic scale, runtime accent contrast, large text, loading action stability and nested semantics.

### Shared surfaces — `09e582082b9fa526fd2fe6321dc7cf2ca37c90f4`

Commit: `ui: modernize shared mobile primitives`

Files changed:
- `omc_app/lib/core/widgets/premium_card.dart`
- `omc_app/lib/core/widgets/premium_info_chip.dart`
- `omc_app/lib/core/widgets/data_freshness_banner.dart`

Implemented:
- Shared cards use neutral surface + border + radius16 with no ordinary shadow.
- Info chips use readable metadata sizing, wrapping and preserved caller-supplied meaning.
- Freshness banner preserves stale source/timestamp/retry behavior while using readable warning hierarchy and adaptive retry layout.

## Validation actually run

- GitHub `main` rechecked before both editing batches; no unexpected concurrent change was present.
- GitHub source was re-read for affected primitives and representative callers before changes.
- Combined GitHub commit status for `5285f62b...`: no status checks reported.
- Local Flutter/Dart: **NOT RUN — Flutter toolchain unavailable in this execution environment.** The execution container has no Flutter/Dart binary and cannot resolve GitHub for a checkout.
- `flutter analyze`: **NOT RUN**.
- Flutter tests: **NOT RUN**.
- Device/render matrix: **NOT RUN**; final device validation remains pending by design.

## Unresolved Phase 1 work / risks

- Phase 1 is intentionally not marked complete yet.
- `AppBackHeader` still needs safe migration; its current fixed `PreferredSizeWidget` sizing and one-line title/subtitle require caller-aware treatment. This is being deferred to the Phase 1/2 boundary rather than applying an unsafe global height hack.
- Global sheet/dialog geometry is themed, but individual `showModalBottomSheet` call sites still need migration/verification in their owning phases.
- Remaining shared search/filter/list/form wrappers and representative callers still need inspection before Phase 1 closure.
- Added tests are source changes only until a real Flutter runner executes them.
- No E ID is complete merely because shared foundations changed.

## Exact next batch

1. Inspect remaining shared search/filter/list/form primitives and representative callers.
2. Close Phase 1 only after shared-component consistency is source-verified and available validation evidence is recorded.
3. Move immediately into Phase 2: both shell implementations, `OmcBottomNav`, More, Quick Actions, `AppBackHeader`, global sheet frames and route/access/readiness presentation while preserving exact navigation authority.
