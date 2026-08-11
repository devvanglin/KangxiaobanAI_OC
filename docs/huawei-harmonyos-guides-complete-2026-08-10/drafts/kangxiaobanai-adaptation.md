# KangxiaobanAI 项目适配章：给 Codex、Claude 与人类开发者的源码落地指南

> 核验日期：2026-08-10  
> 适用目录：`D:\Coding\KangxiaobanAI_OC\KangxiaobanAI`  
> 交付性质：当前工作树的只读、源码可定位适配说明  
> 当前证据等级：**静态确认**；本章没有执行构建、没有安装 HAP、没有真机操作、没有连接后台服务  
> 安全边界：签名配置的具体内容不属于本章审视范围，任何 AI 都不得回显、复制、总结或提交证书路径、口令、密钥等信息

本章不是对 HarmonyOS 官方文档的替代，而是把官方主题映射到当前 `KangxiaobanAI` 工程。它回答四个实际问题：

1. 当前工程究竟是什么，而不是什么；
2. 官方知识点应该落到哪些配置、类、组件和状态边界；
3. Codex、Claude 等编程 AI 修改项目时必须保留哪些既有约束；
4. 修改完成后，什么只能称为静态确认，什么才可以称为构建、真机或服务确认。

文中的 `路径:行号` 对应 2026-08-10 当前工作树。工作树在检查时并不干净，因此本章描述的是**当前检出内容**，不是对 `origin/main` 或某个历史提交的替代声明。行号会随代码变化而漂移，使用时应先搜索符号，再核对上下文。

为减少重复，后文以 `pages/...`、`component/...`、`model/...`、`util/...`、`entryability/...` 开头的短路径，默认都相对于 `KangxiaobanAI/products/entry/src/main/ets/`；配置文件仍写出从 `KangxiaobanAI/` 开始的完整仓库路径。

---

## 1. 先统一证据语言

### 1.1 四种确认不能混用

| 标签 | 可以证明什么 | 不能证明什么 |
| --- | --- | --- |
| 静态确认（Static-confirmed） | 配置字段、导入、调用链、状态所有权、路由声明、源码中是否存在某类实现 | 代码一定能编译；运行时一定进入该路径；设备行为和性能正确 |
| 构建确认（Build-verified） | 某个明确工作树、SDK、构建模式下，编译/打包成功并产生对应产物 | HAP 在目标设备上可用；触摸、键鼠、窗口、安全区、服务行为正确 |
| 真机确认（Device-verified） | 在注明型号、系统版本、窗口形态、输入方式下实际验证了行为 | 后台数据真实落库；其他设备形态也自动通过 |
| 服务确认（Service-verified） | 对配置好的 AGC/后台/API/模型服务做了真实请求，并验证成功、失败、超时、权限和数据一致性 | 离线、跨版本、所有设备体验均已通过 |

本章只使用“静态确认”。如果后续文档或 AI 回答写“已经支持手机、平板、2in1”，必须继续说明它指的是 `deviceTypes` 声明与静态布局分支，还是已经在具体真机上验证。

### 1.2 当前扫描范围

已静态读取的主要范围：

- 根产品配置：`KangxiaobanAI/build-profile.json5`、`AppScope/app.json5`、根 `oh-package.json5`；
- entry 模块：模块 `build-profile.json5`、`oh-package.json5`、`module.json5`、`main_pages.json`；
- 启动与窗口：`EntryAbility.ets`、`WindowUtil.ets`、`BreakpointSystem.ets`、`GlobalInfoModel.ets`；
- 认证与根壳：`LoginPage.ets`、`MainPage.ets`；
- 手机与宽屏核心页面、AI、消息、入住办理、设置持久化和模板测试；
- 生产源码中网络、WebSocket、RDB、Repository、V1 状态装饰器、route map、权限声明的存在性扫描。

没有把 `build`、`oh_modules`、`.hvigor`、IDE 缓存或其他顶层样例工程当成当前产品事实。

---

## 2. 工程身份与固定配置基线

### 2.1 当前交付目标

默认交付目标是 `KangxiaobanAI`。同级样例工程是 API/架构/交互参考，不是可以整体搬入产品的并列业务模块。AI 修改代码时应先在当前工作区查找同代实现，再抽取最小模式适配到产品的 ArkUI V2/HDS 结构。

当前产品从源码上应定义为：**HarmonyOS NEXT 原生智慧养老工作台的高保真本地交互原型**。它已经有较完整的 UI、响应式分支和本地交互，但没有真实登录、机构后台、网络仓库、数据库业务模型、WebSocket 或模型网关。

### 2.2 配置基线表

