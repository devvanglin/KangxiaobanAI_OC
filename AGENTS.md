# KangxiaobanAI_OC Agent Handbook

> Effective scope: this file applies to the whole workspace under `D:\KangxiaobanAI_OC`.
> Baseline date: 2026-07-22.
> Current branch when this baseline was written: `main`.
> This is an operational project constitution for coding agents. It records verified facts, fixed decisions,
> reference-project boundaries, and the HarmonyOS implementation rules that must be followed.

## 1. Project classification and fixed baseline

This workspace is **one active product plus a local HarmonyOS implementation corpus**. It is not one monolithic
application and the top-level projects are not equal delivery targets.

1. `KangxiaobanAI` is the active product and default delivery target.
2. `MusicHome`, `NavigationSettings`, `MultiDeviceCommunication`, and `MultiCommunityApplication` are multi-product,
   multi-HAR architecture references.
3. `ResponsiveLayout`, `transitions-collection`, `Spatialization`, `multi-tab-navigation`, and
   `multi-convenient-life` are focused UI/UX technique references.
4. `account-kit-samplecode-clientdemo-for-atomicservice-arkts`, `map-kit_-sample-code_-demo-arkts`,
   `push-kit-sample-code-clientdemo-arkts`, and `visionkit-sample-code-arkts` are Kit capability samples.
5. `sample_in_harmonyos`, `HarmonyOSComponentUXExamples-dev`, and `cases` are searchable knowledge bases.
6. Unless the user names another project, product work belongs in `KangxiaobanAI` and sample projects remain read-only.
7. Do not copy a sample wholesale. Select a matching API generation, extract the smallest verified pattern, and adapt
   it to the active product's V2/HDS conventions.

### 1.1 Product definition

`KangxiaobanAI` is a HarmonyOS NEXT native smart elderly-care workbench. The current code primarily serves caregivers;
it also contains a wide-screen doctor workspace and a wide-screen administrator workspace. The doctor role is an
elder-care/maintenance and assessment role, not an outpatient diagnosis screen. Phone doctor and administrator layouts
remain WIP placeholders. It is not currently a production clinical system, a real AI client, a distributed-device
application, or a connected institution backend.

The fixed product information architecture is:

- authentication shell;
- home/workbench situational overview;
- resident profile and health context;
- task and handover workflow;
- message/work communication;
- personal settings and account actions;
- advisory AI conversation;
- phone bottom navigation and tablet/2-in-1 wide workspaces.

Do not add another first-level tab without explicit product approval. New business flows should normally enter through
the existing feature root and `Navigation/NavPathStack` destination.

### 1.2 Current maturity

Treat the current application as a **high-fidelity local interactive prototype**:

- ArkUI/HDS presentation and responsive behavior are substantial.
- Login accepts any non-empty account/password after a timer.
- Resident, health, task, device, message, doctor, administrator, and workbench records are local mock data.
- AI responses are deterministic local text generated after a timer.
- There is no application network layer, repository, RDB schema, authenticated session, API DTO, WebSocket,
  distributed data service, or model gateway.
- There is no permission declaration in the main module because the current product does not call restricted Kits.
- Existing tests are DevEco/Hypium template assertions rather than product tests.

Do not describe mock UI as a real implemented service. In user-facing reports distinguish:

- `Implemented`: code path exists and can be traced locally.
- `Build-verified`: a recorded local build succeeded.
- `Device-verified`: explicitly tested on a supported real device.
- `Service-verified`: verified against configured AGC/backend service.
- `Planned`: desired architecture only, not current behavior.

## 2. Source-of-truth order

When facts disagree, use this order:

1. current `build-profile.json5`, `app.json5`, `module.json5`, package manifests, route profiles, and source code;
2. current generated build logs and artifacts, only as evidence of the build that produced them;
3. this `AGENTS.md`, updating it when an intentional architecture change lands;
4. root analysis documents and project README files;
5. sample comments or marketing descriptions.

Known documentation drift:

- `KANGXIAOBANAI_ARKTS_DEEP_PROJECT_REPORT.md` was accurate for an older snapshot but says API 23 and refers to files
  that are absent from the current source. The current product is API 24.
- `PROJECT_MEMORY.md` and `ARKTS_HARMONYOS_OFFICIAL_SAMPLES_GUIDE.md` are useful indexes, but some names, counts,
  versions, and paths are historical.
- Some project README/IMPLEMENTATION text describes upstream samples rather than the current checked-out code.

Never change code merely to make it match an old document. Update the document or record the drift after verifying the
current implementation.

## 3. Workspace safety and Git rules

The workspace may be dirty. Existing changes belong to the user unless the current task created them.

Known tracked edits at the baseline date:

- `MusicHome/build-profile.json5` contains local signing configuration.
- `MusicHome/products/tv/src/main/module.json5` locally adds `tablet` to TV module device types.
- `NavigationSettings/build-profile.json5` contains local signing configuration.

There are also many untracked `.hvigor`, `build`, `oh_modules`, IDE, lock, and generated files. Preserve them unless the
user explicitly asks for cleanup. Never run destructive Git or recursive cleanup commands to make the tree look clean.

Security-sensitive build profiles currently exist in:

- `KangxiaobanAI/build-profile.json5`
- `MusicHome/build-profile.json5`
- `NavigationSettings/build-profile.json5`
- `Spatialization/build-profile.json5`
- `HarmonyOSComponentUXExamples-dev/build-profile.json5`
- `map-kit_-sample-code_-demo-arkts/build-profile.json5`

Some contain local certificate paths and password fields; the Map sample may contain masked placeholders. Never print,
copy, quote, summarize, or commit secret values. If remediation is requested, rotate exposed material, remove it from
tracked history, and replace it with local/CI-injected signing configuration. Deleting only the current value is not a
complete remediation.

## 4. Required discovery workflow

Before changing a HarmonyOS project:

1. Identify the exact top-level project and whether it is an entry/feature HAP, HAR, HSP, atomic service, widget,
   ExtensionAbility, native hybrid, aggregate sample, or performance case.
2. Read the root `build-profile.json5` and `oh-package.json5`.
3. Read `AppScope/app.json5`.
4. Read every relevant module's `module.json5`, module `build-profile.json5`, and module `oh-package.json5`.
5. Trace `mainElement` to Ability `srcEntry`, then `loadContent`, `main_pages.json`, route map, root page,
   `Navigation/NavPathStack`, and destination builders.
6. Determine target/compatible SDK, device types, state generation, HDS dependencies, permissions, and public HAR
   exports before selecting an API or decorator.
7. Search this workspace for a same-generation implementation before inventing a pattern.
8. Consult current official HarmonyOS documentation when local samples disagree or API availability is uncertain.
9. Preserve unrelated changes and modify the smallest coherent ownership boundary.
10. Verify configuration, route consistency, static behavior, tests, build, and device forms in proportion to risk.

Use `rg`/`rg --files` for discovery. Exclude `build`, `oh_modules`, `.hvigor`, and IDE caches when counting or scanning
business source. Do not infer a module type from its directory name; the `module.json5` `type` field is authoritative.

## 5. Core application: verified configuration

### 5.1 Product and package

- Root: `KangxiaobanAI`
- Bundle: `com.gxoc.kxbai`
- Version: `1.0.0`, version code `1000000`
- Product: `default`
- Runtime OS: HarmonyOS
- Target SDK: `6.1.1(24)`
- Compatible SDK: `6.1.1(24)`
- Build modes: `debug`, `release`
- Module: `kanxiaoban` at `products/entry`
- Module type: `entry`
- Delivery: installed with application; not installation-free
- Device types: `phone`, `tablet`, `2in1`
- Ability: configuration name `KanxiaobanAbility`, source `entryability/EntryAbility.ets`
- Home skill: `entity.system.home` + `ohos.want.action.home`
- Pages profile: only `pages/LoginPage` and `pages/MainPage`
- Route map: none
- Restricted permissions: none
- Root business dependencies: none
- Test dev dependencies: `@ohos/hypium` 1.0.25 and `@ohos/hamock` 1.0.0
- Release obfuscation: currently disabled in module build configuration

Current configuration files:

- `KangxiaobanAI/build-profile.json5`
- `KangxiaobanAI/AppScope/app.json5`
- `KangxiaobanAI/oh-package.json5`
- `KangxiaobanAI/products/entry/build-profile.json5`
- `KangxiaobanAI/products/entry/oh-package.json5`
- `KangxiaobanAI/products/entry/src/main/module.json5`
- `KangxiaobanAI/products/entry/src/main/resources/base/profile/main_pages.json`

### 5.2 Startup and lifecycle

The verified runtime chain is:

