# KangxiaobanAI_OC Agent Handbook

> Effective scope: this file applies to the whole workspace under `D:\Coding\KangxiaobanAI_OC`.
> Baseline refreshed: 2026-08-30.
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
it also contains a shared wide-screen management workspace used by doctor and administrator accounts. The doctor role is an
elder-care/maintenance and assessment role, not an outpatient diagnosis screen. Doctor and administrator clients now
share the same management-console UI tree on wide layouts; both use the same WIP adaptation placeholder on phones.
The active clients now use the repository's Go institution backend, but the product is still
not a certified clinical system or a distributed-device application.

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

Treat the current application as a **backend-connected product under integration**:

- ArkUI/HDS presentation and responsive behavior are substantial.
- Login calls the Go backend, stores a JWT session, and derives the visible role from the authenticated account.
- The main and cockpit clients read their core resident, bed, task, health, device, alert, billing, schedule,
  message, AI, and assessment records from tenant-scoped APIs. Empty optional views remain empty rather than inventing
  local records.
- AI conversations, messages, and starter prompts are persisted per tenant and user. A local provider remains an
  explicitly identified offline provider; configured remote-provider failures return an error instead of fake output.
- The Go backend provides authenticated REST, SQLite/MySQL persistence, tenant/RBAC enforcement, WebSocket/MQTT,
  configurable billing/health/operations rules, and the PDF-derived doctor admission workflow.
- There is no permission declaration in the main module because the current product does not call restricted Kits.
- Go tests cover the changed business rules; HarmonyOS template tests are still not broad product-level UI tests.

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

The locally added HarmonyOS guide corpus under
`docs/huawei-harmonyos-guides-complete-2026-08-10/` may be used as a development, implementation, review, and
troubleshooting reference. Its handbook chapters, official-menu indexes, page digests, coverage reports, and helper
tools are intended to help locate relevant platform guidance and compare implementation options. Treat it as a dated
local reference snapshot rather than a higher-priority source of truth: verify current SDK/API behavior against the
active project configuration, current source code, local compilation, and current official HarmonyOS documentation
when availability or behavior is uncertain.

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

- `MusicHome/build-profile.json5`
- `NavigationSettings/build-profile.json5`
- `Spatialization/build-profile.json5`
- `HarmonyOSComponentUXExamples-dev/build-profile.json5`
- `map-kit_-sample-code_-demo-arkts/build-profile.json5`

`KangxiaobanAI/build-profile.json5` currently has no `signingConfigs`; local or CI-injected configuration is required to
produce a signed HAP. Some sample profiles contain local certificate paths and password fields; the Map sample may
contain masked placeholders. Never print, copy, quote, summarize, or commit secret values. If remediation is requested,
rotate exposed material, remove it from tracked history, and replace it with local/CI-injected signing configuration.
Deleting only the current value is not a complete remediation.

### 3.1 Local backend administration access

The currently configured institution backend is hosted at `10.10.1.12`. Its SSH user is `api`, and the corresponding
password-based connection details are stored locally in `.codex/private/backend-ssh.json`. Before asking the user for
backend SSH credentials, future agents must first read that local file and try the configured connection. Ask again only
when the file is absent or authentication has actually failed.

The local credentials file is deliberately Git-ignored. Never print, quote, summarize, stage, commit, or copy its
password into this handbook, source code, scripts, command output, logs, reports, or chat. Deployment work must first
inspect the remote service, process, container, paths, mounts, and effective environment read-only. Preserve database,
uploads, configuration, and rollback material; back up the exact deployed binary or image before replacement, then
verify service health and the authenticated business endpoint after restart.

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
  -> POST /api/v1/auth/login
  -> AuthStore persists the returned JWT/user session
  -> GlobalInfoModel.role = authenticated role
  -> router.replaceUrl('pages/MainPage')
  -> MainPage.aboutToAppear: enable full-screen window layout
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

The backend validates credentials and tenant, issues JWTs, and enforces permissions and tenant scopes. Logout clears
the client session and shared business store. Refresh-token rotation, device trust, account lockout, and a complete
forgot-password/contact-admin workflow remain unimplemented. UI role selection is presentation only; authorization
must continue to be enforced by the backend token and permission middleware.

### 5.4 Main navigation shell

`MainPage.ets` is `@Entry @ComponentV2` and owns:

