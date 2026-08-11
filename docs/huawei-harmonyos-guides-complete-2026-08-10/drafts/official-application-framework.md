# HarmonyOS 官方指南“应用框架”全景工程手册

> 面向人类开发者、Codex、Claude 等编程 Agent。证据核对日期：2026-08-10。
>
> 本章覆盖官网左侧菜单 `开发 > 应用框架` 下全部 15 个直接子类，共 1,090 个正文页面、6,700,857 个正文字符、6,413 个代码块、956 张表、855 个提示/警告块、3,460 张图片。

## 0. 这份综合章能证明什么

[官方事实] 官网“应用框架”不是单一的 ArkTS 教程，而是由 Ability、无障碍、数据、语言、UI、Web、后台任务、内容嵌入、文件、数据增强、卡片、输入法、IPC、本地化和 UI Design Kit 共同组成的应用运行与交互体系。

[官方事实] 本章的目录与数量来自以下已审计材料：

- [逐页结构索引](../FULL_PAGE_DIGESTS.md)：按官网菜单顺序记录 1,090 个页面中的每一页；
- [完整菜单树](../coverage/menu-tree.md)：用于确认每一个分支、子菜单和页面 URL；
- [主题统计](../coverage/topic-statistics.csv)：用于核对每个直接子类的页面、正文、代码、表格、提示和图片数量；
- [标题索引](../coverage/heading-index.csv)：本分支共 6,981 个标题节点，常见结构包括“概述、开发步骤、场景、接口、约束、常见问题”；
- [提示/警告索引](../coverage/admonition-index.csv)：本分支共 855 个提示/警告块；
- `../coverage/crawl.sqlite3`：保存菜单节点、页面元数据、摘要以及压缩后的结构化抽取和原始 HTML。

[解释] 本章是全分支的工程化综合，不是把约 670 万字官网正文复制一遍，也不把抽样阅读冒充逐页重写。需要核查某一个 API、版本、设备、权限、SystemCapability、错误码或完整示例时，应先在本章定位主题，再到 [逐页结构索引](../FULL_PAGE_DIGESTS.md) 搜索标题或 slug，最后回到对应官方页面和 API 参考。

[项目适配] 当前默认项目为 `KangxiaobanAI`，其 target SDK 为 API 24、compatible SDK 为 API 23，采用 Stage 模型、ArkUI V2 和 UI Design Kit/HDS，设备类型为 `phone`、`tablet`、`2in1`。新增 API 24 能力必须明确 API 23 的降级或版本策略；API 26 能力只能作为未来规划。

### 0.1 证据标签

- `[官方事实]`：由本次抓取的华为官方指南页面、菜单或警告块直接支持。
- `[解释]`：为帮助理解而做的工程归纳，不等同于官方原句。
- `[项目适配]`：结合当前 `KangxiaobanAI` 的源码、配置和既定架构边界给出的落地建议。

## 1. 全量覆盖表

| 直接子类 | 页面 | 正文字符 | 代码块 | 表格 | 提示/警告 | 图片 |
|---|---:|---:|---:|---:|---:|---:|
| Ability Kit（程序框架服务） | 91 | 413,824 | 332 | 265 | 77 | 161 |
| Accessibility Kit（无障碍服务） | 29 | 36,342 | 27 | 10 | 2 | 12 |
| ArkData（方舟数据管理） | 51 | 362,491 | 327 | 58 | 34 | 51 |
| ArkTS（方舟编程语言） | 122 | 521,842 | 842 | 126 | 89 | 163 |
| ArkUI（方舟UI框架） | 485 | 4,037,694 | 3,755 | 354 | 519 | 2,525 |
| ArkWeb（方舟Web） | 76 | 555,117 | 495 | 36 | 44 | 165 |
| Background Tasks Kit（后台任务开发服务） | 9 | 38,020 | 31 | 10 | 6 | 13 |
| Content Embed Kit（内容嵌入服务） | 7 | 32,727 | 24 | 2 | 0 | 3 |
| Core File Kit（文件基础服务） | 51 | 148,891 | 176 | 34 | 33 | 92 |
| Data Augmentation Kit（数据增强服务） | 17 | 128,631 | 49 | 14 | 3 | 7 |
| Form Kit（卡片开发服务） | 51 | 231,541 | 181 | 28 | 28 | 164 |
| IME Kit（输入法开发服务） | 12 | 54,829 | 49 | 1 | 7 | 18 |
| IPC Kit（进程间通信服务） | 6 | 30,609 | 14 | 3 | 8 | 9 |
| Localization Kit（本地化开发服务） | 37 | 27,763 | 34 | 8 | 4 | 12 |
| UI Design Kit（UI设计套件） | 46 | 80,536 | 77 | 7 | 1 | 65 |

[解释] 页面数量不是技术重要性的排序。ArkUI 体量最大，但 Ability 决定进程与生命周期，ArkTS 决定执行与并发，ArkData/Core File 决定数据真实落盘，Accessibility/Localization 决定是否真正可用，后台任务/IPC/Extension 则决定应用离开前台或跨进程后还能否正确工作。

## 2. 应用框架的统一心智模型

```text
app.json5 / module.json5 / HAP-HAR-HSP
        ↓
AbilityStage / UIAbility / ExtensionAbility / Context / Want
        ↓
ArkTS 主线程、Promise、TaskPool、Worker、Sendable
        ↓
ArkUI 状态 → 渲染 → Navigation/NavPathStack → Window/Display
        ↓
ArkData / Core File / Web / Form / IME / IPC / 后台任务
        ↓
Accessibility / Localization / UI Design Kit
        ↓
日志、错误码、权限、性能工具、设备与版本验证
```

[解释] 一项功能从“界面看起来能点”走向“工程上成立”，至少要回答十个问题：

1. 它属于哪个 HAP/HAR/HSP 和哪个 Ability/Extension？
2. 谁创建、持有和销毁它？
3. 状态是 UI 临时状态、应用全局状态、持久化业务数据，还是跨设备数据？
4. 耗时操作运行在哪个线程，如何取消和回传？
5. 页面由哪个 Navigation/NavPathStack 管理，跨应用时使用哪种链接或 Want？
6. 是否需要权限、SystemCapability、企业权益或用户授权？
7. 应用退后台、进程被回收、窗口变化或设备离线后会怎样？
8. 数据、文件、Web 桥或 IPC 载荷的边界和安全策略是什么？
9. 异常如何被用户感知、被日志定位、被业务恢复？
10. 哪些结论只在模拟器成立，哪些必须在对应真机和系统版本验证？

[官方事实] `Network Kit` 的完整开发指导位于官网 `开发 > 系统 > 网络`，不属于本章的“应用框架”分支。本章只覆盖 ArkWeb、RAG、后台任务等对网络的使用边界；需要 HTTP、WebSocket、TLS、网络状态与代理等接口时，必须继续查阅网络分支，不能把 ArkWeb 当作通用网络层。

## 3. Ability Kit：应用模型、组件、生命周期与跨应用调度

[官方事实] 本子类共 91 页。直接子菜单全部为：`Ability Kit简介`、`应用模型`、`应用生命周期`、`应用间跳转`、`方舟智能开发框架开发指导`、`基于ModularObjectExtensionAbility的模块化对象开发指导 (C/C++)`、`Native子进程开发指导`、`Ability Kit术语`。

### 3.1 能力边界与关键概念

[官方事实] Ability Kit 提供应用开发和运行所需的应用模型，负责应用组件、生命周期、进程线程、上下文、组件间交互和跨应用调度。应用可以用 HAP 承载功能，用 HAR/HSP 共享代码与资源。当前主推并长期演进的是 API 9 起支持的 Stage 模型；FA 模型已不再主推。

[官方事实] Stage 模型的核心对象包括：

- `AbilityStage`：HAP/Module 级管理器，每个 HAP 在首次加载时创建一个实例；
- `UIAbility`：系统调度的带界面组件，为应用提供主窗口；
- `ExtensionAbility` 派生类型：面向卡片、输入法、延迟任务、嵌入式 UI 等特定系统场景；
- `WindowStage`：与 UIAbility 实例绑定的窗口舞台；
- `Context` 家族：`ApplicationContext`、`AbilityStageContext`、`UIAbilityContext`、`ExtensionContext` 等，各自能力不同，不能靠类型强转互相替代；
- `Want`：组件间信息载体，分为显式 Want 与隐式 Want；
- `app.json5` 与 `module.json5`：分别承载应用级与模块/组件级配置、设备类型、权限、入口和导出状态等信息。

[解释] `UIAbility` 不是普通页面。页面通常应由一个 UIAbility 内的 `Navigation/NavDestination` 管理；只有当业务确实需要独立最近任务、独立窗口、不同进程/生命周期或系统扩展入口时，才考虑增加 UIAbility 或 ExtensionAbility。

### 3.2 常见流程

#### 启动和窗口

[官方事实] UIAbility 首次启动到前台时通常依次触发 `onCreate()`、`onWindowStageCreate()`、`onForeground()`；进入后台触发 `onBackground()`；复用已有单实例时通常进入 `onNewWant()` 而不是重新执行 `onCreate()`。生命周期回调运行在主线程，应只做必要的轻量操作，耗时任务应异步或转交子线程。

[官方事实] UIAbility 必须在 `onWindowStageCreate()` 中通过 `WindowStage.loadContent()` 或等价方式加载初始页面，否则可能白屏。主窗口销毁时对应 `onWindowStageDestroy()`；注册窗口、配置、内存或应用生命周期监听后，应在对称时机取消。

#### 启动模式和任务

[官方事实] UIAbility 支持 `singleton`、`multiton` 和 `specified` 启动模式。单实例复用时会接收新 Want；多实例会创建多个任务；指定实例由 `AbilityStage.onAcceptWant()` 决定复用哪个实例。

[解释] 启动模式是任务和实例策略，不应拿来代替应用内页面栈。详情页、设置页、对话页通常属于 `NavDestination`，不是新的 UIAbility。

#### 应用内和应用间跳转

[官方事实] 应用内启动其他 UIAbility 可通过 `startAbility()` 和显式 Want。应用间跳转从 API 12 起不再推荐三方应用用显式 Want 指定对方 Ability，推荐使用应用链接/App Linking 等方式；隐式 Want 依赖 `skills` 中的 action、entities、URI 和 type 匹配。

[官方事实] 跨应用启动需校验目标组件 `exported`、前后台状态和相关权限。后台任意弹框、后台相互唤醒和前台任意跳转均受系统限制。URL、scheme、host、path 与应用实际配置必须核对，不能凭示例硬编码。

#### 启动任务与恢复

[官方事实] AppStartup 可把启动任务的顺序、依赖和自动/手动执行统一配置，并支持异步启动；启动任务或 so 预加载任务不允许循环依赖。UIAbility 备份恢复用于系统资源回收或异常退出后的临时状态恢复，不等同于业务数据库；其 Want 序列化数据上限为 200KB，备份保存 7 天，并受任务保留机制约束。

#### Extension、智能体和 Native

[官方事实] ExtensionAbility 只能使用系统已定义的具体派生类型。ArkAF 包含意图、Skill 和端侧 A2A 三种能力开放机制；端侧 A2A 从 API 24 起提供标准化 Agent 协作。ModularObjectExtensionAbility 与 Native 子进程属于 C/C++、跨进程能力开放和隔离执行场景，均不是普通页面模块化的首选工具。

### 3.3 工程维度检查

| 维度 | Ability Kit 工程结论 |
|---|---|
| 生命周期 | 初始化、监听注册、窗口创建、前后台切换、销毁必须成对设计；异常退出不能假设会执行完整清理。 |
| 并发 | 生命周期在主线程；启动重任务使用 AppStartup 异步任务、TaskPool/Worker 或业务异步层，不能堵塞首帧。 |
| 状态 | Want 适合启动参数；EventHub/ArkUI 状态适合实例内同步；长期业务状态必须交给持久层。 |
| 路由 | 应用内优先 Navigation；UIAbility 之间使用 Want；跨应用优先官方应用链接机制。 |
| 数据 | Context 只提供运行环境与目录入口，不是数据仓库；备份恢复也不是数据库。 |
| 权限 | 检查 `exported`、`requestPermissions`、后台启动规则、设备能力和企业/系统权限边界。 |
| 性能 | 控制 UIAbility 数量、启动任务依赖和首帧工作；收到内存等级回调时释放可重建资源。 |
| 错误处理 | `startAbility`、连接 Extension、加载页面等均捕获 `BusinessError`；处理连接失败、断连、目标不存在、版本不匹配。 |

### 3.4 给编程 AI 的检查单

- [ ] 先读取 `app.json5`、`module.json5`、模块 `build-profile.json5` 和 pages/router map，再决定组件类型。
- [ ] 新增页面前先判断是否只是 `NavDestination`，不要无理由新建 UIAbility。
- [ ] `loadContent()`、窗口监听、公共事件、生命周期监听都有明确所有者和清理路径。
- [ ] 生命周期回调只做轻量工作；启动任务无循环依赖，失败有降级策略。
- [ ] 应用内跳转、跨模块跳转、跨应用跳转三者不混用。
- [ ] 不把 Want 参数、AppStorage 或 UIAbility 备份恢复当作真实业务持久化。
- [ ] 跨应用前验证目标 URL/能力、安装状态、`exported` 和权限；不复制旧示例中的 bundleName。
- [ ] Extension/子进程/ArkAF 只在明确业务与设备范围内引入，并补充服务发现、超时、取消、断连与安全设计。

### 3.5 当前项目适配

[项目适配] `KangxiaobanAI` 当前只有一个 entry HAP 和一个 `KanxiaobanAbility`。启动链是 `EntryAbility.onWindowStageCreate()` → `loadContent('pages/LoginPage')` → 登录后 `router.replaceUrl('pages/MainPage')` → 根 `HdsNavigation/NavPathStack`。传统 Router 仅保留在认证壳的登录/退出边界；应用内业务流继续使用共享 `NavPathStack`。

[项目适配] 当前没有增加第二个 UIAbility、ExtensionAbility、HSP/HAR 或独立进程的必要证据。医生入院、管理员工作台、AI 对话、居民详情等都仍是本地页面/工作区状态。若以后新增通知入口、服务卡片、输入法、后台调度或智能体，必须把对应 Extension、配置、权限和生命周期作为独立功能边界设计。

[项目适配] `WindowUtil` 已注册窗口监听但 Ability 尚未对称注销。任何新增窗口/配置/显示监听前，应先补齐现有 owner 的 teardown，避免重复监听和销毁后回调。

### 3.6 代表性官方页面

- [Ability Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/abilitykit-overview)
- [Stage模型概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/stage-model-development-overview)
- [UIAbility生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-lifecycle)
- [应用上下文Context](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-context-stage)
- [Want概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/want-overview)
- [应用启动框架AppStartup](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-startup)
- [应用间跳转概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/link-between-apps-overview)
- [端侧A2A框架概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-overview)

## 4. Accessibility Kit：无障碍、屏幕朗读与关怀模式

[官方事实] 本子类共 29 页。直接子菜单全部为：`Accessibility Kit 简介`、`提升应用的无障碍体验`、`测试应用的无障碍功能`、`应用长辈关怀功能体验`。屏幕朗读子树逐项覆盖按钮标注、朗读内容、媒体播报、焦点位置、组合语义、多语言、禁用装饰焦点、状态变化、位置变化、动态内容、弹窗、错误、状态说明、滚动步数、自定义走焦和页面变化通知。

### 4.1 能力边界与关键概念

[官方事实] Accessibility Kit 提供无障碍状态查询、焦点与主动播报等能力；ArkUI 提供组件级无障碍文本、描述、分组、重要性、走焦和操作属性。系统还提供屏幕朗读、大字体、高对比度、颜色校正、单声道音频等辅助能力。

[解释] 无障碍不是“给图片加一句 accessibilityText”就结束。它同时涉及语义是否完整、焦点数量和顺序是否合理、动态变化是否播报、错误是否只靠颜色、弹窗是否困住焦点、放大字体后布局是否仍可操作。

### 4.2 常见流程与规则

[官方事实] 非文本按钮必须提供可理解的标注，但不要把“按钮”“双击打开”等控件类型和操作提示硬编码到标注中，屏幕朗读会根据组件语义补充。无障碍文本优先于显示文本；文本控件应尽量让可见文本与朗读信息一致。

[官方事实] 同一个业务对象由多个小控件组成时，应通过 `accessibilityGroup(true)` 等方式合并语义，只暴露一个自然焦点；装饰图标、分隔符和无意义占位应设为不可聚焦。多维嵌套信息要避免多个焦点重复朗读同一内容。

