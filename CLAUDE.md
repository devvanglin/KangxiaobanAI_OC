# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace layout

This repo is a HarmonyOS workspace. Only one project is an active delivery target; everything else is a read-only reference sample.

- **`KangxiaobanAI/`** — 康小伴AI (KangxiaobanAI), a HarmonyOS NEXT native smart elderly-care caregiver workbench. **This is the only project you edit.** All development happens under `KangxiaobanAI/products/entry/src/main/ets`.
- All other top-level directories (`Spatialization/`, `MusicHome/`, `NavigationSettings/`, `ResponsiveLayout/`, `cases/`, `*-sample-code-*/`, etc.) are **read-only reference samples**. Never copy a sample wholesale — extract the smallest verified pattern that matches the current API generation and adapt it to V2/HDS.
- `AGENTS.md` (repo root, ~69KB) is the exhaustive working-conventions doc. This file is the condensed version; consult `AGENTS.md` for the full ruleset.

The app is a high-fidelity **local interactive prototype**: mock data only, no network layer, no real auth, deterministic local AI text. Do not represent local array mutations as persisted/service operations, and do not build authorization on the role string.

## Build, lint, test

DevEco Studio / Hvigor. Run from `KangxiaobanAI/`. There is no root CI wrapper.

```bash
# Build (product "default", module "kanxiaoban")
hvigorw assembleHap --mode module -p product=default -p buildMode=debug
hvigorw assembleHap --mode module -p product=default -p buildMode=release
hvigorw clean

# Tests (Hypium) — or run via DevEco's test runner
hvigorw test
```

- **SDK**: target = compatible = `6.1.1(24)` (API 24). Runtime OS HarmonyOS. Device types: `phone`, `tablet`, `2in1`.
- **Bundle**: `com.gxoc.kxbai`. Signed artifact lands at `KangxiaobanAI/products/entry/build/default/outputs/default/kanxiaoban-default-signed.hap`.
- A `default`-product build success does **not** prove other device forms build. State build status honestly: Implemented / Build-verified / Device-verified / Planned.

### Tests (Hypium)

Two trees under `products/entry/src/`:
- `src/test/` — local unit tests (JS VM, no device). Suite `localUnitTest`.
- `src/ohosTest/` — instrumented on-device tests. Suite `ActsAbilityTest`, module `entry_test`.

Structure: `describe(name, () => { it(caseName, filterLevel, () => { expect(x).assertEqual(y) }) })`, importing from `@ohos/hypium`. Current tests are DevEco template stubs, not real product tests.

### Lint (`code-linter.json5`)

Scans `**/*.ets` (ignores test/mock/generated dirs). Rule sets `@performance/recommended` + `@typescript-eslint/recommended`. **Weak/legacy crypto rules are `error` and fail the build** (no-unsafe AES/hash/DH/DSA/ECDSA/RSA/3DES). Never introduce legacy crypto.

## Architecture

### State: ArkUI V2 only

Use the **V2 state system exclusively**. Never introduce V1 decorators (`@State`/`@Prop`/`@Observed`/`@Watch`) into the product.