- `@Provider('mainPageStack') pathStack: NavPathStack`;
- `GlobalInfoModel` from `AppStorageV2`;
- `HdsTabsController` and four tab styles;
- `currentTabIndex`, `primaryTabIndex`, sidebar state, and AI/resident-detail cover visibility;
- `HdsNavigation` in `NavigationMode.Stack`;
- local destination builder for `AboutPage` and `GeneralSettingsPage`, both rendered by `MineDetailPage`;
- phone HDS Tabs and wide role-specific workspaces;
- AI conversation overlay using `AiChatPage`.

The role/layout matrix is fixed by current behavior:

| Role | Narrow phone layout | MD/LG/XL wide layout |
|---|---|---|
| Caregiver (`护工`) | Four HDS tabs | `WideCaregiverWorkspace` |
| Doctor (`医师`) | Read-only doctor summary (health/risk) | doctor-owned wide shell with workbench, residents, and AI |
| Administrator (`管理`) | WIP placeholder | `WideAdminWorkspace` local operations prototype |
| Any other string | WIP placeholder | WIP placeholder |

Phone tabs are home, resident, message/task area, and mine. They all instantiate `TabPageView` with a different
`currentTabIndex` and config. Wide caregiver layout has no structural sidebar. Its `56vp + statusBarHeight` HDS MINI title bar
keeps only the current page title on the left, with no brand mark or brand name, and groups a sliding
home/resident/message capsule, AI, and avatar-only account entry on the right. The message capsule shows the live local
unread count as a small top-right corner badge reported by
`WideMessagePage`; there is no separate bell or shift-status control in the command bar. The top account avatar uses a
brand-color fill for contrast, while its menu header contains identity text only and no avatar, clock-in state, shift
progress, or task metrics. Below 1180vp the AI action reduces its text density while the business content also
switches to its compact layout. Home, resident, and message roots stay mounted and switch visibility to retain local UI
state. When the embedded AI conversation history is collapsed, it slides out from the start edge and the title bar
exposes a compact capsule for expanding history, searching, and creating a conversation. The collapsed state is
stored in local preferences, survives navigation away from AI, and is restored after the application relaunches.
The root `HdsNavigation` owns both the phone title bar and the wide caregiver title bar. Both use HDS
`IMMERSIVE`/`ADAPTIVE` system material with a bound `GRADIENT_BLUR` scroll effect. The wide caregiver title actions are
supplied through the HDS title bar `stackBuilder`, while the page title remains native HDS title content. The root title
bar dynamically binds the visible Home/task, resident master/detail, or message list/chat Scroller; split views switch
the binding to the pane the user selects or scrolls. Wide scroll content uses a title-bar-aware initial inset and can
then scroll behind the HDS material surface. Do not replace this with a custom blur Row, an opaque structural panel, or
another nested navigation destination.
The home root is an on-shift workbench. On wide split layouts (1180vp and above, full-window) it shows a greeting
header with the day's schedule shift badge, four metric cards (today's tasks done/total, visible elders with a
building/floor summary, open alerts with emergency count, unread messages with a doctor-sender count), a 2:1 split of
a today-task list (tap opens the existing task detail sheet; the `全部` toggle shows every task) beside quick actions
(check-in hint, assistance request through MessageApi, exception report that creates a real `report`-category task via
`POST /tasks`, and a schedule viewer) plus a focus-elder list that merges open alerts per elder and opens resident
details. Narrower widths keep the responsive modular card grid that separates daily tasks, medication care, care
records, contact communication, exception reporting, and server-backed risk reminders; each populated card opens the
existing on-demand task or reminder detail surface, while the care-rhythm card remains a separate timeline. Resident and message roots use an open shared canvas with independent work surfaces: at
1180vp and above they retain side-by-side master/detail interaction; below 1180vp they use a full-width list followed by
a full-width detail view whose return action is the native root HDS title-bar back control, not a page-wide return row.
Wide doctor layouts use the shared management title shell and `WideAdminWorkspace` only for the workbench
(`WideDoctorWorkspace` remains only as a compatibility facade). The doctor navigation is intentionally limited to
workbench, residents, and AI; collaboration, assessment, risk, and monitoring entries are removed from the doctor UI.
The doctor
"长者" and "康小伴 AI" navigation targets are mounted by `MainPage` with role-owned `WideDoctorResidentPage` and
`WideDoctorAiPage` components. Their initial interaction and responsive behavior match the caregiver experience, but
their component code, Scrollers, and local presentation state are intentionally independent so the two roles can evolve
separately. The doctor resident surface remains server-backed/read-only where the role lacks mutation permission,
including its compact master/detail native HDS back behavior. Both workspaces constrain the content column after the sidebar so the four overview
cards remain inside the available window (the previous administrator root could clip the fourth card on a 2-in-1
display). The doctor account can acknowledge and handle alert rows through the dedicated `alert:handle` permission;
server-side RBAC remains the authorization boundary. The backend-connected
`WideDoctorAdmission` remains available for a future approved entry point but is not exposed by the current doctor
navigation. Wide administrator layouts mount `WideAdminWorkspace` directly; its operations overview and management
modules read and write through authenticated server APIs.