```text
KanxiaobanAbility (class in EntryAbility.ets)
  -> onCreate: keep system color mode using COLOR_MODE_NOT_SET
  -> onWindowStageCreate
  -> windowStage.loadContent('pages/LoginPage')
  -> WindowUtil.initialize(windowStage) after successful load
  -> LoginPage.handleLogin()
  -> 800 ms local timer
  -> GlobalInfoModel.role = selectedRole
  -> router.replaceUrl('pages/MainPage')
  -> MainPage HdsNavigation/NavPathStack shell
```

`onForeground`, `onBackground`, `onDestroy`, and `onWindowStageDestroy` currently log only. `WindowUtil` registers
window listeners but the Ability does not unregister them. When changing lifecycle code, add symmetric cleanup rather
than creating another listener owner.

### 5.3 Authentication boundary

Traditional router is currently allowed only at the authentication shell boundary:

- login: `LoginPage` uses `router.replaceUrl` to enter `MainPage`;
- logout: `MainPage` and `TabPageView` use `router.replaceUrl` to return to `LoginPage`;
- in-app flows: use the shared `NavPathStack`.

The current login has no credential validation, token, tenant, refresh, RBAC enforcement, device trust, lockout, or
logout cleanup. `rememberMe` and forgot-password/contact-admin UI do not implement backend behavior. Do not build new
authorization assumptions on the selected role string.

### 5.4 Main navigation shell

`MainPage.ets` is `@Entry @ComponentV2` and owns:

- `@Provider('mainPageStack') pathStack: NavPathStack`;
- `GlobalInfoModel` from `AppStorageV2`;
- `HdsTabsController` and four tab styles;
- `currentTabIndex`, `primaryTabIndex`, sidebar state, and AI-cover visibility;
- `HdsNavigation` in `NavigationMode.Stack`;
- local destination builder for `AboutPage` and `GeneralSettingsPage`, both rendered by `MineDetailPage`;
- phone HDS Tabs and wide role-specific workspaces;
- AI conversation overlay using `AiChatPage`.

The role/layout matrix is fixed by current behavior:

| Role | Narrow phone layout | MD/LG/XL wide layout |
|---|---|---|
| Caregiver (`护工`) | Four HDS tabs | `WideCaregiverWorkspace` |
| Doctor (`医师`) | WIP placeholder | `WideDoctorWorkspace` |
| Administrator (`管理`) | WIP placeholder | `WideAdminWorkspace` local operations prototype |
| Any other string | WIP placeholder | WIP placeholder |

Phone tabs are home, resident, message/task area, and mine. They all instantiate `TabPageView` with a different
`currentTabIndex` and config. Wide caregiver layout composes wide home/resident/message content. Wide doctor layout is
a separate local mock workspace. Its `admission` sidebar branch mounts `WideDoctorAdmission` directly inside the
workspace shell; it is not a router or `NavPathStack` destination. Wide administrator layouts mount
`WideAdminWorkspace` directly; only its operations overview has local demo content and the other management modules are
placeholders.

`HdsNavigation` uses an immersive/adaptive system material title bar, gradient-blur scroll effect, four bound Scrollers,
hidden back button, a hidden title bar in wide layouts, and system-safe-area expansion. `HdsTabs` overlaps content,
floats above the navigation indicator, and preloads all four tab items. Measure startup/memory before extending preload.

### 5.5 Current route inventory

| Route or presentation | Mechanism | Owner | Destination |
|---|---|---|---|
| Login -> Main | `router.replaceUrl` | `LoginPage` | `pages/MainPage` |
| Logout -> Login | `router.replaceUrl` | `MainPage`, `TabPageView` | `pages/LoginPage` |
| About | `NavPathStack.pushPath` | wide shell / mine | `MineDetailPage('about')` |
| General settings | `NavPathStack.pushPath` | wide shell / mine | `MineDetailPage('general')` |
| AI assistant | animated local cover | `MainPage` | `AiChatPage` |
| Resident detail | transparent `bindContentCover` | `TabPageView` | `ResidentDetailPage` |
| Health expansion | transparent `bindContentCover` | `TabPageView` | `HealthExpandPage` |
| Task expansion | transparent `bindContentCover` | `TabPageView` | internal HDS destination UI |
| Task/message/profile detail | sheet/local pane | `TabPageView` | internal builders |
| Doctor admission | local workspace branch | `WideDoctorWorkspace` | `WideDoctorAdmission` |
| Administrator workspace | local wide workspace branch | `MainPage` | `WideAdminWorkspace` |

There is no `router_map.json`/`route_map.json` in the core product. If notification, card, deep link, dynamic HAR, or
cross-module entry is introduced, add a named route deliberately and keep module `routerMap`, route name,
`pageSourceFile`, exported builder, and parameter type mutually consistent.

## 6. Core application: state and data ownership

### 6.1 ArkUI generation

The current main source is ArkUI V2. New core components must default to:

- `@ComponentV2` for components;
- `@Local` for owned UI state;
- `@Param` and `@Require` for input;
- `@Event` for output callbacks;
- `@Provider/@Consumer` for tree-scoped dependencies such as the navigation stack;
- `@ObservedV2/@Trace` for observable models;
- `@Monitor` only for focused reactions without update cycles;
- `AppStorageV2.connect` only for genuinely application-scoped models.

Do not introduce V1 decorators into the core product without a documented interoperability need. Nearby API 17/20
samples use V1 and are conceptual references only.

### 6.2 Global environment model

`model/GlobalInfoModel.ets` is `@ObservedV2` and contains traced fields for:

- fold expansion;
- width and height breakpoints;
- navigation-indicator, status-bar, and keyboard heights;
- window width and height;
- selected role.

`needDynamicHideBar` and `aspectRatio` are currently ordinary, non-`@Trace` fields. Do not assume their updates alone
trigger UI rebuilds.

`common/CommonConstants.ets` defines aspect-ratio thresholds and these storage keys:

- `kanxiaoban_UIContext`
- `kanxiaoban_GlobalInfoModel`
- `kanxiaoban_CustomMaterialLevel` (currently unused)

The global model is appropriate for environment/session-shell state, not resident records, task lists, or form data.

### 6.3 Window and breakpoint implementation

`util/WindowUtil.ets`:

- obtains the main `window.Window` and `UIContext` after content load;
- connects the UI context and `GlobalInfoModel` through `AppStorageV2`;
- configures full-screen/system-bar behavior;
- reads initial system and navigation-indicator avoid areas;
- listens to `windowSizeChange` and `avoidAreaChange`;
- converts pixels to vp;
- updates device size, aspect ratio, width/height breakpoints, keyboard height, and safe-area values;
- sets `needDynamicHideBar` from breakpoint/aspect thresholds.

`util/BreakpointSystem.ets` provides `BreakpointType<T>` with `xs -> sm` and `xl -> lg` fallbacks plus:

- wide = MD/LG/XL;
- tablet = MD;
- PC/extra-wide = LG/XL.

Do not hard-code device names when a width breakpoint expresses the actual layout requirement. Keep safe-area and
keyboard padding live; never hard-code status/navigation bar heights. Add listener teardown before adding more window,
display, fold, configuration, or keyboard listeners.

### 6.4 Business models

`model/DetailTypes.ets` currently defines UI-facing interfaces and unions for:

- resident identity, room/bed, care level, diagnosis, allergy, emergency contact, and device IDs;
- health, mood, vital signs, vital trends, medication, meals, and risk assessment;
- care tasks, footprints, monitor snapshots, room devices, and alert events;
- status levels (`normal`, `warning`, `danger`) and task states (`todo`, `doing`, `done`).

These are prototype models, not transport contracts. When a backend is added:

1. keep API DTOs separate;
2. map DTOs to domain models;
3. represent missing/unknown values explicitly;
4. validate units, time zones, identifiers, and enum compatibility;
5. enforce tenant and role authorization outside the UI;
6. do not let UI components parse transport payloads.

### 6.5 Current mock ownership

The following local data must be treated as mock/demo state:

- `TabPageView.ets`: bed occupancy, health/device/event records, five residents, six tasks, medication/family/report
  items, inbox messages, filters, sheets, sign-in/out state, and cover state;
- `ResidentDetailPage.ets`: vitals/trends, monitors/devices, mood, footprint, medication, tasks, meals, risk, and alerts;
- `HealthExpandPage.ets`: eighteen health rows;
- `WideHomePage.ets`: clinical tasks and local task progression;
- `WideResidentPage.ets`: resident list and detail tabs;
- `WideMessagePage.ets`: conversations, records, unread state, filtering, and local replies;
- `WideDoctorWorkspace.ets`: navigation, recent patients, queue, modules, trends, and AI question field;
- `WideDoctorAdmission.ets`: four-step admission draft, identity/bed/contact fields, ability and health screening,
  nine service-safety risks, care-plan selection, and confirmation flags.
- `WideAdminWorkspace.ets`: local operations overview KPIs, bed-usage progress, follow-up event state, and placeholder
  entries for six additional management modules.