| 项目 | 当前静态事实 | 源码位置 |
| --- | --- | --- |
| 产品名 | `default` | `KangxiaobanAI/build-profile.json5:3-5` |
| 目标 SDK | `6.1.1(24)` | `KangxiaobanAI/build-profile.json5:7` |
| 兼容 SDK | `6.1.0(23)` | `KangxiaobanAI/build-profile.json5:8` |
| Runtime OS | `HarmonyOS` | `KangxiaobanAI/build-profile.json5:9` |
| Build mode | `debug`、`release` | `KangxiaobanAI/build-profile.json5:18-24` |
| Bundle name | `com.gxoc.kxbai` | `KangxiaobanAI/AppScope/app.json5:3` |
| 版本 | version code `1000000`，version name `1.0.0` | `KangxiaobanAI/AppScope/app.json5:5-6` |
| 模块 | `kanxiaoban`，路径 `./products/entry` | `KangxiaobanAI/build-profile.json5:42-45` |
| Module type | `entry` | `KangxiaobanAI/products/entry/src/main/module.json5:3-4` |
| API model | `stageMode` | `KangxiaobanAI/products/entry/build-profile.json5:2` |
| 设备声明 | `phone`、`tablet`、`2in1` | `KangxiaobanAI/products/entry/src/main/module.json5:7-10` |
| 安装方式 | 随应用安装，非免安装 | `KangxiaobanAI/products/entry/src/main/module.json5:12-13` |
| Main element | `KanxiaobanAbility` | `KangxiaobanAI/products/entry/src/main/module.json5:6` |
| Ability source | `./ets/entryability/EntryAbility.ets` | `KangxiaobanAI/products/entry/src/main/module.json5:17-18` |
| Home skill | `entity.system.home` + `ohos.want.action.home` | `KangxiaobanAI/products/entry/src/main/module.json5:25-33` |
| pages profile | 仅 `pages/LoginPage`、`pages/MainPage` | `KangxiaobanAI/products/entry/src/main/resources/base/profile/main_pages.json:1-6` |
| 模块生产依赖 | 空 | `KangxiaobanAI/products/entry/oh-package.json5:8` |
| 测试依赖 | `@ohos/hypium` 1.0.25、`@ohos/hamock` 1.0.0 | `KangxiaobanAI/oh-package.json5:6-9` |
| release 混淆 | 当前关闭 | `KangxiaobanAI/products/entry/build-profile.json5:12-18` |
| 权限 | 主模块没有 `requestPermissions` | `KangxiaobanAI/products/entry/src/main/module.json5:1-38` 全文件静态确认 |
| route map | 主模块未声明 `routerMap`，工程内未找到 route-map 文件 | `KangxiaobanAI/products/entry/src/main/module.json5:1-38` 与工程文件扫描 |

### 2.3 必须注意的版本漂移

当前 `build-profile.json5` 明确是“目标 API 24、兼容 API 23”。旧报告、旧提示词或旧项目手册如果写成“目标与兼容均为 API 24”，不得反向修改代码或配置去迎合旧文字。当前配置优先。

这个组合还意味着：新增 API 24 才提供的能力时，AI 必须核对兼容 API 23 的运行约束，必要时做能力检测、版本保护或重新取得产品对最低兼容版本的决定。仅仅“在 API 24 SDK 下能补全代码”不等于 API 23 设备可以安全运行。

---

## 3. 启动链与 Ability 生命周期

### 3.1 当前启动链

```text
KanxiaobanAbility
  -> onCreate()
     -> 保持系统颜色模式（COLOR_MODE_NOT_SET）
  -> onWindowStageCreate(windowStage)
     -> loadContent('pages/LoginPage')
     -> 页面加载成功后 WindowUtil.initialize(windowStage)
        -> 获取主窗口和 UIContext
        -> AppStorageV2 注册 UIContext
        -> 先设置非沉浸登录壳
        -> 注册窗口尺寸与避让区监听
  -> LoginPage.handleLogin()
     -> 非空账号/密码
     -> 800ms 本地定时器
     -> GlobalInfoModel.role = selectedRole
     -> router.replaceUrl('pages/MainPage')
  -> MainPage.aboutToAppear()
     -> WindowUtil.setImmersiveMode(true)
  -> HdsNavigation / HdsTabs 或宽屏角色工作台
```

定位证据：

- Ability 继承 `UIAbility`：`entryability/EntryAbility.ets:16-24`；
- 颜色模式：`entryability/EntryAbility.ets:24-30`；
- 加载登录页并在成功后初始化窗口：`entryability/EntryAbility.ets:42-53`；
- Login 本地定时器和路由：`pages/LoginPage.ets:72-85`；
- Main 沉浸进入/退出：`pages/MainPage.ets:94-101`；
- 根 HDS 壳：`pages/MainPage.ets:923-946`。

### 3.2 生命周期修改约束

`WindowUtil` 在 `util/WindowUtil.ets:146-170` 注册 `windowSizeChange` 与 `avoidAreaChange`。当前源码没有相应的 `.off(...)`，`EntryAbility.onWindowStageDestroy()` 只记录日志（`entryability/EntryAbility.ets:56-59`）。

这只能静态确认“没有看到对称解绑”，不能仅凭源码宣称已经发生内存泄漏。若后续任务触碰 Ability、窗口、折叠态、显示、键盘或配置监听，应把监听函数保存为稳定引用，并在同一所有者的销毁路径中对称解除；之后还要在窗口重建、前后台、横竖屏和自由窗口场景做真机验证。

---

## 4. 认证边界：页面切换存在，真实认证不存在

### 4.1 已实现的认证壳行为

`LoginPage` 是 ArkUI V2 页面（`pages/LoginPage.ets:33-45`），提供护工、医师、管理三种角色选项（`pages/LoginPage.ets:23-25,88`）。当前 `handleLogin()` 只检查账号和密码是否为空，然后等待 800ms、写入角色并切换到 `MainPage`（`pages/LoginPage.ets:72-85`）。

因此以下能力**没有被当前源码证明**：

- 凭据校验；
- token、refresh token、租户与机构上下文；
- 服务端 RBAC；
- 账号锁定、设备信任、审计日志；
- 退出时服务端 session 注销和本地敏感信息清理；
- “记住我”的真实凭据持久化；
- “联系管理员”的实际通信流程。

