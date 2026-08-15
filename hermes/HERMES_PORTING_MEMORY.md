# Hermes HarmonyOS Port Memory

> This is the durable progress ledger for context resets. Read it completely before continuing. Update it after every
> coherent implementation or verification batch. Source code and current build output remain the final truth.

## 1. Mission

Port Hermes Studio from `https://github.com/EKKOLearnAI/hermes-studio` to a native HarmonyOS application under this
directory, preserving recognizable visual/interaction fidelity while supporting every device type declared by the
HarmonyOS module: `phone`, `tablet`, and `2in1`.

The native port must not be a WebView wrapper. Backend-dependent behavior must distinguish local mock implementation
from real Hermes Studio HTTP/Socket.IO integration.

## 2. Baselines

### Upstream audited baseline

- Commit: `d9ea9f48761ee857a3f8a5f12e8aff0ec2525efc`
- Version: `0.6.42`
- Commit time: `2026-08-14T21:40:41+08:00`
- Audit checkout: `C:\Users\Shenyi\AppData\Local\Temp\codex-hermes-studio-upstream`
- Upstream shape: Vue 3 client + Koa/Socket.IO server + Electron desktop wrapper
- Client route count: 32 route records including redirects/dynamic desktop route
- Client component count observed: 136 `.vue`/`.ts` component files

### HarmonyOS project baseline

- Root: `D:\Coding\KangxiaobanAI_OC\hermes`
- SDK: target `26.0.0`, compatible `6.1.1(24)`
- Product/module/mode target: `default` / `entry` / `debug`
- Module type: entry HAP
- Devices: phone, tablet, 2in1
- Ability/startup: `EntryAbility` -> `pages/Index`
- Initial page: DevEco Hello World template
- Initial state generation: ArkUI V1 template
- Permissions: `ohos.permission.INTERNET`
- Real backend integration: HTTP Repository path implemented for password login, session list, paginated historical
  messages, and non-streaming chat-run; no configured real Hermes Studio server has been service-verified

## 3. Upstream visual baseline

Pure Ink theme:

- Light: canvas `#FAFAFA`, sidebar `#F5F5F5`, surface `#FFFFFF`, border `#E0E0E0`, text `#1A1A1A`.
- Dark: canvas `#1A1A1A`, sidebar `#202020`, surface `#2A2A2A`, border `#3A3A3A`, text `#E0E0E0`.
- Body baseline: 14px upstream -> 14fp native baseline.
- Sidebar: 240px expanded / 64px collapsed upstream reference.
- Radii: 6-8px controls/cards; app main card uses 14px in the upstream shell.
- Accent is grayscale; status uses green/red/orange and information uses blue.
- Product behavior is a compact productivity console, not a large-card consumer app.

## 4. Route and feature coverage

Status vocabulary: `planned`, `shell`, `implemented`, `build-verified`, `device-verified`, `service-verified`.