The admission flow does not call a repository, Preferences, RDB, or backend. Its generated draft exists only in
component state and is lost when the component is destroyed. The wide doctor AI submit control, wide message replies,
and wide home task transitions also remain local-only. Do not represent any of these as persisted operations.

The next architectural extraction order is fixed unless the task says otherwise:

1. preserve current UI behavior with tests/screenshots;
2. move data construction to per-feature `FakeRepository` implementations;
3. introduce feature ViewModel/store and cached derived values;
4. introduce UseCase/domain service boundaries;
5. define repository interfaces;
6. add real remote/local data sources;
7. move stable boundaries into HAR modules only after dependencies settle.

### 6.6 Doctor admission workflow and state contract

`WideDoctorAdmission` is mounted directly by the `admission` branch of `WideDoctorWorkspace`; it is not a route or a
`NavPathStack` destination. All form, screening, plan, confirmation, and submitted-state values are `@Local` values.
There is no repository, Preferences store, RDB, network request, or backend write. Component destruction discards the
draft.

The four gates are:

1. basic profile: resident name, integer age from 1 through 120, room, bed, contact name, and format-checked phone;
2. fifteen intake observations: four GB/T 42195-2022 primary dimensions, nutrition/swallowing, chronic-disease and
   medication support, plus the nine GB 38600-2019 service-safety risks;
3. explicit selection of one of three care plans: self-support, assisted care, or continuous care;
4. three human confirmations: doctor review, resident/representative informed consent, and service/fee disclosure.

Gender, identity number, intake source, diagnosis, and allergies are currently optional fields. Phone validation only
normalizes spaces, hyphens, and one leading `+`; it does not verify identity or carrier ownership. Every screening item
  starts as `-1`/unassessed. A non-normal safety risk additionally requires structured prevention/response measures,
  an owner, and a due/review point; a high-risk item also requires immediate safeguards and escalation/referral details.
  Changing the risk level clears those details so they must be confirmed for the new level. This is a prototype
  completeness gate, not a formal assessment scale or clinical diagnosis.

The local suggestion rule is deterministic and advisory: any ability score >= 3, at least two high safety risks, or a
total support score >= 16 suggests continuous care; any ability/health score >= 2, at least one high safety risk, or a
score >= 6 suggests assisted care; otherwise it suggests self-support. The suggestion never auto-selects a plan and does
not represent an official ability or nursing-care grade. Plan cards show three base service categories and five optional
service descriptions; optional services are display-only in this prototype and have no itemized price or billing record.
Fees are stated as institution-publication/service-agreement terms.

The admission dirty guard is limited to explicit in-workbench actions (sidebar/module navigation, AI, support/about,
settings, search, and logout). On discard it unmounts the admission branch before running the target action. It does not
cover process termination, system back, a breakpoint transition that removes the wide shell, or automatic saving. The
success view is a local in-memory draft preview; it is not a submitted or persisted admission record.

Responsive behavior is intentionally asymmetric: `MainPage` passes `admissionCompactWidth = true` for every non-XL
wide breakpoint, so MD and LG use stacked/compact admission content while only XL uses the 3+9 step/content layout,
two-column assessment cards, three-column risk/plan cards, and 5+7 confirmation split. The admission footer also adds
the live navigation-indicator avoid height.

## 7. Core application: file ownership map

Current production source is under `KangxiaobanAI/products/entry/src/main/ets`.

| Path | Ownership and verified responsibility |
|---|---|
| `entryability/EntryAbility.ets` | UIAbility lifecycle, LoginPage loading, WindowUtil initialization |
| `pages/LoginPage.ets` | mock login, role selector, keyboard-offset form, auth-shell routing |
| `pages/MainPage.ets` | root HDS navigation, phone/wide selection, role selection, AI overlay, local destinations |
| `component/TabPageView.ets` | all four phone tab feature roots, most phone mock data and sheets/covers |
| `pages/AiChatPage.ets` | local AI conversation UI, history, feedback/copy/edit, mock response timers |
| `pages/ResidentDetailPage.ets` | resident detail sections and local detail mock data |
| `pages/HealthExpandPage.ets` | expanded health list and resident index UI |
| `pages/MineDetailPage.ets` | about/general settings and Preferences-backed toggle values |
| `component/wide/WideCaregiverWorkspace.ets` | wide caregiver shell and settings/logout actions |
| `component/wide/WideDoctorWorkspace.ets` | wide doctor shell, local modules/AI state, admission branch, dirty guard, and admission layout forwarding |
| `component/wide/WideDoctorAdmission.ets` | local four-step admission draft, input validation, 15-item screening, risk-measure gate, advisory plan rule, three care plans, informed confirmations, responsive/accessibility rendering, and local preview/reset state |
| `component/wide/WideAdminWorkspace.ets` | wide administrator shell; local operations overview and placeholder management modules |
| `component/wide/WideHomePage.ets` | wide caregiver home and local task interactions |
| `component/wide/WideResidentPage.ets` | wide resident list/detail split view |
| `component/wide/WideMessagePage.ets` | wide conversation list/detail split view |
| `component/wide/WideSlidingCapsule.ets` | reusable hover/focus segmented selection control |
| `component/ResidentSummaryCard.ets` | resident summary/details builder and vital status presentation |
| `component/HealthListCard.ets` | health summary card |
| `component/EventListCard.ets` | event summary card |
| `component/DeviceListCard.ets` | device summary card |
| `component/WaterFlowView.ets` | responsive WaterFlow rendering using global window data |
| `model/DetailTypes.ets` | prototype resident/health/task/device domain-shaped interfaces |
| `model/GlobalInfoModel.ets` | app-scoped environment and role model |
| `model/TabsBarModel.ets` | HDS tab styles and four shared Scrollers |
| `model/TabPageModel.ets` | resource-backed four-tab presentation configs |
| `util/WindowUtil.ets` | window, safe area, keyboard, size, breakpoint, system-bar state |
| `util/BreakpointSystem.ets` | generic breakpoint values and layout predicates |
| `util/MaterialUtil.ets` | HDS material capability/options/fallback helpers; currently not called |
| `util/PreferenceManager.ets` | singleton ArkData Preferences JSON wrapper |
| `util/Logger.ets` | hilog wrapper |
| `common/CommonConstants.ets` | aspect thresholds and AppStorageV2 keys |

The largest current files are architectural warning points, not templates for further growth:

- `TabPageView.ets`: about 3,447 lines;
- `WideDoctorWorkspace.ets`: about 1,834 lines;
- `WideDoctorAdmission.ets`: about 1,801 lines;
- `WideAdminWorkspace.ets`: about 348 lines;
- `AiChatPage.ets`: about 1,555 lines;
- `WideResidentPage.ets`: about 1,272 lines;
- `WideHomePage.ets`: about 1,202 lines;
- `WideMessagePage.ets`: about 1,034 lines;
- `ResidentDetailPage.ets`: about 808 lines;
- `MainPage.ets`: about 741 lines.

Do not add a new feature root, large dataset, service call, and navigation flow to one of these files in the same change.
Split by real feature/section ownership while preserving current behavior.

## 8. Core application: HDS, responsive UI, and transitions

### 8.1 HDS is the active design system

The core imports `@kit.UIDesignKit`; preserve its HDS conventions instead of replacing them with plain ArkUI for
familiarity. Existing relevant components and options include:

- `HdsNavigation`, `HdsTabs`, `HdsNavDestination`, and `HdsListItemCard`;
- `HdsTabsController` and `BottomTabBarStyle`;
- `hdsMaterial.MaterialType.IMMERSIVE/ADAPTIVE` and `MaterialLevel.ADAPTIVE`;
- gradient-blur title-bar scroll effects;
- `barOverlap`, `barFloatingStyle`, navigation-indicator margin, and bound Scrollers;
- HDS prefix/suffix icon/text models;
- HDS title bar content/style APIs.

`MaterialUtil.isMaterialSupported()` and fallback helpers exist but currently have no caller. New material use must:

1. detect support where the selected API/device requires it;
2. use system material when available;
3. provide a plain background plus `backgroundBlurStyle` fallback;
4. keep contrast correct in dark and light modes;
5. bind title effects to the actual active Scroller;
6. avoid layering multiple translucent surfaces without a content/contrast reason.

### 8.2 Safe areas and window classes

Immersive rendering has two separate responsibilities:

- the visual canvas may extend behind system bars using `ignoreLayoutSafeArea`/`expandSafeArea`;
- interactive content must still account for status bar, navigation indicator, cutout, fold, and keyboard avoid areas.

Use live values from `GlobalInfoModel`. Do not infer status-bar height from a fixed number. Verify rotation, floating
window resize, keyboard opening/closing, dark mode, large fonts, mouse/keyboard focus, and back gesture on every device
form affected by a layout change.