The current administrator capsule is `总览 / 角色 / 用户 / 区域 / 订阅 / 大模型 / 设备`.
`总览` is a server-backed monitoring surface: CPU, memory, and root-disk usage use responsive circular indicators;
network monitoring shows real receive/transmit rates and cumulative bytes from the protected system-monitor API;
server and runtime information remain compact label/value lists; and the lower card shows the latest tenant-scoped
operation logs from the protected audit API with explicit loading, empty, and error states. Full IoT management remains
under the `设备` entry. A backend that predates the network contract renders an explicit unavailable state rather than a
fabricated chart.
`区域` keeps the historical room/bed contract while adding floor, room, corridor, stair, common-area, and other
spatial records, and renders each selected floor as a 2D grid floor plan in `WideAreaManagement`: areas carry
`pos_x`/`pos_y`/`size_w`/`size_h` grid geometry (zero size marks a not-yet-placed legacy area; placing one applies
type defaults, room 3×2 and corridor 6×1), and the canvas supports tap-to-place, drag-to-move, a resize dialog, and
per-floor layouts persisted through the area APIs. `订阅` manages tenant-owned care-package templates and elder
subscriptions that generate runtime
care plans and tasks. The model page edits one tenant-level unified model-service connection (`ai_connections`:
one OpenAI-compatible endpoint (vLLM and friends) plus one Dify RAG connection; keys are encrypted server-side and
never returned to clients) through the `编辑模型索引` dialog and `GET/PUT /api/v1/admin/ai/connection`. Role AIs no
longer own connections: the per-role `提示词` panel assigns the model plus system prompt to the caregiver/doctor
`ai_model_configs` assignments, and the chat gateway merges connection + assignment. The page follows the redesign
platform layout on a 1280vp-centered column: a page header with live stat tags (connected models, enabled
assignments, today's calls, weighted average response), a sliding-capsule module nav that switches between the
stacked-style modules (模型管理 / 提示词库 / MCP 管理 / Skills 管理 / RAG 知识库 — the middle two are explicit
planned-only placeholders), a model card grid whose per-model today calls / average response / success rate aggregate from the
protected `/api/v1/admin/ai/usage/models` endpoint, a prompt-assignment table (with an 全部/护工端/医师端 chip filter
and a copy-to-the-other-role action) over the role configs, and Dify
knowledge-base cards (description, document count, word count) whose `设为机构知识库` action updates the unified
connection binding. The proxies
require `admin:all` and return typed not-configured/unavailable errors that the page renders as explicit states.
Device management accepts MQTT radar
metadata and manually configured RTSP cameras. Camera behavior remains an explicit empty state until the vision
adapter is integrated.

`HdsNavigation` uses an immersive/adaptive system material title bar, gradient-blur scroll effect, the currently active
bound Scroller, a back button hidden except for compact caregiver or doctor-resident local-detail state, a hidden title bar for the other
wide role workspaces, and system-safe-area expansion. `HdsTabs` overlaps content,
floats above the navigation indicator, and preloads all four tab items. `MainPage` owns the full-screen window state while
it is visible; root local covers such as AI and resident detail inherit that state rather than toggling the window independently. Measure startup/memory
before extending preload.

### 5.5 Current route inventory

| Route or presentation | Mechanism | Owner | Destination |
|---|---|---|---|
| Login -> Main | `router.replaceUrl` | `LoginPage` | `pages/MainPage` |
| Logout -> Login | `router.replaceUrl` | `MainPage`, `TabPageView` | `pages/LoginPage` |
| About | `NavPathStack.pushPath` | wide shell / mine | `MineDetailPage('about')` |
| General settings | `NavPathStack.pushPath` | wide shell / mine | `MineDetailPage('general')` |
| AI assistant | animated local cover | `MainPage` | `AiChatPage` |
| Resident detail | animated root local cover | `MainPage` (opened by `TabPageView`) | `ResidentDetailPage` |
| Health expansion | transparent `bindContentCover` | `TabPageView` | `HealthExpandPage` |
| Task expansion | transparent `bindContentCover` | `TabPageView` | internal HDS destination UI |
| Task/message/profile detail | sheet/local pane | `TabPageView` | internal builders |
| Doctor management console | shared local workspace branch | `MainPage` | `WideAdminWorkspace` |
| Doctor resident workspace | doctor-owned local workspace branch | `MainPage` | `WideDoctorResidentPage` |
| Doctor AI workspace | doctor-owned local workspace branch | `MainPage` | `WideDoctorAiPage` |
| Doctor admission | local module surface | `WideDoctorAdmission` | doctor quality module |
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

These are UI-facing view models, not transport contracts. Transport DTOs live under `network/Dto.ets`; keep the
mapping boundary explicit:

1. keep API DTOs separate;
2. map DTOs to domain models;
3. represent missing/unknown values explicitly;
4. validate units, time zones, identifiers, and enum compatibility;
5. enforce tenant and role authorization outside the UI;
6. do not let UI components parse transport payloads.

### 6.5 Current data ownership

- `BusinessStore` loads tenant-scoped elders, rooms, beds, tasks, devices, alerts, medication, notifications, bills,
  schedules, dining, assessments, contacts, messages, health records, and operation policy from authenticated APIs.
- Phone and wide caregiver pages derive their cards and detail sections from those shared server IDs. Optional concepts
  without a server record render an empty state; do not reintroduce fallback people, vitals, tasks, or conversations.
- Task progress, message replies, AI conversations, and doctor admission drafts/submissions write through server APIs.
- AI starter prompts, health thresholds, billing rates, operation thresholds, assessment templates/options/dictionaries,
  and level-specific care packages are tenant-owned database reference data. Clients must not duplicate their values.
- `WideAdminWorkspace` modules outside the operations overview remain explicit placeholders. The doctor parity shell
  intentionally uses those same placeholders; a placeholder is not permission to populate a local demo dataset.
- View-only labels, enum presentation names, responsive dimensions, and temporary form state remain client concerns;
  persistent business facts and configurable institutional rules belong to the server.

### 6.6 Doctor admission workflow and state contract

`WideDoctorAdmission` is a backend-connected local module surface, not a route or a `NavPathStack` destination.
`AdmissionRepository` loads the
current server template and free beds, creates/resumes a database draft, saves each step, requests authoritative
scoring, and submits the completed workflow.

The four gates are:

1. appendix A profile: reason/date, identity, height/weight, living/medical context, diagnoses, medications, health
   issues, information provider, contact, location, and recent risk events;
2. appendix B: all 26 persisted questions and server-owned options/scores;
3. appendix C: server-calculated 90-point result, initial/final five-level ability grade, adjustment reasons, bed, and
   a database care package with optional services;
4. four human confirmations: doctor review, plan consent, fee disclosure, and information-provider signature.

The server recalculates every score from option IDs, applies the coma and grade-adjustment rules, and refuses incomplete
or inconsistent submissions. Optional GAD-7, GDS-15, sleep, Mini-Cog, AD8, MMSE, and MoCA Beijing screenings use
persisted templates. Mini-Cog/AD8 are alternative first-stage screens; a positive result requires MMSE and MoCA before
submission. Their output is screening/advisory information, not a diagnosis.

The admission dirty guard still protects explicit in-workbench navigation. Drafts are persisted on step transitions,
so component destruction no longer destroys saved work. A successful submit transaction creates/links the elder, bed,
assessment, care plan/items, tasks, notifications, and audit trail.

Responsive behavior remains asymmetric: MD/LG use stacked compact sections while XL enables wider assessment and plan
layouts. Current-step context and previous/next actions stay in the fixed footer, including the live navigation-indicator
avoid height.

## 7. Core application: file ownership map

Current production source is under `KangxiaobanAI/products/entry/src/main/ets`.

| Path | Ownership and verified responsibility |
|---|---|
| `entryability/EntryAbility.ets` | UIAbility lifecycle, LoginPage loading, WindowUtil initialization, configuration-driven system-bar refresh |
| `pages/LoginPage.ets` | authenticated backend login, role validation, keyboard-offset form, auth-shell routing |
| `pages/MainPage.ets` | root HDS navigation, responsive role workspace selection, window-immersive ownership, AI and resident-detail overlays, local destinations |
| `component/TabPageView.ets` | phone tab feature roots backed by `BusinessStore`, sheets/covers, task updates, and resident-detail open events |
| `pages/AiChatPage.ets` | persisted AI conversations/messages, database starter prompts, feedback/copy/edit UI, and shell immersive state |
| `pages/WideDoctorAiPage.ets` | doctor-owned wide AI conversation UI with independent presentation state and the authenticated AI data boundary |
| `pages/ResidentDetailPage.ets` | resident detail sections derived from server-loaded business records |
| `pages/HealthExpandPage.ets` | expanded health list and resident index UI |
| `pages/MineDetailPage.ets` | about/general settings and Preferences-backed toggle values |
| `component/wide/WideCaregiverWorkspace.ets` | responsive top command-bar shell, sliding primary navigation, live message badge, persistent wide feature roots, avatar account actions, local-back cleanup, and safe-area forwarding |
| `component/wide/WideDoctorWorkspace.ets` | compatibility facade that delegates the visible doctor console to `WideAdminWorkspace`; the former duplicate doctor builders were removed |
| `component/wide/WideDoctorAdmission.ets` | backend-persisted four-step appendix A/B/C admission workflow, server preview/scoring, screenings, care-plan selection, confirmations, and submission result |
| `component/wide/WideDoctorQuickPanel.ets` | doctor workbench quick views for beds, tasks, alerts, assessments, bills, and daily schedules |
| `component/wide/WideAreaManagement.ets` | compatibility-aware floor/room/bed and corridor/stair area management |
| `component/wide/WideCarePackageManagement.ets` | administrator care-package template, item, and elder subscription UI |
| `component/wide/WideAdminWorkspace.ets` | server-backed administrator overview plus the doctor workbench; the removed doctor collaboration/assessment/risk/monitoring entries are out of visible navigation |
| `component/wide/WideHomePage.ets` | caregiver on-shift workbench, server task summaries/queue, resident rhythm, and persisted task actions |
| `component/wide/WideResidentPage.ets` | open-canvas responsive resident master/detail view; wide view uses independent list/detail work surfaces and widths below 1180vp switch between full-width list and detail |
| `component/wide/WideDoctorResidentPage.ets` | doctor-owned resident master/detail view with independent local state, Scrollers, compact navigation, and read-only server records |
| `component/wide/WideMessagePage.ets` | open-canvas responsive server conversation master/detail view with persisted replies/read state and unread-count reporting; widths below 1180vp switch between full-width list and detail |
| `component/wide/WideSlidingCapsule.ets` | reusable animated segmented selection control with hover/focus, symbols, inline/corner badges, and optional badge colors |
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
- `WideDoctorWorkspace.ets`: small compatibility facade (the former duplicate doctor shell was removed);
- `WideDoctorAdmission.ets`: about 1,793 lines;
- `WideAdminWorkspace.ets`: about 724 lines;
- `AiChatPage.ets`: about 1,552 lines;
- `WideHomePage.ets`: about 1,420 lines;
- `WideResidentPage.ets`: about 1,409 lines;
- `WideMessagePage.ets`: about 1,153 lines;
- `WideCaregiverWorkspace.ets`: about 452 lines;
- `ResidentDetailPage.ets`: about 808 lines;
- `MainPage.ets`: about 1,265 lines.

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

The wide caregiver shell uses one continuous `background_secondary` canvas across its root, HDS title bar, content
region, and system-bottom area. Do not reintroduce a structural sidebar or white top-bar panel, frame borders, or shadows
that form a separate dashboard shell. Reserve `comp_background_primary` for business surfaces and the active navigation
target; use brand blue for interactive emphasis, and use red/orange/green only for risk or status meaning. The HDS MINI
title bar uses the `56vp + statusBarHeight` rhythm, keeps identity/title on the left, and places the animated primary capsule,
AI, and avatar-only account action on the right. The message badge owns notification count; do not add a duplicate bell
or shift chip. Detailed shift progress remains in the home workbench.

### 8.2 Safe areas and window classes

Immersive rendering has two separate responsibilities:

- the visual canvas may extend behind system bars using `ignoreLayoutSafeArea`/`expandSafeArea`;
- interactive content must still account for status bar, navigation indicator, cutout, fold, and keyboard avoid areas.

Use live values from `GlobalInfoModel`. Do not infer status-bar height from a fixed number. Verify rotation, floating
window resize, keyboard opening/closing, dark mode, large fonts, mouse/keyboard focus, and back gesture on every device
form affected by a layout change.

`MainPage` enables full-screen layout while the authenticated shell is visible and restores the non-full-screen login
shell when it disappears. Child covers such as `AiChatPage` must not independently reset that window state. Never apply
`naviIndicatorHeight` as padding to an entire persistent page viewport: let the visual canvas extend behind the system
area and consume the inset only in scroll-content endings, fixed action bars, composers, or other interactive owners.
The authenticated shell's `HdsNavigation.ignoreLayoutSafeArea` is the single root layout-expansion owner for ordinary
shell content; wide workspaces must not layer another full-window expansion on top of it. A full-window overlay may own
one outermost `ignoreLayoutSafeArea`, but its descendants must not repeat it. Keep both the status bar and navigation
indicator visible in immersive mode. Dark surfaces change system-bar content color only and must not hide a system bar.
Logout owners await the non-full-screen transition before routing to `LoginPage`, and `LoginPage` asserts that state on
appearance. A system color-mode configuration update must refresh status/navigation content colors without changing the
current full-screen ownership.

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

`pages/AiChatPage.ets` uses the authenticated AI gateway:

- conversations and messages are persisted and isolated by tenant and user;
- starter prompts are enabled/ordered database rows rather than client content constants;
- new/select/delete/send flows call typed REST endpoints;
- remote provider errors surface as service failures and are not rewritten as local answers;
- the response records its actual provider/model identity;
- the gateway merges one tenant-level unified connection (`ai_connections`: endpoint, keys, enable, RAG) with the
  role assignment (`ai_model_configs`: model and system prompt per role); assignments no longer carry endpoints;
- every gateway call writes one tenant-scoped `ai_usage_logs` row (provider-reported tokens when available, a
  character-based estimate for the local provider, RAG attempts, success flag, duration) without message content;
- when the unified connection enables RAG on an http endpoint, the gateway performs a best-effort Dify dataset
  retrieval and injects the
  fragments as reference context; retrieval failures do not block the chat and local-provider connections never retrieve;
- UI-only feedback, copy/edit state, scrolling, focus, keyboard behavior, and simple rich-text parsing remain local.

Future production hardening must still provide:

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

- Local signing material/password fields existed in tracked history; values require rotation and history cleanup even
  though the core product's current build profile no longer contains `signingConfigs`.
- JWT authentication, RBAC, tenant scoping, and audit are implemented, but refresh rotation, device trust, lockout, and
  externally reviewed privacy/retention controls remain open production requirements.
- Sensitive care/health/location/device data still needs deployment-specific encryption, backup, retention, and access
  review beyond application-level tenant isolation.
- AI remains advisory and non-streaming; configured remote-model privacy, redaction, evidence, and clinical governance
  require deployment review.

### Functional/lifecycle risks

- `PreferenceManager.hasValue()` can recurse forever when initialization fails.
- `HealthExpandPage` creates a `ListScroller`, but the rendered `Scroll()` does not bind that scroller; index positioning
  is ineffective.
- `WindowUtil` listeners do not have symmetric teardown from Ability lifecycle.
- The administrator phone layout and non-overview administrator modules remain WIP placeholders. The doctor phone
  layout now provides a read-only health/risk summary; it does not expose caregiver write actions. The doctor admission
  component is mounted under the doctor quality module, but still requires real-device and service verification.
- Several optional detail concepts have no server records and intentionally render empty states.
- Admission drafts persist, but offline conflict resolution and multi-editor locking are not implemented.
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

Recorded build evidence at the baseline date and latest workspace verification:

- `assembleHap` for module `kanxiaoban`, product `default`, build mode `debug`, completed successfully on 2026-07-29
  with DevEco/Hvigor after setting `DEVECO_SDK_HOME` to the SDK root and using the bundled JBR;
- the current build profile has no `signingConfigs`, so the generated artifact is
  `KangxiaobanAI/products/entry/build/default/outputs/default/kanxiaoban-default-unsigned.hap`;
- an unsigned artifact proves compilation/packaging only and is not release/install signing evidence;
- the current top-command-bar, safe-area, and workspace edits pass `git diff --check` and the API 24 ArkTS compiler;
- build logs retain non-fatal `router.replaceUrl` deprecation diagnostics and must be re-read after future builds.
- A run without the SDK-root environment setting still fails before compilation with
  `00303168 Configuration Error: SDK component missing`; this is an environment setup issue, not current source
  evidence. The build is `Build-verified` for this exact local product/mode; it is not `Device-verified` or
  `Service-verified` without real-device and backend checks.

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
| Geometry transition | `KangxiaobanAI/.../TabPageView.ets` + `MainPage.ets` + `ResidentDetailPage.ets` | stable IDs and root-level animated insertion/removal above HDS Tabs |
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