| Upstream route/feature | Native owner | Status | Notes |
|---|---|---|---|
| Login `/` | `HermesLoginPage.ets`, `HermesHttpRepository` | device-verified | Empty URL uses labelled preview; configured URL performs real NetworkKit password login. Exact contract passed a device-local mock; a real Hermes server remains unverified. |
| Chat `/hermes/chat` | `HermesChatPage.ets`, `HermesChatModel`, `HermesHttpRepository` | device-verified | Local preview remains immediate; remote mode uses official non-streaming `/api/chat-run/runs` with real pending/success/failure state. Device HTTP contract passed against a temporary mock, not a real Hermes service. |
| Session `/hermes/session/:sessionId` | `HermesChatPage.ets`, `HermesHttpRepository` | device-verified | Session summaries, the first 150-message page, and explicit load-more pages use the audited APIs with loading/content/empty/error/401 states. User, assistant, tool, system, command, and MoA roles are mapped without local placeholder leakage. |
| History + history session | `HermesHistoryPage.ets`, `HermesHistorySupport.ets`, `HermesRuntime` | device-verified | Native read-only source groups, search/source filtering, independent selection, paginated message detail, phone list/detail/outline flow, and tablet list/detail split are implemented. Real delete/pin/import/unarchive/group-page APIs and real Hermes service verification remain absent. |
| Global Agent + session | `HermesFeaturePage.ets` | shell | Navigation and generic native page only. |
| Connections + devices | `HermesFeaturePage.ets` | device-verified | Tablet page shell inspected; no discovery, pairing, or capability service. |
| Group Chat + room | `HermesFeaturePage.ets` | shell | Navigation and generic native page only. |
| Shared group chat | none | planned | Public/invite-only boundary. |
| Group chat link | none | planned | Standalone configuration flow. |
| Jobs | `HermesFeaturePage.ets` | shell | Cron-shaped local snapshot only. |
| Kanban | `HermesFeaturePage.ets` | shell | Metrics/activity shell; drag/move remains planned. |
| Workflow | `HermesFeaturePage.ets` | shell | Generic page; native canvas/node authoring remains high-risk work. |
| Models | `HermesFeaturePage.ets` | shell | Local Provider/model snapshot only. |
| Profiles | `HermesFeaturePage.ets` | shell | Generic super-admin page shell. |
| Logs | `HermesFeaturePage.ets` | shell | Local log-shaped snapshot only. |
| Usage | `HermesFeaturePage.ets` | shell | Local metric snapshot; no charts/service. |
| Performance | `HermesFeaturePage.ets` | shell | Local metric snapshot; no admin service. |
| Journey | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Skills usage | `HermesFeaturePage.ets` | shell | Local metric snapshot only. |
| Skills | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Plugins | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Petdex | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Memory | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Settings | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Theme | `HermesFeaturePage.ets`, resources | shell | Light/dark semantic resources exist; settings behavior is not implemented. |
| Channels | `HermesFeaturePage.ets` | shell | Generic page shell; platform forms remain planned. |
| Terminal | `HermesFeaturePage.ets` | shell | Generic page shell; PTY/WebSocket remains planned. |
| Files | `HermesFeaturePage.ets` | shell | Local file-shaped snapshot; browser/editor/preview remain planned. |
| Coding Agents | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Version Preview | `HermesFeaturePage.ets` | shell | Generic page shell. |
| MCP Manager | `HermesFeaturePage.ets` | shell | Generic page shell. |
| Desktop Browser | TBD | planned | Electron-only upstream; native boundary TBD |
| Desktop Pet | TBD | planned | Electron pet window; HarmonyOS adaptation TBD |

## 5. Completed work

### 2026-08-15 Batch 0: discovery and durable project rules

- Read the workspace root `AGENTS.md` completely.
- Read the `harmonyos-design` skill plus principles, adaptation, accessibility, ArkUI mapping, and motion references.
- Recorded parent workspace dirty state; unrelated changes exist in `KangxiaobanAI`, `KanxiaobanDS`, `MusicHome`, and
  `NavigationSettings`. Scope is restricted to `hermes`.
- Audited the new HarmonyOS manifests, module, Ability, page profile, and template page.
- Cloned and audited the upstream source at the exact commit shown above.
- Counted and categorized upstream routes, views, components, themes, and product features.
- Added `hermes/AGENTS.md` and this memory file.
- Confirmed the local phone and tablet emulators both run API 24. The initial target/compatible API 26 HAP could not be
  installed because the device SDK was older, so `compatibleSdkVersion` was deliberately lowered to `6.1.1(24)` while
  retaining target SDK `26.0.0` for compilation.

Verification:

- Discovery only; no HarmonyOS build has been run yet.
- No device or backend verification exists yet.

### 2026-08-15 Batch 1: native responsive shell and first vertical slice

- Replaced the Hello World page with ArkUI V2 production components.
- Added Pure Ink semantic light/dark resources, upstream Hermes mascot, responsive login, phone drawer, persistent wide
  sidebar, full first-level feature inventory, chat session list, message list, composer, and generic feature pages.