### 8.3 Shared-element identities

Current geometry identities include:

- `aiReminderCard` between the AI reminder source and `AiChatPage`;
- `resident_geo_<residentId>` between resident summaries and `ResidentDetailPage`;
- `healthCard` between the health source card and `HealthExpandPage`;
- `quick_expand_geo_<index>` for task/medication expansions.

Source and destination must share the same stable non-empty identity. Insert/remove the destination inside
`UIContext.animateTo`, keep the source layout stable, and use `ModalTransition.NONE` with a transparent content cover
when geometry transition is the primary animation. Clear item-specific IDs when closing if multiple possible sources
can remain mounted. Back dismissal must use the same animated state transition.

Use `NodeController`, `BuilderNode`, `FrameNode`, or `NodeContainer` only when a live rendering node must survive context
changes, such as uninterrupted video or a gesture-preserving image. Ordinary cards and text should use
`geometryTransition`.

### 8.4 Accessibility and motion

The current `MineDetailPage` persists `reduceMotion`, `hapticFeedback`, and `operationSound`, but these values currently
control settings UI only. They are not application-wide behavior. Do not claim Reduce Motion support until animations,
haptics, and sound owners consume a shared preference and provide tested fallbacks.

New interactive elements must have semantic labels, visible focus where appropriate, predictable focus order, adequate
touch/focus target size, large-font behavior, and keyboard/mouse handling on 2-in-1. Avoid color-only status meaning.

## 9. Core application: AI boundary

`pages/AiChatPage.ets` is a local prototype:

- stores up to fifty local in-memory sessions through an `AppStorageV2` model;
- restores/synchronizes active history;
- supports new conversation, selection, feedback, copy, edit, and simple `**bold**` parsing;
- manages list scrolling, focus, keyboard avoid mode, history drawer, and immersive mode;
- returns a fixed `buildAnswerText` response after roughly 650 ms;
- regenerates a fixed response after roughly 500 ms;
- cancels response/scroll timers on disappearance;
- does not persist history through ArkData;
- has no network request, model identifier, prompt contract, token, streaming protocol, DTO, or audit service.

For production AI, add a gateway behind a UseCase and Repository/DataSource boundary. It must provide:

- prompt and model versioning;
- minimum-necessary data selection and redaction;
- timeout, cancellation, retry, circuit/fallback behavior;
- structured response validation;
- evidence/source and confidence presentation where relevant;
- non-sensitive audit identifiers;
- explicit human confirmation for consequential actions.

Use deterministic rules for vital thresholds, device-offline alerts, missed medication, overdue tasks, and emergency
conditions. Generative output is advisory and must never directly change medication, care level, identity, payment,
access control, or emergency action.

## 10. Core application: persistence, errors, and resources

### 10.1 Preferences

`util/PreferenceManager.ets` wraps ArkData Preferences store `KanxiaobanStore`:

- singleton construction;
- host context obtained from the AppStorageV2-connected UI context;
- JSON stringify/parse for generic values;
- synchronous put/get/has/delete;
- asynchronous `flush()` with logging.

Known defect: `hasValue()` retries recursively without a retry guard. If initialization continues to fail, recursion is
unbounded. Follow the bounded-retry pattern already used by `getValue`, `setValue`, and `deleteValue` when fixing it.

Preferences are appropriate for small flags. Use RDB for structured offline records and file APIs for files. Define
migrations, corruption recovery, encryption requirements, logout cleanup, and tenant switching before persisting care
or health data.

### 10.2 Error handling

- Catch Kit and platform failures as `BusinessError` where the API contract provides it.
- Log code/message internally through the local Logger without protected payloads.
- Map platform/network/storage errors to typed domain errors before UI presentation.
- Model loading, empty, denied, offline, timeout, expired session, conflict, retry, and terminal failure states.
- Do not show raw error objects, local paths, endpoints, tokens, or stack traces to users.
- Keep side effects out of `build()` and high-frequency builders.

### 10.3 Resources

The core has base colors/floats/strings, dark colors, and `en_US`/`zh_CN` string qualifiers. Use:

- `$r('app.string.*')` for user-visible text;
- `$r('app.color.*')` and `$r('sys.color.*')` for colors;
- `$r('app.float.*')` and `$r('sys.float.*')` for reusable dimensions/typography;
- `$r('app.media.*')` and `$r('sys.symbol.*')` for media and system symbols.

There is still substantial hard-coded Chinese text, color, and spacing in pages. New work must not increase that debt.
Resourceize affected user-visible strings and stable design tokens in the same ownership boundary. Do not edit generated
resource files.

## 11. Core application: known defects and risks

Treat these as verified open risks, not necessarily part of every unrelated task:

### P0/P1 security and product risks

- Local signing material/password fields are tracked; values require rotation and history cleanup.
- Authentication is simulated; there is no session, tenant, RBAC, or authorization check.
- Sensitive care/health/location/device concepts have no production privacy, encryption, audit, retention, or tenant
  isolation layer.
- AI is a local response simulation without safety/audit boundaries.
- Business data and state are embedded in UI components.

### Functional/lifecycle risks

- `PreferenceManager.hasValue()` can recurse forever when initialization fails.
- `HealthExpandPage` creates a `ListScroller`, but the rendered `Scroll()` does not bind that scroller; index positioning
  is ineffective.
- `WindowUtil` listeners do not have symmetric teardown from Ability lifecycle.
- Wide doctor AI input has a submit action, but it only produces fixed local advisory text; it has no model gateway,
  persistence, audit, or backend integration.
- Wide message replies and task progress are local-only.
- Admission drafts are local component state. The explicit in-workbench dirty guard does not cover system back,
  process/window destruction, or a resize that removes the wide doctor branch.
- Non-normal admission risks require a free-text local measure note, but there is no structured owner, deadline, referral,
  audit, or persistence model yet.
- `MaterialUtil` and the `MATERIAL_LEVEL` storage key are currently unused.
- Settings such as Reduce Motion do not drive application behavior.
- `router.replaceUrl` calls currently produce deprecation warnings in the latest recorded build; migration must preserve
  the authentication-shell semantics.

### Quality/performance risks

- Very large V2 components combine datasets, derived calculations, navigation, sheets, and rendering.
- Derived filters and arrays may be rebuilt inside render paths.
- Preloading all phone tabs can increase startup and memory cost.
- There are no meaningful domain, component, route, permission, or UI tests.
- Release obfuscation is disabled.
- No real-device performance baseline exists for startup, long lists, transitions, memory, CPU, or leaks.

Do not opportunistically fix all risks in an unrelated narrow task. Do avoid deepening them, and surface any risk that
directly affects the requested change.

## 12. Core application: verification baseline

Recorded build evidence at the baseline date:

- a recent debug HAP build completed successfully;
- the signed default HAP exists at
  `KangxiaobanAI/products/entry/build/default/outputs/default/kanxiaoban-default-signed.hap`;
- its existence proves only that specific local default build, not real-device behavior or backend correctness;
- build logs include non-fatal/deprecation diagnostics and must be re-read after future builds.
- The current admission/workspace edits pass `git diff --check` and the API 24 ArkTS compiler.
- `assembleApp` for product `default`, build mode `debug`, completed successfully on 2026-07-22 with DevEco/Hvigor
  6.1.1.125 after setting `DEVECO_SDK_HOME` to the SDK root (`.../DevEco Studio/sdk`). The signed HAP is produced at
  `KangxiaobanAI/products/entry/build/default/outputs/default/kanxiaoban-default-signed.hap`.
- A run without the SDK-root environment setting still fails before compilation with
  `00303168 Configuration Error: SDK component missing`; this is an environment setup issue, not current source
  evidence. The build is `Build-verified` for this exact local product/mode, but remains `Device-verified` and
  `Service-verified` only after real-device and backend checks.

Do not commit `.hvigor`, `build`, `oh_modules`, IDE metadata, or generated cache files unless a task explicitly requires
them. There is no root unified build wrapper or CI pipeline. Use the project's DevEco/Hvigor environment and report the
exact module/product/mode used. A successful TV/default product build does not prove PC/watch/other products build.

The current tests under `products/entry/src/test` and `src/ohosTest` contain template `abc` assertions. They are not
evidence of feature correctness.

For core product work, choose verification by risk:

- config/route change: parse all affected manifests and route profiles, then build the exact product;
- model/UseCase change: focused unit tests plus build;
- component change: loading/empty/error/content states plus interaction checks;
- navigation change: forward/back/deep-entry/process recreation path;
- responsive change: phone, tablet, and 2-in-1 widths, rotation, resize, keyboard, dark mode, and large font;
- permission/Kit change: denial, permanent denial, settings return, capability absence, offline/service failure, real
  supported device;
- performance change: measured before/after profiler evidence;
- AI/data change: schema, cancellation, timeout, redaction, audit, and human-confirmation tests.