选中的 `role` 只是 UI 分支字符串，不能作为数据权限、接口权限或合规审计依据。

### 4.2 Router 的允许边界

传统页面 Router 当前只应用在认证壳边界：

- Login -> Main：`pages/LoginPage.ets:81`；
- Main -> Login：`pages/MainPage.ets:294-301`；
- 手机“我的”退出 -> Login：`component/TabPageView.ets:2696`。

退出路径先等待 `WindowUtil.setImmersiveMode(false)` 再进入登录页，避免登录壳继承认证区的全屏状态。新增退出入口必须调用同一所有权路径，不要在子页面直接复制另一套窗口切换逻辑。

应用内业务导航应继续使用共享 `NavPathStack`、HDS destination、sheet/content cover 或明确的本地宽屏分栏状态。不要因为熟悉 Web Router，就把每个 ArkUI 组件都改成传统 Router 页面。

---

## 5. Navigation、HDS 与呈现层级

### 5.1 当前导航所有权

`MainPage` 是根 `@Entry @ComponentV2`，通过 `@Provider('mainPageStack')` 创建唯一业务 `NavPathStack`（`pages/MainPage.ets:70-75`）。`TabPageView` 通过 `@Consumer('mainPageStack')` 复用它（`component/TabPageView.ets:182-188`）。

当前可定位的呈现清单：

| 入口 | 机制 | 所有者 | 目标/结果 |
| --- | --- | --- | --- |
| Login -> Main | `router.replaceUrl` | `LoginPage` | `pages/MainPage` |
| Logout -> Login | `router.replaceUrl` | `MainPage`、`TabPageView` | `pages/LoginPage` |
| 关于 | `NavPathStack.pushPath` | 根壳、手机“我的” | `MineDetailPage(pageType='about')` |
| 通用设置 | `NavPathStack.pushPath` | 根壳、手机“我的” | `MineDetailPage(pageType='general')` |
| AI 助手 | 根 `Stack` 中的条件本地 cover + `geometryTransition` | `MainPage` | `AiChatPage` |
| 长者详情 | `bindContentCover` | `TabPageView` | `ResidentDetailPage` |
| 健康展开 | `bindContentCover` | `TabPageView` | `HealthExpandPage` |
| 任务展开 | `bindContentCover` | `TabPageView` | 内部 HDS destination UI |
| 手机消息聊天 | `bindContentCover` | `TabPageView` | `PhoneMessageChatPage` |
| 任务/提醒/资料操作 | `bindSheet` | `TabPageView`、`WideHomePage` | 本地 builder |
| 医师入住办理 | 本地 workspace 分支 | `WideDoctorWorkspace` | `WideDoctorAdmission` |
| 宽屏长者/消息详情 | 同一工作台的 master/detail 或紧凑详情态 | 宽屏组件 | 非全局 route |

主要证据：

- 本地 destination builder 仅处理 About/General：`pages/MainPage.ets:903-910`；
- `HdsNavigation` 绑定 path stack、destination、title bar 和 Scroller：`pages/MainPage.ets:923-943`；
- AI cover：`pages/MainPage.ets:912-920,948-950`；
- 手机 content covers：`component/TabPageView.ets:3493-3530`；
- 医师入住本地分支：`component/wide/WideDoctorWorkspace.ets:1654-1667`。

如果未来加入通知点击、卡片、Want deep link、跨模块页面或动态 HAR，才应设计命名路由，并同步保证模块 `routerMap`、route name、`pageSourceFile`、导出 builder 与参数类型一致。

### 5.2 HDS 是当前产品设计系统

`MainPage` 直接导入 `HdsNavigation`、`HdsTabs`、`HdsListItemCard`、HDS title bar 和 system material 等能力（`pages/MainPage.ets:16-33`）。AI 不应为了“代码更熟悉”把它们整体换成普通 `Navigation`、`Tabs` 或自绘顶部栏。

当前根 title bar：

- 使用 `GRADIENT_BLUR` 滚动效果；
- 使用 `IMMERSIVE` + `ADAPTIVE` 系统材质；
- 绑定当前真实 Scroller；
- 宽屏护工把导航操作放入 HDS title bar 的 `stackBuilder`；
- 医师和管理宽屏隐藏根 title bar，由各自 workspace 承担其局部结构。

定位：`pages/MainPage.ets:154-208,211-237,815-834,926-940`。

手机四个根功能都使用 HDS Tabs，底栏浮动、与内容重叠、预加载四项，并把导航指示条高度计入底部边距（`pages/MainPage.ets:698-809`）。扩展预加载前要先测启动时间和内存，不能把“代码调用了 preload”写成“性能已优化”。

`MaterialUtil` 已提供系统材质支持检测与纯背景/模糊 fallback（`util/MaterialUtil.ets:21-42`），但静态扫描没有找到调用方。新增材质效果时应先核对目标 API/设备的支持情况，并决定复用 HDS 自带降级，还是接通这个 helper；不要叠加多层半透明材质来制造所谓“高级感”。

---

## 6. ArkUI V2 状态所有权

### 6.1 当前代际

生产 UI 静态扫描显示核心组件使用 `@ComponentV2`，没有找到 V1 的 `@State`、`@Prop`、`@Link`、`@Provide`、`@Consume`、`@ObjectLink` 或 `@Observed`。新增产品组件默认继续使用 ArkUI V2：