- Added source files:
  - `entry/src/main/ets/model/HermesModels.ets`;
  - `entry/src/main/ets/data/HermesCatalog.ets`;
  - `entry/src/main/ets/component/HermesLoginPage.ets`;
  - `entry/src/main/ets/component/HermesSidebar.ets`;
  - `entry/src/main/ets/component/HermesChatPage.ets`;
  - `entry/src/main/ets/component/HermesFeaturePage.ets`.
- Changed `compatibleSdkVersion` to `6.1.1(24)` while keeping target `26.0.0`, because the available phone and tablet
  emulators run API 24.
- Replaced empty text glyph buttons with system `SymbolGlyph` resources for menu, add, and send.
- Built `entry/default/debug` successfully and produced
  `entry/build/default/outputs/default/entry-default-unsigned.hap`.
- Ran `hvigor test -p product=default -p module=entry@default -p buildMode=debug`; it passed, but tests remain template
  assertions and are not feature evidence.
- Installed and ran on phone `127.0.0.1:5555` and tablet `127.0.0.1:5557`, both API 24.
- Verified phone login/chat, tablet login/three-column chat, and fixed right-side chat text overflow.

### 2026-08-15 Batch 2: interaction/device verification and truthful reply state

- Reinstalled the latest HAP on both API 24 emulators and verified the system menu/add/send icons render.
- Verified phone drawer open, phone navigation to History, tablet navigation to Connections, tablet local session
  selection, text entry, keyboard resize, send action, and local response rendering.
- Device testing exposed a real bug: the original 700 ms fake reply timer could be invalidated while the software
  keyboard changed the page area, leaving `Hermes 正在思考…` permanently pending.
- Added `HermesChatModel` as the persistent feature-state owner and moved chat messages/input/session state out of the
  transient child component.
- Removed the fake delayed success. Local preview now appends an immediate, explicitly labelled local reply. Pending,
  confirmed, failed, retry, cancellation, and streaming must be reintroduced only when a real Repository result drives
  them.
- Rebuilt and reran unit tests successfully after the fix.
- Reinstalled and verified final local replies on both phone and tablet while the keyboard was open. UI-tree evidence
  contains both the submitted text and the completed local reply, with no lingering pending row.
- Final evidence screenshots include:
  - `screenshots/hermes-phone-drawer.jpeg`;
  - `screenshots/hermes-feature-latest-127.0.0.1-5555.jpeg`;
  - `screenshots/hermes-feature-latest-127.0.0.1-5557.jpeg`;
  - `screenshots/hermes-phone-verified-reply.jpeg`;
  - `screenshots/hermes-tablet-verified-reply.jpeg`.
- Required command-line build environment for this machine:
  - `DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk`;
  - prepend `C:\Program Files\Huawei\DevEco Studio\jbr\bin` to `PATH` for packaging;
  - use the bundled Hvigor wrapper under `tools/hvigor/bin/hvigorw.bat`.

### 2026-08-15 Batch 3: native HTTP Repository, honest remote states, and device contract proof

- Added DTO/domain separation and Repository contracts for password authentication, session summaries, and one-shot
  chat runs:
  - `entry/src/main/ets/common/HermesUrl.ets`;
  - `entry/src/main/ets/data/HermesDtos.ets`;
  - `entry/src/main/ets/data/HermesRepository.ets`;
  - `entry/src/main/ets/data/HermesMappers.ets`;
  - `entry/src/main/ets/data/HermesHttpRepository.ets`.
- Declared `ohos.permission.INTERNET` in `entry/src/main/module.json5`.
- Login now has optional Hermes Server URL and Profile inputs:
  - empty URL keeps the explicitly labelled local preview;
  - invalid URL is blocked before a request;
  - non-empty valid URL calls `POST /api/auth/login` through NetworkKit;
  - cleartext HTTP shows a trusted-LAN-only warning;
  - the returned token is held only in process memory and is cleared on logout.
- Authenticated calls attach `Authorization: Bearer <token>` and `X-Hermes-Profile`; session loading calls
  `GET /api/hermes/sessions?profile=...`.
- Remote session UI now models loading, content, empty, error, and unauthorized states. Remote history messages are not
  invented: the page explicitly says historical detail is not connected yet.