- Structs are `@ComponentV2`. Props: `@Param` / `@Param @Require`. Callbacks: `@Event` (default no-op). Local state: `@Local`. Reactions: `@Monitor` (not `@Watch`). Cross-tree: `@Provider`/`@Consumer`. Derived: `@Computed`.
- **Global app-scope state is a single `@ObservedV2` class, `GlobalInfoModel`** (`model/GlobalInfoModel.ets`), shared via `AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel())`. Any component needing device metrics / role connects the same singleton. Mutating a `@Trace` field re-renders all connected views.
  - `@Trace` fields (trigger rebuild): `foldExpanded`, `widthBreakpoint`, `heightBreakpoint`, `naviIndicatorHeight`, `statusBarHeight`, `keyboardHeight`, `deviceHeight`, `deviceWidth`, `role`.
  - Non-`@Trace` (updates alone don't rebuild): `needDynamicHideBar`, `aspectRatio`.
  - Storage keys (`StorageKey` in `common/CommonConstants.ets`): `kanxiaoban_UIContext`, `kanxiaoban_GlobalInfoModel`, `kanxiaoban_CustomMaterialLevel` (unused).
- Only session/env/window/role goes in `GlobalInfoModel`. Business records/lists/forms do **not** — they stay local to components.
- `UIContext` is also stored in `AppStorageV2` (`StorageKey.UI_CONTEXT`) so non-UI utils (`PreferenceManager`) can obtain a context.

### Device state pump: `util/WindowUtil.ets`

Single source of truth for device metrics. `WindowUtil.initialize(windowStage)` (called from `EntryAbility.onWindowStageCreate`) caches the window + UIContext, forces immersive full-screen with transparent bars, and registers `windowSizeChange` / `avoidAreaChange` listeners that write status-bar height, nav-indicator height, keyboard height, device W/H, aspect ratio, and both breakpoints back into `GlobalInfoModel`. **Read these from `GlobalInfoModel`; never re-query the window.** Because the app runs immersive full-screen, pages pad manually using `statusBarHeight` / `naviIndicatorHeight`.

### The dual-layout split (the defining pattern)

Every major surface renders one way on phone, a fundamentally different way on wide. Selection keys off `GlobalInfoModel.widthBreakpoint`:
- `WIDTH_SM` → **phone**: single-column lists, bottom tabs, `bindSheet` sheets, `bindContentCover` full-screen covers.
- `WIDTH_MD/LG/XL` → **wide**: multi-pane master-detail, sidebars, hover/keyboard/focus affordances.

Logic centralized in `util/BreakpointSystem.ets`: `BreakpointUtil.isWide()` = MD|LG|XL, `isTablet` = MD, `isPc`/`isExtraWide` = LG|XL. Responsive scalar values via `new BreakpointType<T>({xs,sm,md,lg,xl}).getValue(widthBreakpoint)` (with `xs→sm` and `xl→lg` fallbacks).

### Role × layout gating (护工 / 医师 / 管理 = caregiver / doctor / admin)

- Role is a plain `string` on `GlobalInfoModel.role` (default `'护工'`), set at login. **Display-only, NOT authorization.**
- `MainPage.wideShell()` dispatches by role: `管理` and `医师` both use the shared `WideAdminWorkspace`, while other
  roles use `WideCaregiverWorkspace` (all in `component/wide/`). `WideDoctorWorkspace` is retained only as a
  compatibility facade.
- **Phone builds out 护工 (caregiver) only.** Doctor/admin have no phone equivalent — on phone both show the same
  "适配中" stub (`roleWipPanel`).

### Navigation: three distinct mechanisms

1. **Inter-page router** — only Login↔Main. `router.replaceUrl` at the auth-shell boundary only (login success / logout). Emits deprecation warnings; do not extend this for in-app flows.
2. **Intra-shell `NavPathStack`** — `MainPage` owns `@Provider('mainPageStack') pathStack`; children consume via `@Consumer('mainPageStack')`. `HdsNavigation(this.pathStack).navDestination(destinationBuilder)`. Route names map to destinations (e.g. `AboutPage`/`GeneralSettingsPage` → `MineDetailPage` by `pageType`). Push via `pathStack.pushPath({name})`. **Adding a real route means editing both `main_pages.json` and `destinationBuilder`.**
3. **Overlay covers (NOT navigation)** — AiChatPage, HealthExpandPage, ResidentDetailPage, task-expand are `Stack`-layered covers toggled by `@Local is*Show` booleans + `animateTo(curves.interpolatingSpring)`, using shared-element `geometryTransition` IDs. They look like pages but are conditional overlays inside a component's `build()`. `onBackPress` intercepts to close them.

Only **two real router pages** exist (`main_pages.json`): `pages/LoginPage`, `pages/MainPage`. Everything else is a component, NavPathStack destination, or overlay.

### Data-driven tabs

- `model/TabPageModel.ets` → `TAB_PAGE_CONFIGS` (4 entries: home / elder / task / mine), fully data-driven page specs sourced from `$r('app.string.*')`. `component/TabPageView.ets` renders from this config.
- `model/TabsBarModel.ets` → caches `BottomTabBarStyle[]`; defines the 4 bottom icons and 4 pre-created `Scroller`s bound to the nav title bar for scroll-driven blur.
- **Legacy misnomer warning**: tab resource keys `tab_music`/`tab_message` now mean 长者/任务 (residents/tasks). Don't trust the key names.
- `model/DetailTypes.ets` — pure domain types (no logic). `StatusLevel = 'normal'|'warning'|'danger'` is the app-wide severity enum for color coding.

### HDS (HarmonyOS Design System) UI

Heavy use of `@kit.UIDesignKit`: `HdsNavigation`, `HdsNavDestination`, `HdsTabs`/`HdsTabsController`, `HdsListItemCard` (universal row primitive with `PrefixIcon`/`SuffixText`/`SuffixButton`/`SuffixArrow`/`SuffixSwitch` slots), `HdsActionBar`, `hdsMaterial`. Icons are system `$r('sys.symbol.*')` glyphs.

- **Immersive title-bar recipe** (recurring): `systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: ADAPTIVE }` + `scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR }` gives the frosted blur-on-scroll bar. `HdsNavDestination` pages use `titleMode(MINI)`, `hideBackButton`, `expandSafeArea([SafeAreaType.SYSTEM],[TOP,BOTTOM])`, `ignoreLayoutSafeArea`.
- **Shared-element (一镜到底) transition**: `geometryTransition(id, {follow:true})` on source + `geometryTransition(id)` on destination, both with `.transition(TransitionEffect.OPACITY)`, presented via `bindContentCover(..., {modalTransition: ModalTransition.NONE})`. Insert/remove inside `animateTo`. Selected source renders an empty placeholder to carry the morph. Clear item-specific IDs on close.
- **Keyboard adaptation**: react to global `keyboardHeight` via `@Monitor('globalInfoModel.keyboardHeight')`, keep a local `keyboardOffset`, animate with `animateTo`, apply `.padding({bottom})`. Do **not** use `expandSafeArea(KEYBOARD)` (double-avoidance conflict).

### Theming

Two token systems coexist. Dark mode is automatic (`COLOR_MODE_NOT_SET` + `dark/element/color.json`).
- Phone + caregiver-wide surfaces: system tokens (`sys.color.*`, `sys.float.*`) + app palette (`app.color.brand_blue`, `status_danger/warning/normal`(`_bg`), `text_on_brand`, `ai_feed_background`).
- Doctor + Admin consoles: dedicated dark `app.color.doctor_workspace_*` palette (surface/border/accent/text_* etc.) — the "professional console" theme.

## Key files

| File | Role |
|------|------|
| `products/entry/src/main/ets/entryability/EntryAbility.ets` | App entry; loads LoginPage, inits WindowUtil |
| `pages/MainPage.ets` | Shell; owns pathStack, dispatches phone tabs vs wide workspace by role |
| `pages/LoginPage.ets` | Auth/role selection (accepts any non-empty creds after 800ms) |
| `pages/AiChatPage.ets` | 康小伴 AI chat (dual-layout, sessions in AppStorageV2, deterministic local AI) |
| `component/TabPageView.ets` | Phone shell (~3450 lines) — 4 tabs, mock data, sheets + expand covers |
| `component/wide/Wide*Workspace.ets` | Caregiver console plus the shared Admin console used by Doctor/Admin; `WideDoctorWorkspace` is a compatibility facade |
| `component/wide/WideSlidingCapsule.ets` | Shared animated segmented-control primitive |
| `component/*Card.ets` | Shared list cards (Health/Event/Device/ResidentSummary) |
| `model/GlobalInfoModel.ets` | Single global observed state class |
| `model/{TabPageModel,TabsBarModel,DetailTypes}.ets` | Tab config + domain types |
| `util/{WindowUtil,BreakpointSystem,PreferenceManager,MaterialUtil,Logger}.ets` | Device pump, layout, prefs, material, logging |
| `KangxiaobanAI/IMPLEMENTATION.md` | Deep dive on the 7 core patterns above |

## Conventions & cautions

- Keep I/O, timers, mutation, and heavy parsing/sorting out of `build()` and hot builders. Use `@Builder` for repeated UI; plain private functions for calculation. Use stable keys for `ForEach`/`Repeat`/`LazyForEach`.
- Fixed information architecture: **don't add a new first-level tab** without explicit product approval. New flows enter via an existing feature root + NavPathStack destination.
- Use resource refs (`$r('app.string.*')`, `$r('sys.color.*')`, `$r('sys.symbol.*')`); don't grow hard-coded Chinese-text/color/spacing debt; don't edit generated resource files.
- **File-size discipline**: `TabPageView.ets` (~3450 lines) and `AiChatPage.ets` (~1555) are warning points, not templates. `WideDoctorWorkspace.ets` is now a small compatibility facade over `WideAdminWorkspace`; keep it that way. Don't pile a new feature root + dataset + nav flow into a warning-point file in a single change; split by real ownership while preserving behavior.
- `StatusLevel` + `statusColor()`/`statusBg()`/`statusText()` helper triplets are currently duplicated across components (not centralized) — match the local pattern.
- **Known open defects** (avoid depending on them): `PreferenceManager.hasValue()` unbounded recursion; `HealthExpandPage` ListScroller not bound to its Scroll; `WindowUtil` listeners lack teardown (add symmetric cleanup before adding listeners); the retained `WideDoctorAdmission` component is not currently mounted by the parity shell; `MaterialUtil` unused; reduce-motion setting doesn't drive behavior.

### Security & Git

- Build-profiles (`KangxiaobanAI`, `MusicHome`, `NavigationSettings`, `Spatialization`, some samples) contain **local cert paths and inline passwords** — never print, quote, copy, or commit secret values.
- Working tree is dirty; existing changes belong to the user. Only commit when explicitly asked. Never run destructive Git or recursive cleanup. Never commit `.hvigor`/`build`/`oh_modules`/IDE/generated files.

### Source-of-truth order

Current build-profile / app.json5 / module.json5 / manifests / source > build logs > `AGENTS.md` > analysis docs & READMEs > sample comments. Trust `module.json5` `type` over directory name. Known drift: `KANGXIAOBANAI_ARKTS_DEEP_PROJECT_REPORT.md` says API 23, but the current product is API 24 — never change code just to match an old doc.