| 目的 | 当前项目约定 | 典型位置 |
| --- | --- | --- |
| 组件私有 UI 状态 | `@Local` | `MainPage` 的 tab/cover 状态；各 feature 的筛选、选中、草稿 |
| 父组件输入 | `@Param`，必要项加 `@Require` | 宽屏 workspace 的 Scroller、compactWidth、safe-area inset |
| 子组件输出 | `@Event` | tab 切换、未读数、关闭、发送、dirty change |
| 树级共享依赖 | `@Provider/@Consumer` | `mainPageStack` |
| 可观察模型 | `@ObservedV2/@Trace` | `GlobalInfoModel`、`AiChatHistoryStore` |
| 精准副作用 | `@Monitor` | 键盘高度、compact/detail、未读列表变化 |
| 应用壳级共享对象 | `AppStorageV2.connect` | UIContext、GlobalInfoModel、AI 会话 store |

不要把 V1/V2 混用当作普通重构。若样例只提供 V1 写法，应先确认目标 API 与互操作边界，再提取概念而不是复制装饰器。

### 6.2 全局环境模型只存环境和壳状态

`GlobalInfoModel` 是 `@ObservedV2`，以下字段带 `@Trace`：折叠展开、宽高断点、状态栏、导航指示条、键盘高度、设备宽高、角色（`model/GlobalInfoModel.ets:16-26`）。

`needDynamicHideBar` 与 `aspectRatio` 当前不是 `@Trace`（`model/GlobalInfoModel.ets:27-28`）。`WindowUtil` 会更新它们（`util/WindowUtil.ets:198-210`），但不能假定“只改变这两个普通字段”一定触发依赖 UI 的 V2 重建。

这个模型适合：

- window/breakpoint/safe-area/keyboard；
- 当前认证壳角色；
- 全局 UIContext 连接。

它不适合：

- 长者档案；
- 任务集合；
- 消息记录；
- 入住表单；
- API DTO；
- ViewModel 的所有业务状态。

把业务数据塞进 `GlobalInfoModel` 会制造跨功能耦合、无法清理的 session 状态和不必要重建。

### 6.3 AppStorageV2 不等于业务持久化

AI 对“全局可见”和“可持久化”必须分开：

- `WindowUtil` 把 UIContext 与环境模型连接到 `AppStorageV2`：`util/WindowUtil.ets:32-42,146-170`；
- `AiChatPage` 的 `AiChatHistoryStore` 也连接到 `AppStorageV2`：`pages/AiChatPage.ets:127-147`；
- 这不能证明 AI 历史已写入 Preferences/RDB/云端，也不能证明进程终止后仍存在。

当前明确使用 ArkData Preferences 的是 `PreferenceManager`，它提供同步 put/get/has/delete 与异步 flush（`util/PreferenceManager.ets:25-128`），`MineDetailPage` 用它读取和保存减少动效、触感、操作提示音等设置（`pages/MineDetailPage.ets:60-102`）。这仍然不等于长者、任务、消息或入住档案已持久化。

---

## 7. Window、断点与安全区

### 7.1 窗口状态链

`WindowUtil.initialize()`：

1. 取得主窗口与 `UIContext`；
2. 把 UIContext 连接到 `AppStorageV2`；
3. 初始化为非沉浸登录壳；
4. 读取初始尺寸与 system/navigation indicator avoid area；
5. 监听 `windowSizeChange`、`avoidAreaChange`；
6. 把 px 转 vp；
7. 更新设备尺寸、宽高断点、宽高比、状态栏、导航指示条和键盘高度。

定位：`util/WindowUtil.ets:32-45,135-170,176-212`。

全屏切换是串行 Promise 任务，避免短时间内相反请求乱序覆盖（`util/WindowUtil.ets:48-69`）。系统状态栏与导航指示条在沉浸模式下仍显式启用，并使用透明背景与随深浅背景变化的内容色（`util/WindowUtil.ets:103-120`）。

### 7.2 宽屏不是单纯看断点

`BreakpointSystem` 的关键规则：

- 宽屏工作台最小窗口宽度：`720vp`；
- 只有实际设备类型为 `tablet` 或 `2in1` 才会进入宽屏工作台；
- 宽度已知时要求 `deviceWidth >= 720`；
- 宽度未知时才回退到 MD/LG/XL 断点；
- `BreakpointType<T>` 提供 XS -> SM、XL -> LG 的缺省回退。

定位：`util/BreakpointSystem.ets:18,20-57,66-95`。

因此“手机横屏变宽”不会自动变成桌面工作台。设备声明、运行设备类型、窗口宽度和 breakpoint 共同决定布局。AI 不能只写 `width: '100%'` 就声称完成多端适配。

护工宽屏还有第二层业务密度阈值：小于 `1180vp` 使用 compact master/detail 结构，MD 也强制 compact（`pages/MainPage.ets:53,346-350`）。医师/管理的 `compactWidth` 目前按 MD 判断，而入住办理在非 XL 时使用 compact（`pages/MainPage.ets:839-869`）。

### 7.3 安全区有两个不同责任

1. **视觉画布扩展**：根 `HdsNavigation` 可以延伸到系统栏后面；
2. **交互内容避让**：按钮、输入框、列表结尾、固定 composer/footer 必须消费实时 inset。

