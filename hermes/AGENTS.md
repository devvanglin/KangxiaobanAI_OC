# Hermes HarmonyOS Port Agent Handbook

> Scope: this file applies to the whole `D:\Coding\KangxiaobanAI_OC\hermes` project.
> Port baseline: 2026-08-15.
> Upstream: `https://github.com/EKKOLearnAI/hermes-studio`.

## 1. Mandatory first reads

Before inspecting or changing this project, read in this order:

1. this `AGENTS.md` completely;
2. `HERMES_PORTING_MEMORY.md` completely;
3. the workspace root `..\AGENTS.md` sections relevant to HarmonyOS discovery, safety, V2 state, responsive layout,
   resources, lifecycle, testing, and verification;
4. current manifests and runtime entry files named in section 4 below.

After every coherent implementation or verification batch, update `HERMES_PORTING_MEMORY.md` with the exact files,
behavior, build result, remaining gaps, and next step. Never claim a route, device form, service, or interaction is
finished unless the memory file records its acceptance evidence.

## 2. Product and fidelity target

This project is the native HarmonyOS port of Hermes Studio. The goal is feature and visual fidelity to the upstream
client while adapting navigation, window layout, focus, safe areas, keyboard handling, and interaction to ArkUI.

`One-to-one` means all of the following:

- the same information architecture and user-visible feature inventory;
- recognizable visual identity, density, hierarchy, colors, spacing, radii, icons, and empty/loading/error states;
- equivalent primary interactions and state transitions;
- responsive behavior for every device type declared by the module;
- honest separation between local prototype behavior and real Hermes server integration.

It does not mean embedding the upstream website in a Web component, copying Vue/DOM code into ArkTS, or stretching a
phone layout across a tablet/2-in-1 window.

## 3. Fixed upstream baseline

The initial audited upstream baseline is:

- repository: `EKKOLearnAI/hermes-studio`;
- commit: `d9ea9f48761ee857a3f8a5f12e8aff0ec2525efc`;
- version: `0.6.42`;
- commit date: `2026-08-14T21:40:41+08:00`;
- local read-only audit checkout:
  `C:\Users\Shenyi\AppData\Local\Temp\codex-hermes-studio-upstream`.

The upstream checkout is evidence, not a write target. Do not modify it. When refreshing upstream, record the new
commit and reconcile the route/feature inventory before changing the port.

Upstream source priorities:

1. `packages/client/src/router/index.ts` for route inventory;
2. `packages/client/src/views` for screen ownership;
3. `packages/client/src/components` for reusable interactions;
4. `packages/client/src/styles/variables.scss` and `theme.ts` for visual tokens;
5. `packages/client/src/stores` and `packages/client/src/api` for client state and service contracts;
6. `packages/server/src` for backend behavior and API ownership;
7. README text only as a secondary summary.

## 4. Current HarmonyOS boundary

The current native project is:

- root: `hermes`;
- runtime OS: HarmonyOS;
- target SDK: `26.0.0`;
- compatible SDK: `6.1.1(24)` so the port can be exercised on the available API 24 phone/tablet emulators;
- product: `default`;
- module: `entry`;
- module type: `entry` HAP;
- device types: `phone`, `tablet`, `2in1`;
- Ability: `EntryAbility`;
- startup page: `pages/Index`;
- initial template state generation: ArkUI V1; migration to V2 is intentional for production code;
- restricted permissions: `ohos.permission.INTERNET` is declared for the native HTTP repository;
- backend integration: password login, authenticated session-list loading, paginated conversation-message loading,
  load-more, the native read-only History browser, and the official non-streaming `POST /api/chat-run/runs` bridge are
  implemented behind a Repository boundary, but no configured real Hermes Studio server has been service-verified;
  Socket.IO `/chat-run` streaming remains planned.

Required discovery files:

- `build-profile.json5`;
- `oh-package.json5`;
- `AppScope/app.json5`;
- `entry/build-profile.json5`;
- `entry/oh-package.json5`;
- `entry/src/main/module.json5`;
- `entry/src/main/resources/base/profile/main_pages.json`;
- `entry/src/main/ets/entryability/EntryAbility.ets`;
- `entry/src/main/ets/pages/Index.ets`.

Do not print or copy signing secrets, certificate paths, passwords, tokens, provider credentials, or private endpoints.

## 5. Architecture decisions

Default to ArkUI V2:

- `@ComponentV2`, `@Local`, `@Param`, `@Require`, `@Event`;
- `@Provider/@Consumer` for the shared navigation stack or narrow tree-scoped dependencies;
- `@ObservedV2/@Trace` for feature and app models;
- `AppStorageV2.connect` only for application/window/session shell state.

The native UI baseline is **ArkTS + ArkUI V2 + HDS**. Import HDS from `@kit.UIDesignKit` and prefer the available
system patterns for application navigation, sidebars, list rows, title bars, materials, tabs, destinations, action
bars, and snackbars. The current SDK does not provide `HdsTextInput` or `HdsButton`; use system ArkUI input/button
controls where HDS has no equivalent instead of inventing unsupported HDS APIs or embedding Web content.

Use this dependency direction:

```text
Entry shell
  -> feature page/component
  -> feature store/view model
  -> use case
  -> repository interface
  -> fake or HTTP/WebSocket data source
```

Keep fake and real repositories behind the same contract. UI files must not construct transport payloads, own retry
policy, parse raw server errors, store credentials, or imply persistence when only local state changed.