[官方事实] 当前焦点节点隐藏或销毁后，应把焦点移到合理的新节点；自定义堆叠页面系统无法自动识别时，应主动通知页面变化。模态弹窗应限制焦点在弹窗内；非模态提示不能阻断当前流程。

[官方事实] 重要动态内容、控件状态、拖拽位置、网络中断或其他错误应及时播报，且错误不能只用红色表示。多语言朗读文本应进入资源系统，不应直接拼接导致 RTL 或语序错误。

[官方事实] 从 API 26 起，系统增加应用关怀模式声明、应用内关怀模式与系统设置同步，以及系统关怀模式查询/监听接口。注册状态监听应在对应消失/销毁阶段取消。

### 4.3 工程维度检查

| 维度 | Accessibility 工程结论 |
|---|---|
| 生命周期 | 页面出现时注册必要状态监听，消失时取消；页面切换和弹窗关闭后恢复合理焦点。 |
| 并发 | 主动播报和状态更新回到正确 UIContext；避免后台线程直接修改 UI 无障碍状态。 |
| 状态 | 标注、选中/展开/禁用状态和业务状态同步变化，不能出现视觉已更新但朗读仍是旧值。 |
| 路由 | Navigation、内容覆盖、Sheet 和自定义 Stack 切页后都要验证首焦点与返回路径。 |
| 数据 | 姓名、健康风险、房间号等敏感信息只播报完成任务所需内容，避免在公共环境过度泄露。 |
| 权限 | 一般组件标注不需敏感权限；关怀模式和系统能力仍需核对 API/设备/SystemCapability。 |
| 性能 | 过多、过细焦点会增加操作步骤和走焦负担；组合语义可同时改善效率。 |
| 错误处理 | 错误必须有文本、播报和恢复动作；不可只改颜色或短暂显示一个无法聚焦的提示。 |

### 4.4 给编程 AI 的检查单

- [ ] 所有图标按钮、头像入口、横滑操作和自绘控件都有业务语义。
- [ ] 同一业务卡片不会被拆成大量重复焦点；装饰节点不会进入焦点链。
- [ ] 焦点顺序遵循视觉与任务顺序，列表、弹窗、返回和动态删除后无焦点丢失。
- [ ] 加载、成功、失败、警告和状态切换对屏幕朗读用户可感知。
- [ ] 字体放大、高对比度、深浅色、键盘和横竖屏下仍能完成主要流程。
- [ ] 文本与标注进入资源文件，多语言不靠字符串拼接。
- [ ] 至少在真机开启屏幕朗读，用触摸浏览和线性浏览完成一次端到端主流程。

### 4.5 当前项目适配

[项目适配] `KangxiaobanAI` 是智慧养老工作台，无障碍与适老化属于核心质量属性，不是发布前补丁。居民卡、风险状态、任务按钮、AI 覆盖层、消息未读徽标、头像菜单、Sheet 和宽屏主从视图都应验证语义、焦点与大字体。

[项目适配] 当前目标 API 24，不能直接使用 API 26 的系统关怀模式接口。可以先完善应用自身的大字体、对比度、触控尺寸、文本资源和焦点逻辑；若将来升级 SDK，再按 `canIUse`/版本判断接入系统关怀模式同步。

### 4.6 代表性官方页面

- [Accessibility Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/accessibilitykit-overview)
- [按钮标注](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scenario-button-annotation)
- [多UI控件组合](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scenario-multicomponent)
- [内容动态变化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scenario-dynamic-content-change)
- [弹窗类控件走焦](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pop-up-controls-focus)
- [测试屏幕朗读功能](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/test-screen-reader)
- [获取关怀模式状态](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/eldercare-description)

## 5. ArkData：持久化、同步、共享、可靠性与向量数据

[官方事实] 本子类共 51 页。直接子菜单全部为：`ArkData简介`、`标准化数据定义`、`应用数据持久化`、`同应用跨设备数据同步（分布式）`、`同应用端云数据同步（分布式）`、`数据可靠性与安全性`、`跨应用数据共享`、`应用数据向量化 (ArkTS)`、`arkdata数据库调试工具`、`SQLite调试工具指导`、`ArkData术语`、`ArkData常见问题`。

### 5.1 能力边界与选型

[官方事实] ArkData 提供标准化数据定义、Preferences、KV-Store、关系型数据库、向量数据库、跨设备/端云同步、备份恢复、加密、数据分级访问控制和跨应用共享。

| 数据形态 | 适用场景 | 不适合 |
|---|---|---|
| Preferences | 字体大小、主题、开关、少量偏好 | 大量业务记录、复杂查询、机密明文 |
| KV-Store | 关系简单的键值业务、跨版本/跨设备兼容 | 复杂关联、事务型查询 |
| RelationalStore | 有模式、关系、事务、索引、复杂查询的数据 | 把大文件或超大二进制直接塞进单行 |
| Vector Store | 向量相似检索、推荐、语义搜索 | 没有嵌入模型和评估方案的普通 CRUD |
| 分布式数据对象 | 生命周期短的跨设备状态 | 长期可靠业务账本 |
| UDMF/数据通路 | 标准化跨应用过程数据 | 永久数据仓库或绕过权限共享敏感数据 |

[官方事实] Preferences 的 XML 模式适合单进程小数据并在需要时 `flush`；API 18 起的 GSKV 模式支持多进程并发写并实时落盘。Preferences 不提供内建加密，敏感数据需在写入前加密或选用更合适的存储。

[官方事实] 关系型数据库底层基于 SQLite，默认 WAL 日志和 FULL 落盘策略，通常有 4 个读连接和 1 个写连接，同一时间仅一个写操作。官方建议单条数据不要超过 2MB；大数据查询和批量写入必须关注卡顿、事务和连接释放。

[官方事实] 向量数据库从 API 18 起支持，仍需判断设备是否支持。应用数据向量化从 API 15 起支持，但当前官方指南说明计算量较大且仅支持 2in1，单次文本上限 512 字符、图像小于 20MB，推荐 NPU 加速。

### 5.2 常见流程

#### 本地持久化

1. [解释] 先定义业务模型与持久化模型，不让 UI 组件直接拼 SQL 或解析传输 DTO。
2. [官方事实] 使用正确 Context 打开对应沙箱中的存储实例。
3. [解释] 设计 schema/version/migration、唯一键、索引、事务和失败回滚。
4. [官方事实] 查询结果集、数据库、订阅和观察者用完后及时关闭/取消。
5. [解释] 为重建、备份、恢复、加密参数变更和异常退出准备可验证路径。

#### 跨设备同步

[官方事实] 同应用跨设备同步面向可信组网设备，只保证最终一致性。KV 可用单版本或多设备协同模式，关系型数据库使用分布式表，分布式数据对象适合临时状态。同步需要考虑冲突、设备离线、数据安全等级、变化通知和重试，不应假设写入后所有设备立即一致。

#### 端云同步与跨应用共享

[官方事实] 端云同步需要云侧表结构和端侧 schema 共同配置。跨应用共享按一对多与多对多区分；部分 DataShare 能力仅系统应用开放。UDMF 标准化数据通路适合过程数据，并由系统管理生命周期；公共数据通路中的数据会定期清理，不能当永久存储。

#### 安全和恢复

[官方事实] 数据库可配置加密，关系型数据库 API 22 起可 `rekeyEx` 调整加密参数。分布式数据按 S1-S4 数据标签和 SL1-SL5 设备等级控制同步。E 类加密数据库位于 EL5，需要相应权限，并在锁屏密钥不可用时设计 C/E 类库切换与数据迁移。

### 5.3 工程维度检查

| 维度 | ArkData 工程结论 |
|---|---|
| 生命周期 | 数据库连接、结果集、订阅者有清晰 owner；页面销毁不应误关共享仓库，应用退出前不依赖最后一刻同步。 |
| 并发 | 写入串行化、事务边界明确；回调中不阻塞 UI；不要在多个线程并发删除/重建同一 Preferences 或数据库。 |
| 状态 | UI 状态、缓存状态、持久化状态、同步状态分别建模，禁止用一个 boolean 假装全部成功。 |
| 路由 | 页面参数只传 ID/查询条件，详情页从仓库读取；不要在路由参数传完整大对象充当数据库。 |
| 数据 | DTO、domain、entity/schema 分层；空值、单位、时区、枚举和版本迁移显式处理。 |
| 权限 | 跨设备、端云、E 类数据库、跨应用共享分别核对权限、账号、设备和系统能力。 |
| 性能 | 索引、分页、批量事务、异步接口、查询列裁剪；向量化和大查询放到合适线程并做设备判断。 |
| 错误处理 | 捕获 `BusinessError`/数据库异常；监听 `sqliteErrorOccurred`；准备重建、备份恢复、密钥回退与同步冲突策略。 |

### 5.4 给编程 AI 的检查单

- [ ] 先写数据分类和选型理由，再选择 Preferences/KV/RDB/Vector/文件。
- [ ] 不把 AppStorageV2、内存数组、定时器回调或 UI 卡片状态描述成持久化。
- [ ] RDB 有 schema 版本、迁移、事务、索引、关闭 ResultSet 和异常重建策略。
- [ ] 所有同步状态至少区分 `idle/loading/success/empty/error/offline/conflict`。
- [ ] 敏感健康/身份数据有安全等级、加密、最小访问和日志脱敏设计。
- [ ] 跨设备功能在真实双设备、账号、组网、离线和冲突场景验证。
- [ ] 向量/RAG 先验证设备支持、模型、数据质量、检索指标和资源预算，不能只证明接口能调用。
- [ ] 删除数据库、Preferences 或密钥前明确不可恢复性，并有备份或迁移验证。

### 5.5 当前项目适配

[项目适配] 当前 `KangxiaobanAI` 只有 `MineDetailPage` 的少量 Preferences 开关；居民、健康、任务、消息、医生、管理员和 AI 数据均是组件内 mock/本地状态，没有 RDB、远端仓库、端云同步或分布式数据库。

[项目适配] 下一步不是直接在超大页面里调用 RDB，而是先保持 UI 行为，用 per-feature `FakeRepository` 抽离数据构造，再引入 ViewModel/store、UseCase、repository interface，最后接真实本地/远端数据源。健康数据与机构数据必须在 UI 模型之外定义独立 DTO/domain/schema 和授权边界。

[项目适配] `AppStorageV2` 当前适合窗口、断点、角色等应用环境状态；不要把居民列表、任务记录、表单草稿放入全局环境模型。医生入院草稿若要持久化，应设计专属 repository、草稿版本、恢复策略和知情确认记录，而不是使用一个全局对象静默保存。

### 5.6 代表性官方页面

- [ArkData简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-mgmt-overview)
- [应用数据持久化概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-data-persistence-overview)
- [Preferences持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences)
- [关系型数据库持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store)
- [跨设备数据同步概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/sync-app-data-across-devices-overview)
- [数据库加密](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-encryption)
- [跨应用数据共享概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-share-overview)
- [应用数据向量化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/aip-data-intelligence-embedding)

## 6. ArkTS：语言、异步、多线程、运行时与编译工具链

[官方事实] 本子类共 122 页。直接子菜单全部为：`ArkTS简介`、`ArkTS基础类库`、`ArkTS并发`、`ArkTS跨语言交互`、`ArkTS运行时`、`ArkTS编译工具链`、`ArkTS术语`。基础类库继续覆盖 XML、Buffer/FastBuffer、JSON 扩展和线性/非线性容器；并发继续覆盖 Promise、TaskPool、Worker、线程间通信对象和多线程实践；运行时继续覆盖 GC、模块化等内容；工具链继续覆盖方舟字节码与 ArkGuard 源码/字节码混淆。

### 6.1 能力边界与关键概念

[官方事实] ArkTS 是 HarmonyOS 应用开发的官方高级语言，在 TypeScript 生态基础上强化静态检查、可分析性、稳定性和性能，同时支持 TS/JS 互操作。编译工具链把高级语言编译成方舟字节码 `*.abc`，ArkTS Runtime 在设备侧解释/AOT/JIT 执行并负责内存、模块、分析工具、标准库和 Node-API 互操作。

[解释] “看起来像 TypeScript”不代表可以原样照搬任意前端写法。编程 AI 必须遵守当前 ArkTS 编译规则、可序列化/Sendable 约束、装饰器代际和 API 版本，不能用 `any`、动态对象技巧或浏览器全局对象绕过类型系统。

### 6.2 异步和多线程怎么选

| 场景 | 推荐能力 | 原因与边界 |
|---|---|---|
| 单次网络/文件/数据库异步等待 | `Promise`、`async/await` | 不阻塞当前执行流；仍然只有一段 JS/ArkTS 代码在同一线程执行。 |
| 可拆分的 CPU 密集或批处理任务 | `TaskPool` | 系统管理线程池、优先级、任务组、取消和扩缩容。 |
| 需要长期线程上下文、连续消息或常驻任务 | `Worker` | 独立运行环境和消息队列，但线程生命周期与资源由开发者管理。 |
| 大段二进制传输 | `ArrayBuffer` 转移或 `SharedArrayBuffer` | 避免普通对象深拷贝；共享内存需自行保证同步正确。 |
| 跨线程共享 ArkTS 对象 | `@Sendable`/Sendable 对象 | 遵守 Sendable 类型与可变性约束，减少序列化成本。 |
| Native 与 ArkTS 交互 | Node-API/Taihe 等对应机制 | 必须处理线程、引用、生命周期和异常边界。 |

[官方事实] ArkTS 并发采用 Actor 内存隔离模型。普通对象跨线程使用 Structured Clone 深拷贝；单次序列化数据量限制为 16MB。状态管理中的 `@State`、`@Prop`、`@Link` 等复杂对象不支持直接作为线程通信对象。

[官方事实] TaskPool 会自动扩缩工作线程；普通任务函数需用 `@Concurrent`，跨实例传递带方法对象时通常需 `@Sendable`。TaskPool 普通任务的同步 CPU 执行时长不能超过 3 分钟，异步 I/O 等待不计入该 CPU 时长。Worker 每个实例有独立执行环境和内存开销，Worker 文件还要正确进入构建配置。

[解释] `async` 不等于“自动跑到后台线程”。把大循环包在 `async function` 中仍可能阻塞 UI。反过来，简单 I/O 没必要为了“并发”创建 Worker，额外序列化和线程管理可能更慢。

### 6.3 线程通信与取消

[官方事实] TaskPool 和 Worker 均支持普通对象拷贝、ArrayBuffer 转移、SharedArrayBuffer 共享、Transferable 所有权转移和 Sendable 引用传递等方式。对象越大，Structured Clone 成本越高。

[解释] 一条健壮的并发链应包含：输入快照 → 任务标识 → 执行/进度 → 可取消点 → 成功结果或结构化错误 → 回到正确 UIContext 提交状态 → 组件销毁后丢弃过期结果。只写 `execute().then(...)` 而没有取消和过期结果判断，容易产生页面退出后仍更新状态、重复请求覆盖新结果等问题。

### 6.4 运行时、内存与模块

[官方事实] ArkTS Runtime 包含解释器、AOT/JIT、GC、字节码文件与模块管理、CPU/Heap profiling、标准库和 Node-API。垃圾回收不意味着监听、定时器、闭包、Native 引用和大型缓存会自动按业务时机释放。

[解释] 内存优化首先是所有权优化：缩短大对象生命周期、取消监听、关闭资源、避免全局缓存无限增长、避免把完整页面数据复制到多个观察对象。只有观察到真实瓶颈后，再使用 profiler、heap snapshot 和调用栈定位。

[官方事实] ArkGuard 提供源码和字节码混淆；混淆配置、保留规则和不同包类型策略必须与反射、序列化、动态加载、路由 Builder 名称和 Native 导出保持一致。混淆不是权限控制，也不是敏感信息加密。

### 6.5 工程维度检查

| 维度 | ArkTS 工程结论 |
|---|---|
| 生命周期 | Promise、Worker、TaskPool、Timer、订阅和 Native 引用都要绑定组件/Ability owner，退出时取消或忽略过期结果。 |
| 并发 | 先区分异步 I/O 与并行计算；跨线程对象遵守 16MB、序列化、Sendable 和所有权约束。 |
| 状态 | ArkUI 状态只能在 UI 主线程使用；后台线程返回不可变结果，再由主线程提交。 |
| 路由 | 并发任务不直接持有页面栈；通过 ViewModel/use case 返回结果，由界面决定是否导航。 |
| 数据 | 不在 Worker 中共享可变 UI 模型；为 DTO、二进制缓冲区和任务结果定义稳定类型。 |
| 权限 | 语言能力本身不替代 Kit 权限；Node-API/文件/网络/设备能力仍按各 Kit 申请和判断。 |
| 性能 | 先测主线程耗时、序列化量、任务粒度和 Worker 数量；避免过细任务及无上限并发。 |
| 错误处理 | Promise 链必须捕获；跨线程错误要序列化为可诊断结构；Worker/TaskPool 失败、取消和超时分开处理。 |