当前根壳在 `pages/MainPage.ets:940` 统一 `ignoreLayoutSafeArea`。手机 HDS 浮动底栏在 `pages/MainPage.ets:794-799` 使用实时 `naviIndicatorHeight`。宽屏长者与消息页面分别在列表/详情结尾和消息 composer 消费底部 inset，例如 `component/wide/WideResidentPage.ets:522,668`、`component/wide/WideMessagePage.ets:740,764-765,1029,1045-1046`。

新增页面时禁止：

- 把固定状态栏高度写成常量；
- 给整个持久页面再套一层全窗口 `ignoreLayoutSafeArea`；
- 把 `naviIndicatorHeight` 加到整个 viewport，造成双重空白；
- 全屏 overlay 的父子多层重复扩展安全区；
- 深色页面通过隐藏系统栏来解决对比度。

必须真机验证旋转、分屏/自由窗口、键盘、导航方式、深浅主题、刘海/挖孔与大字体。

---

## 8. 多端与角色矩阵

### 8.1 结构选择

| 运行条件 | 静态选中的结构 | 当前证据性质 |
| --- | --- | --- |
| phone 设备，不论窗口变宽 | 手机结构 | `usesWideWorkspace()` 对非 tablet/2in1 返回 false；仅静态确认 |
| tablet/2in1，窗口 < 720vp | 手机 HDS Tabs 结构 | 宽度阈值分支；仅静态确认 |
| tablet/2in1，窗口 >= 720vp | 宽屏角色工作台 | 设备类型 + 宽度分支；仅静态确认 |
| 护工宽屏 < 1180vp 或 MD | compact 宽屏工作台 | `MainPage.useCompactCaregiverWorkspace()`；仅静态确认 |
| 护工宽屏 >= 1180vp 且非 MD | 全宽 master/detail 工作台 | 反向分支；仅静态确认 |

### 8.2 角色矩阵

| 角色 | 手机/窄结构 | tablet/2in1 宽结构 | 不得误述为 |
| --- | --- | --- | --- |
| 护工 | 四个 HDS Tabs，页面由 `TabPageView` 承担 | `WideCaregiverWorkspace`，首页/长者/消息根保持挂载并切换 visibility | 已接机构后台的护理系统 |
| 医师 | WIP“适配中”面板 | `WideDoctorWorkspace` 本地养护/评估原型，入住办理是本地分支 | 门诊诊断系统、真实医嘱系统 |
| 管理 | WIP“适配中”面板 | `WideAdminWorkspace`，运营总览有本地内容，其余模块多为演示入口 | 已连接人事、财务、床位、设备后台 |
| 其他字符串 | WIP 面板 | WIP 面板 | 已完成未知角色兜底业务 |

角色适配条件：`pages/MainPage.ets:256-285`；宽屏角色分派：`pages/MainPage.ets:837-900`；手机四 Tabs：`pages/MainPage.ets:698-809`。

宽屏护工三个根页面使用 `Visibility.Hidden/Visible` 保持挂载（`component/wide/WideCaregiverWorkspace.ets:55-69,162-220`），因此局部选中、滚动和草稿状态不会像每次重建那样自动清空。AI 若把它改成条件创建，需要先明确是否接受状态丢失、定时器重建和内存变化。

宽屏长者和消息分别维护 master/list 与 detail/chat 两个 Scroller；compact 时在全宽列表和全宽详情间切换，非 compact 时并排呈现（`component/wide/WideResidentPage.ets:437-453,464-680`，`component/wide/WideMessagePage.ets:1124` 及其 list/chat builders）。根 HDS title bar 绑定的 Scroller 会随活动 pane 变化，不能固定绑定一个已隐藏 Scroller。

---

## 9. Mock、本地状态与真实服务边界

### 9.1 静态服务扫描结论

对生产 `.ets` 的静态扫描没有找到 NetworkKit/HTTP client、WebSocket、RDB、Repository 接口或实现。主模块没有受限权限声明，模块生产 dependencies 为空。当前出现的系统能力主要是 ArkUI、AbilityKit、UIDesignKit、InputKit、BasicServicesKit 的设备/剪贴板/错误类型、ArkData Preferences 和 hilog。

“没有搜索到”是当前源码静态结论，不是对未来分支、生成代码、原生库或外部服务的永久保证。

### 9.2 业务真相表

| 功能 | 当前真实实现 | 关键证据 | AI 必须使用的表述 |
| --- | --- | --- | --- |
| 登录 | 任意非空账号/密码，800ms 后进入 Main | `LoginPage.ets:72-85` | “本地演示登录” |
| 角色 | 字符串写入 `GlobalInfoModel.role` | `LoginPage.ets:79` | “UI 角色选择”，不是授权 |
| AI 对话 | 650ms 定时器后拼接固定模板回复 | `AiChatPage.ets:571-583,596-622` | “本地确定性模拟回复” |
| AI 重新生成 | 500ms 后用同一本地生成函数替换 | `AiChatPage.ets:625-643` | 不是模型重采样 |
| 医师 AI | 立即写入固定本地提示文本 | `WideDoctorWorkspace.ets:344-352` | “本地演示建议” |
| 宽屏消息发送 | 追加到 `@Local sentRecords` | `WideMessagePage.ets:559-576` | “本地会话记录”，无发送状态 |
| 手机消息发送 | 子组件创建 record，父组件追加本地数组 | `PhoneMessageChatPage.ets:180-193`；`TabPageView.ets:2510-2522` | “本地记录”，无服务确认 |
| 宽屏任务 | 修改 `inProgressTaskIds`、`completedTaskIds` | `WideHomePage.ets:742-759` | “本地任务状态” |
| 任务完成文案 | 本地完成后显示“记录已提交” | `WideHomePage.ets:1691-1699` | 不得据此宣称已入档；接服务时必须改为真实结果驱动 |
| 医师入住 | 全部表单、评估、计划、确认是 `@Local`；最后只令 `submitted=true` | `WideDoctorAdmission.ets:56-87,574-584` | “本地入住草稿” |
| 入住成功态 | 明确提示未提交后台、不形成正式档案 | `WideDoctorAdmission.ets:1632-1656` | 保留这类真实性提示，直到服务确认 |
| 管理端 | 本地数组、已处理 ID 与占位模块 | `WideAdminWorkspace.ets:36-63,199,330` | “本地运营演示” |
| 设置 | Preferences 保存布尔偏好 | `PreferenceManager.ets:47-128`；`MineDetailPage.ets:76-102` | 可称“本地偏好持久化”，不能扩展到业务档案 |