`Index.ets` owns one process-stable `HermesAppModel`, one chat `HermesChatModel`, one independent History
`HermesChatModel`, and one `HermesRuntime` instance. Async repository flows must update the exact model instance bound
to the visible feature; do not retain a transient component copy across `await`. `HermesMessage` is `@ObservedV2` with
traced fields because keyed `ForEach` reuses rows whose IDs stay stable while pending content changes to success or
failure.

`HermesHistoryPage.ets` is a read-only native History browser, not the generic feature shell. It keeps History
selection independent from Chat, groups sessions by upstream source order, supports local title/model/Profile/source
search and source filtering over the currently loaded session page, loads real paginated messages through the shared
Repository/Runtime, and builds a question/Markdown-heading outline. Phone uses list -> detail -> outline task states;
wide windows use list/detail split and may add a third outline pane at extra-wide width. Delete, batch delete, pin,
import-to-Web-UI, unarchive, copy-link, and group-page load-more must not be shown as successful until their real
Repository contracts are implemented.

Historical paging follows the upstream offset contract: the first page uses offset `0` and limit `150`; load-more uses
the current loaded count, deduplicates by message ID, prepends older messages, and preserves the previously first row's
position. Keep loading, retry, exhausted, stale-session, and unauthorized states explicit.

The current token is intentionally process-memory-only. Do not persist it in Preferences or logs. An empty server URL
selects the explicitly labelled local preview; a non-empty URL must pass `http://`/`https://` validation and use the
HTTP Repository. Plain HTTP is for trusted LAN development only and must remain visibly warned in the login UI.

Use `Navigation/NavPathStack` for in-app routes. A narrow phone may use a drawer/bottom-level entry plus pushed detail;
tablet and 2-in-1 should use persistent left navigation and split panes where the upstream desktop layout does.

## 6. Design and responsive baseline

Preserve the upstream Pure Ink identity:

- light canvas `#FAFAFA`, light surface `#FFFFFF`, sidebar `#F5F5F5`;
- dark canvas `#1A1A1A`, dark surface `#2A2A2A`, sidebar `#202020`;
- primary text `#1A1A1A` light / `#E0E0E0` dark;
- secondary text `#666666` light / `#A0A0A0` dark;
- border `#E0E0E0` light / `#3A3A3A` dark;
- primarily grayscale accent, with green/red/orange reserved for status and blue reserved for information;
- 14fp body baseline, compact productivity density, 6-8vp small radii, restrained shadows;
- upstream wide sidebar reference width 240px and collapsed width 64px.

All stable values belong in semantic resources or token files. Use `vp` for layout and `fp` for text. Support light and
dark resources; do not hard-code a single theme in page files.

Responsive expectations:

- phone: compact single-pane task flow, drawer or compact primary navigation, pushed detail, keyboard-safe composer;
- tablet: persistent navigation when width permits, list/detail split for chat/history/files/settings, touch-first targets;
- 2-in-1: persistent navigation, denser panels, mouse hover, keyboard focus and shortcuts, resizable/flexible work areas;
- every form: rotation, resize, system bars, navigation indicator, keyboard, large font, long text, and empty/error states.

The authenticated shell currently uses `HdsNavigation` with an immersive/adaptive MINI title bar and `HdsSideBar`.
Phone uses the HDS overlay drawer; tablet/2-in-1 widths use the HDS embedded persistent sidebar. Navigation, session,
profile, and activity rows use `HdsListItemCard`. Preserve HDS press/hover/focus/selected semantics and keep custom
Pure Ink styling at the resource and content-layout layer.

## 7. Implementation and fidelity protocol

Before implementing a route:

1. locate its upstream route, view, child components, store, API calls, i18n strings, and styles;
2. add it to the coverage table in `HERMES_PORTING_MEMORY.md`;
3. identify states: loading, empty, content, pending, success, failure, offline/unauthorized where applicable;
4. decide phone/tablet/2-in-1 navigation and layout transformations;
5. implement the smallest coherent native feature boundary;
6. build and inspect the exact device/layout surface affected;
7. record evidence and gaps in the memory file.

Do not mark backend-dependent actions as service-verified until they reach a configured Hermes Studio backend. Local
demo data must be labeled and remain replaceable through repository interfaces.

## 8. Verification gates

Every batch must run the narrowest relevant checks, then broaden when shared code changes:

1. inspect `git diff --check` and changed files;
2. validate manifests, page profiles, resources, and route names;
3. run focused unit/component tests for changed state or rules;
4. build `entry/default/debug` with the local DevEco/Hvigor environment;
5. inspect phone, tablet, and 2-in-1 layouts when shared shell or responsive code changes;
6. check light/dark, large font, focus/hover, keyboard, safe areas, loading/empty/error, and rapid repeated input;
7. update `HERMES_PORTING_MEMORY.md` with exact results.

Use these completion labels consistently:

- `Implemented`: native code path exists and is traceable;
- `Build-verified`: exact HarmonyOS product/module/mode compiled and packaged;
- `Device-verified`: explicitly run on the named real or virtual device form;
- `Service-verified`: explicitly tested against a configured Hermes Studio server;
- `Planned`: design or architecture only.

## 9. Workspace safety

The parent workspace is dirty and contains unrelated user changes. Modify only files under `hermes` unless the user
explicitly expands scope. Do not clean caches or reset other projects. Do not commit `.hvigor`, `build`, `oh_modules`,
IDE metadata, `local.properties`, generated caches, credentials, or screenshots containing secrets.