- Remote send uses the upstream official non-streaming bridge `POST /api/chat-run/runs`. Pending is created only for the
  real request and resolves to success or visible failure; HTTP 401 marks the session expired. Socket.IO streaming,
  tools, approvals, clarification, cancellation, and reconnect remain planned.
- Added focused unit tests for URL normalization, login-response validation/profile selection, and session DTO mapping.
  Final result: `Tests run: 4, Failure: 0, Error: 0, Pass: 4, Ignore: 0`.
- Final `assembleHap` for `default / entry / debug` succeeded. Artifact remains unsigned:
  `entry/build/default/outputs/default/entry-default-unsigned.hap`.
- Installed the final HAP on API 24 phone `127.0.0.1:5555` and tablet `127.0.0.1:5557`.
- Reverified on both devices:
  - responsive login layout;
  - keyboard entry and local preview login;
  - composer send while the software keyboard is open;
  - completed local reply with no residual pending state.
- Exercised the actual NetworkKit runtime on the phone against a temporary in-memory contract server implementing the
  exact audited endpoints. The device successfully completed login, loaded `NetworkKit contract session`, sent
  `contract-message`, and rendered `NetworkKit contract reply: contract-message`. The temporary server was stopped
  afterward. This is device/transport contract evidence only, not `Service-verified` evidence for Hermes Studio.
- Device review caught a real responsive regression introduced during this batch: a percentage `minHeight` on a Scroll
  child produced a blank tablet login page. It was removed, rebuilt, reinstalled, and both final phone/tablet login
  screenshots were rechecked successfully.
- New evidence includes:
  - `screenshots/batch3-phone-final-login-fixed.jpeg`;
  - `screenshots/batch3-tablet-final-login-fixed2.jpeg`;
  - `screenshots/batch3-phone-invalid-url.jpeg`;
  - `screenshots/batch3-phone-contract-session.jpeg`;
  - `screenshots/batch3-phone-contract-reply.jpeg`;
  - `screenshots/batch3-phone-final-reply.jpeg`;
  - `screenshots/batch3-tablet-final-reply.jpeg`.

### 2026-08-15 Batch 4: paginated message history and keyed-row async-state repair

- Implemented the audited historical-message endpoint through the Repository boundary:
  `GET /api/hermes/sessions/conversations/{id}/messages/paginated` with offset, limit, and profile parameters.
- Added message DTO/result mapping for user, assistant, tool, system, command, and MoA roles. Empty tool output is shown
  truthfully as `工具：<tool_name>` and second/millisecond timestamps are normalized for display.
- Remote session selection now loads real history with loading, content, empty, error, retry, and unauthorized states.
  Remote mode clears preview messages so a server session never inherits unrelated local placeholder content.
- Added `HermesRuntime` as the process-memory Repository/auth controller. App, chat, and runtime models are created once
  per process in `Index.ets`; tokens remain memory-only and are cleared on logout.
- Device testing exposed two distinct ArkUI V2 lifetime/rendering issues:
  - component reconstruction around keyboard/layout changes made ordinary async component references unsafe across
    `await`, so async Repository flows now run through the stable runtime and receive the exact model bound to the page;
  - the keyed message `ForEach` reused a pending row because its ID stayed constant while `HermesMessage` was a plain
    object. `HermesMessage` is now `@ObservedV2` with traced fields, and completion/failure mutates those fields in place.
- Final unit result: `Tests run: 6, Failure: 0, Error: 0, Pass: 6, Ignore: 0`, including a focused pending-to-complete
  message-state test.
- Final `assembleHap` for `default / entry / debug` succeeded. The artifact remains unsigned at
  `entry/build/default/outputs/default/entry-default-unsigned.hap`.
- Phone API 24 contract verification passed with the software keyboard open: login, session list, historical messages,
  and one-shot run all reached the temporary contract server; the UI tree contained the returned reply and contained
  neither the pending text nor a send-failure row.
- Tablet API 24 regression verification passed for wide login, three-column local preview, keyboard-open send, and the
  completed local reply with no residual pending state.