### 9.3 异步状态的项目规则

以后接入真实服务时，按钮按下、动画结束或定时器到期都不能直接代表成功。至少需要：

```text
Idle -> Pending -> Confirmed
                -> Failed -> Retry/Pending
```

还应覆盖超时、取消、重复提交、请求 ID/幂等、乱序返回、离线、权限失败和服务端校验失败。只有真实服务结果可以驱动 `Confirmed`。本地 optimistic update 必须有回滚与冲突策略。

### 9.4 业务层抽取顺序

在不改变现有 UI 行为的前提下，建议按以下顺序演进：

1. 用截图、静态契约和关键交互测试固定当前行为；
2. 把页面内数据构造移到 per-feature `FakeRepository`；
3. 引入 feature ViewModel/store，集中派生状态；
4. 引入 UseCase/domain service；
5. 定义 repository interface；
6. 增加 remote/local data source、DTO -> domain 映射、缓存与错误模型；
7. 边界稳定后再拆 HAR/HSP，不要先按文件大小机械模块化。

DTO、domain model 和 UI model 必须分开。服务数据要显式处理缺失值、单位、时区、枚举兼容、租户与角色权限；UI 组件不得直接解析 transport payload。

---

## 10. HarmonyOS 官方主题到当前项目文件的映射

下面这张表用于 AI 在阅读官方文档后迅速找到项目落点。状态“缺失”不是让 AI 自动补齐，而是说明只有在明确需求下才应设计该层。

| 官方主题族 | 当前项目落点 | 当前状态/使用方式 |
| --- | --- | --- |
| ArkTS 语言基础、类型、类、接口 | `products/entry/src/main/ets/**/*.ets`；业务接口集中在 `model/DetailTypes.ets` 和各 feature 文件顶部 | 已大量使用；新增公共类型前先确定 domain/DTO/UI 所有权 |
| Stage 模型与 UIAbility | `module.json5`、`EntryAbility.ets` | `stageMode` 单 entry Ability |
| 应用包与模块配置 | 根/模块 `build-profile.json5`、`app.json5`、两个 `oh-package.json5` | target API24、compatible API23；单 entry 模块 |
| 页面加载与生命周期 | `EntryAbility.ets` | `loadContent(LoginPage)`，窗口初始化在成功回调后 |
| Router | `LoginPage.ets`、`MainPage.ets`、`TabPageView.ets` | 仅认证边界 |
| Navigation / NavPathStack | `MainPage.ets`、`TabPageView.ets`、`MineDetailPage.ets` | 根 HDS Navigation，About/General 为本地 destination |
| Sheet、ContentCover、局部呈现 | `TabPageView.ets`、`WideHomePage.ets` | 手机详情/展开/聊天与本地操作 |
| ArkUI V2 状态管理 | `GlobalInfoModel.ets`、`MainPage.ets`、所有 V2 feature 组件 | `@Local/@Param/@Event/@Provider/@Consumer/@ObservedV2/@Trace/@Monitor` |
| 应用级状态 | `WindowUtil.ets` + `AppStorageV2`；`AiChatHistoryStore` | 环境/壳和运行期 AI 会话；不等同业务持久化 |
| HDS / UIDesignKit | `MainPage.ets`、`HealthExpandPage.ets`、`MineDetailPage.ets`、详情 destination | 当前活跃设计系统，应优先保留 |
| Material 与滚动 title bar | `MainPage.ets:154-237`、`MaterialUtil.ets` | 根壳已用系统材质；helper 尚无调用方 |
| Tabs | `MainPage.phoneTabs()`、`TabsBarModel.ets` | 手机四项 HDS Tabs，预加载全部 |
| 响应式布局与断点 | `BreakpointSystem.ets`、`WindowUtil.ets`、`MainPage.ets`、`component/wide/*` | 设备类型 + 窗口宽度 + breakpoint，不是设备名硬编码的单一判断 |
| 沉浸式与安全区 | `WindowUtil.ets`、`MainPage.ets`、wide 页面 footer/composer | 根扩展画布，交互 owner 消费实时 inset |
| 键盘避让 | `WindowUtil.ets`、`LoginPage.ets`、`AiChatPage.ets`、消息 composer | 监听 keyboard avoid area；仍需真机验证 |
| 动效、spring、geometry transition | `MainPage.ets`、`AiChatPage.ets`、`WideSlidingCapsule.ets` | AI cover 和滑动胶囊有自定义动效；不得把动画完成当业务完成 |
| 无障碍与多输入 | `WideSlidingCapsule.ets`、wide 工作台的 `KeyCode`/focus/hover、多个 `accessibilityText` | 有局部实现；整体验收仍待读屏、大字、键鼠真机 |
| Preferences | `PreferenceManager.ets`、`MineDetailPage.ets` | 仅通用设置偏好 |
| RDB/关系数据库 | 无生产实现 | 需求明确后新增 data source/repository，不在 UI 内直写 |
| 网络请求 | 无生产实现 | 需求明确后设计 DTO、鉴权、超时、重试、错误状态 |
| WebSocket/实时消息 | 无生产实现 | 当前消息仅本地数组；不能宣称实时通信 |
| Account Kit/真实账号 | 无生产实现 | 当前登录不调用账号服务 |
| 通知、卡片、Deep Link | 无 route map、无通知入口实现 | 引入时必须建立 named route/Want 参数契约 |
| 分布式/多设备协同 | 仅声明 phone/tablet/2in1 UI 设备类型 | 多端 UI 声明不等于分布式能力 |
| AI/模型服务 | `AiChatPage.ets`、`WideDoctorWorkspace.ets` | 固定本地文本，无模型 gateway |
| NDK/Native | 无当前产品实现 | 不因官方文档存在 NDK 章节就自动引入 |
| 日志与性能分析 | `Logger.ets` 使用 hilog；UI 有 Scroller/预加载/材质 | 没有当前真机帧率、长帧、内存证据 |
| 测试 | `src/test/LocalUnit.test.ets`、`src/ohosTest/.../Ability.test.ets` | 仍是模板 `assertContain`，不是产品行为测试 |
| 构建与发布 | 根/模块 build profile、DevEco/Hvigor 环境 | 本章未构建；release 混淆当前关闭；签名信息不得进入文档或 AI 输出 |