## 13. HarmonyOS implementation rules

These rules apply across the workspace, interpreted against each project's SDK and state generation.

### 13.1 ArkTS and declarative UI

- ArkTS is not browser TypeScript, React, Flutter, or Android XML. Do not use web-only APIs or assume unrestricted
  TypeScript dynamism.
- UI components are `struct` declarations with declarative `build()` trees and chainable modifiers.
- Use `@Builder` for repeated declarative UI; use ordinary private functions for calculation.
- Keep I/O, network, timers, mutation, large parsing, sorting, and aggregation out of `build()` and frequently evaluated
  builders.
- Split a component when it owns multiple screens, large datasets, navigation, dialogs/sheets, and business rules.
- Use stable keys for `ForEach`, `Repeat`, `LazyForEach`, and reusable list items.

### 13.2 State management generations

V1 projects may use:

- `@State` for owned local state;
- `@Prop` for parent-to-child input;
- `@Link` for explicit two-way references;
- `@Provide/@Consume` for tree scope;
- `@Observed/@ObjectLink` for observable objects;
- `AppStorage`, `@StorageLink/@StorageProp`, and LocalStorage variants for their defined scopes.

V2 projects may use:

- `@Local`, `@Param`, `@Require`, `@Event`;
- `@Provider/@Consumer`;
- `@ObservedV2/@Trace`;
- `@Monitor` with cycle/expense review;
- `AppStorageV2.connect` with one clear initialization owner.

Preserve the project's existing generation unless migration is explicitly requested. Do not copy V1 decorators into a
V2 component or vice versa without checking supported interoperability. Do not copy mutable input into local state
without defining synchronization behavior. AppStorage/AppStorageV2 is not a database.

State ownership default:

- app: session, tenant, current user, theme, window/environment;
- feature: list, paging, filters, selected entity, load/error state;
- page: sheet visibility, text input, local selection, animation identity;
- persistent: preferences, drafts, cache, offline queue through a storage/repository abstraction.

### 13.3 Ability and window lifecycle

Trace `onCreate`, `onWindowStageCreate`, `loadContent`, `onForeground`, `onBackground`, `onWindowStageDestroy`, and
`onDestroy`. Use application context, Ability context, host context, and UIContext only for APIs that accept that exact
context. Register window/display/fold/keyboard/configuration/sensor/media listeners with matching cleanup.

Initialize UI window utilities only after the main window/UIContext is available. Release players, sessions, timers,
PixelMaps, NodeControllers, sensor subscriptions, observers, and native resources in the owner lifecycle.

### 13.4 Routing choices

Use traditional router for a small page set or explicit shell replacement. Use `Navigation + NavPathStack` for scalable
in-app flows. Use named router maps when cross-module discovery, notifications, cards, deep links, dynamic features, or
continuation require stable external route identities.

For a router-map entry keep all of these consistent:

- module `routerMap` profile reference;
- route `name`;
- `pageSourceFile` path;
- exported `buildFunction` symbol;
- typed parameters and back behavior.

Do not mix router and Navigation casually. Define the boundary in the feature architecture.

### 13.5 HAP, HAR, HSP, and product organization

- Entry/feature HAP packages a product entry or independently delivered feature.
- HAR provides reusable compile-time code/resources and must expose a deliberate public `Index.ets` surface.
- HSP/shared modules are for justified runtime sharing/packaging, not a default abstraction.
- Use `products/features/common` when multiple products or stable substantial features need reuse.
- Do not create a module for every page. Split on stable ownership, independent delivery/compilation, product reuse, or
  dependency direction.
- Never create circular HAR dependencies to avoid parameter passing.

### 13.6 Responsive layouts

Use declared device types plus actual window width/input mode. Typical transformations are:

- bottom tabs -> left navigation;
- single pane -> split list/detail;
- two columns -> three columns;
- GridRow/GridCol reflow;
- SideBarContainer collapse;
- touch-only actions -> hover/focus/key/remote-capable actions.

Test freeform resize, fold state, rotation, keyboard, mouse, focus order, remote input, dark mode, locale, and font scaling
as applicable. Do not claim support for TV/wearable/PC unless the selected product/module declares and tests it.

### 13.7 Kit and permission workflow

Before adding any Kit API:

1. read the target module's `module.json5`;
2. verify target/compatible SDK and current official API/capability contract;
3. inspect a same-generation local/official sample;
4. add only required dependency, metadata, and permission;
5. request restricted permission at the point of user intent;
6. explain purpose and handle granted, denied, permanently denied, cancellation, and settings-return paths;
7. use capability checks such as `canIUse` where required;
8. catch `BusinessError` and redact protected data;
9. test unsupported device, offline, timeout, and service errors;
10. verify hardware/AGC service behavior on a supported real device.

Never copy all permissions from a sample. The declaration, runtime request, purpose resource, and actual code path must
remain mutually consistent.

### 13.8 Account and identity

Account Kit can provide Huawei account identity/authorization, but it does not replace application tenant membership,
institution RBAC, session refresh, device trust, logout cleanup, or audit. Keep provider identity separate from domain
user identity. Validate anti-CSRF state and never persist authorization codes/tokens in ordinary preferences or logs.

### 13.9 Push and notifications

Use Push Kit for delivery and Notification Kit for local display/interaction. Payloads should contain minimal opaque
identifiers; fetch sensitive details only after authenticated app entry. Define token refresh, duplicate delivery,
expiration, channel/category, tap routing, background limits, logout cleanup, and notification permission behavior.
Never expose resident health/location details in a notification payload or lock-screen text without explicit policy.

### 13.10 Map and location

Map Kit covers maps, camera, markers/overlays, static maps, search, selection, and routes. Location consent/permission is
separate. Request foreground/background precision only when justified, handle disabled location service, minimize
precision/retention, and never leak vulnerable-person tracks in logs or notifications.

### 13.11 Vision, camera, and biometric

State the purpose before requesting camera/biometric access. Check hardware/capability presence and handle denial and
cancellation. Treat images, face/liveness results, biometric outcomes, and identity linkage as sensitive. Prefer storing
a verification result/audit token over raw biometric media. Release returned PixelMaps and camera/native resources.

### 13.12 Media and AVSession

Use Media Kit and AVSession Kit according to playback ownership. Release players, sessions, event listeners, and live
nodes. Handle audio interruption, background behavior, headset/control events, errors, and app lifecycle. Preserve one
live player/node for a shared-player transition instead of creating competing players.

### 13.13 Device/distributed capabilities

The project name `MultiDeviceCommunication` is not evidence of distributed communication. For discovery,
continuation, backup, Bluetooth, sensors, awareness, or distributed data, verify the actual imported Kit and capability.
Model devices as transient: discovery timeout, reconnection, duplicate events, permission denial, version mismatch, and
privacy boundaries are required.

### 13.14 Storage, network, and files

- ArkData Preferences: small flags/settings.
- RDB: structured offline data with schema/migration/recovery.
- File APIs: files with cancellation/progress/checksum/cleanup as relevant.
- Network Kit: transport behind a data-source abstraction.
- TaskPool/Worker: CPU-heavy work only when transfer/serialization cost is justified.

Avoid synchronous heavy I/O on the UI thread. Define cache freshness, retry/backoff, pagination, idempotency, optimistic
updates, conflicts, offline queues, tenant boundaries, and logout deletion before production data integration.

### 13.15 Performance

Measure before optimizing. Establish target-device baselines for cold start, first interaction, transition latency,
long-list frame rate, memory, CPU, network, database, and package size. Use Profiler, SmartPerf, ArkUI Inspector,
HiDumper, and hilog as appropriate.

Prefer:

- `Repeat` or `LazyForEach` with stable keys/data source;
- `@Reusable` and reuse pools for homogeneous hot lists;
- cached filtered/sorted/aggregated values in ViewModel/store;
- small observation scopes;
- lazy loading of details, images, charts, video, and history;
- explicit release of timers/listeners/media/nodes/controllers/native resources.

Do not optimize solely by copying a performance case. Reproduce the problem, select a compatible positive example,
measure before/after, and preserve behavior.

### 13.16 Testing and security

Testing pyramid:

- unit: validators, mapping, rules, ViewModel, UseCase, repository behavior;
- component: loading, empty, error, content, interaction, state update;
- UI/ohosTest: primary flows, navigation, back, permission, process/lifecycle behavior;
- contract: schemas, errors, pagination, idempotency, permissions;
- performance: startup, lists, transitions, memory/resource leaks.

Always review least privilege, authentication/token handling, role/tenant authorization, encrypted transport/storage,
logs/screenshots/clipboard/notifications, input validation, Web boundaries, dependency provenance, and AI privacy/audit.

## 14. SDK generations and reference-project selection