- New evidence includes:
  - `screenshots/batch4-phone-history.jpeg`;
  - `screenshots/batch4-phone-observable-result.jpeg`;
  - `screenshots/batch4-tablet-local-result.jpeg`.
- The temporary contract server was stopped after verification. No test credential, token, or private endpoint was
  written to source or this memory file. This remains device/transport contract evidence, not real-service verification.

### 2026-08-15 Batch 5: upstream-compatible historical load-more

- Audited the upstream `HistoryView.vue`, chat store, `HistoryMessageList.vue`, and sessions API. The upstream contract
  loads 150 messages at offset `0`, then requests offset=`loadedMessageCount`, deduplicates message IDs, and prepends the
  older page.
- Added traced paging state to `HermesChatModel`: total, loaded count, has-more, loading, and retryable error text.
- Added `HermesRuntime.loadOlderMessages()` with auth revision and selected-session stale checks. Successful pages are
  deduplicated and prepended; exhausted, unauthorized, and error states remain explicit.
- Added a native `加载更早消息`/retry control above the transcript. After a page is prepended, the list restores the
  previously first message row so reading position is not thrown to the new top.
- Added a focused deduplication/prepend test. Final unit result:
  `Tests run: 7, Failure: 0, Error: 0, Pass: 7, Ignore: 0`.
- Final `assembleHap` for `default / entry / debug` succeeded and produced the unsigned HAP.
- Phone API 24 paging contract verification passed: the first UI tree contained only the newer page and the load-more
  control; tapping it requested offset `2`, then the final tree contained all four messages in chronological order,
  removed the load-more control, and showed no load error.
- Tablet API 24 local-preview regression passed on the same HAP with the software keyboard open; the completed reply
  appeared with no pending row and no remote load-more control.
- New evidence includes `screenshots/batch5-phone-paging-final.jpeg`.
- The temporary paging contract server was stopped after verification; this is not real Hermes-service verification.

### 2026-08-15 Batch 6: ArkTS + ArkUI V2 + HDS component baseline

- Confirmed the native component policy: ArkTS and ArkUI V2 remain mandatory, while navigation, sidebars, title bars,
  list rows, materials, tabs/destinations, action bars, and snackbars prefer `@kit.UIDesignKit`. The installed SDK
  exposes `HdsNavigation`, `HdsSideBar`, `HdsListItemCard`, `HdsNavDestination`, `HdsTabs`, `HdsActionBar`, and
  `HdsSnackBar`; it does not expose `HdsTextInput` or `HdsButton`, so uncovered input/button roles continue to use
  system ArkUI controls. No WebView/Web component is used.
- Migrated `entry/src/main/ets/pages/Index.ets` to an HDS root shell with `HdsNavigation`, MINI title mode,
  immersive/adaptive system material, HDS title-bar menu, and `HdsSideBar`. Phone uses Overlay and wide windows use
  Embed. The wide `scaleContentEnabled` setting was corrected after UI-tree evidence showed the sidebar container at a
  real `-80vp` offset; final tablet bounds start at zero and the complete 240vp Hermes sidebar is visible.
- Migrated primary navigation, profile/collapse/logout rows, chat session header/list/header, and generic feature
  activity rows to `HdsListItemCard` in `HermesSidebar.ets`, `HermesChatPage.ets`, and `HermesFeaturePage.ets`.
  Chat bubbles and the composer remain native ArkUI because HDS has no chat/input equivalent.
- Replaced the phone chat-session hamburger with `sys.symbol.chevron_right` so it is visually and semantically distinct
  from the root HDS main-menu button. Phone activity suffixes now show only status, while wide windows retain status and
  time; an extra row padding layer was removed so HDS suffix content stays inside the right boundary.
- Device testing caught a runtime crash caused by passing an inline ArkUI DSL arrow to `PrefixCustomBuilder` inside an
  HDS-created context: `TypeError: Cannot read property fontSize of undefined`. All affected prefixes now use supported
  `PrefixIcon` plus `SymbolGlyphModifier`; no new TypeError, ReferenceError, JS crash, or fatal log appeared afterward.