---

## 11. 编程 AI 修改本项目的标准工作流

### 11.1 修改前

1. 确认目标是 `KangxiaobanAI`，除非用户明确指定其他顶层工程；
2. 读取当前根/模块配置，而不是引用旧报告；
3. 从 `mainElement -> srcEntry -> loadContent -> main_pages -> Login/Main -> HdsNavigation` 追完整调用链；
4. 记录当前 branch、工作树状态和已有改动，禁止覆盖用户修改；
5. 确认目标 API 24、兼容 API 23，以及 API/组件的可用范围；
6. 搜索当前工作区同代实现，样例只读、最小提取；
7. 明确状态所有者、导航所有者、安全区所有者和服务真相；
8. 先写验收场景，再写代码。

### 11.2 修改中

- 默认 `@ComponentV2`；
- owned UI state 用 `@Local`，输入用 `@Param/@Require`，输出用 `@Event`；
- 树级导航继续用 `mainPageStack`；
- 不新增第一层 tab，除非有明确产品批准；
- 不把长者/任务/消息放进 `GlobalInfoModel`；
- 不在页面里直接写 HTTP、RDB 和 DTO 解析；
- 不复制一套窗口/沉浸/系统栏 owner；
- 不给每个 child 再加全屏 safe-area expansion；
- 不把 HDS 根壳替换成自绘 dashboard chrome；
- 不让 `setTimeout`、动画回调或本地数组更新产生“后台已提交”的成功语义；
- 不读取、打印、移动或提交签名敏感内容。

### 11.3 修改后

1. 静态核对配置、路由、装饰器、import、资源和状态所有权；
2. 运行与风险相称的 lint/type/build；
3. 在所有受影响的设备形态和输入方式上真机验证；
4. 如果接了服务，验证真实成功/失败/超时/权限/重试/乱序；
5. 报告中分别列出 Static、Build、Device、Service 结论；
6. 没有证据的项写“待验证”，不能用“应该没问题”替代。

---

## 12. 修改前后验收矩阵

### 12.1 通用矩阵