The workspace intentionally contains several SDK generations. The profile values below are a selection guide, not a
license to mix source blindly:

| Generation/profile family | Projects | Typical state/design generation | Typical device scope |
|---|---|---|---|
| `6.1.1(24)` target+compatible | `KangxiaobanAI` | ArkUI V2 + HDS | phone/tablet/2in1 |
| `6.1.0(23)` target, `6.0.2(22)` compatible | `MusicHome`, `NavigationSettings`, `MultiDeviceCommunication`, `MultiCommunityApplication` | mostly V2, HDS branches | phone/tablet/2in1 plus product-specific forms |
| `6.1.0(23)` target+compatible | `Spatialization`, `HarmonyOSComponentUXExamples-dev` | V2/HDS or catalog-specific | phone/tablet/PC/TV/wearable as declared |
| `6.1.0(23)` target, `6.0.1(21)` compatible | `sample_in_harmonyos` | mixed large aggregate | phone/PC/TV/wearable |
| `6.0.0(20)` target, `5.0.5(17)` compatible | `ResponsiveLayout` | ArkUI V1 | phone/tablet/2in1 |
| `5.0.5(17)` target+compatible | `transitions-collection`, `multi-convenient-life`, `multi-tab-navigation`, Account/Map samples | mostly ArkUI V1 | sample-declared devices |
| mixed case profiles | `cases` | API-dependent case by case | case-declared devices |

Before copying code compare, in this order:

1. target SDK and compatible SDK;
2. `module.json5` module type and declared device types;
3. V1 versus V2 decorators;
4. HDS package/API branch and fallback;
5. route profile format and exported builder;
6. permission, metadata, and Ability/ExtensionAbility declarations;
7. actual build evidence.

The root `oh-package.json5` model version is not the same thing as target API. For example, core package model version
6.1.0 coexists with target/compatible SDK 6.1.1(24); use `build-profile.json5` for SDK facts.

## 15. Reference project catalog

The following entries are a durable navigation map. Each sample is a source of patterns, not a product dependency.

### 15.1 `MusicHome`: primary modular architecture reference

Shape:

```text
MusicHome/
  common/musicbasic        HAR: models, state, utilities
  features/player          HAR: player, lyrics, full-screen playback
  features/playlist        HAR: playlist/detail/mini-player
  features/recommendation  HAR: recommendation/home/wide panels
  products/default         HAP: phone/tablet
  products/pc              HAP: 2-in-1/PC
  products/tv              HAP: TV
  products/watch           HAP: wearable
```

Profile family is target `6.1.0(23)` and compatible `6.0.2(22)`. It uses V2 models, `AppStorageV2.connect`, intent
state, HDS Navigation/Tabs, API-version fallback, MediaKit, AVSessionKit, ImageKit, and ArkGraphics2D. The default shell
keeps queue/index/progress/volume/full-screen/mini-bar state in a shared app model. Player ownership, lifecycle release,
and backup ExtensionAbilities are the useful patterns.

Canonical paths:

- `common/musicbasic/src/main/ets/model/MusicAppState.ets`
- `products/default/src/main/ets/pages/Index.ets`
- `features/player/src/main/ets`
- `features/playlist/src/main/ets`
- `features/recommendation/src/main/ets`
- product `module.json5` files under `products/*/src/main`

Use it to design `common/features/products` boundaries for KangxiaobanAI. Do not copy music-domain state or assume its
TV/watch APIs are valid in API 24. The latest recorded success proves the TV product in the local state only; it does not
prove default/PC/watch products. The working tree has an existing signing-profile edit and a local TV device-type edit;
preserve both.

### 15.2 `NavigationSettings`: settings and parameterized V2 reference

Shape: `common/multisettingbase` HAR, `features/multisettinglink` HAR, `products/default` HAP, and `products/pc` HAP.
Profile target `6.1.0(23)`, compatible `6.0.2(22)`. Default declares phone/tablet; PC declares 2-in-1.

Canonical paths and patterns:

- `products/default/src/main/ets/pages/Index.ets`
- `products/pc/src/main/ets/pages/Index.ets`
- `features/multisettinglink/src/main/ets/viewmodel/WlanViewModel.ets`
- `common/multisettingbase/src/main/ets`
- product `route_map.json` files under `src/main/resources/base/profile`

Uses `@ComponentV2`, `@Param`, `@Require`, `@Event`, `@Monitor`, `@ObservedV2/@Trace`, ViewModels, `WindowInfo`,
`HdsNavigation/HdsNavDestination` for distribution OS API 60100+ and native `Navigation/NavDestination` fallback below
that threshold. It demonstrates list/detail split on wide screens and named routes for WLAN, more connections, NFC, and
settings details.

WLAN/NFC values are fixed Huawei-Guest/demo data; no real WLAN/NFC Kit is connected. A default product build has been
recorded. A historical PC failure was caused by using a phone device target for a 2-in-1 module; always build with the
module's declared device form.

### 15.3 `MultiDeviceCommunication`: message UI and ExtensionAbility reference

Shape: `common/commonmultidevicecommunication` HAR, `features/message`, `features/social`, `features/user`,
`features/commonui` HARs, and `products/default`/`products/pc` HAPs. Profile target `6.1.0(23)`, compatible `6.0.2(22)`.

It demonstrates V2 ViewModel/state, HDS/native navigation branches, message/contact/social/mine tabs, wide split
message detail, backup ExtensionAbility declarations, and feature route maps.

Canonical paths:

- `products/default/src/main/ets/pages/Index.ets`
- `products/pc/src/main/ets/pages/Index.ets`
- `features/message/src/main/ets`
- `features/user/src/main/ets`
- `features/social/src/main/ets`
- `features/commonui/src/main/ets`

Despite its name, it does not prove DistributedData, network synchronization, or real cross-device continuation. Treat
messages, contacts, and profile data as local UI samples.

### 15.4 `MultiCommunityApplication`: content-flow and wide sidebar reference

Shape: `common/commonmulticommunityapplication` HAR, `features/contentcommunity`, `features/socialcommunity`,
`features/commoncommunityui`, and `product/default`/`product/pc` HAPs. Profile target `6.1.0(23)`, compatible `6.0.2(22)`.

Canonical paths:

- `product/default/src/main/ets/pages/Index.ets`
- `product/pc/src/main/ets/pages/Index.ets`
- `features/contentcommunity/src/main/ets`
- `features/socialcommunity/src/main/ets`
- feature `router_map.json` files

Uses V2 providers/local state, WaterFlow, HDS/API 60100 fallback, PC SideBarContainer, content/detail/comment routes,
and feature-shared card components. It is useful for content-heavy layouts and wide navigation, but elderly-care tasks
and alerts require ordered List semantics; do not make WaterFlow the default for every business list. All domain content is
local mock data.

### 15.5 `ResponsiveLayout`: canonical breakpoint/window reference

Single entry project, target `6.0.0(20)`, compatible `5.0.5(17)`, declared phone/tablet/2in1. It is ArkUI V1 and includes
route-map destinations for layout demonstrations.