- Final unit result: `Tests run: 7, Failure: 0, Error: 0, Pass: 7, Ignore: 0`.
- Final `assembleHap` for `default / entry / debug` succeeded. The unsigned artifact is
  `entry/build/default/outputs/default/entry-default-unsigned.hap`, 679308 bytes, SHA-256
  `E03751AA7667C3E3655C3E24B8B1E8D4B2686DBABDE08B78775614EFCC6B432E`.
- Installed the final HAP on API 24 phone `127.0.0.1:5555` and tablet `127.0.0.1:5557`. Verified the HDS phone drawer,
  feature switching to History, the distinct session-list affordance, keyboard-open send, completed local reply after
  keyboard dismissal/scroll, persistent tablet sidebar, selected Connections row, and non-clipped wide activity rows.
- Final evidence includes:
  - `screenshots/batch6-hds-phone-drawer.jpeg`;
  - `screenshots/batch6-final3-phone-history.jpeg`;
  - `screenshots/batch6-final-phone-chat-reply2.jpeg`;
  - `screenshots/batch6-final2-tablet-connections.jpeg`;
  - their paired UI-tree JSON files under `screenshots/`.
- This HDS batch is phone/tablet device-verified only. The declared `2in1` form, real hardware, dark mode, large font,
  screen reader, mouse/keyboard focus traversal, free-window resize, and performance remain unverified.

### 2026-08-15 Batch 7: native History browser

- Replaced the generic History snapshot with `entry/src/main/ets/component/HermesHistoryPage.ets` and added
  `entry/src/main/ets/data/HermesHistorySupport.ets` for source labels/order, case-insensitive local filtering, grouping,
  and question/Markdown-heading outline extraction.
- Extended `HermesSession` and the HTTP mapper with source, Profile, message count, and archived metadata. Preview
  sessions now cover Web UI/API Server, CLI, Coding Agent, and Cron groups without claiming remote persistence.
- `Index.ets` now owns an independent process-stable History `HermesChatModel`. History reuses the existing
  `HermesRuntime` and Repository for session/message loading and upstream-compatible 150-message paging rather than
  duplicating HTTP logic or sharing Chat selection state.
- Phone implements History list -> read-only detail -> outline states with an explicit return action. Tablet implements
  a persistent 300vp History list plus message detail; extra-wide windows can expose a third 260vp outline pane.
  HDS `HdsListItemCard` owns History headers, source groups, sessions, and outline rows; ArkUI TextInput/Button/List own
  roles not provided by the installed HDS SDK.
- Search covers title, preview, model, Profile, and source label over the currently loaded sessions. Device testing
  caught and fixed three issues: mixed-case queries initially did not lower-case the full index; V2 TextInput required
  `$$` binding; and dependency reads had to be passed explicitly from the Builder into filter/group helpers. The final
  phone UI tree shows a `Provider` query reducing Web UI/API Server from two sessions to one and displaying only
  `Provider 配置检查` after keyboard dismissal.
- Device testing also caught and fixed phone message-bubble and title-row right overflow. Final phone detail keeps the
  list-bullet outline action and all long message text inside the viewport. The final outline UI tree contains one user
  question for the preview transcript; Markdown headings are covered by unit tests.
- Deliberately not implemented in this batch: session delete, batch delete, pin/unpin persistence, import to Web UI,
  unarchive, copy link/ID, source-group server paging, workspace badge, and exact Markdown heading anchor scrolling.
  No destructive control reports local success without a real Repository result.
- Final unit result: `Tests run: 9, Failure: 0, Error: 0, Pass: 9, Ignore: 0`. New focused tests cover source
  grouping/order, case-insensitive query/source filtering, and History outline extraction.
- Final `assembleHap` for `default / entry / debug` succeeded. The unsigned artifact is
  `entry/build/default/outputs/default/entry-default-unsigned.hap`, 815035 bytes, SHA-256
  `0B34F078B38E54AA147B8C19AC786725B179AA5AE7306B58DF2E59D9CB978CCE`.