| 验收域 | 修改前必须留存 | 修改后静态确认 | 构建确认 | 真机确认 | 服务确认 |
| --- | --- | --- | --- | --- | --- |
| 工作树安全 | branch、`git status`、目标文件、用户已有改动 | 只出现任务允许的改动；无样例误改、无敏感信息 | 不适用 | 不适用 | 不适用 |
| SDK/Module | target/compatible、entry、deviceTypes、pages、Ability | 配置互相一致；API24-only 能力有兼容决定 | 当前 SDK 下 debug/release 按需求成功 | API23/24 目标设备按支持范围启动 | 不适用 |
| 启动 | Ability -> Login -> WindowUtil -> Main 链 | `loadContent`、初始化顺序不破坏 | 冷启动代码可编译打包 | 冷/热启动、前后台、窗口重建 | 登录服务接入后才验证 session |
| 认证 | 记录当前本地演示行为 | UI 不再把角色字符串当权限 | auth 代码构建通过 | 登录失败、返回、退出、旋转/键盘 | 凭据、token、刷新、锁定、注销、RBAC |
| Navigation | route/path stack/cover 清单 | 入口、返回、参数和 owner 一致 | destination 构建通过 | 系统返回、手势返回、快速重复进入、状态保留 | deep link/通知参数若存在则真实验证 |
| ArkUI V2 | 当前装饰器与 owner | 无无理由 V1 混入；无双向状态暗耦合 | ArkTS 类型检查通过 | 快速输入、反向切换不丢状态 | 不适用 |
| 窗口/安全区 | 当前 inset、breakpoint、沉浸 owner | 无固定系统栏高度、无重复扩展 | API 调用可编译 | 旋转、分屏、自由窗口、键盘、导航方式 | 不适用 |
| 手机护工 | 四 tabs、sheet/cover、local state | tab 数与信息架构不漂移 | 构建通过 | phone 竖/横屏、返回、聊天、详情 | 接服务后验证真实数据 |
| tablet/2in1 护工 | 720/1180 阈值、master/detail | compact/full 分支和 Scroller 绑定一致 | 构建通过 | 719/720、1179/1180 附近 resize；鼠标键盘 | 接服务后验证状态同步 |
| 医师/管理 | 手机 WIP、宽屏 local prototype | 不把 WIP/本地内容误标为已上线 | 构建通过 | 宽屏导航、入住 dirty guard、返回 | 入住/运营后台真实确认 |
| AI cover | current geometry ID、关闭/返回 | 转场不重复，业务状态不依赖动画完成 | 构建通过 | 快速开关、反向中断、键盘、低动效 | 模型成功/失败/取消/超时/内容安全 |
| 消息 | 本地 record、未读、scroll owner | 若仍本地则明确标识；若接服务则有状态机 | 构建通过 | 历史浏览、发送、失败 UI、跳到底部 | 消息投递、ack、重连、乱序、重复 |
| 任务/入住 | 本地数组/草稿与真实性文案 | Confirmed 只由真实结果驱动 | 构建通过 | 表单、大字、键盘、离开保护 | 幂等、校验、持久化、审计、权限 |
| Preferences | key、默认值、读取/保存路径 | key 兼容与迁移明确 | 构建通过 | 进程重启、清除数据、升级 | 云同步若有则另验 |
| 无障碍 | 当前语义、focus、hover | 非文本控件有名称/角色/状态；颜色非唯一信号 | 构建通过 | 读屏、键盘、放大字体、高对比/深浅色 | 不适用 |
| 性能 | 当前列表规模、预加载、材质、动画 | 避免高频布局属性与重复重建 | release/接近 release 构建 | SmartPerf/Profiler、长帧、内存、快速输入 | 服务耗时另行记录 |
| 测试 | 模板测试现状 | 新测试覆盖真实行为而非仅字符串断言 | 测试任务通过 | UI 自动化在目标设备执行 | integration/e2e 对真实服务执行 |

### 12.2 当前设备场景最小集合

只要改动涉及根壳、导航、响应式、输入或 safe area，至少应覆盖：

1. phone 竖屏；
2. phone 横屏，确认不会错误进入 tablet workspace；
3. tablet/2in1 窗口小于 720vp；
4. tablet/2in1 刚好跨越 720vp；
5. 护工宽屏刚好跨越 1180vp；
6. tablet MD 下的医师、管理和入住 compact；
7. XL 下的入住非 compact；
8. 键盘打开/关闭；
9. 手势返回、系统返回、键盘 Esc/返回；
10. 浅色、深色、大字体；
11. 触摸、鼠标、键盘焦点；
12. 快速连续切 tab、开关 AI、进出详情；
13. 读屏顺序与 master/detail 焦点顺序；
14. 长列表、材质模糊和转场的帧率/长帧。

这些场景未实际运行前，最终报告只能写“待真机验证”。

---

## 13. 当前静态风险与待验证项

以下不是对产品作运行时定罪，而是编码 AI 在改造时必须保留的证据边界：

1. `WindowUtil` 有监听注册、未见对称解绑；需窗口重建与生命周期验证；
2. `MaterialUtil` 有 capability/fallback helper，但根材质路径未调用它；需核对 HDS 自身降级和目标设备；
3. `needDynamicHideBar`、`aspectRatio` 非 `@Trace`；不得假定单独变化可驱动 UI；
4. 当前 compatible API 为 23；新增 API24-only 能力必须做兼容决定；
5. 手机医师/管理明确是 WIP，登录页却允许选择；不能对用户宣称三角色手机端均完成；
6. 宽屏任务本地完成后存在“记录已提交，可在长者档案中查看”的强成功文案，但没有 repository/service；接服务前应保持原型边界，接服务时必须由真实结果驱动；
7. 消息只有本地插入，没有 sending/sent/failed/ack；
8. AI 是定时器与固定文本，没有取消、失败、超时、服务状态；
9. 产品测试仍是模板断言，不能证明登录、路由、状态、窗口、任务、消息、AI、入住流程；
10. 尚无本章可引用的当前构建日志、当前 HAP、真机矩阵、读屏、性能或后台验证结果。

---

## 14. 给 AI 的最终操作口诀

```text
当前配置优先于旧文档；
KangxiaobanAI 是产品，样例是只读语料；
Router 只守认证边界，业务走 NavPathStack/HDS/局部呈现；
ArkUI V2 保持单向状态所有权；
GlobalInfoModel 只放环境和壳，不放业务世界；
根壳扩展画布，交互 owner 消费实时安全区；
宽屏由设备类型 + 窗口宽度 + breakpoint 决定；
本地数组、AppStorageV2、定时器都不是后台成功；
动画完成不是业务完成；
构建通过不是真机通过，真机通过也不是服务通过；
没有证据就写待验证；
绝不输出签名秘密。
```