### 6.6 给编程 AI 的检查单

- [ ] 代码符合当前 ArkTS/SDK 语法，不照搬未经验证的 TypeScript/Node.js 片段。
- [ ] `async/await` 只用于异步等待，CPU 重任务明确评估 TaskPool/Worker。
- [ ] TaskPool 函数、入参与返回值满足 `@Concurrent`、序列化和 Sendable 约束。
- [ ] Worker 路径和构建配置正确，创建数量有上限，退出时 `terminate`/清理监听。
- [ ] 并发任务有 taskId、取消、超时、错误和过期结果保护。
- [ ] 不在后台线程直接操作 ArkUI 状态、Navigation、Window 或 UIContext。
- [ ] 大对象传输优先减少数据、转移 ArrayBuffer 或使用合适共享机制，而非反复深拷贝。
- [ ] 混淆开启后验证路由、序列化、Native 导出、动态属性和崩溃符号化。

### 6.7 当前项目适配

[项目适配] 当前核心源码采用 ArkUI V2。新组件继续使用 `@ComponentV2`、`@Local`、`@Param`、`@Require`、`@Event`、`@Provider/@Consumer`、`@ObservedV2/@Trace`。不要把附近旧样例的 V1 装饰器复制进核心产品。

[项目适配] 当前 AI 回复、登录和部分交互只是短定时器模拟，不代表真实并发层。未来接入网络、RDB、知识检索或批量健康数据处理时，应在 repository/use case 层决定 Promise/TaskPool/Worker，而不是在大页面文件中直接开线程。

[项目适配] `GlobalInfoModel` 中未标记 `@Trace` 的字段不能假设会单独触发刷新。编程 AI 遇到“值变了但 UI 没更新”时，应先检查观察边界，而不是用重复赋值、定时器或全局刷新规避状态模型。

### 6.8 代表性官方页面

- [ArkTS简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-overview)
- [并发概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/concurrency-overview)
- [异步并发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/async-concurrency-overview)
- [TaskPool简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/taskpool-introduction)
- [Worker简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/worker-introduction)
- [TaskPool和Worker的对比](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/taskpool-vs-worker)
- [线程间通信对象概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/serializable-overview)
- [ArkTS运行时概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-runtime-overview)

## 7. ArkUI：声明式 UI、V2 状态、Navigation、布局、窗口与性能

[官方事实] 本子类共 485 页，是“应用框架”中体量最大的直接子类。直接子菜单全部为：`ArkUI简介`、`UI开发 (ArkTS声明式开发范式)`、`UI开发 (基于NDK构建UI)`、`UI开发 (兼容JS的类Web开发范式)`、`UI开发调试调优`、`窗口管理`、`屏幕管理`、`ArkUI术语`。

[官方事实] ArkTS 声明式范式继续逐项覆盖基本语法、组件生命周期、状态管理 V1/V2、渲染控制、响应式环境、Navigation/Router、布局、列表网格、文本、媒体、表单选择、弹窗、绘制、交互、动画、自定义节点/Modifier、国际化、无障碍、主题和 UIContext 等系统场景能力。NDK 与类 Web 范式是独立开发路径，不能和当前 ArkTS V2 代码无差别拼接。

### 7.1 核心原则：UI 是状态的函数

[官方事实] ArkUI 声明式模型中，状态变化驱动 UI 重新渲染。未被状态管理框架观察的普通变量变化不会自动刷新界面。状态管理功能只支持在 UI 主线程使用，不能直接在 Worker/TaskPool 中使用。

[官方事实] 对新应用，官方建议使用状态管理 V2。V2 让数据本身可观察，支持深度观察和更明确的组件输入/输出，核心能力包括：

- `@Local`：组件内部拥有状态；
- `@Param` 与 `@Once`：外部输入及仅初始化同步；
- `@Event`：组件输出事件；
- `@Provider/@Consumer`：跨层级依赖；
- `@ObservedV2/@Trace`：类与字段观察；
- `@Monitor/@SyncMonitor`、`@Computed`：响应与派生值；
- `AppStorageV2`：主线程内跨 UIAbility 的应用级 UI 状态；
- `PersistenceV2`：UI 状态持久化。

[解释] `AppStorageV2` 和 `PersistenceV2` 仍属于 UI 状态工具，不自动拥有业务事务、schema 迁移、数据授权和领域一致性。真实订单、健康记录、任务历史应由 ArkData/repository 管理，ViewModel 再把适合渲染的状态交给 ArkUI。

### 7.2 组件生命周期与资源所有权

[官方事实] 传统 `aboutToAppear/aboutToDisappear` 之外，API 23 起提供受状态机约束的新生命周期装饰器，包括 `@ComponentInit`、`@ComponentAppear`、`@ComponentBuilt`、`@ComponentDisappear`、`@ComponentReuse`、`@ComponentRecycle`、`@ComponentActive` 等。`@ComponentDisappear` 中不建议修改状态变量，尤其避免修改可能导致不稳定的双向状态。

[解释] 生命周期函数不是“任何业务都放这里”的入口。初始化可重复执行吗、列表复用时是否重复注册、隐藏但未销毁时是否继续订阅、返回页面时是否恢复滚动位置，都应按组件实例、激活、复用和真正销毁的差异设计。

### 7.3 Navigation 与 Router

[官方事实] 官方推荐 `Navigation` 实现应用内页面和组件内跳转。核心对象是：

- `Navigation`：导航根容器，可提供标题栏、内容、工具栏与单双栏；
- `NavDestination`：子页面容器；
- `NavPathStack`：与一个 Navigation 一一对应的页面栈控制器；
- 路由表：页面名到 Builder/NavDestination 的映射，可使用系统路由表或自定义路由表。

[官方事实] `NavPathStack` 支持 push、replace、pop、remove、clear、参数、路由拦截和栈查询。每个 Navigation 有独立路由栈，`NavPathStack` 不可在多个 Navigation 间复用。API 12 起系统路由表支持跨 HAP/HSP/HAR 动态路由；API 23 起支持按需加载 HSP 页面，`router_map.json`、`module.json5.routerMap`、Builder 名称和参数类型必须一致。

[官方事实] `@ohos.router` 已标为不推荐，页面栈上限 32；它仍适合历史工程或认证壳等明确边界，但新业务应优先 Navigation。Navigation 的 `Stack`、`Split`、`Auto`、`AUTO_WITH_ASPECT_RATIO` 可支持单栏、宽屏分栏和方向适配；`Start/End` 会随 LTR/RTL 语言变化。

### 7.4 布局、列表和响应式

[官方事实] ArkUI 提供线性、层叠、Flex、相对、栅格、列表、网格、瀑布流和懒加载布局。布局应从内容区、组件区域、padding/border/margin 和约束传递理解，不能只依赖固定宽高或设备名称。

[官方事实] 同类集合可按形态选择 `List`、`Grid`、`WaterFlow`，圆形屏使用 `ArcList`。混合内容流可用 `LazyColumnLayout/LazyVGridLayout/LazyVWaterFlowLayout`。`Repeat` 从 API 12 起支持状态监听和节点复用，官方建议相对 `LazyForEach` 优先使用；`LazyForEach` 仍适合既有 IDataSource 场景，但依赖稳定 key、正确容器与可测量尺寸。

[解释] 长列表优化的优先顺序通常是：只渲染可见区域 → 稳定 key → 数据增量更新 → 组件复用 → 缓存/预加载 → 减少嵌套与重绘。把所有数据先映射成大型观察对象，再“加一个 LazyForEach”并不能自动解决性能问题。

### 7.5 UIContext、窗口、屏幕与安全区

[官方事实] 一个窗口对应一个 UI 实例。在 Stage 模型的多窗口/多 UI 实例中，全局 UI 接口可能因为异步边界失去上下文；官方建议使用对应 `UIContext` 操作界面。Promise、Worker、NAPI 等异步链必须保持或显式获取正确 UIContext。

[官方事实] 一个 UIAbility 对应一个 WindowStage，一个 WindowStage 管理一个主窗口。主窗口生命周期与 UIAbility 关联，辅助窗口由应用自行管理。窗口事件包含显示、隐藏、前后台、焦点、尺寸、旋转、层级、沉浸式和自由窗口等状态。

[官方事实] 沉浸式布局会把应用可布局区域扩展到整个窗口，但系统 UI 仍在更高层；重要交互内容必须根据状态栏、导航区域、挖孔、键盘等避让区域布局。组件安全区只是绘制/布局策略的一部分，不能用一个固定 padding 代替实时 avoid area。

[官方事实] Display 能力可查询分辨率、逻辑/物理像素密度、刷新率、旋转、显示设备与折叠状态，并监听变化。响应式布局应依据窗口实际尺寸和环境，而不是把 `phone/tablet/2in1` 当作永远不变的布局宽度。

### 7.6 动画、交互和可打断性

[官方事实] ArkUI 覆盖属性动画、转场、粒子、组件动画、曲线、动画衔接、手势、拖拽和自定义绘制。官方性能指导强调同时关注感知流畅和运行流畅，包括资源加载/释放、缓存复用和减少重复绘制。

[解释] 动画必须表达真实状态：后端未完成不能先显示成功；手势跟随应可打断；页面返回、旋转、窗口缩放和快速重复点击时不应留下半完成状态。动画参数不是装饰常量，应纳入组件状态机和无障碍“减少动态效果”策略。

### 7.7 调试、性能与错误定位

[官方事实] UI 性能分析流程是复现 → 用 CPU Profiler/Trace 定位瓶颈 → 根据调用栈或布局树修改 → 用同一场景重新测量。ArkUI Inspector 用于查看组件树和布局参数。官方明确建议由数据而非直觉指导优化。

[官方事实] ArkUI 调试分支覆盖显示异常、UIContext 异常、稳定性、状态不刷新、Navigation 动画常见问题、窗口日志和高性能实践。性能常见方向包括推迟不可见资源、使用懒加载/复用、减少布局层级和避免主线程耗时。

### 7.8 工程维度检查

| 维度 | ArkUI 工程结论 |
|---|---|
| 生命周期 | 监听、控制器、Scroller、弹窗、动画和异步任务绑定明确 owner；复用、冻结、隐藏与销毁区别处理。 |
| 并发 | 状态更新只在 UI 主线程；异步回调使用正确 UIContext；耗时工作下沉。 |
| 状态 | owned/input/output/tree/global/persisted 状态分层，派生值缓存合理，避免双源真相。 |
| 路由 | 一个 Navigation 一个 NavPathStack；路由表、Builder、参数和返回行为一致；Router 仅留历史边界。 |
| 数据 | View 不解析 DTO/SQL；空、加载、失败、权限拒绝、离线、部分成功均有真实状态。 |
| 权限 | 组件本身与调用的系统 Kit 权限分开；权限拒绝后界面不显示伪成功。 |
| 性能 | 列表按需渲染、稳定 key、减少嵌套、绑定正确 Scroller、测量首帧/帧率/内存。 |
| 错误处理 | UIContext、路由未注册、窗口状态、控制器时机和异步竞态均有日志与用户可恢复路径。 |

### 7.9 给编程 AI 的检查单

- [ ] 新组件默认 V2；输入、输出、owned 状态和全局依赖明确。
- [ ] 不把业务持久化塞进 AppStorageV2/PersistenceV2，也不在 View 中写 SQL/网络协议。
- [ ] Navigation/NavPathStack 所有权唯一，路由名、Builder 和参数可静态追踪。
- [ ] 组件退出、复用、隐藏后异步结果不会误更新别的页面实例。
- [ ] 列表 key 稳定，数据更新不是整表重建；大列表选择 Repeat/LazyForEach 有证据。
- [ ] 宽度、方向、字体、键盘、安全区、折叠和自由窗口变化均不依赖固定像素。
- [ ] 动画可中断、状态真实，无障碍焦点和系统返回在转场中仍正确。
- [ ] 性能结论有同场景前后 Trace/帧率/内存证据，模拟器截图不等于真机性能。

### 7.10 当前项目适配

[项目适配] 当前根 `MainPage` 已拥有共享 `NavPathStack`、HDS Navigation、手机 HDS Tabs、宽屏角色工作区和 AI cover。不得为宽屏 caregiver 页面再嵌套一个结构性 Navigation，也不得把业务内页退回到传统 Router。

[项目适配] 根 HDS 标题栏已绑定当前可见的真实 Scroller；resident/message 的主从视图会随选择与滚动切换绑定。新增滚动区域时必须把 Scroller owner、标题栏材质和页面可见状态一起处理，不能用固定模糊 Row 模拟。

[项目适配] `MainPage` 是全屏窗口状态 owner，子 cover 继承该状态。宽屏工作区不要再次全窗口 `ignoreLayoutSafeArea`；导航指示器高度只加在固定 footer、composer 或滚动末端，不得给整个持久页面重复 padding。

[项目适配] 现有大文件是拆分信号。新增 feature root、数据集、服务调用和导航流时，应按真实 feature/section ownership 拆组件、ViewModel 和 repository，而不是继续扩大 `TabPageView.ets`、`WideDoctorWorkspace.ets` 等文件。

### 7.11 代表性官方页面

- [ArkUI简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkui-overview)
- [状态管理概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-state-management-overview)
- [V1和V2更新机制差异](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-v1-v2-update-difference)
- [自定义组件生命周期（推荐）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-custom-components-new-lifecycle)
- [Navigation基础架构](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-architecture)
- [Navigation页面路由](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-jump)
- [Repeat循环渲染](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-rendering-control-repeat)
- [使用UIContext操作界面](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-global-interface)
- [UI高性能开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-performance-overview)
- [窗口沉浸式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/immersive-window-feature)

## 8. ArkWeb：Web 容器、JSBridge、网络边界与渲染进程

[官方事实] 本子类共 76 页。直接子菜单全部为：ArkWeb简介、ArkWeb进程、Web组件的生命周期、设置基本属性和事件、Web渲染和布局、在应用中使用前端页面JavaScript、管理网页交互、管理Web组件的网络安全与隐私、管理网页加载与浏览记录、管理网页文件上传与下载、使用网页多媒体、处理网页内容、同层渲染、使用离线Web组件、使用WebNativeMessagingExtensionAbility组件实现浏览器扩展和应用通信场景、Web调试维测、ArkWeb术语。

### 8.1 能力边界、进程与生命周期

[官方事实] ArkWeb 通过 ArkUI Web 组件在应用中显示本地或在线网页，覆盖页面加载、Cookie 与存储、JavaScript 交互、上传下载、多媒体、同层渲染、离线预渲染以及调试维测。在线页面需要在 module.json5 中声明 ohos.permission.INTERNET；ArkWeb 不是 Network Kit 的替代品，HTTP、WebSocket、TLS、代理和网络状态仍应按网络分支实现。

[官方事实] ArkWeb 采用多进程模型，涉及应用进程、Web 渲染进程、Web GPU 进程、Web 孵化进程和系统 Foundation 进程。移动设备默认更倾向于共享渲染进程以节省内存，2in1 更倾向于隔离渲染进程以提高稳定性与安全性；具体策略仍应按当前 API 和设备核验。

[官方事实] WebviewController 与 Web 组件绑定成功后触发 onControllerAttached。在该回调之前调用 Web 组件接口会产生 JS 错误；此时网页尚未加载，也不能调用依赖已加载页面的缩放等接口。页面加载还涉及 onLoadIntercept、onInterceptRequest、onPageBegin、进度、页面结束、页面可见、渲染退出和渲染无响应等不同阶段。

[官方事实] 自定义组件销毁时，Web 组件、Controller 绑定关系和对应 JavaScript 运行环境会一并销毁。隐私模式通过 incognitoMode 开启，Cookie、缓存等不写入持久化存储，隐私 Web 组件销毁后相关数据清除。

[解释] Web 页面“加载完成”不是一个布尔值。主 frame 的 onPageEnd、图片和动态脚本完成、首屏可交互、业务数据可用以及子 frame 完成可能发生在不同时间。必须按业务所需的真实阶段启用按钮、读取页面高度或隐藏占位骨架。

### 8.2 渲染、布局与交互

[官方事实] Web 支持异步渲染、同步渲染和内容自适应布局等模式。异步渲染适合 Web 作为页面主体；FIT_CONTENT 用于 Web 与原生内容共同滚动的长内容场景，并需按官方约束选择同步渲染。异步渲染模式下 Web 组件高度不能超过 7,680 物理像素，否则可能白屏。