- Installed the final HAP on API 24 phone `127.0.0.1:5555` and tablet `127.0.0.1:5557`. Verified phone source groups,
  case-insensitive search/filter, list/detail return, non-clipped messages, and outline; verified tablet persistent HDS
  sidebar plus History list/detail split. Both final processes remained alive and final recent logs contained no new
  TypeError, ReferenceError, JS fatal, or `Cannot read property` error.
- Final evidence includes:
  - `screenshots/batch7-history-phone-detail-fixed.jpeg`;
  - `screenshots/batch7-history-phone-search-real-final.jpeg`;
  - `screenshots/batch7-history-phone-outline.jpeg`;
  - `screenshots/batch7-history-tablet-latest.jpeg`;
  - their paired UI-tree JSON files under `screenshots/`.
- This batch is phone/tablet device-verified only. The declared `2in1` form, real hardware, real Hermes Studio service,
  dark mode, large font, screen reader, complete keyboard/mouse focus traversal, free-window resize, and performance
  remain unverified.

## 6. Architecture plan

Planned native source shape:

```text
entry/src/main/ets/
  common/        tokens, route names, errors, formatters
  model/         app/window/session and UI-facing models
  data/          repository interfaces and fake/remote data sources
  feature/
    auth/
    chat/
    history/
    automation/
    workspace/
    administration/
  component/     shell and reusable controls
  pages/         Index root only; feature destinations built below it
  util/          window/safe-area/lifecycle helpers
```

First interactive prototype order:

1. V2 app model, semantic design tokens, light/dark resources, window breakpoint model.
2. Responsive application shell and navigation inventory.
3. Login surface.
4. Chat session list, chat header, message list, composer, local send/streaming simulation.
5. Generic native feature-page templates for every first-level route so navigation coverage is visible and traceable.
6. Replace generic pages feature by feature using the coverage table.

## 7. Current blockers and risks

- The full upstream product is very large: 32 routes and 136 client components. A faithful port requires staged delivery.
- Many upstream features depend on Koa APIs, Socket.IO, SQLite, local files, PTY, Electron bridges, or desktop runtime.
- HarmonyOS HTTP authentication/session/history/chat-run contracts are implemented and device-tested against a
  temporary contract server, but remain unverified against a configured real Hermes Studio deployment.
- Socket.IO `/chat-run`, reconnect/resume, tools, approvals, clarification, cancellation, and streaming remain
  unimplemented.
- Workflow canvas, terminal, rich file previews, desktop browser, and desktop pet require explicit native product decisions.
- Phone and tablet emulators are device-verified for the surfaces listed above; 2in1, physical devices, dark mode,
  large font, rotation/free window, screen reader, keyboard focus order, and performance remain unverified.
- The project has no signing configuration. The current HAP is unsigned and is not release-signing evidence.
- Local unit tests now cover URL normalization, login/session/message mapping, pending-to-complete message state,
  historical paging deduplication, History grouping/filtering, and outline extraction; ohosTest remains a template and
  broader transport/UI behavior still depends on device verification.
- No real Hermes Server URL, user credentials, API token, HTTP response, Socket.IO stream, SQLite data, PTY, or file
  service has been configured or service-verified.

## 8. Exact next step

1. Configure and service-test against an actual Hermes Studio deployment without storing credentials or private URLs in
   source, screenshots, logs, or this memory file.
2. Add deterministic stale-selection, timeout, malformed-response, and cancellation tests with injectable transport.
3. Implement a proven Socket.IO/Engine.IO-compatible `/chat-run` client or a maintained compatible dependency; preserve
   event ordering, reconnect/resume, cancellation, approval, clarification, tools, usage, and title updates. Do not
   substitute plain WebSocket.
4. Add timeout/cancellation controls and repository tests with an injectable transport so 401, 403, malformed JSON,
   timeout, server failure, requires-action, and stale-response races are deterministic.
5. Replace generic Jobs, Kanban, Models, Skills, Files, and Settings shells feature by feature; then add the omitted real
   History mutation/pinning/import/group-paging contracts without regressing the read-only browser.
6. Verify dark mode, large font, rotation/free window, mouse/keyboard focus, screen reader, performance, and an actual
   2in1 device or emulator.