Canonical paths:

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/utils/WindowUtil.ets`
- `entry/src/main/ets/utils/WidthBreakpointType.ets`
- `entry/src/main/ets/views/*View.ets`

Patterns include List lanes, WaterFlow columns, Swiper, Grid, SideBarContainer, list/detail split, two/three columns,
mail/calendar/chat layouts, GridRow/GridCol, and bottom/side Tabs. `WindowUtil` covers size, avoid area, immersive mode,
keyboard, fold, orientation, and cleanup. It is local data only. A gravity sensor registration in the sample must be
paired with `off` before using that pattern in production.

Use this project to improve wide KangxiaobanAI layout policy, but translate V1 state and API 20 syntax into current V2/API
24 contracts.

### 15.6 `transitions-collection`: advanced transition reference

Single entry, phone-focused, target/compatible `5.0.5(17)`. The entry page uses `Navigation/NavPathStack` and a route map
with many transition destinations.

Canonical areas:

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/utils/customtransition/CustomNavigationUtils.ets`
- `entry/src/main/ets/feature/*LongTakeTransition*`
- `NodeController.ets`, `ImageGalleryNode.ets`, `AVPlayerManager.ets`, snapshot helpers

Demonstrates geometry transitions for search/card/list/image, `bindSheet`/`bindContentCover`, custom navigation
transitions and interactive back, component snapshots/PixelMaps, NodeController/BuilderNode live image/video migration,
MediaKit AVPlayer ownership, and book-flip effects.

It has no recorded build artifact. The route allow-list contains stale/nonexistent old names; listeners and PixelMap/
AVPlayer cleanup need review. Use individual ideas only after API migration, lifecycle cleanup, Reduce Motion fallback,
and real-device interruption/back testing.

### 15.7 `multi-convenient-life`: V1 responsive business-page reference

Single entry, target/compatible `5.0.5(17)`, phone/tablet. Main pages are `Index`, `FoodList`, `GraphicText`, and `Living`.
It uses traditional `getRouter().pushUrl`, local constants/ViewModels, GridRow/GridCol, Navigation split/stack,
SideBarContainer, and geometry transitions.

Canonical paths:

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/FoodList.ets`
- `entry/src/main/ets/pages/GraphicText.ets`
- `entry/src/main/ets/pages/Living.ets`
- `entry/src/main/ets/components/*`

Food/shop/comments/live data are local UI values. The Ability window-size listener lacks complete teardown and old router
syntax should not be copied into API 24 core code without checking deprecation and route boundaries.

### 15.8 `multi-tab-navigation`: navigation-style gallery

Single entry, phone-only, target/compatible `5.0.5(17)`, with roughly thirteen independent main pages. It is a V1 gallery,
not a business app.

Canonical paths:

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/common/Constants.ets`
- `entry/src/main/ets/viewmodel/TabViewModel.ets`
- `entry/src/main/ets/pages/*Tab.ets`

It covers fixed bottom Tabs/badges/controller, left/side/drawer tabs, underline/background/word tabs, rudder style,
slide-and-more, nested Tabs, gesture/pan behavior, and a local Video tab. Use it only to compare interaction choices;
do not treat API 17 V1 syntax as current HDS architecture.

### 15.9 `Spatialization`: HDS material and awareness reference

Target/compatible profile is `6.1.0(23)`, with phone/tablet entry product under `products/entry`. It uses V2,
`AppStorageV2`, `@ObservedV2/@Trace`, HDS Navigation/Tabs, immersive/adaptive materials, Repeat/WaterFlow, and a
breakpoint/window utility.

Canonical paths:

- `products/entry/src/main/ets/pages/MainPage.ets`
- `products/entry/src/main/ets/view/ImmersiveLightView.ets`
- `products/entry/src/main/ets/view/AdaptiveTabView.ets`
- `products/entry/src/main/ets/view/SmartReachView.ets`
- `products/entry/src/main/ets/util/BreakpointSystem.ets`
- `products/entry/src/main/ets/util/WindowUtil.ets`

`SmartReachView` actually calls `@kit.MultimodalAwarenessKit`, checks capability, listens for holding-hand changes, and
performs cleanup. The module declares `ohos.permission.DETECT_GESTURE`, but its used-scene/Ability naming needs real
device and permission verification. PreferenceManager and sample data are local. A prior build log contains both a
successful signed artifact and an earlier material API mismatch; always use current target SDK signatures rather than
copying old `MaterialLevel` names.

### 15.10 `sample_in_harmonyos`: large aggregate application reference

This is a multi-product sample aggregate with target `6.1.0(23)` and compatible `6.0.1(21)` profiles:

```text
products/phone
products/pc
products/tv
products/wearable
common
features/abilitycommon
features/commonbusiness
features/componentlibrary
features/devpractices
features/exploration
features/mine
features/widgetcommon
```

Products expose Ability/backup/form/liveForm/UIExtension/shortcut patterns, while features expose router maps and public
builders. It demonstrates `BaseVM`, account/push services, RDB, rawfile JSON `MockRequest`, dynamic sample installation,
Insight Intent, forms, and product-specific layout.

Canonical paths:

- `products/phone/src/main/ets/page/MainPage.ets`
- `products/phone/src/main/module.json5`
- `products/pc/src/main/module.json5`
- `features/*/src/main/resources/base/profile/router_map.json`
- `common/src/main/ets`

The rawfile/MockRequest layer is sample data, not a production backend. Its permissions, client IDs, product flavors,
and form/extension declarations are examples; import only the capability and permission actually needed by the target.

### 15.11 `HarmonyOSComponentUXExamples-dev`: device/component catalog

Target/compatible profile is `6.1.0(23)`. It has a shared `commons/componentuxexamplesbase` HAR and phone, PC, TV,
wearable products (the PC module is a feature-type product in its current manifest). It contains roughly 483 ETS files
covering component behavior, source previews, input differences, and device-specific UX.

Canonical paths:

- `commons/componentuxexamplesbase/src/main/ets`
- `products/phone/src/main/module.json5`
- `products/pc/src/main/module.json5`
- `products/tv/src/main/module.json5`
- `products/wearable/src/main/module.json5`
- each product's `router_map.json` and page/view directories

Use it to inspect HDS/component behavior, focus/remote/input semantics, and device-specific variants. It is not a
drop-in design system and its network permissions are not automatically valid for KangxiaobanAI.

### 15.12 Kit samples

#### Account Kit

Project: `account-kit-samplecode-clientdemo-for-atomicservice-arkts`.

- Profile target/compatible `5.0.5(17)`.
- Entry: `entry/src/main/ets/pages/Index.ets`.
- Uses Huawei ID provider/login request, silent login, random state/response validation, `FunctionalButton` account
  surfaces, avatar/phone/address/invoice examples, and minors-protection capability checks.
- Uses `PersistentStorage` only for demo silent-login mapping and local layout/window checks.
- Requires real client configuration/account service to validate; it does not implement institution tenant/RBAC/session.

#### Map Kit

Project: `map-kit_-sample-code_-demo-arkts`.

- Profile target/compatible `5.0.5(17)`.
- Entry: `entry/src/main/ets/pages/Index.ets`; route profile `route_map`.
- Declares location and approximate-location permissions and requests them at point of use.
- Canonical pages: `MapControllerDemo.ets`, `OverlayDemo.ets`, `StaticMapDemo.ets`, `NaviDemo.ets`,
  `AdvancedControlsDemo.ets`.
- Covers map camera/position, markers/circle/polyline/polygon, static `PixelMap`, route planning, distance matrix,
  text/nearby search, autocomplete, reverse geocode, and selection controls.
- Requires real Map Kit/AGC/network configuration and device validation. Release `PixelMap` results and avoid retaining
  location history without policy.

#### Push Kit

Project: `push-kit-sample-code-clientdemo-arkts`.

- Profile is API 17-era compatible; inspect current target before copying.
- Entry: `entry/src/main/ets/pages/Index.ets`, `GetTokenPage.ets`, `ExamplePage.ets`.
- Additional abilities include `PushMessageAbility`, `VoIPUIAbility`, `RemoteNotificationExtAbility`, backup, and form
  Ability; widget pages live under `widget/pages/WidgetCard.ets`.
- Covers token, notification, revoke, card refresh, TTS, background, live-window, in-app call, and service-card flows.
- Treat TODOs, provider configuration, notification channels, background restrictions, token refresh, and payload privacy
  as unfinished. A declared background-location permission appears unrelated and must be justified or removed before
  reuse.

#### Vision Kit

Project: `visionkit-sample-code-arkts`.

- Profile target `6.1.0(23)`, compatible `5.0.5(17)`.
- Entry: `entry/src/main/ets/pages/Index.ets`.
- Declares `ohos.permission.CAMERA`, starts interactive liveness detection, reads result, and shows success/failure.
- Use only with explicit purpose, cancellation/denial paths, hardware capability checks, and sensitive-result handling.

### 15.13 `cases`: searchable feature and performance corpus

`cases` is not a buildable product boundary. It contains a large `CommonAppDevelopment` collection, performance docs,
and runnable positive/negative performance projects. Counts fluctuate with upstream content; the current snapshot is on
the order of thousands of ETS files and hundreds of module profiles.

Important areas:

- `CommonAppDevelopment/feature`: UI/layout, navigation/dialog, animation/gesture, image/vision, media, Web/H5, files,
  database, system Kit, foldable/immersive, and device cases;
- `CommonAppDevelopment/common/routermodule`: dynamic route infrastructure and `@AppRouter` registrations;
- `docs/performance`: cold start, imports, list/reuse, state, Web, animation, TaskPool, Native Drawing, memory/CPU/frame
  measurement, SmartPerf, HiDumper, ArkUI Inspector;
- `test/performance`: runnable comparisons such as Web prestart/preconnect, lazy import, taskpool serialization, RDB
  offload, Native drawing, image white-block and cold-start variants.

Correct use:

1. reproduce and measure the active problem;
2. search `rg` for the exact API/issue and select a case with a compatible SDK;
3. read its README and both positive/negative implementations;
4. extract the minimum pattern into the owning project;
5. run the target project's own tests/build/profile.

Never add `cases` wholesale as a dependency, copy a permission without need, or infer production readiness from a case
that only renders a concept.

## 16. Cross-project implementation index

Use this lookup before starting a new implementation:

| Need | First local reference | Adaptation rule |
|---|---|---|
| V2 observable app state | `MusicHome/common/musicbasic/.../MusicAppState.ets` | keep state ownership narrow; do not make every feature global |
| HDS floating Tabs/MiniBar | `KangxiaobanAI/.../MainPage.ets`, `MusicHome/.../Index.ets` | check API 60100+ and material fallback |
| HDS immersive material | `KangxiaobanAI/.../MaterialUtil.ets`, `Spatialization/.../ImmersiveLightView.ets` | detect support and bind Scroller |
| Window/safe-area/fold | `KangxiaobanAI/.../WindowUtil.ets`, `ResponsiveLayout/.../WindowUtil.ets` | add symmetric listener release |
| Responsive list/grid/split | `ResponsiveLayout/entry/src/main/ets/views`, `NavigationSettings/.../view` | use width/input mode, not device name only |
| Parameterized V2 settings | `NavigationSettings/features/multisettinglink/...` | `@Param/@Require/@Event` ownership stays explicit |
| Wide list/detail messaging | `MultiDeviceCommunication/...`, `KangxiaobanAI/.../WideMessagePage.ets` | mock data is not distributed sync |
| Wide content/sidebar | `MultiCommunityApplication/...`, `ResponsiveLayout/...` | use ordered List for tasks/alerts |
| Geometry transition | `KangxiaobanAI/.../TabPageView.ets` + `ResidentDetailPage.ets` | stable IDs, transparent cover, animated insertion/removal |
| Complex custom transition | `transitions-collection/.../utils/customtransition` | API migration, interruption, PixelMap/resource cleanup |
| Live image/video node migration | `transitions-collection/.../NodeController.ets` | use only when live node continuity is required |
| Account authorization | `account-kit-.../entry/src/main/ets/pages` | separate provider identity from institutional identity |
| Push/notification | `push-kit-.../entry/src/main/ets` | minimal payload and authenticated landing |
| Map/location | `map-kit_-.../entry/src/main/ets/pages` | consent, precision, retention, real service config |
| Camera/liveness | `visionkit-.../entry/src/main/ets/pages/Index.ets` | sensitive data and capability/denial handling |
| Component/remote UX | `HarmonyOSComponentUXExamples-dev/products/*` | verify declared form factor and input model |
| Performance diagnosis | `cases/docs/performance`, `cases/test/performance` | measure before and after |

## 17. Planned production architecture for `KangxiaobanAI`

This section is a **directional architecture baseline**, not a claim that these modules currently exist. Create them
incrementally only when the requested work establishes a stable boundary.

```text
KangxiaobanAI/
  AppScope/
  common/
    core/             Result/AppError, logging, time, configuration
    domainmodel/      Resident, Task, Alert, User, Session, Tenant
    network/          transport, auth interceptor, DTO foundation
    database/         RDB, migrations, encryption, offline queue
    designsystem/     HDS wrappers, theme, common cards and states
  features/
    auth/
    dashboard/
    resident/
    task/
    health/
    message/
    settings/
    notification/
    aiassistant/
  products/
    caregiver/        current phone/tablet/2-in-1 delivery shell
    station/          create only if station/PC behavior becomes independently owned
```

Default dependency direction:

```text
Product shell
  -> Feature ArkUI Page/Component
  -> Feature ViewModel/Store
  -> UseCase / domain service
  -> Repository interface
  -> RemoteDataSource and LocalDataSource implementations
```

Fixed architectural decisions:

- UI does not construct transport DTOs, own retry policy, decide authorization, or build large mock datasets.
- Fake and real repositories implement the same interface so UI is replaceable without rewrite.
- Session, Tenant, CurrentUser, and UserRole are explicit models; a display role string is not authorization.
- Repository operations define pagination, idempotency, cache freshness, conflicts, offline behavior, and errors.
- Sensitive local data is minimized, encrypted where required, redacted from logs, and removed on logout/tenant switch.
- Rules and AI are separate services. Deterministic safety rules remain available when AI is unavailable.
- HAP/HAR splits happen after feature dependencies are stable; HSP is introduced only for a demonstrated packaging need.
- Visual behavior should remain stable while extracting data/state. Avoid simultaneous visual redesign and deep data
  migration unless the task explicitly requires both.

## 18. Change protocol for future agents

### 18.1 Before editing

1. Read this file and any closer `AGENTS.md` if one is later added.
2. Record `git status --short`; identify existing user changes in overlapping files.
3. Name the target project/product/module and its SDK/device/state generation.
4. Trace the current runtime/config/route/data path end to end.
5. Search local same-generation examples and current official documentation as needed.
6. State assumptions that affect architecture, permissions, user data, external services, or device support.

### 18.2 While editing

- Use the existing code style, imports, HDS components, resource system, and state generation.
- Keep edits inside the smallest coherent feature/ownership boundary.
- Do not refactor unrelated sample projects.
- Do not overwrite user changes, signing profiles, IDE/device setup, or generated state.
- Do not add a permission, Ability, route, product, HAR/HSP, dependency, or global state key without updating all linked
  configuration and documenting why.
- Keep comments short and useful; do not narrate obvious assignments.
- Never put secrets, personal data, health records, tokens, private endpoints, or machine paths in tracked code/logs.

### 18.3 After editing

Verify the narrowest useful set, then broaden for shared or high-risk behavior:

1. inspect diff and configuration/route/resource consistency;
2. run focused unit/component tests or add them where behavior changed;
3. build the exact product/module/mode;
4. run UI/device checks for visual, navigation, permission, or hardware work;
5. inspect new warnings and the first causal error rather than deleting caches blindly;
6. re-run `git status --short` and ensure no generated/unrelated files were accidentally added;
7. report exactly what was and was not verified.

The handoff must include:

- changed files and behavioral outcome;
- configuration, permission, route, storage, or dependency changes;
- tests and exact build product/mode;
- device forms and SDK assumptions;
- fallbacks and unsupported states;
- remaining security, privacy, performance, lifecycle, and untested-service risks.

## 19. Review checklist

Use this checklist for implementation and code review.

### Configuration

- [ ] Target/compatible SDK and runtime OS are confirmed from current profile.
- [ ] Module type, device types, mainElement, pages, route map, abilities, extensions, and permissions match code.
- [ ] Local `file:` dependencies resolve and public HAR exports are deliberate.
- [ ] No signing secret, token, endpoint credential, or personal machine path is introduced.

### Runtime and routes

- [ ] Ability `loadContent` and root page are correct.
- [ ] Router versus Navigation boundary is explicit.
- [ ] Route names, source files, builders, typed params, deep entry, and back behavior are consistent.
- [ ] Timers/listeners/players/sensors/nodes/PixelMaps are released by their lifecycle owner.

### State and data

- [ ] V1/V2 generation is preserved.
- [ ] App, feature, page, and persistent state ownership is explicit.
- [ ] Business data is not placed in global storage for convenience.
- [ ] Loading, empty, error, denied, offline, retry, conflict, and expired-session states are modeled.
- [ ] DTO/domain mapping, units/time zones, pagination, idempotency, caching, and tenant isolation are defined as needed.

### UI/HDS/responsive

- [ ] Existing HDS component and material conventions are preserved.
- [ ] Material fallback and Scroller binding are correct.
- [ ] System bars, navigation indicator, cutout, fold, and keyboard safe areas are handled.
- [ ] Phone/tablet/2-in-1 layout and applicable input modes are tested.
- [ ] Text/resources, dark mode, locale, font scaling, focus, semantic labels, and contrast are checked.
- [ ] Shared-element IDs and modal transitions remain stable; Reduce Motion fallback is considered.

### Kits, security, and AI

- [ ] Capability/API contract is verified for the current SDK.
- [ ] Permission declaration, runtime request, rationale, denial, settings return, and cleanup are complete.
- [ ] `BusinessError` handling does not expose protected details.
- [ ] Sensitive data is minimized, encrypted/redacted as required, and excluded from notification/log/clipboard leakage.
- [ ] AI is advisory, validated, auditable, cancellable, and subject to human confirmation for consequential actions.

### Quality and performance

- [ ] Tests cover changed rules/state/interactions rather than template assertions.
- [ ] Expensive work is outside `build()` and hot builders.
- [ ] Lists use stable keys and appropriate lazy/reuse mechanisms.
- [ ] Startup/preload/list/transition/resource behavior is measured when blast radius warrants it.
- [ ] The exact product build succeeds; one product is not reported as all-product success.

## 20. Documentation maintenance

Update this file in the same change when any of these stable facts change:

- active delivery project or product positioning;
- target/compatible SDK or declared device forms;
- HAP/HAR/HSP/module structure;
- startup page, navigation boundary, or external route strategy;
- V1/V2 state architecture or global-state ownership;
- real backend/auth/AI/Kit capability becoming implemented;
- security or verification policy.

Do not turn this file into a generated inventory of every source line. Source code remains the final detail. Keep paths,
symbols, architecture boundaries, implementation methods, and known caveats detailed enough that a future agent can
locate the exact implementation without trusting stale prose.