[官方事实] 网页高度在图片、脚本和异步内容继续加载时会变化，动态网页不宜只在 onPageEnd 等单次回调里读取高度并永久固定。Web 嵌套在 List、Scroll、Tabs、WaterFlow、Refresh 或 Sheet 中时，需要明确内外滚动的手势分发与 NestedScrollMode，不能让两个滚动 owner 竞争同一手势。

[官方事实] ArkWeb 还覆盖软键盘避让、焦点、触摸与鼠标滚轮、网页缩放、网页弹窗、拖拽、新窗口、全屏视频和网页安全区。ArkWeb 手势作用于网页，ArkUI 手势作用于 Web 组件本身，二者不能混为一层事件。

[解释] 原生导航栏隐藏、Web 尺寸变化和网页重排若分三个时刻发生，容易产生底部闪烁。解决方向是让窗口、安全区、导航栏状态和 Web 布局变更在同一状态机中协调，而不是在多个回调里各自修改高度。

### 8.3 JSBridge、请求、文件与隐私

[官方事实] 应用侧可用 runJavaScript/runJavaScriptExt 调用网页函数；网页调用应用侧可在初始化时使用 javaScriptProxy，或在 Controller 绑定后使用 registerJavaScriptProxy。动态注册通常在下一次加载或重新加载后生效；两种注册方式都应配合 deleteJavaScriptRegister 解除注册，避免泄漏。

[官方事实] WebMessagePort 用于应用与网页建立双向消息通道，端口不再使用或 Webview 销毁前必须 close。Native JSBridge 和 Native PostWebMessage 面向 ArkTS/C++ 混合或小程序式架构，不应仅为“调用一个网页函数”引入。

[解释] JSBridge 等于把应用能力暴露给不完全可信的网页运行环境。必须同时限制允许加载的 scheme/host/path、允许暴露的对象和方法、参数类型与长度、调用频率、回调来源、页面跳转和新窗口目标。不要向网页暴露 Context、文件任意路径、认证令牌或通用命令执行能力。

[官方事实] ArkWeb 支持 Cookie、DOM Storage、隐私模式、请求拦截、自定义响应、智能防跟踪、广告过滤和坚盾守护模式。跨域、本地资源、JavaScript、文件、图片和网络图片均有独立开关或安全约束；打开所有开关不是通用“修复白屏”方案。

[官方事实] 网页上传可通过 onShowFileSelector 接管并拉起 Picker；下载可注册 DownloadDelegate 监听进度。摄像头、麦克风、位置、传感器、打印、相册或文件访问分别依赖相应系统权限、用户选择或安全控件，网页自身的 W3C 权限请求不能替代应用侧授权。

### 8.4 性能、崩溃与维测

[官方事实] 离线 Web 组件可预启动渲染进程或预渲染页面，但单个 Web 组件可能消耗约 200MB 内存和相应计算资源，不应批量预创建。离线节点的创建、挂载、复用、隐藏和释放必须有明确 owner。

[官方事实] ArkWeb 提供 DevTools 调试、Crashpad 转储、onRenderExited、onRenderProcessNotResponding 和 Hypium/Selenium 自动化测试指导。白屏排查应依次检查网络与权限、页面资源和跨域、JavaScript 异常、渲染模式与尺寸约束、生命周期调用时机、坚盾守护限制以及渲染进程状态。

### 8.5 工程维度检查

| 维度 | ArkWeb 工程结论 |
|---|---|
| 生命周期 | Controller 绑定后再调用接口；JS 代理、消息端口、下载委托、新窗口和离线节点均对称释放。 |
| 并发 | 页面回调可能交错；用导航请求 ID 或页面会话 ID 拒绝过期回调，避免旧页面覆盖新页面状态。 |
| 状态 | 区分组件创建、Controller 已绑定、主 frame 加载、业务可用、渲染进程异常和已销毁。 |
| 路由 | Web 内跳转、原生 Navigation、外部应用链接和新窗口分别设白名单与返回策略。 |
| 数据 | Cookie、缓存、DOM Storage、下载文件和 JSBridge 数据分别定义保留、清除、加密与审计规则。 |
| 权限 | INTERNET 只解决联网；位置、相机、麦克风、文件、传感器、打印等仍需逐项核对。 |
| 性能 | 控制 Web 实例数、渲染进程策略和离线预渲染规模，测量首屏、内存、进程退出与恢复。 |
| 错误处理 | 加载失败、证书/跨域、404、JS 异常、白屏、渲染退出、下载失败均有用户可恢复路径。 |

### 8.6 给编程 AI 的检查单

- [ ] 先确认业务确实需要 Web，而不是用 Web 绕过原生组件、网络层或数据层。
- [ ] WebviewController 只有一个明确 owner，所有调用均晚于 onControllerAttached。
- [ ] 加载 URL、重定向、新窗口、外链和本地资源均有允许列表。
- [ ] JSBridge 只暴露最小方法集，校验来源、参数、频率和返回值，并在销毁时注销。
- [ ] WebMessagePort、下载委托、权限回调、渲染状态监听和离线节点全部清理。
- [ ] 隐私模式、普通模式、登录 Cookie 和退出登录清理行为分别验证。
- [ ] 文件上传使用 Picker/URI 授权，下载路径和文件名经过校验，不接受网页提供的任意本地路径。
- [ ] 真机验证键盘、安全区、旋转、鼠标键盘、深色模式、渲染进程崩溃和弱网恢复。

### 8.7 当前项目适配

[项目适配] 当前 KangxiaobanAI 没有 Web 组件和网络层，AI 对话也是本地定时器生成文本。不得为了“快速接后台”把 Web 页面直接塞进 AiChatPage，也不得把 ArkWeb 当作真实 AI 网关或 HTTP 客户端。

[项目适配] 若未来仅展示帮助、协议或机构门户，应建立独立 Web feature：由共享 NavPathStack 进入，复用根窗口和安全区 owner，声明精确 INTERNET/文件权限，限制域名与外链，定义登录 Cookie 和退出清理，并对渲染失败显示原生恢复页面。

[项目适配] 若 Web 页面包含居民、健康或机构数据，JSBridge 不得暴露完整领域对象和本地文件路径；应由应用侧完成鉴权、字段最小化和审计，网页只接收完成当前操作所需的数据。

### 8.8 代表性官方页面

- [ArkWeb简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-component-overview)
- [ArkWeb进程](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web_component_process)
- [Web组件的生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-event-sequence)
- [前端页面调用应用侧函数](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-in-page-app-function-invoking)
- [建立应用侧与前端页面数据通道](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-app-page-data-channel)
- [管理Web组件的网络安全与隐私](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-manage-cyber-security-privacy)
- [管理网页加载与浏览记录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-manage-loading-browsing)
- [使用离线Web组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-offline-mode)
- [定位与解决Web白屏问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-white-screen)
- [定位网页加载问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-page-loading)

## 9. Background Tasks Kit：受约束的后台执行

[官方事实] 本子类共 9 页。直接子菜单全部为：Background Tasks Kit简介、短时任务(ArkTS)、短时任务(C/C++)、长时任务(ArkTS)、延迟任务(ArkTS)、代理提醒(ArkTS)、Background Tasks Kit接入规范、Background Tasks Kit术语。

### 9.1 四类后台任务如何选择

[官方事实] 应用退后台后，普通进程可能被挂起或终止，定时器、网络、CPU、定位和蓝牙等资源也会受到限制。后台任务只在规定场景内延长或代理业务，不保证进程永久存活；系统资源严重不足时，即使已申请任务，进程仍可能被终止。

| 类型 | 适用场景 | 核心约束 |
|---|---|---|
| 短时任务 | 退后台前完成状态保存、消息发送等短工作 | 必须在前台或 onBackground 内申请；同一应用同时最多 3 个；默认 24 小时总配额 10 分钟、单次最多 3 分钟，低电量时单次默认 1 分钟；完成后主动取消。 |
| 长时任务 | 音乐、导航、设备连接等长时间且用户可感知的业务 | 任务类型必须与实际行为一致，通常有持续可见通知；业务结束立即取消，禁止用来恶意保活。 |
| 延迟任务 | 同步、整理、拉取等实时性不高且可延迟业务 | 系统按网络、充电、存储、电池、温度和用户习惯调度；同一应用最多 10 个；WorkSchedulerExtensionAbility 单次回调最长 2 分钟。 |
| 代理提醒 | 应用退出或进程终止后仍需系统定时提醒 | 支持倒计时、日历、闹钟；部分设备、应用分类和场景受权益管控，营销提醒不属于允许场景。 |

[解释] 选择依据不是“我希望它后台继续”，而是实时性、持续时间、用户是否能感知、触发条件和任务结束信号。短时任务不是三分钟定时器，长时任务不是保活开关，延迟任务不是准点闹钟，代理提醒也不是推送营销工具。

### 9.2 生命周期、配额与恢复

[官方事实] 短时任务需要查询剩余时间并在超时回调或业务完成时取消。多个短时任务并不会让同一时间段重复获得配额；忘记取消会继续消耗当日额度。

[官方事实] 长时任务会接受业务一致性检查。用户删除关联通知、主动停止业务或系统判断类型不匹配时，任务可能被停止；应用不得立即重新申请规避用户或系统决定。

[官方事实] 延迟任务由独立 Extension 进程承载，onWorkStart/onWorkStop 不是普通 UI 页面生命周期。调度时间只表示满足条件后进入系统决策，不承诺精确时刻；任务应可重试、幂等，并能在两分钟内提交阶段结果或安全退出。

[官方事实] 后台进程仍受内存、CPU 和磁盘写入配额限制。进程被杀、设备重启、网络变化或用户撤销权限后，任务必须从持久化检查点恢复，不能只依赖内存变量。

### 9.3 工程维度检查

| 维度 | Background Tasks 工程结论 |
|---|---|
| 生命周期 | 申请、开始、进度、完成、取消、超时、用户停止和进程重建均有状态转换。 |
| 并发 | 防止重复申请与同一业务并发执行；调度回调应持有幂等任务 ID。 |
| 状态 | 任务记录需持久化实际进度，不能用“已申请后台任务”表示业务成功。 |
| 路由 | 后台回调不直接操作已销毁页面；通过 repository/store 更新，前台恢复后再渲染。 |
| 数据 | 写入采用事务或临时文件加原子替换，进程中断后可识别半成品。 |
| 权限 | 除后台任务本身外，仍需核对定位、蓝牙、网络、通知以及受管控权益。 |
| 性能 | 控制 CPU、网络、定位和磁盘使用；合并任务，避免频繁唤醒。 |
| 错误处理 | 配额不足、条件未满足、任务超时、系统停止、权限撤销和重启均有降级。 |

### 9.4 给编程 AI 的检查单

- [ ] 先写清实时性、最长耗时、用户是否可感知、触发条件和完成条件，再选任务类型。
- [ ] 不用后台任务维持常驻进程，也不在被系统停止后立即循环重申。
- [ ] 短时任务申请时机正确，最多 3 个，结束后主动取消。
- [ ] 长时任务类型、实际资源使用、通知内容和用户操作一致。
- [ ] 延迟任务最多 10 个，回调在 2 分钟内完成，任务幂等且可断点恢复。
- [ ] 代理提醒先核对设备、应用分类、业务场景、开放权益和上架规范。
- [ ] 后台结果通过持久层传播，不直接抓取页面实例或 UIContext。
- [ ] 报告明确区分“已注册任务”“系统已调度”“业务已完成”。

### 9.5 当前项目适配

[项目适配] 当前项目中的登录、AI 回复、任务状态切换和医生入院草稿都只是前台内存状态或定时器；没有 Background Tasks Kit。应用退后台、进程被杀或设备重启后，不应宣称这些流程会继续。

[项目适配] 如果未来要做用药提醒、交接提醒或设备告警，先确定真实服务端/本地数据源、通知与授权，再选择 Calendar Kit、代理提醒、Push Kit 或后台任务。护理业务的时间敏感提醒不能靠前台 setTimeout。

[项目适配] 如果未来要做数据同步，优先使用可恢复的 repository 同步任务；短时任务仅用于退后台收尾，延迟任务用于可等待同步，长时任务只用于用户明确感知且官方类型允许的持续业务。

### 9.6 代表性官方页面

- [Background Tasks Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/background-task-overview)
- [短时任务(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/transient-task)
- [长时任务(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/continuous-task)
- [延迟任务(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/work-scheduler)
- [代理提醒(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-powered-reminder)
- [Background Tasks Kit接入规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/bgtask-design-formula)

## 10. Content Embed Kit：跨应用文档嵌入与协同编辑

[官方事实] 本子类共 7 页。直接子菜单全部为：Content Embed Kit简介、客户端和服务端交互流程、服务端应用开发、客户端应用开发、Content Embed Kit常见问题、Content Embed Kit术语。

### 10.1 OE 客户端/服务端模型

[官方事实] Content Embed Kit 从 API 24 开始提供对象编辑（Object Editor，OE）框架，用于一个应用文档嵌入另一种文档，并按需启动原应用进行跨应用编辑。它面向 CAD、办公文档、笔记等复合文档场景，不是把普通 ArkUI 页面嵌入另一个页面的通用容器。

[官方事实] 客户端应用负责创建或加载 OE 文档、创建客户端 OE 对象、显示图标或快照、启动服务端 Extension 并发起编辑；服务端应用注册可处理的文档类型和 OE Extension，提供快照并启动对应 UIAbility 编辑文档。OE SA 负责 Extension 注册、发现与调度。

[官方事实] 典型时序为：按 OEID、源文件或 OE 格式创建文档 → 创建客户端对象并注册回调 → 启动 OE Extension → 服务端注册 Extension 与服务端对象回调 → 客户端请求快照 → 服务端启动 UIAbility 编辑 → 编辑结果回传并更新客户端文档。

### 10.2 链接与嵌入语义

[官方事实] 基于文件创建 OE 文档时，链接模式会继续引用并修改源文件；源文件移动、删除或重命名会导致后续编辑失败，链接也不支持指向客户端应用沙箱。嵌入模式会复制临时文件到客户端沙箱，服务端修改不会改变原始源文件，客户端正常退出时临时文件清理。

[解释] 链接适合“始终编辑同一外部文件”，但依赖长期 URI/文件可达性；嵌入适合“文档携带一份独立副本”，但必须处理副本大小、版本冲突和临时文件清理。产品需要明确哪一个才是用户预期，不能只按接口布尔值选择。

[官方事实] 客户端应先查询 OE Extension 是否支持快照；不支持时可退化显示文件图标。快照是展示结果，不等同于原始文档或可编辑状态。

### 10.3 配置、权限与 Native 边界

[官方事实] 当前开发指导使用 OH_ContentEmbed C API。客户端在调用前检查 SystemCapability.ContentEmbed.ObjectEditor，并申请 ohos.permission.CONNECT_OBJECTEDITOR_EXTENSION；服务端申请 ohos.permission.REGISTER_OBJECTEDITOR_EXTENSION。

[官方事实] 服务端在 module.json5 的 extensionAbilities 中把类型配置为 contentEmbed、exported 设为 true，并通过固定 metadata 指向 OE Extension 配置文件；配置中的 OEID、文档类型、入口和实际实现必须一致。

[解释] 这两个权限、SystemCapability、设备和应用开放范围必须回到当前 API 参考核验。指南出现权限名不代表任意普通应用在任意设备上都能获批或运行。

### 10.4 工程维度检查

| 维度 | Content Embed 工程结论 |
|---|---|
| 生命周期 | 客户端对象、服务端对象、Extension、回调、快照和临时文件都有明确创建与释放时机。 |
| 并发 | 同一 OE 文档的打开、编辑、保存和关闭序列化；避免两个服务端实例同时覆盖结果。 |
| 状态 | 区分仅图标、快照可用、可编辑、编辑中、源文件失效、服务端不可用和结果已更新。 |
| 路由 | 服务端编辑 UIAbility 是跨应用编辑入口，不替代客户端自身 Navigation。 |
| 数据 | 明确链接/嵌入所有权、版本、临时副本、持久化位置、大小和冲突策略。 |
| 权限 | 同时核对客户端连接权限、服务端注册权限、exported、SystemCapability 和文件授权。 |
| 性能 | 快照尺寸与频率受控；大文档不在 UI 线程复制、解析或序列化。 |
| 错误处理 | 无服务端、无快照、源文件失效、权限拒绝、编辑应用退出和回传失败均可降级。 |

### 10.5 给编程 AI 的检查单

- [ ] 只有真正的复合文档跨应用编辑需求才选择 Content Embed Kit。
- [ ] 明确当前应用是客户端、服务端还是两者，并读取对应 Native API 与配置。
- [ ] 检查 API 24、SystemCapability、设备、权限开放范围和签名要求。
- [ ] 链接与嵌入模式通过产品语义决定，不用默认值代替设计。
- [ ] OEID、文档类型、Extension 配置、导出状态和实现入口互相一致。
- [ ] 源文件 URI/授权、临时文件、快照和编辑结果分别定义 owner 与清理。
- [ ] 服务端不可用时显示图标/只读状态，不伪造“已编辑”。

### 10.6 当前项目适配

[项目适配] 当前 KangxiaobanAI 没有办公文档编辑器、Native OE 模块或 Content Embed Extension。居民附件、健康报告和入院表单不应因为“需要显示文件”就引入本 Kit；普通附件应先按 Core File Kit 的 Picker/URI 与业务 repository 处理。

[项目适配] 如果未来确有跨应用编辑评估表、护理计划或办公附件的需求，应单独设计文档领域模型、Native 模块、权限申请、审计与版本冲突策略。医疗/养老敏感内容还需先确定数据最小化和跨应用授权边界。

### 10.7 代表性官方页面

- [Content Embed Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/content-embed-kit-overview)
- [客户端和服务端交互流程](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/client-server-interaction-process)
- [服务端应用开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/content-embed-server-guidelines)
- [客户端应用开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/content-embed-client-guidelines)
- [Content Embed Kit常见问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/content-embed-faq)

## 11. Core File Kit：应用文件、用户文件、同步、备份与压缩

[官方事实] 本子类共 51 页。直接子菜单全部为：Core File Kit简介、应用文件、用户文件、分布式文件系统、端云文件协同、文件压缩解压缩、文件基础服务开发实践。

### 11.1 三类文件与所有权

[官方事实] Core File Kit 按所有者区分应用文件、用户文件和系统文件。应用文件位于应用沙箱，由应用管理；用户文件属于当前设备用户，应通过 Picker、媒体库或公共目录能力访问；系统文件通常不向普通应用开放管理。

[官方事实] 应用沙箱路径应从 Context 对应属性获取，禁止手工拼接上级目录或依赖安装路径。通常应把敏感应用数据放在用户认证后可访问的 EL2 加密区；只有闹钟、壁纸等确需首次认证前可用的数据才考虑 EL1。

[解释] 文件所有权决定删除、备份、分享和卸载后的语义。应用缓存、业务数据库、用户主动保存的报告和从 Picker 临时打开的附件，不应使用同一种路径或保留策略。

### 11.2 文件 I/O、URI 与授权

[官方事实] ArkTS 基础文件接口覆盖创建、读取、写入、复制、移动、删除、属性、哈希和空间统计。read/write 等耗时操作建议使用异步接口；读写 offset 可能沿用上一次位置；流必须及时关闭，且同一流不支持并发读写，不能混用同步和异步操作。

[官方事实] 用户文件 URI 是系统提供的唯一标识，不建议解析 URI 片段做业务逻辑。文档 URI、媒体 URI 和应用分享 URI 的访问方式不同，应使用对应 Kit 或文件接口。

[官方事实] FilePicker 选择或保存文件通常无需应用自行申请存储权限，但返回 URI 默认只有临时读写授权，应用退后台后可能失效；长期使用必须按官方持久化授权流程处理。Picker 的“无权限”是因为用户通过系统界面授权具体文件，不代表应用可以访问任意路径。

[官方事实] 应用分享文件时应使用系统接口把路径转换为 URI，不能手工拼接 file URI。分享前还需限制文件范围、接收方、授权模式和有效期。

### 11.3 备份、迁移、分布式与端云

[官方事实] 应用数据备份恢复、应用克隆和设备升级迁移需要配置 BackupExtensionAbility、备份范围和转换逻辑，并通过开发者自验证和端到端验证。备份扩展执行结束后，框架会清理备份恢复目录，所需转换与迁移必须在回调完成前结束。

[解释] 备份恢复是数据搬运通道，不自动解决数据库 schema 升级、账号隔离、租户授权、加密密钥和业务幂等。恢复后的应用必须重新验证数据版本与用户身份。

[官方事实] 分布式文件系统覆盖数据等级、跨设备共享访问与拷贝；端云文件协同覆盖同步状态、云端版本和空间管理。两者均依赖设备组网、账号、系统能力和服务状态，不能由本地路径存在推断“已同步”。

[官方事实] 压缩解压缩包含文件归档、流式和缓冲区 C API。解压外部压缩包时应限制目标目录、条目数量、总展开大小和符号链接/路径穿越，避免覆盖沙箱内其他数据。

### 11.4 工程维度检查

| 维度 | Core File 工程结论 |
|---|---|
| 生命周期 | fd、流、Picker URI 授权、分享授权、备份目录和同步监听均成对关闭或撤销。 |
| 并发 | 同一文件写入串行或加锁；长操作异步；采用临时文件、fsync/事务和原子替换。 |
| 状态 | 区分文件存在、授权有效、本地可用、云端占位、同步中、冲突、损坏和已删除。 |
| 路由 | Picker/系统页面返回 URI 后再进入业务页面；页面栈不保存打开的 fd 或原始大数据。 |
| 数据 | 文件元数据与领域记录分离，数据库只存稳定 ID/URI 与状态，不把路径当永久主键。 |
| 权限 | 沙箱访问、用户选择授权、媒体安全控件、分享临时授权和受限公共目录分别处理。 |
| 性能 | 大文件流式处理，避免整文件读入内存；统计、哈希、压缩和同步不阻塞 UI。 |
| 错误处理 | 权限失效、空间不足、文件移动、云端离线、校验失败和部分写入均可恢复。 |

### 11.5 给编程 AI 的检查单

- [ ] 先判定文件属于应用、用户还是系统，确定卸载、分享、备份和删除语义。
- [ ] 应用路径只从正确 Context 获取，不拼接沙箱根目录，不解析用户文件 URI。
- [ ] read/write 使用合适的异步或流式接口，offset 明确，fd/stream 在 finally 中关闭。
- [ ] Picker 返回的临时授权不会被误当成永久权限；需要长期访问时完成持久化授权。
- [ ] 分享 URI 由系统接口生成，授权范围和时限最小化。
- [ ] 备份/迁移包含 schema、账号、加密和幂等验证，不只验证“文件已复制”。
- [ ] 云端/分布式文件显示真实同步状态，离线时不显示伪成功。
- [ ] 解压外部内容防路径穿越、压缩炸弹和覆盖已有文件。

### 11.6 当前项目适配

[项目适配] 当前项目只有 PreferenceManager 用于少量设置，没有居民附件 repository、业务 RDB、备份策略、分布式文件或端云同步。界面中的报告、健康记录和入院资料仍是本地 mock，不得描述为已落盘文件。

[项目适配] 如果新增健康报告导入/导出，应通过 Picker 获得用户明确选择的 URI，把文件读取、解析、领域映射和 UI 展示拆开；数据库保存稳定记录与授权状态，不在组件中长期保存 fd、绝对路径或完整二进制。

[项目适配] 养老健康数据需要额外定义加密目录、导出脱敏、分享有效期、备份排除/包含策略和退出登录清理。是否允许云同步或跨设备访问是产品与合规决定，不应由 AI 自动开启。

### 11.7 代表性官方页面

- [Core File Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-file-kit-intro)
- [应用沙箱目录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-sandbox-directory)
- [应用文件访问(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-file-access)
- [应用文件分享](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/share-app-file)
- [应用数据备份恢复](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-file-backup-restore)
- [用户文件URI介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/user-file-uri-intro)
- [选择用户文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/select-user-file)
- [保存用户文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/save-user-file)
- [分布式文件系统](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/distributed-fs)
- [端云文件协同](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloud-sync-file)
- [文件压缩解压缩](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/compression)

## 12. Data Augmentation Kit：知识加工、检索、RAG 与端侧问答

[官方事实] 本子类共 17 页。直接子菜单全部为：Data Augmentation Kit简介、知识加工、RAG、智慧化数据检索-ArkTS、智慧化数据检索-C++、端侧问答模型、Data Augmentation Kit术语。

### 12.1 从业务数据到回答的完整链

    业务数据源
      → schema 与知识加工
      → 倒排索引 / 向量库 / 特征表
      → 多路召回与条件过滤
      → 重排
      → RAG 提示词与上下文
      → 应用提供的 LLM / 端侧模型
      → 流式思考、引用与答案
      → 应用安全过滤、展示、反馈与审计

[官方事实] Data Augmentation Kit 提供知识加工、智慧化检索、RAG 和端侧问答模型。RAG 的价值是从外部知识库检索证据辅助生成，减少静态模型知识不足；它不能保证答案必然正确，也不替代业务权限、数据治理或人工审核。

### 12.2 知识加工与检索

[官方事实] 知识加工通过 resources/rawfile/arkdata/knowledge/knowledge_schema.json 描述源 RDB 表与知识产物。relationalStore 开库 name 必须与 schema 的 dbName 一致，表名和列名也必须一致，并设置 enableSemanticIndex 才会触发相应加工。

[官方事实] 开库可启动加工，源表插入、更新或删除也可触发加工。知识加工使用的表不支持同时进行端端同步、端云同步以及搜索；schema 升级时需按指导清理旧知识数据并重建。

[官方事实] 智慧化检索使用多路召回和重排。ArkTS 路径可结合倒排检索、向量语义检索、条件过滤和重排；C++ 路径重点提供向量召回和排序能力。召回分数不是业务正确性，仍需阈值、分档和空结果策略。

### 12.3 RAG 会话、LLM 与安全

[官方事实] 知识问答前必须先完成知识加工。当前指南中的 RAG 历史上下文范围为最近一次问答；RAG 不提供敏感词风控，应用必须自行检查用户输入和返回内容。

[官方事实] streamChat 中与 LLM 的网络交互由应用实现，因此通常需要 INTERNET 权限、实际模型服务、凭证保护、超时、重试和流式解析。官方建议选择上下文长度至少 30k Tokens 的 LLM，否则检索上下文可能超限导致失败。

[官方事实] RAG 支持提示词模板、超参和分析过程模板。配置键名、类型、UTF-8 编码和占位符必须符合规定；配置失败可能回落默认值。分析过程模板有长度限制，不能把内部中间文本当作经过验证的事实。

[解释] RAG 的“引用”只能证明系统检索到了某段内容，不证明回答完整遵守引用。应用应保存问题、检索结果 ID、版本、模型请求、最终答案和用户反馈，以便追踪答案依据。

### 12.4 端侧问答模型

[官方事实] 当前端侧问答模型仅支持 PC/2in1，并面向企业开发者申请；首次使用会进入本地 AI 模型管理与隐私声明/模型下载流程。网络权限可能用于模型资源管理，不能仅凭“端侧”二字宣称全流程离线。

[解释] 端侧模型、远端模型与混合 RAG 是三种部署方案。选择要比较设备范围、模型大小、隐私、延迟、功耗、升级、离线和答案质量，而不是默认端侧一定更安全或远端一定更强。

### 12.5 工程维度检查

| 维度 | Data Augmentation 工程结论 |
|---|---|
| 生命周期 | 数据库连接、知识加工器、RagSession、流式问答和模型连接有明确创建、取消与释放。 |
| 并发 | 同一会话请求可取消；数据库加工、检索和 UI 流式更新不互相覆盖；拒绝过期 token。 |
| 状态 | 区分未加工、加工中、可检索、索引过期、检索空、模型中断、被取消和安全拦截。 |
| 路由 | 页面离开后取消或转交会话，返回时从 store 恢复；不把长会话绑死在组件实例。 |
| 数据 | DTO、领域数据、知识 schema、向量产物、引用和聊天记录分别建模与授权。 |
| 权限 | INTERNET、企业能力、PC/2in1、模型下载、数据访问和敏感内容规则逐项核验。 |
| 性能 | 测量加工时长、索引大小、召回延迟、首 token、总响应、内存和模型下载。 |
| 错误处理 | schema 不匹配、索引失败、空召回、上下文超限、网络/模型错误和内容拦截可恢复。 |

### 12.6 给编程 AI 的检查单

- [ ] 先定义数据来源、可检索字段、权限边界和更新频率，再写 schema。
- [ ] dbName、tableName、columnName 与实际 RDB 完全一致，enableSemanticIndex 配置正确。
- [ ] 数据更新后有索引新鲜度状态，不在加工完成前显示“知识已更新”。
- [ ] RAG 先检索再生成；空检索时明确回答无依据，不让模型自由补全事实。
- [ ] 应用实现输入/输出安全过滤、引用展示、超时、取消、重试和审计。
- [ ] LLM 凭证不写入源码或前端日志，模型服务失败不回退为伪造本地答案。
- [ ] 端侧问答先核对企业资格、PC/2in1、模型下载和隐私流程。
- [ ] 用固定问题集评估召回率、引用正确率、答案忠实度和拒答，而不只看演示截图。

### 12.7 当前项目适配

[项目适配] 当前 AiChatPage 的回复由本地定时器和固定文本生成，不存在知识加工、RAG、模型服务或端侧模型。接入本 Kit 后也必须继续把“检索到资料”“模型生成回答”“人工确认”显示为不同状态。

[项目适配] 养老场景含健康、用药和护理数据。知识库建立前应先完成真实 repository、身份与租户授权、数据脱敏和审计；不能直接把 TabPageView、ResidentDetailPage 中的 mock 数组当作生产知识源。

[项目适配] 当前项目同时支持 phone、tablet、2in1，因此 PC/2in1 专属端侧问答不能作为全设备默认实现。可先设计模型无关的 ChatRepository/RagGateway 接口，再按设备与服务能力提供实现和清晰降级。

### 12.8 代表性官方页面

- [Data Augmentation Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/dataaugmentation-introduction)
- [知识加工](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-knowledge-processing)
- [RAG概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-rag-overview)
- [知识问答](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-rag-development)
- [RAG配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-rag-config)
- [智慧化数据检索-ArkTS](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/dataaugmentation-retrieval)
- [端侧问答模型](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/dataaugmentation-localchatmodel)

## 13. Form Kit：桌面/锁屏服务卡片与应用直达

[官方事实] 本子类共 51 页。直接子菜单全部为：Form Kit简介、ArkTS卡片开发（推荐）、JS卡片开发、Form Kit术语。

### 13.1 卡片不是普通应用内组件

[官方事实] Form Kit 用于把应用重要信息或常用操作显示在桌面、锁屏等系统宿主中，支持 Phone、Tablet、PC/2in1、TV、Wearable、Car，不支持轻量级智能穿戴设备。卡片不能作为普通组件嵌入应用页面；应用页面仍由 ArkUI/Navigation 构建。

[官方事实] 系统包含卡片使用方、卡片提供方、卡片管理服务和卡片渲染服务。普通应用通常是卡片提供方；桌面等系统应用是使用方。ArkTS 卡片页面在系统卡片渲染服务中运行，与应用 UIAbility、FormExtensionAbility 都不是同一个页面实例。

[官方事实] 卡片提供方主进程和 FormExtensionAbility 进程内存隔离，但共享应用文件沙箱。卡片渲染实例由系统管理；同一提供方的卡片运行在同一 ArkTS 虚拟机环境，不同提供方之间隔离，因此不应依赖 globalThis 保存单张卡片私有状态。

### 13.2 创建、配置与生命周期

[官方事实] ArkTS 卡片可与应用共包，也可从 API 20 起使用独立卡片包。独立包中应用包与卡片包是两个模块，安装时需保持版本匹配。

[官方事实] 卡片唯一身份由 bundleName、moduleName、abilityName、formName、formDimension 五元组确定。五元组不建议引用会变化的资源 ID；升级时五元组变化会使系统把它视为另一张卡片，已有桌面卡片可能被删除。单个配置最多定义 16 个卡片。

[官方事实] FormExtensionAbility 提供 onAddForm、onUpdateForm、onRemoveForm、onFormEvent、配置变化等回调。该 Extension 进程不能常驻，生命周期调度结束后通常只继续存在约 10 秒；超过此时间的长业务应拉起主应用或交给合适后台机制，再通过 updateForm 更新卡片。

[解释] 卡片生命周期是“系统需要数据时短暂唤起提供方”，不是后台服务。网络、数据库或图片加载必须有超时、缓存和旧数据回退，不能假设进程会一直等待请求完成。

### 13.3 刷新、事件与数据

[官方事实] 卡片刷新分主动和被动。应用可用 updateForm 主动更新自己的卡片；系统可根据配置触发定时、定点或网络恢复刷新。定时刷新和定点刷新同时配置时有优先级规则，系统还会结合可见性与刷新次数决定是否真正调度。

[官方事实] 卡片与提供方是独立进程，提供方推送的数据由卡片通过 LocalStorageProp 接收，并会转换为字符串。卡片的领域状态应在提供方持久化，卡片仅持有足够渲染的数据快照。

[官方事实] 动态卡片使用 postCardAction、静态卡片使用 FormLink，均可表达 router、call、message 三类事件：router 跳转到本应用 UIAbility；call 拉起 UIAbility 到后台并调用指定方法；message 唤起 FormExtensionAbility 的 onFormEvent。call 后若要持续后台工作，仍需按后台任务规范申请，不会自动获得后台豁免。

[解释] 事件送达不等于业务完成。卡片点击后应显示处理中、完成、失败或等待打开应用的真实状态，并处理重复点击与消息重放。

### 13.4 锁屏、透明背板和互动卡片

[官方事实] 锁屏卡片从 API 18 起支持，尺寸和内容受额外限制，不建议展示隐私敏感数据，并需要按开放能力、签名和上架流程接入。背板透明卡片从 API 22 起支持，真机效果不能由 Previewer 代替，也需要开放能力审核。互动卡片从 API 20 起提供趣味交互或场景动效，但业务不能强依赖互动动效才能完成。

[解释] 高级卡片能力通常同时包含 API、设备、设计规范、开放权益和上架审核五道门。能编译只是第一道门。

### 13.5 工程维度检查

| 维度 | Form Kit 工程结论 |
|---|---|
| 生命周期 | FormExtensionAbility 回调短暂运行；初始化、更新、删除、事件和进程退出均可重入。 |
| 并发 | 同一 formId 更新串行，重复事件幂等；主应用与 Extension 不并发覆盖同一记录。 |
| 状态 | 区分占位、缓存、刷新中、已过期、离线、需登录、失败和已更新。 |
| 路由 | 卡片 router/call 进入认证壳后再定位业务；不能绕过登录、租户与角色检查。 |
| 数据 | formId 与业务对象映射持久化；onRemoveForm 清理映射；卡片只接收最小字符串快照。 |
| 权限 | 核对卡片类型、锁屏/透明/互动开放能力、签名、通知和后台任务要求。 |
| 性能 | 限制卡片数据、图片、字体和动效；避免每次刷新启动重网络或大数据库扫描。 |
| 错误处理 | 进程超时、刷新未调度、数据过期、应用未登录、版本不匹配均有明确展示。 |

### 13.6 给编程 AI 的检查单

- [ ] 确认需求是系统桌面/锁屏卡片，而不是普通应用内卡片 UI。
- [ ] 五元组稳定，FormExtensionAbility metadata 与 form_config.json 一致，配置不超过 16 个。
- [ ] FormExtensionAbility 回调保持短小，不在其中等待超过约 10 秒的业务。
- [ ] formId 与业务记录持久化，并在 onRemoveForm 清理。
- [ ] updateForm 数据最小化，卡片端按字符串类型安全解析并提供缺省值。
- [ ] router、call、message 的权限、目标、重复点击和完成反馈分别实现。
- [ ] 锁屏内容不泄露隐私；透明背板和互动能力完成真机、签名与开放权益核验。
- [ ] 卡片刷新测试包含系统未调度、离线、进程重建、主题/语言变化和应用升级。

### 13.7 当前项目适配

[项目适配] 当前项目没有 FormExtensionAbility 或 form_config.json。若未来提供护理工作台卡片，卡片只能展示经过授权的摘要，例如本人待办数量或班次状态；不得在锁屏直接显示居民姓名、诊断、用药和告警详情。

[项目适配] 卡片点击进入应用时应先经过真实认证和角色授权，再由 MainPage 的共享 NavPathStack 打开目标业务。当前“选择角色字符串即登录”的 mock 行为不能作为卡片深链的安全边界。

[项目适配] 卡片数据必须来自未来的 TaskRepository/ResidentRepository 等真实数据层，而不是直接复制 WideHomePage 或 TabPageView 的内存数组。卡片显示的“已完成”也必须以持久化业务结果为准。

### 13.8 代表性官方页面

- [Form Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/formkit-overview)
- [ArkTS卡片概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-form-overview)
- [创建ArkTS卡片](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-widget-creation)
- [配置ArkTS卡片的配置文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-widget-configuration)
- [管理ArkTS卡片生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-widget-lifecycle)
- [ArkTS卡片页面刷新概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-widget-interaction-overview)
- [ArkTS卡片页面交互概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-widget-event-overview)
- [锁屏卡片开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-lockscreen-form-development)
- [背板透明卡片开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-ui-transparent-backplate-form-development)

## 14. IME Kit：输入法应用、自绘编辑框与安全模式

[官方事实] 本子类共 12 页。直接子菜单全部为：IME Kit简介、实现一个输入法应用、在自绘编辑框中使用输入法、切换输入法应用、输入法子类型开发指南、输入法安全模式介绍、在自绘编辑框中使用输入法开发指导 (C/C++)、输入法应用沉浸模式、Ime工具、不可获焦窗口中输入框与输入法交互指南、输入法开发服务术语。

### 14.1 先区分三个场景

[官方事实] IME Kit 建立编辑框应用与输入法应用之间的通信，也提供输入法管理能力。普通应用使用 ArkUI TextInput/TextArea 时，系统已负责与输入法协作，通常不需要创建 InputMethodExtensionAbility。

[官方事实] 只有开发一款输入法应用时，才需要实现 InputMethodExtensionAbility、软键盘 Panel、候选区、子类型和输入法服务接口。只有开发 Canvas/XComponent 等自绘编辑器时，才需要直接使用 InputMethodController 绑定输入法并实现插入、删除、选择、光标和编辑状态同步。

[解释] “想自定义输入框外观”不等于“自绘文本编辑器”。能用标准 TextInput 加样式、输入类型和事件完成时，应保留系统现成的焦点、无障碍、选择、剪贴板和 IME 行为。

### 14.2 输入法 Extension 与子类型

[官方事实] InputMethodExtensionAbility 首次创建触发 onCreate，再次启动已存在服务不会重复触发；销毁时 onDestroy 用于取消监听和释放 Panel 等资源。module.json5 中需配置 type=inputMethod、导出状态和固定 metadata 资源。

[官方事实] 一个输入法应用只需一个 InputMethodExtensionAbility，多种语言或布局通过输入法子类型配置，共享同一 Extension。子类型的 id、locale、label、icon 和模式必须稳定，切换接口部分只允许当前输入法应用调用。

[官方事实] 输入法 Panel 支持固定态、悬浮态和候选词/状态栏等形态。前台编辑框还可向输入法传递沉浸模式期望，最终显示模式由输入法应用结合自身能力决定。

### 14.3 自绘编辑框与焦点

[官方事实] 自绘编辑框在获得焦点时通过 InputMethodController attach，向输入法提供 TextEditorProxy/编辑属性并接收编辑操作；失焦、组件隐藏或销毁时必须 detach 并注销回调。Native 路径同样需要创建代理、绑定选项并释放对象。

[官方事实] 不可获焦窗口无法正常接收键盘输入。需要在悬浮窗等不可获焦窗口显示输入框时，应按官方子窗和焦点转移方案设计，不能只调用 showSoftKeyboard 强行弹出键盘。

[解释] 文本、选区、光标和 composing 区域是一组原子编辑状态。自绘编辑器如果只维护一个字符串，会在中文拼音、候选词、Emoji、组合字符、撤销和选区替换时出现错误。

### 14.4 基础模式与完整体验模式

[官方事实] 输入法安全模式分基础模式和完整体验模式。基础模式严格限制网络、剪贴板、相机、麦克风、定位、账号、健康数据、分布式能力等可能泄露输入内容的系统能力，也不能拉起其他 UIAbility/ExtensionAbility；输入法 Extension 只能使用完成基础输入所需的能力。

[官方事实] 基础模式下 Extension 对共享沙箱只读，对自身独立沙箱可读写；完整体验模式下共享沙箱可读写。开发者应在 onCreate 查询安全模式并隐藏不支持的功能，不得尝试绕过基础模式把输入数据传出进程。

### 14.5 工程维度检查

| 维度 | IME Kit 工程结论 |
|---|---|
| 生命周期 | Extension、Panel、编辑器 attach/detach、焦点、监听和安全模式变化对称处理。 |
| 并发 | 输入法回调按编辑版本应用；异步建议词不得覆盖用户后续输入和选区。 |
| 状态 | 文本、选区、光标、composing、键盘显示、子类型和安全模式分别建模。 |
| 路由 | 输入法 Extension 不作为普通页面入口；基础模式禁止借输入事件拉起其他组件。 |
| 数据 | 默认不记录输入内容；词库、学习数据和共享沙箱定义最小化与清除策略。 |
| 权限 | 切换/管理接口、系统 API、基础模式和完整模式限制逐项核验。 |
| 性能 | 按键到回显低延迟，候选计算下沉，Panel 不因大状态树频繁重建。 |
| 错误处理 | attach 失败、焦点丢失、Extension 重建、模式受限和输入法切换可恢复。 |

### 14.6 给编程 AI 的检查单

- [ ] 普通表单优先用 TextInput/TextArea，不无理由实现输入法或自绘编辑器。
- [ ] 输入法应用的 Extension、metadata、子类型和 Panel 配置完整且稳定。
- [ ] 自绘编辑框把 attach/detach 与真实焦点、可见性和销毁绑定。
- [ ] 文本、选区、光标和 composing 状态同步，正确处理 Emoji 与组合字符。
- [ ] 基础模式下不访问网络、剪贴板、账号或其他受限能力，并提供功能降级。
- [ ] 异步候选或联想结果带版本号，过期结果不覆盖新输入。
- [ ] 在真机验证软键盘避让、旋转、外接键盘、输入法切换、中文组合输入和无障碍。

### 14.7 当前项目适配

[项目适配] 当前项目是养老工作台，不是输入法产品。登录、搜索、表单和 AI 输入应继续使用标准 ArkUI 输入组件；不要为了定制视觉创建 InputMethodExtensionAbility。

[项目适配] 当前 WindowUtil 已跟踪 keyboardHeight。新增输入区域时应复用实时键盘避让与根窗口 owner，验证输入法出现/隐藏、横竖屏和 2in1 物理键盘，而不是固定增加底部 padding。

[项目适配] 若未来出现签名板、Canvas 病历编辑器等真正自绘输入场景，再单独设计 TextEditorProxy、选区、composing、无障碍和 attach/detach；不要把普通 Text 组件伪装成可编辑框。

### 14.8 代表性官方页面

- [IME Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-intro)
- [实现一个输入法应用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/inputmethod-application-guide)
- [在自绘编辑框中使用输入法](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/use-inputmethod-in-custom-edit-box)
- [输入法子类型开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/input-method-subtype-guide)
- [输入法安全模式介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-security)
- [输入法应用沉浸模式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/inputmethod-immersive-mode-guide)
- [不可获焦窗口中输入框与输入法交互指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/use-inputmethod-in-not-focusable-window)

## 15. IPC Kit：设备内 Binder IPC 与跨设备 RPC

[官方事实] 本子类共 6 页。直接子菜单全部为：IPC Kit简介、IPC与RPC通信开发指导(ArkTS)、IPC与RPC通信开发指导(C/C++)、远端状态订阅开发实例、IPC与RPC通信术语。

### 15.1 Proxy/Stub 模型与能力边界

[官方事实] IPC 使用 Binder 驱动，面向单设备跨进程通信；RPC 使用软总线，面向跨设备跨进程通信。两者采用客户端 Proxy、服务端 Stub 模型，客户端通常先通过 Ability Kit 的连接能力获得代理对象，再编码请求、发送、解码应答。

[官方事实] 单设备 IPC 单次传输数据最大为 200KB；超过限制的数据应考虑匿名共享内存、文件或业务分片，而不是继续向 Parcel 填充。跨设备 RPC 还有网络、组网、设备身份、连接中断和代理不可二次传递等额外限制。

[解释] IPC 是进程隔离后的协议，不是“更高级的函数调用”。接口码、数据顺序、类型、版本、超时、权限和错误码共同构成协议；客户端和服务端必须能够独立升级和拒绝非法数据。

### 15.2 第三方应用限制

[官方事实] ArkTS 指南对普通第三方应用实现通用跨进程服务有严格限制：第三方应用通常只能连接系统提供的 ServiceExtensionAbility。API 20 起在 2in1 上可按 AppServiceExtensionAbility 的开放范围实现应用服务通信；三方应用间还可按场景使用动态公共事件。

[解释] 因此不能看到 IPC API 就为两个普通页面创建 ServiceExtensionAbility。是否允许服务端实现，要按应用类型、设备、组件类型、权限和 SDK 开放范围逐项核对。

### 15.3 连接、死亡通知与清理

[官方事实] 连接回调至少包含连接成功、连接失败和断开。连接成功后保存 Proxy 并注册 DeathRecipient；结束通信时先取消死亡监听，再断开连接并清空本地代理。远端进程退出或 RPC 软总线断开时，onRemoteDied 用于清理状态和触发重连/降级。

[官方事实] RPC 不支持未向 SAMgr 注册的匿名 Stub 死亡通知，IPC 支持；反向死亡通知仅限设备内 IPC。Proxy/Stub 对象的可传递范围也受限制，不能把远端 Proxy 任意回传或跨进程二次传递。

[解释] 死亡通知只表示连接对象不可用，不表示上一次业务请求是否执行成功。涉及写操作时应使用请求 ID、幂等键和服务端查询接口判断结果。

### 15.4 工程维度检查

| 维度 | IPC Kit 工程结论 |
|---|---|
| 生命周期 | 连接、Proxy、Stub、DeathRecipient、Parcel 和共享内存均有 owner 与释放路径。 |
| 并发 | 请求码和序列号对应；并发请求不共享可变 Parcel；回调线程不直接修改 UI。 |
| 状态 | 区分未连接、连接中、已连接、远端死亡、重连中、版本不兼容和权限拒绝。 |
| 路由 | IPC 不承担页面导航；服务返回业务结果后由前台 store 驱动 Navigation。 |
| 数据 | 协议字段有版本和长度限制；单设备超过 200KB 改用文件/共享内存/分片。 |
| 权限 | 先验证第三方开放范围、组件类型、exported、连接权限和跨设备权限。 |
| 性能 | 减少高频小调用和大对象序列化，批量读取但不越过载荷上限。 |
| 错误处理 | 连接失败、远端死亡、软总线断开、超时、协议错误和重复请求均可恢复。 |

### 15.5 给编程 AI 的检查单

- [ ] 先证明必须跨进程/跨设备，不能用同进程 repository 或普通函数解决。
- [ ] 当前应用类型与设备允许实现/连接目标 Extension，不复制系统应用示例。
- [ ] Proxy/Stub 协议记录接口码、字段顺序、类型、版本、大小、错误码和权限。
- [ ] 单设备 IPC 载荷不超过 200KB；大数据走文件、共享内存或分片并做校验。
- [ ] 连接成功注册死亡监听，断开时注销；onRemoteDied 清理所有派生状态。
- [ ] 写操作有幂等键和结果查询，断连后不盲目重复。
- [ ] IPC 回调切回正确 UIContext/store，不持有销毁页面。
- [ ] 真机验证进程被杀、服务升级、跨设备断网和重新组网。

### 15.6 当前项目适配

[项目适配] 当前 KangxiaobanAI 是单 entry HAP、单 UIAbility、本地 mock 数据，没有 ServiceExtensionAbility、独立业务进程或分布式服务。组件拆分和 feature 模块化不需要 IPC。

[项目适配] 若未来在 2in1 上引入独立后台服务或跨设备协同，先验证 AppServiceExtensionAbility/分布式能力的当前开放范围，再设计 repository 接口、协议版本、权限和断连降级。不得把 IPC 作为绕过当前巨型 UI 文件重构的手段。

### 15.7 代表性官方页面

- [IPC Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ipc-rpc-overview)
- [IPC与RPC通信开发指导(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ipc-rpc-development-guideline)
- [IPC与RPC通信开发指导(C/C++)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ipc-capi-development-guideline)
- [远端状态订阅开发实例](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/subscribe-remote-state)

## 16. Localization Kit：国际化、本地化、RTL 与语言测试

[官方事实] 本子类共 37 页。直接子菜单全部为：国际化和本地化概述、应用国际化、应用本地化、本地化测试、Localization Kit术语。

### 16.1 I18n 与 L10n 的职责

[官方事实] 国际化（I18n）是在设计和开发阶段避免假设单一语言、地区和文化，为日期、数字、货币、单位、电话、日历、排序、文字方向等提供通用实现。本地化（L10n）是针对具体目标市场翻译资源、检查敏感禁忌并做语言与布局测试。

[官方事实] UI 字符串、图片、音视频等应与代码逻辑分离到资源目录，由系统按语言、脚本、国家/地区和限定词匹配。区域 ID 基于 BCP 47，由语言、脚本、国家/地区和扩展参数组成；仅比较 zh、en 等语言码不足以表达完整文化习惯。

[官方事实] 应用可设置一种偏好语言，它只影响本应用，不改变系统语言；清除偏好后应用重新跟随系统。应用还应感知系统语言、区域、时制和用户偏好变化，并对注册的公共事件监听做对称退订。

### 16.2 格式化而不是拼字符串

[官方事实] 时间日期使用 Intl.DateTimeFormat、相对时间和时间段格式化；数字、货币和单位使用 Intl.NumberFormat 与单位转换；电话号码使用 PhoneNumberFormat；日历可选择公历、农历等历法并设置时区、一周起始日等。

[官方事实] PhoneNumberFormat 的有效性判断是格式层能力，不验证号码所有权、运营商、联系人身份或真实性。业务身份校验仍需独立流程。

[官方事实] 夏令时跳变日可能只有 23 小时或 25 小时，并会出现本地挂钟时间的空缺或重复。持续时长应按时间戳计算，日程应保存时区/区域语义，不能假设“一天永远是 24 小时”或把本地显示字符串当时间主键。

[官方事实] 多语言排序应使用 Intl.Collator；联系人等长列表可用 IndexUtil 生成符合本地习惯的索引。Unicode 字符类别、音译和转拼音可辅助检索，但多音字可能转换不准确，不能把拼音结果当作姓名权威读音。

### 16.3 可翻译 UI 与 RTL

[官方事实] 翻译后文本可能显著变长，界面应使用弹性布局、换行和合理最小/最大尺寸。RTL 语言需要用 start/end 等逻辑方向替代 left/right，并检查布局、方向性图标、滑动含义、返回方向和混合双向文本。

[官方事实] 应避免硬编码和直接拼接可翻译字符串。包含变量的完整句子应使用资源占位符；单复数使用资源的复数规则。给译员提供上下文、词性、变量含义、长度限制和界面截图，不能只交付孤立词条。

[解释] 同一个中文词在按钮、标题、状态和动词中可能需要不同翻译。为了少建资源而复用同一短词，会让翻译失去上下文并产生错误。

### 16.4 本地化测试

[官方事实] 伪本地化用于在正式翻译前发现硬编码、字符串拼接、截断、缺字和 RTL 问题。翻译伪本地化可使用 en-XA，镜像测试可使用 ar-XB；切换测试区域的接口属于系统能力，普通应用依赖系统环境切换后进行测试。

[官方事实] 最终语言测试应由熟悉当地语言和文化的人员检查准确性、一致性、语气、布局、敏感词和当地习惯。机器翻译或开发者自测不能替代本地语言审校。

### 16.5 工程维度检查

| 维度 | Localization 工程结论 |
|---|---|
| 生命周期 | 语言、区域、时区和时制监听按应用/页面 owner 注册并退订，变化后刷新派生文本。 |
| 并发 | 后台格式化或资源加载结果携带 locale 版本，语言切换后拒绝旧结果。 |
| 状态 | 原始领域值与本地化展示字符串分离；切换语言不改业务数据。 |
| 路由 | 路由名和参数不依赖翻译文本；返回、手势和 Tabs 顺序在 RTL 下正确。 |
| 数据 | 时间保存时间戳/时区，数字保存数值/单位，电话保存规范化值；展示时再格式化。 |
| 权限 | 多数格式化无需危险权限，但伪区域切换和部分系统设置接口有应用范围限制。 |
| 性能 | 缓存格式化器而不是缓存最终字符串；大列表只重算受 locale 影响的字段。 |
| 错误处理 | 缺失资源、超长译文、不支持 locale、非法时间/号码和字体缺字有回退。 |

### 16.6 给编程 AI 的检查单

- [ ] 所有用户可见字符串进入资源文件，不硬编码、不拼接半句。
- [ ] 日期、数字、货币、单位、电话和排序调用国际化接口，不手写格式。
- [ ] 领域层保存原始数值、时间戳、时区和单位，不保存本地化字符串作为真相。
- [ ] 使用 start/end、弹性布局和语义化图标，验证 RTL、超长文本和大字体。
- [ ] 复数、占位符和翻译上下文完整，变量顺序可由译文调整。
- [ ] 应用偏好语言与系统语言变化后，资源、格式化器和缓存同步更新。
- [ ] en-XA、ar-XB、目标语言真机和本地语言审校均进入验收。
- [ ] 不把拼音、电话格式有效性或机器翻译当成业务身份/语义验证。

### 16.7 当前项目适配

[项目适配] 当前产品主要面向中文界面，但 phone/tablet/2in1、多角色和养老术语仍应从现在开始保持资源化。新增按钮、状态、错误和无障碍文本不得继续散落为硬编码字符串。

[项目适配] WideCaregiverWorkspace、WideResidentPage、WideMessagePage 和医生入院流程包含大量固定宽度与密集业务文本。任何国际化改动都要验证窄屏换行、XL 双列布局、HDS 标题栏、表单错误、风险卡片和固定 footer，不只检查首页。

[项目适配] 时间、用药、任务、交接和生命体征将来接入真实数据时，必须保存明确时区与单位；界面按用户区域格式化。不得把当前 mock 中的中文日期字符串直接升级为后端字段。

### 16.8 代表性官方页面

- [国际化和本地化概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-l10n)
- [国际化界面设计](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-ui-design)
- [应用偏好语言](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-preferred-language)
- [时间日期国际化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-time-date)
- [数字与度量衡国际化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-numbers-weights-measures)
- [时区](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-time-zone)
- [夏令时跳变](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/i18n-dst-transition)
- [多语言适配](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/l10n-multilingual-resources)
- [避免硬编码与拼接](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/l10n-hard-coding-concatenate)
- [伪本地化测试概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pseudo-i18n-testing-overview)

## 17. UI Design Kit：HDS 组件、材质、光效与一致体验

[官方事实] 本子类共 46 页。直接子菜单全部为：UI Design Kit简介、图标处理、组件导航、侧边栏样式、侧边栏菜单样式、底部页签、即时操作、核心操作栏、列表、应用加载自定义Symbol、视效、应用内多窗、沉浸光感、颜色选择与收藏管理、UI Design Kit常见问题。

### 17.1 HDS 与 ArkUI 的关系

[官方事实] UI Design Kit 是符合 HarmonyOS Design System 的增强 UI 套件，提供 HdsNavigation/HdsNavDestination、HdsSideBar、HdsSideMenu、HdsTabs、HdsSnackBar、HdsActionBar、HdsListItemCard、图标/Symbol、应用内多窗、光效、材质和颜色选择等能力。它建立在 ArkUI 的布局、状态、滚动、窗口和渲染基础上，不替代 ArkUI。

[官方事实] 本 Kit 当前仅支持中国境内，不含香港特别行政区、澳门特别行政区和中国台湾。支持模拟器开发，但模拟器不支持 HDS 沉浸视效，包括点光源、按压阴影、双边流光、背景流光和沉浸光感材质；这些结论必须真机验证。

[解释] HDS 组件能统一视觉与交互，但不会自动解决导航所有权、异步状态、无障碍、权限或业务数据。错误的数据流套上 HDS 外观仍然是错误实现。

### 17.2 HdsNavigation 与滚动材质

[官方事实] HdsNavigation 支持标题、菜单、信息提醒、自定义 stackBuilder/bottomBuilder、动态显隐、半模态标题栏、图标类型和应用内多窗入口。标题栏模糊效果需要绑定真实可滚动容器，支持通用模糊、过渡模糊和渐变模糊等模式。

[官方事实] 一个 Navigation 对应一个 NavPathStack。HdsNavigation 的标题栏虽然可自定义区域，但返回按钮、标题、菜单、滚动绑定和安全区仍由导航组件统一协调；自定义节点过多可能产生遮挡、交互冲突和性能问题。

[解释] “跟随滚动的材质标题栏”必须绑定当前用户实际滚动的 Scroller。列表/详情分栏、Tab 保活和页面切换时，错误 Scroller 会造成材质不变化或响应隐藏页面。

### 17.3 HdsTabs、侧边栏与操作组件

[官方事实] HdsTabs 支持分割线、直接/渐变模糊、图标出血、纵向侧边页签、悬浮样式和迷你栏。悬浮页签与迷你栏从 API 23 起支持，依赖底部位置、水平布局、barOverlap 和受支持的 TabBar 样式。

[官方事实] HdsSideBar/HdsSideMenu 用于确有侧边导航层级的场景，支持 overlay/embed 与一二级菜单。HdsSnackBar 适合轻量、非模态反馈；HdsActionBar 用于核心操作组合；HdsListItemCard 提供一致列表卡片和横滑操作。

[解释] 组件类型由信息架构决定。宽屏出现不意味着必须加侧边栏，成功提示也不意味着所有操作都弹 SnackBar；应先判断导航层级、操作可逆性和反馈持续时间。

### 17.4 图标、光效、材质与版本

[官方事实] 图标处理支持推荐的分层图标和单层图标；批量处理最大并发数 10、单次最多 500 个。自定义 Symbol 注册只支持一组资源，最多 10 个自定义图标及动效参数资源。

[官方事实] 点光源、阴影、流光等沉浸视效从 API 20 等不同版本逐步开放。HDS 组件沉浸光感材质从 API 23 起支持，推荐使用系统自适应材质，让系统按设备算力调整效果。颜色选择与收藏管理从 API 26 起支持，对当前 API 24 项目属于未来能力。

[解释] 材质和光效必须有普通背景/模糊回退、深浅色对比和性能预算。多层半透明面板叠加会降低对比并增加渲染成本，不能因为 API 可用就全部开启。

### 17.5 无障碍与性能

[官方事实] HDS 图标和菜单仍需提供 label 等无障碍信息；焦点、键盘、Hover、Pressed、Disabled、Selected 状态仍需完整。HDS 不会替开发者补齐业务自定义 Builder 内的语义。

[解释] 动态模糊、光效、复杂 Builder 和预加载 Tabs 都会增加首帧、内存与持续渲染负担。验证应包括不支持材质的回退、模拟器与真机差异、低性能设备以及减少动态效果设置。

### 17.6 工程维度检查

| 维度 | UI Design Kit 工程结论 |
|---|---|
| 生命周期 | Navigation、TabsController、Scroller、Snackbar、ActionBar 和材质监听都有明确 owner。 |
| 并发 | 异步操作完成后再更新成功反馈；页面已离开时不向旧 HDS 组件发事件。 |
| 状态 | Selected、Pressed、Focused、Disabled、Loading、Error 与业务状态一致。 |
| 路由 | HdsNavigation 仍遵守一个 NavPathStack；SideBar/Tabs 是壳层导航，不制造第二套真相。 |
| 数据 | HDS 只消费 ViewModel 状态，不解析 DTO、SQL 或网络响应。 |
| 权限 | 核对中国地区、设备、API、开放能力和模拟器差异，不把组件可导入等同可交付。 |
| 性能 | 材质支持检测、普通回退、正确 Scroller、受控预加载，并测量帧率与内存。 |
| 错误处理 | 不支持材质/多窗/颜色选择时保留可操作 UI，不让按钮无响应。 |

### 17.7 给编程 AI 的检查单

- [ ] 先确认当前项目已使用 HDS 的代际与约定，不以普通 ArkUI 随意替换。
- [ ] 每个 HdsNavigation 只有一个 NavPathStack，返回、标题、菜单和目的地一致。
- [ ] 动态标题效果绑定当前可见且真实滚动的 Scroller，并在主从视图切换时更新。
- [ ] HdsTabs 的 controller、barOverlap、floating、safe area 和预加载策略完整。
- [ ] SideBar、Tabs、Navigation 和 Sheet 按信息架构选择，不重复表达同一层导航。
- [ ] Symbol、图标、菜单和自定义 Builder 有无障碍名称及键鼠焦点状态。
- [ ] 材质先检查 API/设备支持，提供普通背景与模糊回退，真机验证深浅色和性能。
- [ ] API 26 的 HdsColorPicker 不写入当前 API 24 产品代码。

### 17.8 当前项目适配

[项目适配] 当前产品已经使用 HdsNavigation、HdsTabs、HdsNavDestination、HdsListItemCard、HdsTabsController、BottomTabBarStyle 和系统材质。新页面应延续这些约定，而不是因为示例更短就换回普通 Navigation/Tabs。

[项目适配] MainPage 的根 HdsNavigation 是 authenticated shell 的单一导航 owner；手机标题栏和宽屏 caregiver 标题栏都属于它。不得在 WideCaregiverWorkspace 内再套结构性 Navigation，也不得把 About/General 等业务目的地拆成另一套 Router。

[项目适配] 宽屏 caregiver 使用连续 background_secondary 画布，没有结构性侧边栏。当前主导航是右上滑动胶囊，resident/message 在宽度足够时使用开放画布主从工作面；不能仅因为 HdsSideBar 存在就重建仪表盘式侧栏。

[项目适配] 根标题栏绑定当前可见的 Home、居民列表/详情或消息列表/对话 Scroller。新增页面必须加入这条绑定状态机；不能用自绘模糊 Row 代替 HDS 标题栏，也不能让隐藏的保活页面继续驱动材质。

[项目适配] 当前 API 24 可使用 API 23 的沉浸光感与悬浮页签，但仍需 MaterialUtil 支持检测和普通背景/模糊回退。模拟器不支持 HDS 沉浸视效，因此只看 Previewer 或模拟器不能声明材质、对比和性能通过。

### 17.9 代表性官方页面

- [UI Design Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-introduction)
- [组件导航](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-navigation)
- [设置动态模糊样式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-navigation-dynamic-blur)
- [侧边栏样式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-sidebar)
- [底部页签](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-tabs)
- [设置页签栏的悬浮样式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-tabs-bar-floating)
- [即时操作](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-snackbar)
- [核心操作栏](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-actionbar)
- [列表](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-list-item-card)
- [沉浸光感](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material)
- [颜色选择与收藏管理](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-color-picker-favorites)

## 18. 跨 Kit 实施工作流：从需求到可验证交付

### 18.1 第一步：把一句需求拆成能力图

[解释] 不要从组件名或 API 名开始。先把用户需求拆成“入口、界面、状态、数据、系统能力、后台、跨进程/跨设备、权限、失败、验证”十个维度。例如“给居民添加健康报告并让 AI 回答问题”至少涉及：

| 需求部分 | 主要 Kit/边界 |
|---|---|
| 选择报告 | Core File Kit 的 Picker 与 URI 授权 |
| 解析和持久化 | ArkTS 并发 + ArkData/repository |
| 展示报告 | ArkUI/HDS + Navigation |
| 建知识库 | Data Augmentation 知识加工 |
| 检索与生成 | Data Augmentation RAG + 应用自己的模型/网络层 |
| 敏感数据控制 | 认证、租户、字段最小化、日志脱敏，不由某一个 UI Kit 自动提供 |
| 退后台继续 | 只有业务真的符合时才选 Background Tasks |
| 分享或导出 | Core File Kit 的 URI/授权，不传绝对路径 |
| 卡片入口 | 只有桌面/锁屏需求才选 Form Kit |
| 失败恢复 | 文件授权失效、加工失败、空检索、模型失败、页面离开分别处理 |

[解释] 这一步的目标是识别边界，不是把所有 Kit 都引入。每个新增依赖都要有明确的不可替代理由。

### 18.2 第二步：建立工程指纹

[项目适配] 对 KangxiaobanAI，编程 AI 在修改前至少读取：

1. 根 build-profile.json5、oh-package.json5；
2. AppScope/app.json5；
3. products/entry/build-profile.json5、oh-package.json5、module.json5；
4. main_pages.json 与任何 router map；
5. EntryAbility → LoginPage → MainPage 启动链；
6. 目标 feature 的组件、模型、Scroller、NavPathStack、WindowUtil 与 PreferenceManager；
7. 当前 Git 状态和用户已有修改。

[解释] 工程指纹回答 API 版本、设备、应用模型、组件类型、权限、依赖和路由代际。没有这些信息，官方示例中的接口即使正确，也可能不适用于当前工程。

### 18.3 第三步：做 API 证据卡

每个新 API 至少记录：

| 字段 | 必填内容 |
|---|---|
| 能力目标 | 业务为什么需要它，是否有更简单的同进程/原生方案 |
| Kit 与 import | 精确模块、命名空间、类、方法、回调和参数 |
| 版本 | Kit、类、方法、枚举、字段各自的 since；当前 compatible/target SDK 是否满足 |
| 设备 | phone/tablet/2in1/TV/wearable/car 的支持差异 |
| 应用范围 | 普通应用、系统应用、企业开发者、元服务或开放权益限制 |
| SystemCapability | canIUse 或等价检查点，以及不支持时的降级 |
| 权限 | module.json5 声明、运行时授权、用户 Picker 授权、ACL/开放能力 |
| 线程与生命周期 | 可调用线程、Controller/Context 时机、资源 owner 与清理 |
| 错误 | BusinessError/错误码、超时、取消、重复调用和恢复 |
| 验证 | 静态、构建、真机、服务端和上架能力分别如何证明 |

[解释] 证据卡的价值是阻止“某个示例能运行，所以整个功能可用”的跳跃。API 参考、指南、当前 SDK 声明和同代本地样例要互相印证。

### 18.4 第四步：画 owner 与状态机

[解释] 每个长期对象都要回答“谁创建、谁持有、谁清理”：

| 对象 | 典型 owner |
|---|---|
| NavPathStack、根 HDS 标题栏、全屏窗口状态 | MainPage/authenticated shell |
| 页面 Scroller、局部 Sheet、表单草稿 | 对应 feature root 或 ViewModel |
| WebviewController、JSBridge、WebMessagePort | 独立 Web 页面/feature |
| fd、stream、Picker URI 授权 | 文件 use case/repository |
| RagSession、模型流、索引任务 | AI/RAG repository 或 session store |
| FormExtensionAbility 数据 | 卡片 provider repository |
| Background task requestId/workId | 后台任务调度层 |
| IPC Proxy/DeathRecipient | 服务连接 manager |

[解释] 状态机至少包含 idle/loading/success/empty/error/cancelled；涉及权限时增加 notDetermined/denied/permanentlyDenied；涉及同步时增加 localOnly/syncing/synced/conflict。不能只用一个 isLoading 和一个 success 布尔值表达全部情况。

### 18.5 第五步：按最小闭环实现

1. 先实现领域接口和 FakeRepository，保持现有 UI 行为；
2. 用 ViewModel/store 管理异步状态和取消；
3. 再接真实文件、数据库、网络、Kit 或 Extension；
4. 为不支持设备、权限拒绝、离线和服务失败实现可见降级；
5. 最后接入 UI 动效、HDS 材质、预加载和性能优化；
6. 每一步都保持可构建、可回滚并有最小行为测试。

[项目适配] 这与当前项目既定抽取顺序一致：先保行为，再 FakeRepository，再 ViewModel/UseCase，再 repository 接口和真实数据源，边界稳定后才考虑 HAR/HSP。

### 18.6 第六步：分层验证

| 证据层 | 能证明什么 | 不能证明什么 |
|---|---|---|
| 静态检查 | 配置、路由、类型、权限声明、owner 和代码路径存在 | SDK 真能构建、设备支持、服务可用 |
| 构建验证 | 当前 SDK/依赖下能产生产物 | 安装、运行、权限、UI 和服务正确 |
| Previewer/模拟器 | 部分布局和交互 | HDS 沉浸材质、真实性能、硬件/系统服务 |
| 真机验证 | 指定设备/系统上的 UI、权限和系统 Kit 行为 | 其他设备、其他版本、线上服务 |
| 服务验证 | 配置环境中的真实请求与数据语义 | 离线、弱网、账号/租户全覆盖 |
| 上架/权益验证 | 开放能力、签名和审核链成立 | 所有运行时业务都正确 |

[解释] 报告必须使用“Implemented、Build-verified、Device-verified、Service-verified、Planned”等明确词，不得用“完成”覆盖所有层级。

## 19. Codex / Claude 全局编程检查单

### 19.1 修改前

- [ ] 确认用户要求是解释、诊断、评审还是实现；只读请求不改代码。
- [ ] 确认唯一目标工程，样例工程保持只读。
- [ ] 读取当前 Git 状态，保留用户已有修改和生成文件。
- [ ] 读取应用、产品、模块、Ability、页面、路由和依赖配置。
- [ ] 追踪 mainElement、srcEntry、loadContent、根页面和目标 feature 调用链。
- [ ] 记录 target/compatible SDK、设备类型、ArkUI V1/V2、HDS 与权限基线。
- [ ] 在本地样例和本手册中搜索同代实现，再查当前官方指南/API。
- [ ] 为每个新 API 完成版本、SystemCapability、设备、应用范围和权限证据卡。
- [ ] 写出数据 owner、资源 owner、取消和销毁路径。
- [ ] 先写验收场景，包含成功、空、失败、离线、拒绝、重复、返回和进程重建。

### 19.2 实现中

- [ ] 核心组件默认使用 ArkUI V2 的 Local/Param/Event/Provider/Consumer/ObservedV2/Trace。
- [ ] 不把 View、DTO、SQL、文件协议、网络协议和模型请求混在同一个组件。
- [ ] 不继续扩大现有超大文件；按 feature/section、ViewModel 和 repository 拆分。
- [ ] 应用内业务使用共享 NavPathStack；Router 只保留既定认证壳边界。
- [ ] 新 Scroller 接入 HDS 标题栏真实绑定，隐藏页面不驱动材质。
- [ ] 异步操作带请求 ID/版本和取消，旧结果不覆盖新页面。
- [ ] 权限拒绝、系统能力缺失和服务失败显示真实状态，不伪造成功。
- [ ] 监听、Controller、fd、stream、Port、Proxy、RagSession 和定时任务全部对称清理。
- [ ] 用户可见字符串资源化，布局支持大字体、长文本、RTL、键盘和安全区。
- [ ] 机密凭证、健康数据、绝对路径和完整响应不写日志。

### 19.3 修改后

- [ ] 检查 JSON5、资源、pages、route map、Builder、参数和 module 配置一致。
- [ ] 运行静态检查、相关单元/组件/UI 测试和适当构建。
- [ ] 对受影响设备形态验证 phone、tablet、2in1 的窗口变化与输入方式。
- [ ] 权限测试覆盖首次请求、允许、拒绝、再次拒绝、设置中撤销。
- [ ] 生命周期测试覆盖前后台、返回、旋转/自由窗口、进程重建和快速重复操作。
- [ ] 数据测试覆盖空、部分、过期、冲突、离线和 schema 升级。
- [ ] 性能结论有同场景前后数据，不用“感觉流畅”代替。
- [ ] 输出只声明真实验证层级，列出未完成的真机、服务或上架验证。
- [ ] 最终 diff 只包含任务范围内文件，不覆盖用户其他改动。

### 19.4 AI 幻觉禁区

- 不凭记忆发明 HarmonyOS API、枚举、权限、错误码或 module.json5 字段。
- 不把 API 26 示例写入 API 24 工程而没有条件编译/版本降级。
- 不把普通应用能力说成系统应用能力，也不把企业/开放权益能力说成默认可用。
- 不把 Picker“无需申请权限”解释成任意文件访问。
- 不把后台任务、FormExtensionAbility、Web 离线组件或 IPC 当作保活方案。
- 不把 AppStorageV2、Want、卡片数据或 UI 状态当作业务数据库。
- 不把模型生成、RAG 引用或 mock 文本称为临床建议、真实服务结果或持久化记录。
- 不把 Previewer、模拟器截图、静态代码检查或编译成功称为真机验收。

## 20. 版本、SystemCapability、权限与开放范围矩阵

| 能力 | 官方门槛/关键约束 | 配置或权限 | 运行时必须验证 | 当前 API 24 项目结论 |
|---|---|---|---|---|
| ArkWeb 在线页面 | Web 实例、Controller 生命周期、渲染进程 | ohos.permission.INTERNET；其他硬件能力另算 | 域名、证书、弱网、渲染退出、JSBridge 来源 | 可规划；当前未接入 |
| 短时任务 | 同时最多 3 个；默认日配额 10 分钟、单次 3 分钟 | 后台任务接口及相关业务权限 | 配额、超时、系统终止、主动取消 | 当前无需求实现 |
| 延迟任务 | 最多 10 个；单次回调最长 2 分钟；非准点 | WorkSchedulerExtensionAbility 配置 | 实际调度、重启、条件变化、幂等 | 可用于未来可延迟同步 |
| 代理提醒 | 设备、应用分类、场景和权益管控 | 相应权限/开放能力申请 | 申请结果、提醒送达、用户关闭 | 不能默认用于用药提醒 |
| Content Embed | API 24；SystemCapability.ContentEmbed.ObjectEditor；Native C API | CONNECT_OBJECTEDITOR_EXTENSION / REGISTER_OBJECTEDITOR_EXTENSION | 客户端/服务端发现、权限、源文件、快照、编辑回传 | 版本满足，但当前没有业务与 Native 边界 |
| FilePicker | 用户通过系统 UI 选择具体文件 | 通常无需广泛存储权限；URI 临时/持久授权 | 退后台后授权、文件移动、空间、分享有效期 | 推荐未来附件入口 |
| 数据备份恢复 | BackupExtensionAbility、配置和迁移逻辑 | 备份范围、签名/上架映射等 | 自验证、端到端恢复、schema/账号 | 当前未接入 |
| Data Augmentation RAG | 先知识加工；应用实现 LLM；上下文与安全约束 | 常需 INTERNET；数据库/schema 配置 | 加工状态、召回、引用、模型、内容安全 | 可规划；当前 AI 为 mock |
| 端侧问答模型 | 当前 PC/2in1、企业开发者、模型管理 | INTERNET/隐私与模型下载流程 | 企业资格、设备、下载、内存、离线行为 | 不能覆盖 phone/tablet 默认路径 |
| Form 普通卡片 | FormExtensionAbility、五元组、系统宿主 | module/profile 配置 | 添加、刷新、进程重建、升级 | 当前未接入 |
| 锁屏/透明/互动卡片 | 分别有 API、设计、签名和开放权益门槛 | 手动签名/Profile/开放能力等 | 真机、审核、隐私、主题 | 不得只按示例启用 |
| 普通文本输入 | 标准 TextInput/TextArea | 通常无需 IME Extension | 键盘、焦点、避让、输入法切换 | 当前应使用此路径 |
| 自定义输入法 | InputMethodExtensionAbility、安全模式 | Extension/metadata；部分管理 API 受限 | 基础/完整模式、真机、外接键盘 | 当前产品不应引入 |
| IPC/RPC | Binder/软总线；单设备 200KB；三方服务端受限 | Ability 连接、组件/跨设备权限 | 连接、死亡通知、设备断开、协议版本 | 当前单进程无需 IPC |
| Localization | Locale/资源/Intl；伪区域切换为系统能力 | 多语言资源和限定词 | en-XA、ar-XB、目标语言、DST | 应从新代码开始资源化 |
| HDS 沉浸材质 | API 23；设备算力与系统支持；中国地区限制 | @kit.UIDesignKit；支持检测与回退 | 真机深浅色、性能、无材质回退 | API 24 可用，当前已采用 |
| HdsColorPicker | API 26；Phone/Tablet，并受取色能力约束 | UI Design Kit | 当前设备和 Pen/取色能力 | 当前 API 24 禁止直接使用 |

[解释] 表中权限名只说明指南出现的入口，不替代 API 参考中的权限等级、授权方式和应用开放范围。实施前仍需逐项查看当前 SDK 声明与 API 参考。

## 21. 来源导航与逐页核查附录

### 21.1 本地证据文件

| 文件 | 用途 |
|---|---|
| [FULL_PAGE_DIGESTS.md](../FULL_PAGE_DIGESTS.md) | 按官网菜单顺序记录全部 5,694 个正文页面；搜索任一页面标题、slug 或主题 |
| [menu-tree.md](../coverage/menu-tree.md) | 完整左侧菜单层级，确认每个子菜单是否进入 |
| [menu-inventory.csv](../coverage/menu-inventory.csv) | 菜单节点、父子关系、slug、URL、是否含正文 |
| [page-status.csv](../coverage/page-status.csv) | 每页状态、更新时间、内容哈希和结构统计 |
| [topic-statistics.csv](../coverage/topic-statistics.csv) | 按直接子类汇总页面、文字、代码、表、警告和图片 |
| [heading-index.csv](../coverage/heading-index.csv) | 搜索所有页面章节标题 |
| [code-source-index.csv](../coverage/code-source-index.csv) | 查找代码块来源页、语言和位置 |
| [admonition-index.csv](../coverage/admonition-index.csv) | 集中查找官方说明、注意和警告 |
| [crawl.sqlite3](../coverage/crawl.sqlite3) | 菜单、页面元数据、摘要、结构化抽取、原始文本和 HTML |
| [audit-report.md](../coverage/audit-report.md) | SQLite、菜单页集合、成功数、哈希与二次目录基线审计 |

### 21.2 给人类与 AI 的检索顺序

1. 先在本章确定属于哪个 Kit、能力边界和项目规则；
2. 在 FULL_PAGE_DIGESTS.md 搜索页面标题、接口名或错误关键词；
3. 在 admonition-index.csv 查限制、警告、版本和设备说明；
4. 在 code-source-index.csv 找官方代码块的真实来源；
5. 在 page-status.csv 获取精确 URL、更新时间和内容哈希；
6. 回到当前官方页面与 API 参考核对 since、SystemCapability、权限和错误码；
7. 再检查当前 SDK 声明和本地同代样例；
8. 最后才能写入产品代码。

### 21.3 可直接使用的本地命令

    rg -n "onControllerAttached|RagSession|FormExtensionAbility" docs/huawei-harmonyos-guides-complete-2026-08-10/FULL_PAGE_DIGESTS.md

    rg -n "权限名|SystemCapability|API version 24" docs/huawei-harmonyos-guides-complete-2026-08-10/coverage/admonition-index.csv

    rg -n "页面标题|slug" docs/huawei-harmonyos-guides-complete-2026-08-10/coverage/page-status.csv

    sqlite3 docs/huawei-harmonyos-guides-complete-2026-08-10/coverage/crawl.sqlite3 "select title, requested_url, summary from pages where slug='目标slug';"

[解释] FULL_PAGE_DIGESTS.md 的菜单路径、章节线索和哈希用于定位，不应替代完整官方正文。实现 API 时必须回到当前页面与 API 参考；如果官网已更新，应以当前内容重新核对。

## 22. 最终覆盖结论与使用路线

### 22.1 覆盖结论

[官方事实] 本章已覆盖“开发 > 应用框架”全部 15 个直接子类：Ability Kit、Accessibility Kit、ArkData、ArkTS、ArkUI、ArkWeb、Background Tasks Kit、Content Embed Kit、Core File Kit、Data Augmentation Kit、Form Kit、IME Kit、IPC Kit、Localization Kit、UI Design Kit。

[官方事实] 这 15 个子类合计 1,090 个正文页面，全部在逐页结构索引和 SQLite 中有独立记录；全站指南抓取审计为 5,694/5,694 成功、失败 0、待读取 0，菜单正文 slug 集合与页面集合一致，并完成第二次目录基线核对。

[解释] “覆盖全部页面”表示每个菜单正文节点均已发现、读取、结构化抽取、摘要并纳入可审计索引；不表示本章复制了 670 万字原文，也不表示所有 API 已在当前项目真机运行。工程使用时仍按第 21 节回到对应原页与 API 参考。

### 22.2 人类阅读路线

- 只想建立整体认识：读第 0～2 节，再读与你任务相关的 Kit“能力边界”和“当前项目适配”。
- 要实现功能：先读对应 Kit 全章，再执行第 18 节跨 Kit 工作流和第 20 节矩阵。
- 要审查 AI 代码：直接使用第 19 节检查单，并在第 21 节追溯 API 来源。
- 要核对某一子菜单：在 FULL_PAGE_DIGESTS.md 搜索标题或 URL，查看该页独立摘要、章节、统计和哈希。

### 22.3 Codex / Claude 最小上下文包

向编程 AI 分派 HarmonyOS 任务时，至少提供：

1. 用户目标与禁止事项；
2. 当前工程 AGENTS.md；
3. app.json5、module.json5、build-profile.json5、oh-package.json5；
4. 启动链、目标页面、NavPathStack 和状态 owner；
5. 本章对应 Kit 小节；
6. 目标官方页面/API 参考；
7. 当前 Git diff；
8. 需要达到的验证层级。

### 22.4 本章的验证边界

- 已验证：官网菜单范围、页面读取成功、页面数量、结构统计、逐页结构索引、15 个应用框架 Kit 的工程综合。
- 已验证：当前项目的静态配置、target API 24、compatible API 23、Stage/ArkUI V2/HDS 基线和本章使用的项目架构边界。
- 未由本章验证：新增功能构建、签名、安装、真机行为、权限审批、AGC/后端服务、跨设备组网、上架权益和性能指标。
- 后续任何实现都应在交付报告中重新声明实际完成的验证层级。
