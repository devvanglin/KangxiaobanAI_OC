# HarmonyOS / ArkTS AI 编程工作手册

> 面向读者：Codex、Claude 等编程 Agent，以及使用这些工具的人类开发者、评审者和测试人员  
> 编写日期：2026-08-10  
> 官方入口：[HarmonyOS 应用开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts)  
> 本地覆盖证据：[`coverage/crawl-report.md`](../coverage/crawl-report.md)、[`coverage/menu-tree.md`](../coverage/menu-tree.md)、[`coverage/page-status.csv`](../coverage/page-status.csv)  
> 适配项目：`D:\Coding\KangxiaobanAI_OC\KangxiaobanAI`

这是一份“如何让 AI 可靠地修改 HarmonyOS 工程”的工作手册。它不把几千个官方页面压缩成若干条万能结论，也不替代具体 API 参考。它解决的是更容易出错的那一层：AI 在动手前应该查什么，怎样证明某个 API 真正可用，怎样保持 ArkUI V2 代际一致，怎样处理权限和生命周期，怎样区分静态、构建、真机、服务证据，以及出错后怎样定位第一原因。

本地采集报告记录了 5,694 个左侧菜单正文链接均已读取、失败为 0、待读取为 0；采集结束后的二次官网目录差异检查也已通过。这个结论证明的是 2026-08-10 快照范围的逐页读取与完整性，不代表任何一份摘要可以永久替代当前官网、当前 SDK 类型声明或当前项目源码。HarmonyOS 文档、SDK、设备能力和项目配置都会演进；涉及具体接口时，仍必须执行本手册的 API 核验流程。

---

## 1. 先统一四种标签，防止 AI 把不同层级的规则混在一起

本文使用以下标签。编程 Agent 在自己的计划、代码审查和交付报告中也应沿用它们。

| 标签 | 含义 | 典型例子 |
| --- | --- | --- |
| `【官方通则】` | 来自当前 HarmonyOS 官方指南或 API 参考的能力、约束、术语与推荐路径 | 权限最小化；用户授权应在业务触发点申请；V2 的 `@Param` 是外部输入 |
| `【工程方法】` | 为了让人类和 AI 可审计地执行任务而总结的操作方法，不冒充官方原文 | 建立 API 证据卡；先锁定第一条因果错误；分四级报告验证状态 |
| `【项目规则：KangxiaobanAI】` | 只对当前仓库、当前产品架构和当前产品决策生效 | 默认交付目标是 `KangxiaobanAI`；核心 UI 使用 ArkUI V2/HDS；应用内导航使用共享 `NavPathStack` |
| `【待验证】` | 仅凭当前证据不能确认，需要构建、真机、服务或产品决策 | 某个硬件 Kit 在目标设备是否可用；窗口重建时监听是否重复；真实后台是否幂等 |

### 1.1 冲突时的判断顺序

`【工程方法】` 推荐按下面顺序判断事实：

1. 当前工程的 `build-profile.json5`、`app.json5`、`module.json5`、包清单、路由配置与源码；
2. 当前安装 SDK 的声明文件、当前官网 API 参考与当前指南；
3. 能明确对应到当前工作树的构建日志、产物和真机记录；
4. 当前工作区的 `AGENTS.md` 与经核验的项目适配文档；
5. README、旧分析报告、博客、问答、历史样例和模型记忆。

旧文档与当前配置不一致时，不能修改代码去“迎合旧文档”。先确认漂移，再更新说明或取得产品决策。

### 1.2 三个经常被混淆的词

- “官方指南中有这个主题”不等于“当前项目已经实现这个能力”。
- “当前 SDK 能编译这个接口”不等于“最低兼容设备能够运行这个接口”。
- “界面显示成功”不等于“后台、AGC、数据库或模型服务已经确认成功”。

---

## 2. 修改前发现流程：AI 没完成这张图，就不应开始写代码

官方文档按入门、开发、工具、测试、体验建议组织知识；真实工程却必须从“交付目标—配置—运行链—状态—外部能力—验证”反向发现。下面的流程适用于功能开发、Bug 修复、重构和代码审查。

### 2.1 第零步：确认授权边界

`【工程方法】` 先回答：

- 用户要求的是解释、审查、诊断，还是明确要求修改？
- 是否允许构建、安装、连接设备、访问外部服务、改配置、加权限或新增依赖？
- 是否指定了顶层项目、模块、产品、设备形态、SDK 或分支？
- 工作树已有修改是否属于用户？哪些文件绝不能覆盖？
- 是否包含签名、证书、账号、健康数据、令牌或私有端点？

只读任务不得顺手修复。诊断任务不得擅自改代码。明确的实现任务可以完成正常、可逆、在范围内的修改与验证，但不能自动扩大到另一个产品、远端服务或高风险系统设置。

### 2.2 第一步：记录工作树与目标边界

建议形成以下快照：

```text
工作区：
目标顶层项目：
目标 product：
目标 module：
module 配置类型：entry / feature / shared / skill / 其他
交付/工程形态：HAP / HAR / HSP / 元服务 / Extension / Native hybrid / 聚合样例 / 其他
当前分支：
工作树状态：
与任务重叠的既有修改：
允许修改的文件：
禁止修改的文件：
```

`【项目规则：KangxiaobanAI】`

- 用户未指定其他工程时，默认产品工作属于 `KangxiaobanAI`。
- 同级样例工程是只读参考，不是并列交付目标。
- 工作树可能不干净；用户已有修改、生成物和本地配置必须保留。
- 签名配置可能含敏感信息。AI 不得回显、复制、总结、迁移或提交具体证书路径、口令、密钥和 Profile 内容。

### 2.3 第二步：读取配置指纹

`【官方通则】` HarmonyOS 应用和模块配置共同决定包、模块、Ability、设备、页面、权限和分发行为。官方也明确提醒：配置示例直接复制到工程中可能因为资源不存在或场景不同而无法编译。

`【工程方法】` 至少读取：

1. 根 `build-profile.json5`；
2. 根 `oh-package.json5`；
3. `AppScope/app.json5`；
4. 目标模块的 `build-profile.json5`；
5. 目标模块的 `oh-package.json5`；
6. 目标模块 `src/main/module.json5`；
7. pages profile、route map、资源 profile、Extension/卡片/意图等任务相关配置；
8. 本地依赖和公共导出边界。

记录以下字段，不要只写“这是一个鸿蒙项目”：

| 维度 | 必填事实 |
| --- | --- |
| SDK | target SDK、compatible SDK、runtime OS、model version |
| 产物 | product、module、module type、HAP/HAR/HSP、build mode |
| 入口 | mainElement、Ability/Extension 名称、`srcEntry`、`loadContent` |
| 设备 | `deviceTypes`、窗口/屏幕限制、是否有不同 product/module |
| 页面/路由 | pages profile、router map、Navigation destination、Want/deep link |
| 权限 | `requestPermissions`、ACL/Profile、usedScene/reason、运行时申请点 |
| 依赖 | `@kit`、OHPM 包、本地 `file:` 依赖、Native 库、公共 HAR 导出 |
| 构建 | 签名来源、混淆、资源、flavor/target、测试 target |

### 2.4 第三步：追启动链，而不是只打开目标页面

`【工程方法】` 对普通 Stage 模型 UI 应用，至少追到：

```text
module.json5.mainElement
  -> Ability srcEntry
  -> UIAbility 生命周期
  -> WindowStage / 主窗口
  -> loadContent 页面
  -> pages profile / route map
  -> 根 ArkUI 页面
  -> Navigation / NavPathStack / Tabs / 本地 cover 或 sheet
  -> 目标功能入口
```

同时回答：

- 谁拥有主窗口？谁改变沉浸式或系统栏？
- 谁拥有根导航栈？传统 Router 与 Navigation 的边界在哪里？
- 系统返回、手势返回、窗口缩放、前后台切换会经过哪些 owner？
- 目标组件是一直挂载、按需创建、缓存复用，还是离开即销毁？

只读了目标 `.ets` 文件，没有追入口、参数和生命周期，不能算“理解了改动范围”。

### 2.5 第四步：画状态和数据所有权图

至少区分：

```text
应用/窗口环境状态
  -> feature 状态
     -> 页面 owned UI 状态
        -> 子组件输入/输出

远端 DTO
  -> repository/data source
     -> domain model/use case
        -> ViewModel/store
           -> UI model
```

需要查明：

- 当前组件使用 ArkUI V1 还是 V2？
- 哪个字段真正可观察？修改哪一层会触发 UI？
- 哪个对象是应用运行期全局状态，哪个是持久化状态？
- 数据是 mock、本地内存、Preferences/RDB、跨设备还是服务端？
- “成功”由谁确认？定时器、动画、本地数组，还是远端响应？
- 是否存在并发、重复提交、乱序回调、离线、缓存或会话过期？

### 2.6 第五步：盘点外部能力、权限与资源 owner

对每个 Kit、设备能力、监听、定时器或资源，建立一条账：

| 项目 | 注册/创建位置 | 使用位置 | 停止/解绑/释放位置 | 生命周期 owner | 失败/拒绝路径 |
| --- | --- | --- | --- | --- | --- |
| 窗口监听 |  |  |  |  |  |
| 传感器/位置/相机 |  |  |  |  |  |
| Player/Decoder/PixelMap/Node |  |  |  |  |  |
| 定时器/订阅/事件总线 |  |  |  |  |  |
| 网络/模型请求 |  |  |  |  |  |
| Worker/TaskPool/Native handle |  |  |  |  |  |

如果“释放位置”为空，必须标为风险；不能假设系统会替应用完成所有清理。

### 2.7 第六步：先写验收场景，再选择实现

把需求变成可观察结果：

```text
给定：设备形态、窗口宽度、角色、权限、网络/服务状态、初始数据
当：用户执行具体动作
则：UI、导航、状态、日志、持久化、服务端分别发生什么
并且：失败、取消、重复、返回、旋转、前后台、进程重启时发生什么
```

如果需求会改变权限、路由、数据持久化、外部服务、信息架构或最低兼容版本，AI 应先明确产品决定，不能把重要选择藏在代码里。

### 2.8 修改前完成判据

- [ ] 已确认用户授权是只读、诊断还是实现。
- [ ] 已记录分支、工作树和重叠修改。
- [ ] 已确认 product/module/type/target/compatible/deviceTypes。
- [ ] 已追完 Ability—WindowStage—页面—导航—目标功能调用链。
- [ ] 已确认 ArkUI 状态代际与 owner。
- [ ] 已确认数据是真实服务、本地持久化还是 mock。
- [ ] 已列出权限、SystemCapability、硬件、AGC/账号等前提。
- [ ] 已列出所有注册、监听、定时器、异步任务和释放点。
- [ ] 已写成功与失败验收场景。
- [ ] 已确定需要的静态、构建、真机和服务验证。

---

## 3. API、`@since` 与 `SystemCapability` 核验：禁止“凭印象写接口”

AI 最危险的错误不是语法小错，而是生成一个看起来很像 HarmonyOS 的模块名、方法、枚举或参数。任何新 API 在写入产品代码前，都应通过下面的九道门。

### 3.1 第一门：确认要解决的能力，而不是先猜接口名

先写清楚：

```text
业务目标：
需要的平台能力：
调用发生在 Ability / Page / Component / Service / Native 哪一层：
输入：
输出：
错误与取消：
设备/账号/网络/硬件前提：
```

同一个目标可能有 ArkTS、C/C++、系统控件、Kit、AGC 服务或第三方库多条路径。不能因为搜索到一个同名方法就认定它属于当前技术栈。

### 3.2 第二门：核对精确 import、命名空间和符号

`【工程方法】` 需要同时找到：

- 当前官方 API 参考中的模块/Kit；
- 当前安装 SDK 声明文件中的精确符号；
- 项目中同 SDK 代际的已用模式；
- 函数、类、枚举、类型、回调、返回值和异常的完整签名。

不得只根据：

- 搜索引擎摘要；
- 旧博客；
- 另一个 API 版本样例；
- 其他平台的同名接口；
- IDE 自动补全的一小段；
- 模型记忆。

如果官网与本机 SDK 不一致，先确定项目实际使用哪套 SDK。编译行为由当前 SDK 声明决定；设计意图和新版本变更由当前官方文档解释；是否允许升级 SDK 由项目决定。

### 3.3 第三门：逐级核对 `@since`

`【工程方法】` 不只看类或模块的起始版本，还要看实际调用成员和所选重载：

1. Kit/模块是否在目标 SDK 存在；
2. 类、接口、枚举是否存在；
3. 实际方法/属性/枚举值的 `@since`；
4. 所用参数对象字段的 `@since`；
5. 所选同步/异步重载或新返回类型的 `@since`；
6. 相关生命周期装饰器、配置字段、设备类型支持版本；
7. 废弃、替代、仅系统应用、仅特定设备或受限开放标记。

判断规则：

| 情况 | 结论 |
| --- | --- |
| `@since` 高于 target SDK | 当前配置下不可直接使用；通常无法通过当前 SDK 编译 |
| `@since` 不高于 target、但高于 compatible | 可以被当前 SDK 识别，不代表最低兼容设备可安全运行；必须有版本/能力决策 |
| 类可用但成员起始版本更高 | 只能使用满足版本的成员，不能以类的版本代替成员版本 |
| 样例 target 更旧或更新 | 只提取概念；逐个重验 import、装饰器、参数和行为 |

`【项目规则：KangxiaobanAI】` 当前配置静态事实是 target `6.1.1(24)`、compatible `6.1.0(23)`。因此新增 API 24 才出现的成员时，必须明确 API 23 设备策略：不用该能力、提供降级、能力检测，或由产品批准提高最低兼容版本。仅写出 API 24 代码不算完成兼容设计。

### 3.4 第四门：核对 `SystemCapability`

`SystemCapability` 回答“系统/设备是否提供这类能力”，权限回答“当前应用是否被允许访问”，二者不是一回事。

`【工程方法】` 对每个 API 记录：

```text
SystemCapability：
官方支持设备/产品形态：
是否需要硬件：
是否需要系统组件/服务：
是否需要账号、AGC、网络或厂商配置：
官方是否提供能力检测/支持查询：
不支持时的降级：
```

禁止推理：

- 有权限，所以一定有 SystemCapability；
- `deviceTypes` 声明了 tablet，所以所有平板都有对应硬件；
- 模拟器能跑，所以真机服务可用；
- API reference 中列出，所以三方应用一定可调用；
- 系统能力存在，所以用户一定已授权；
- `SystemCapability` 相同，所以不同版本的方法签名相同。

如果官方为该能力提供了检测接口或支持查询，应使用该能力文档指定的精确路径；不要杜撰一个通用的“canUse”方法。

### 3.5 第五门：核对设备、应用类型和开放范围

逐项检查：

- phone、tablet、2in1、PC、TV、wearable、car 等支持范围；
- 普通 HAP、元服务、ArkTS 卡片、Extension、HAR/HSP 是否可用；
- 三方应用、系统应用、预置应用、企业设备或特定区域限制；
- 是否受限开放、需要申请权限/ACL、白名单、证书指纹或商用审批；
- 是否依赖 AGC 项目、App ID、Client ID、公钥指纹、服务开关或测试账号；
- 是否只支持真机，模拟器/预览器是否不具备该能力；
- 是否要求特定系统版本、芯片、传感器或外设。

### 3.6 第六门：核对权限全链路

权限不是在 `module.json5` 加一行就结束。至少确认：

1. 权限名称精确存在；
2. 授权类型是 system_grant、user_grant 还是 manual_settings；
3. 是否需要 ACL/Profile 或额外申请；
4. 配置声明、`reason`、`usedScene` 是否符合该权限要求；
5. 运行时在哪个用户动作触发申请；
6. 每次实际操作前怎样检查当前授权状态；
7. 首次拒绝、再次拒绝、不再询问、设置页返回如何处理；
8. 用户撤销权限、系统回收权限、进程重启后如何恢复；
9. 无权限时非相关功能是否仍可使用；
10. 日志、通知、剪贴板、缓存中是否泄漏敏感数据。

### 3.7 第七门：核对线程、生命周期、错误和资源释放

读取 API 参考与指南中的：

- 同步还是异步；Promise、回调或事件监听；
- 可调用线程/上下文；
- `BusinessError`、错误码和失败条件；
- 是否可能多次回调、乱序、重复或延迟完成；
- `on` 与 `off`、创建与 destroy/release/close 的配对关系；
- 页面不可见、Ability 后台、窗口销毁、进程终止时的要求；
- 大对象、Native handle、PixelMap、播放器、相机、传感器等资源释放。

错误码只能引用当前接口文档中确认过的值。不要把另一个 Kit 或旧版本的错误码复制过来。

### 3.8 第八门：用当前 SDK 声明和本地同代样例交叉确认

`【工程方法】` 推荐使用 `rg` 查找：

- 精确模块 import；
- 精确方法/枚举/类型名；
- `@since`、`@syscap` 或同等元数据；
- 当前工作区 target/compatible 相近的样例；
- 同一 API 的注册与释放完整实现。

本地样例的正确用途是回答“真实代码怎样组织”，不是替代版本和能力核验。优先选同代样例；旧 V1/API 17 样例只作为概念参考。

### 3.9 第九门：分层验证

1. 静态检查：import、类型、配置、权限、资源、调用链一致；
2. 构建：准确的 product/module/mode 在当前 SDK 下成功；
3. 真机：准确设备/系统/输入/窗口下走成功、拒绝、不支持和释放路径；
4. 服务：若依赖 AGC/后台/账号/模型，使用真实配置验证成功、失败、超时和权限；
5. 性能：高频、媒体、图形、AI、长列表或后台任务需测量资源与帧表现。

### 3.10 API 证据卡模板

把下面内容放入任务笔记或 PR 描述。缺一项就写“未确认”，不要让 AI 自行补全。

```text
目标能力：
官方指南 URL：
官方 API 参考 URL：
Kit/import：
类/接口：
实际成员/重载：
参数与返回值：
成员 @since：
相关参数/枚举 @since：
SystemCapability：
支持设备/应用类型：
权限类型与名称：
ACL/AGC/账号/网络/硬件前提：
错误与取消：
注册/释放：
当前项目 target/compatible：
API 兼容策略：
本地 SDK 声明位置：
同代样例位置：
静态结论：
构建结论：
真机结论：
服务结论：
```

---

## 4. ArkTS 与 ArkUI V2：保持语言和状态代际一致

### 4.1 ArkTS 不是“可以随便写 TypeScript”

`【官方通则】` ArkTS 强化静态类型与编译期检查，限制会影响正确性、可读性或运行时开销的 TypeScript 特性。官方迁移指南明确强调静态类型、对象布局稳定和严格检查。

AI 应遵守：

- 使用明确类型，不用 `any` 掩盖设计问题；
- 不用注释关闭类型检查来“通过编译”；
- 不从 JavaScript/TypeScript 代码机械粘贴不受支持的语法；
- 公共接口、复杂对象字面量、函数边界给出可读的显式类型；
- 遵循项目已有命名、缩进、行宽和 import 风格；
- 错误处理保留可诊断上下文，但不得泄漏敏感信息。

如果 ArkTS 编译器报错，先查官方“从 TypeScript 到 ArkTS 的适配规则”和对应 ArkTS 编译错误，而不是用类型断言层层压住错误。

### 4.2 V2 组件的数据方向

`【官方通则】` V2 通过更明确的输入、输出与深度观测改善组件化。常用装饰器的职责如下：

| 需求 | V2 工具 | 关键边界 |
| --- | --- | --- |
| 组件内部 owned 状态 | `@Local` | 必须由组件内部初始化；外部不能把它当构造输入 |
| 外部输入 | `@Param` | 数据源变化可向子组件同步；子组件不得直接修改该变量 |
| 必填构造输入 | `@Require` | 让缺失参数在构造/编译阶段暴露，而不是运行后猜默认值 |
| 子组件输出 | `@Event` | 子组件通过回调请求 owner 更新数据，不能偷偷改父状态 |
| 跨层级共享 | `@Provider/@Consumer` | 只用于真正的树级依赖，避免把所有业务状态变成全局 |
| 可观察类 | `@ObservedV2/@Trace` | 类与需观测属性配合；普通未追踪字段变化不能被假定会刷新 UI |
| 精准副作用 | `@Monitor` | 监听 V2 状态变化；按异步/合并语义设计，不能依赖每次赋值立即同步回调 |
| 应用运行期 UI 共享 | `AppStorageV2` | 应用运行期共享状态，不自动等于业务持久化或服务端状态 |
| UI 状态持久化 | `PersistenceV2` | 只在需求和数据性质合适时使用；仍需考虑版本、迁移、敏感性和业务边界 |

### 4.3 V1/V2 混用不是默认方案

`【官方通则】` 官方提供迁移和特定版本后的互操作方法，是为了迁移已有代码，不是鼓励新代码同时使用两套状态模型。

`【工程方法】`

- 新组件先识别所在树的代际；
- 不把 `@State/@Prop/@Link/@Provide/@Consume/@Observed` 和 V2 装饰器随意混入同一设计；
- 必须互操作时，列出数据方向、可观察深度、更新时机和 API 版本；
- 只在最小适配边界桥接，不让兼容代码扩散到整个 feature；
- 迁移时先用测试固定行为，再迁移 owner 和数据流，不同时重做 UI 和服务层。

`【项目规则：KangxiaobanAI】` 核心产品 UI 默认使用 `@ComponentV2`，owned state 用 `@Local`，输入用 `@Param/@Require`，输出用 `@Event`，导航栈等树级依赖使用 `@Provider/@Consumer`，模型使用 `@ObservedV2/@Trace`。没有明确互操作理由，不得引入 V1 装饰器。

### 4.4 V2 更新问题的标准诊断顺序

当“数据改了但 UI 没变”时，依次查：

1. UI 实际读取的是哪个对象/字段？
2. 字段是否被正确的 V2 状态装饰器跟踪？
3. `@ObservedV2` 类中的目标字段是否真的有 `@Trace`？
4. 修改的是被 UI 引用的同一个实例，还是另一个临时/默认实例？
5. 父组件数据源是否是状态变量？`@Param` 是否只是接到了普通常量？
6. 子组件是否试图直接修改 `@Param`，而不是通过 `@Event` 通知 owner？
7. Map/Set/Array/嵌套类的修改路径是否在当前 V2 观察范围？
8. `@Monitor` 是否因异步合并而没有按“每次赋值立即触发”的错误预期运行？
9. 组件是否被冻结、缓存、复用、不可见或已经销毁？
10. 是否在 `build()`/builder 中创建了新对象，导致 identity 不稳定或重复计算？

### 4.5 状态 owner 检查表

- [ ] 页面临时选择、筛选、展开状态属于页面/feature，不属于应用全局。
- [ ] 父组件拥有的数据由父组件修改，子组件只发事件。
- [ ] 跨层共享 key 唯一、可追踪，生命周期足够长但不过长。
- [ ] 业务数据没有为了“方便”塞入窗口/环境模型。
- [ ] AppStorageV2、PersistenceV2、Preferences、RDB、远端服务的语义没有混淆。
- [ ] 派生值没有每次 build 重做昂贵计算；复杂重复派生值才评估计算属性或缓存。
- [ ] Monitor 不产生更新循环，不承担应该由显式命令完成的业务事务。
- [ ] 离开页面、退出账号、切换租户、进程重启后的状态策略明确。

### 4.6 `KangxiaobanAI` 的具体状态边界

`【项目规则：KangxiaobanAI】`

- `GlobalInfoModel` 只适合窗口、断点、安全区、键盘、折叠状态和认证壳角色等环境/壳状态。
- 长者、任务、消息、入住表单、API DTO 不得因方便而放入 `GlobalInfoModel`。
- `AppStorageV2` 中的 AI 会话/环境对象不能被描述为数据库或云端持久化。
- 当前真实持久化只应按实际 Preferences/RDB/服务调用证据描述；不存在的 repository、RDB、网络或模型网关不得通过类型命名“假装存在”。
- 当前 mock 数据演进应先提取 per-feature FakeRepository，再引入 ViewModel/store、UseCase、repository interface 和真实 data source；不要先机械拆 HAR/HSP。

---

## 5. 权限、安全与用户可控：从“声明”走到“完整行为”

### 5.1 官方权限原则转成开发动作

`【官方通则】`

- 权限必须按真实业务逐个声明，遵循最小化原则；禁止申请非必要或已废弃权限。
- 敏感 user_grant 权限应在用户触发对应业务时动态申请，而不是应用启动即批量索取。
- 申请原因必须让用户理解“当前动作为什么需要当前权限”。
- 用户拒绝某权限后，与该权限无关的功能应继续可用。
- 每次执行敏感操作前都应确认当前授权状态，因为权限可能被撤销或系统回收。
- 不应频繁弹窗骚扰用户；需要转设置页时，要有明确解释和返回后的重新检查。
- 权限弹窗不得被业务 UI 遮挡或伪装。

### 5.2 权限状态机

不要只写 `granted: boolean`。至少考虑：

```text
Unknown
  -> NotDeclared / Unsupported
  -> NotDetermined
  -> Requesting
  -> Granted
  -> Denied
  -> DeniedAndNeedsSettings
  -> Revoked
  -> Restricted/ACLNotAvailable
```

应用 UI 应针对具体业务给出：继续、取消、降级、重试或打开设置，而不是无限循环申请。

### 5.3 权限审查问题

1. 没有这个权限，产品是否仍能完成核心任务？
2. 能否用系统选择器、安全控件或更小权限完成？
3. 申请时机是否紧贴用户动作？
4. `reason/usedScene` 是否准确且与 Ability 对应？
5. 第三方库是否引入了额外权限？
6. 精确/模糊、一次/长期、前台/后台权限是否选对？
7. 被拒绝、撤销、系统回收后是否仍安全？
8. 敏感数据是否最小收集、最短保存、可删除、日志脱敏？
9. 通知、剪贴板、截图、缓存、备份是否泄漏内容？
10. 真机、账号、区域、AGC 与审核要求是否完成？

`【项目规则：KangxiaobanAI】` 当前主模块没有受限权限声明。新增权限必须由明确功能驱动，同时提交配置、运行时申请、拒绝/撤销路径、隐私说明与真机验证计划。不得为了未来可能接入相机、定位、推送或健康数据而预先加权限。

---

## 6. 生命周期、监听器与异步清理：谁创建，谁负责结束

### 6.1 先区分不同生命周期

`【官方通则】` UIAbility、WindowStage、主窗口和 ArkUI 自定义组件各有生命周期，触发条件并不相同。UIAbility 前后台切换不必然等于组件销毁；组件不可见也不必然等于 Ability 进入后台；辅助窗口可能由应用自行管理。

因此不能用一个 `aboutToDisappear` 清理所有全局资源，也不能把页面定时器留给 Ability 销毁时再处理。

### 6.2 owner 选择原则

| 资源 | 推荐 owner 思路 |
| --- | --- |
| 应用/Ability 级服务连接 | 创建该连接的 Ability/服务对象，在对应销毁回调解除 |
| WindowStage/主窗口监听 | WindowStage/窗口管理 owner，保存回调引用并在窗口销毁时 `off` |
| 页面可见期监听/定时器 | 页面或 feature owner，页面离开/销毁时取消 |
| 弹层/会话请求 | 弹层或会话 store；关闭时取消或使旧回调失效 |
| Player/Camera/Sensor | 专门 manager/store，明确 start/stop/release 状态机 |
| PixelMap/Native handle/Node | 创建者或专门资源 owner，异常路径也释放 |
| 全局事件/订阅 | 注册者保存 token/callback，在生命周期结束时对称取消 |

### 6.3 对称清理账本

| 创建/注册 | 必须找到的对称动作 |
| --- | --- |
| `on(...)` | 对应 `off(...)`，通常需要同一个事件名和可识别回调 |
| `setTimeout` / `setInterval` | `clearTimeout` / `clearInterval`，并防止旧回调写入新状态 |
| 订阅/observer | unsubscribe/取消订阅/token dispose |
| player/decoder/camera/session | stop + release/close/destroy，按官方顺序 |
| PixelMap/Native resource | release/destroy，包含失败和替换路径 |
| 网络/模型请求 | cancel/abort，或用 request ID 忽略过期结果 |
| Worker/Task/Native callback | 终止、取消或在 owner 销毁后屏蔽回调 |

具体方法名必须以该 API 的当前参考为准。此表描述配对思想，不授权 AI 猜测释放方法。

### 6.4 监听回调 identity

常见泄漏来自注册时使用匿名函数，解绑时无法拿到同一回调。建议：

1. owner 保存回调或订阅 token；
2. 防止重复 initialize 重复注册；
3. destroy 时幂等解绑；
4. 重新绑定新窗口/设备前先解绑旧对象；
5. 记录注册次数和 owner identity，便于窗口重建排查。

### 6.5 异步回调的“过期结果”

即使 API 不支持取消，也必须阻止旧请求覆盖新状态：

```text
请求 A 开始
请求 B 开始
请求 B 先返回并显示
请求 A 后返回
```

如果没有 request ID、generation、当前会话校验或幂等策略，A 可能覆盖 B。页面关闭后回调还可能写入已销毁 owner。

最少需要：

- 请求唯一标识或 generation；
- 完成前检查当前 owner/会话仍有效；
- 重复提交禁用或幂等键；
- 超时、取消、重试和错误状态；
- `finally` 只做安全清理，不把失败也改成成功；
- UI 成功状态只由当前有效请求的确认结果驱动。

### 6.6 `KangxiaobanAI` 的生命周期关注点

`【项目规则：KangxiaobanAI】`

- `WindowUtil` 当前负责主窗口、UIContext、窗口尺寸和 avoid-area 监听。
- 静态扫描可见窗口监听注册，但未见对称解绑；这是生命周期风险，不是已经由真机证明的泄漏。
- 在增加 display、fold、keyboard、window、configuration 或其他监听前，必须先设计统一 teardown，不能再创建第二个不清理的 owner。
- `MainPage` 是认证后全屏/沉浸状态 owner；普通 child cover 不得独立重置窗口状态。
- AI/滚动等页面定时器应由页面 owner 清理；定时器完成只代表本地模拟步骤，不代表服务成功。

---

## 7. 配置、路由、资源和导航的一致性检查

很多“页面打不开”并不是页面代码错误，而是配置链断裂。

### 7.1 配置链

```text
product/module 声明
  -> module type / deviceTypes
  -> mainElement / Ability srcEntry
  -> pages profile / routerMap
  -> pageSourceFile / exported builder
  -> route name / typed params
  -> 调用方 push/replace/Want/deep link
  -> 返回与恢复行为
```

检查：

- 配置资源引用实际存在；
- 大小写与规范化 OHM URL 一致；
- route name、source、builder 和参数类型一致；
- 页面导出形式符合路由机制；
- HAP/HAR/HSP 的公共导出和依赖方向正确；
- deep link/通知/卡片入口验证不可信参数；
- 返回行为不会绕开 dirty guard 或 session 清理；
- 设备/产品分支不会进入没有出口的 WIP 页面。

### 7.2 Router 与 Navigation 不能随意混用

传统 Router、`Navigation/NavPathStack`、sheet、content cover、本地 pane 和 Extension/Want 各有 owner。新增流程前先判断它是：

- 应用壳页面切换；
- 应用内业务 destination；
- 临时模态呈现；
- 同页面 master/detail 状态；
- 外部/跨 Ability/跨应用入口。

`【项目规则：KangxiaobanAI】`

- `router.replaceUrl` 只保留在登录进入 Main、退出回到 Login 的认证壳边界。
- 应用内流程使用共享 `NavPathStack` 或现有局部 sheet/cover/pane 机制。
- 不经产品批准不得增加第一层 tab。
- 当前主模块没有 route map；通知、卡片、deep link、动态 HAR 或跨模块入口引入时，必须同步建立完整 named route 契约。

---

## 8. 验证边界：实现、构建、真机、服务不能互相冒充

### 8.1 推荐证据等级

| 标签 | 可以证明 | 不能证明 |
| --- | --- | --- |
| `Implemented` / 源码已实现 | 当前工作树存在可追踪代码、配置和调用路径 | 一定能编译、运行或连上服务 |
| `Static-confirmed` / 静态确认 | 配置、类型、路由、状态、权限声明和源码关系经过检查 | 编译器、设备和运行时一定接受 |
| `Build-verified` / 构建确认 | 指定工作树、SDK、product/module/mode 构建成功，产物对应本次代码 | HAP 能在目标设备完成交互；服务真实可用 |
| `Device-verified` / 真机确认 | 指定设备型号、系统版本、窗口、输入、权限状态下完成实际操作 | 其他设备/系统自动通过；后台一定持久化 |
| `Service-verified` / 服务确认 | 对真实 AGC/后台/账号/模型/分布式服务验证成功、失败与一致性 | 离线、性能、所有设备体验自动通过 |
| `Performance-verified` / 性能确认 | 有明确工具、场景、基线、样本和前后指标 | 其他场景无回归 |
| `Release-verified` / 发布确认 | release 签名、混淆、包、上架检查与发布配置通过 | 线上所有业务和服务永远正确 |
| `Planned` / 规划 | 架构或任务路线已定义 | 能力已经存在 |

### 8.2 构建报告必须具体

不写“项目构建成功”，要写：

```text
工作树/提交：
SDK/DevEco/Hvigor 环境：
product：
module：
target：
mode：debug / release
执行入口：DevEco / wrapper / CI
结果：
产物：
新增警告：
未覆盖：其他 product/module/mode、签名、安装、真机、服务
```

一个 sample 或另一个 product 构建成功，不等于目标产品成功。历史 `build` 目录存在也不能证明当前工作树已构建。

### 8.3 真机报告必须包含环境

```text
设备型号：
系统/API 版本：
应用 build：
窗口形态与尺寸：
输入：触摸 / 鼠标 / 键盘 / 手势 / 遥控
主题/字体/语言：
权限初始状态：
网络/账号：
步骤与结果：
日志/截图/录屏：
未覆盖：
```

涉及响应式和 ArkUI 时，至少考虑旋转、分屏/自由窗口、键盘开合、系统返回、快速重复操作、深浅色、大字体、读屏和焦点。

### 8.4 服务确认不只测“200/成功”

至少覆盖：

- 正常成功及服务端最终状态；
- 身份/角色/租户权限；
- 超时、断网、服务不可用；
- 参数校验和业务拒绝；
- 重复提交与幂等；
- 乱序、重试、冲突与回滚；
- token 过期、注销、切换账号/租户；
- 数据单位、时区、枚举和缺失值；
- 日志、通知、缓存和本地持久化的一致性；
- AI 输出的取消、安全审核、人类确认和可追溯性。

### 8.5 `KangxiaobanAI` 的真实性边界

`【项目规则：KangxiaobanAI】` 当前产品是高保真本地交互原型：登录、任务、消息、入住、医师/管理工作区和 AI 的大量行为是本地 mock/内存状态。没有网络层、repository、RDB 业务库、真实鉴权、WebSocket 或模型网关的证据时：

- 不得写“已登录后台”“消息已发送”“档案已提交”“AI 模型已回复”；
- 应写“本地演示登录”“本地记录”“本地草稿”“固定模板模拟回复”；
- 动画结束、定时器到期、本地数组更新只能驱动本地状态；
- 真实 `Confirmed` 必须由真实数据源/服务确认，并处理失败、超时和回滚。

---

## 9. 错误定位方法：先定界，再定位第一原因

### 9.1 保存失败现场

发生错误后先保存：

- 完整命令/IDE 操作和工作目录；
- product/module/target/mode；
- target/compatible SDK、DevEco/Hvigor/JDK/NDK 环境；
- 第一条 error、完整堆栈和其前后上下文；
- 当前 diff、相关配置、依赖锁文件；
- 设备型号、系统版本、权限、网络、账号；
- 可稳定复现的最短步骤；
- 最近一次成功的工作树/环境（如果有证据）。

不要一开始就清缓存、删 `oh_modules`、改 JDK、换 SDK、重建项目。那会同时改变多个变量，并可能破坏用户状态。

### 9.2 先给错误分层

| 层 | 常见表现 | 第一检查点 |
| --- | --- | --- |
| 环境/工具链 | 命令不存在、JDK/SDK/NDK 不匹配、进程无法启动 | 实际可执行文件、版本、环境变量、DevEco 配置 |
| 依赖 | 找不到模块、导出成员不存在、OHM URL 冲突 | `oh-package.json5`、lock、公共 exports、版本代际 |
| 配置/schema | `app/module/build-profile` 字段或资源引用错误 | 当前 schema、字段起始版本、资源实际存在性 |
| 资源 | `$string/$media/$profile` 不存在、重复或设备限定缺失 | 资源目录、限定词、名称、大小写 |
| ArkTS 编译 | 类型、装饰器、TS 迁移限制、API 成员不存在 | 精确错误码/规则、SDK 声明、V1/V2 代际 |
| Native/link | undefined symbol、ABI、CMake、头文件/库未打包 | ABI、链接目标、Native 依赖、打包配置 |
| 签名/安装 | 证书、Profile、设备、包一致性 | 使用正确签名来源；不得回显敏感值 |
| 启动/路由 | 黑屏、页面不存在、参数错误、返回异常 | mainElement—srcEntry—loadContent—route 全链 |
| 生命周期/资源 | 重复回调、后台仍工作、泄漏、窗口重建异常 | owner、注册次数、对称解绑、过期异步结果 |
| UI 状态 | 数据变但 UI 不变、旧状态覆盖新状态 | `@Trace`、实例 identity、`@Param/@Event`、Monitor 时序 |
| 权限/能力 | 构建成功但调用失败或设备不支持 | `@since`、SystemCapability、权限、ACL、设备、AGC |
| 服务 | UI 成功但后台无记录、超时、401/403/冲突 | 真实请求、身份、幂等、DTO、服务日志 |
| 性能 | 卡顿、长帧、内存/能耗异常 | 可复现场景、Profiler/HiLog、前后基线 |

### 9.3 锁定“第一条因果错误”

构建日志后面常有大量连锁错误。顺序是：

1. 找第一条明确 error，而不是最后一行“build failed”；
2. 找它引用的首个项目文件、配置字段、资源或依赖；
3. 判断后续错误是否只是该错误的传播；
4. 只修改最小原因；
5. 用同一命令复现；
6. 第一错误消失后，再处理下一条真正独立错误。

官方工具文档把 Hvigor 错误分为依赖、脚本、配置、资源、语法、规格、权限、操作异常、ArkTS 编译和签名等类别。利用错误码分类，比在日志中猜关键词更可靠。

### 9.4 API/类型错误定位

看到“成员不存在”“参数不匹配”“导出不存在”时：

1. 复制精确符号，不改写；
2. 查当前 SDK 声明中的 import、namespace、类和成员；
3. 查成员/重载的 `@since` 和 `SystemCapability`；
4. 查项目 target/compatible；
5. 查样例是否来自另一代 API 或 V1；
6. 查同步/异步重载、可选字段和返回类型是否混用；
7. 修正到当前 SDK 的真实签名；
8. 不用 `any`、强转或忽略规则掩盖错误。

### 9.5 配置/schema 错误定位

1. 根据错误路径确认是 app、module、product、target 还是资源 profile；
2. 查字段在当前 SDK/schema 是否存在及起始版本；
3. 检查字段层级、类型、重复字段和逗号；
4. 检查 `$resource` 是否真实存在；
5. 检查 module type/deviceTypes 与 product 安装组合；
6. 检查 Ability/Extension、permissions、routeMap 相互引用；
7. 不从另一个项目整段复制配置。

### 9.6 UI 不更新定位

```text
用户动作
  -> handler 是否进入
  -> 修改哪个 owner 的哪个实例
  -> 字段是否可观察
  -> 父子数据方向是否正确
  -> 组件是否仍激活/挂载
  -> build 是否读取该字段
  -> 是否被后续旧异步结果覆盖
```

记录修改前后值、owner identity 和 request generation，通常比到处加刷新调用更有效。

### 9.7 权限/设备能力定位

按顺序查：

1. 当前设备和系统是否支持；
2. API 版本是否满足；
3. SystemCapability 是否满足；
4. 普通应用是否可调用；
5. 配置是否声明；
6. ACL/Profile/AGC/账号是否完成；
7. 运行时授权状态；
8. 用户是否拒绝/撤销；
9. 调用时机和上下文是否正确；
10. 错误码是否来自当前接口。

### 9.8 日志与调试器使用原则

`【官方通则】` DevEco Studio 提供 ArkTS 调试、断点、变量检查、异步堆栈、HiLog 过滤/导出和 Profiler。Hvigor 也支持不同日志级别与堆栈跟踪配置。

`【工程方法】`

- HiLog 按应用进程、level、tag、关键词过滤，避免把全设备噪声当应用错误；
- 给一次用户动作附 request/operation ID，串起 UI、repository 和服务日志；
- 日志记录状态转换和错误上下文，不记录口令、token、身份证、健康详情或完整响应；
- 断点查看真实对象和异步堆栈，不能只依赖日志时序猜测；
- 性能问题先实时定界，再深度录制；先记录基线，后比较修复；
- Windows PowerShell 中根据 `$LASTEXITCODE` 或 `if` 判断命令结果，不套用 Bash 的 `||` 写法。

### 9.9 修复后的验证顺序

1. 用原始最短复现验证错误消失；
2. 执行同层相邻场景，确认不是绕过；
3. 跑目标模块静态检查/测试/构建；
4. 若改配置、公共状态或导航，扩大到受影响 product/device；
5. 若改生命周期，重复进入退出、前后台和窗口重建；
6. 若改服务，验证失败、超时、重复和乱序；
7. 检查 diff 和工作树，确认没有生成物、敏感信息或无关修改。

---

## 10. 给 Codex / Claude 的可复制提示词模板

模板中的方括号必须由人类或 Agent 用真实信息替换。AI 不得自行编造缺失的 SDK、API、设备或服务配置。

### 10.1 只读理解工程

```text
请只读理解 [工作区绝对路径] 中的 [目标项目]，不要修改文件、切换分支、拉取、构建或连接外部服务。

先读取适用的 AGENTS.md，然后：
1. 记录 branch 与 git status，标出已有修改；
2. 读取根/模块 build-profile.json5、oh-package.json5、AppScope/app.json5、module.json5、pages/route profile；
3. 确认 product、module type、target/compatible SDK、deviceTypes、权限和依赖；
4. 从 mainElement -> srcEntry -> loadContent -> 根页面 -> Navigation/Router -> [目标功能] 追调用链；
5. 画状态、数据、生命周期和资源 owner；
6. 区分 mock、本地持久化、真实服务；
7. 用 文件:行号 给证据。

报告分别标记 Static-confirmed、Build-pending、Device-pending、Service-pending。不要把不存在的层补成规划，更不要把规划说成实现。
```

### 10.2 实现一个功能

```text
在 [工作区] 的 [product/module] 实现：[需求]。

约束：
- 保留用户已有修改；只改最小 ownership boundary；
- 先确认 target/compatible SDK、ArkUI V1/V2、HDS/导航/状态 owner；
- 每个新增 HarmonyOS API 必须提供精确 import、成员/重载、@since、SystemCapability、设备范围、权限和官方链接证据；
- 不得凭样例猜 API，不得用 any 或忽略类型检查绕过；
- 创建的监听、定时器、资源和异步任务必须有对称清理/过期结果保护；
- 不把本地状态或动画结束显示成后台成功；
- 若涉及权限，完成声明、业务触发申请、拒绝/撤销/设置返回路径；
- 若存在产品级选择且无法从源码确认，停止并说明需要的决定。

先写验收场景，然后修改、检查 diff、运行与风险相称的测试/构建。最终分别报告 Implemented、Build、Device、Service 证据和待验证项。
```

### 10.3 只核验某个 API 是否可用

```text
请只读核验 [API/能力名称] 是否可用于 [项目/模块]，不要修改代码。

必须核对：
1. 当前 target/compatible SDK；
2. 官方 Kit/import、类、实际成员和重载；
3. 成员及参数/枚举的 @since；
4. SystemCapability、设备/应用类型、三方/系统应用限制；
5. 权限、ACL、AGC、账号、网络、硬件前提；
6. 错误、线程、生命周期、on/off 或 release；
7. 当前安装 SDK 声明与同代本地样例。

输出一张 API 证据卡。若任何字段未确认，明确写“未确认”，不要生成代码猜答案。
```

### 10.4 接入需要权限的 Kit

```text
为 [业务动作] 设计/实现 [Kit] 接入。

请先证明：权限名称、授权类型、@since、SystemCapability、支持设备、普通应用开放范围和 AGC/ACL 前提。
权限必须最小化，并在用户触发 [具体动作] 时申请。

覆盖状态：未声明/不支持、未决定、申请中、已授权、拒绝、需设置、撤销、系统回收。
每次敏感操作前重新确认权限；拒绝后非相关功能继续可用；不得循环弹窗。
列出敏感数据收集、保存、日志、通知、删除和退出账号清理策略。

完成后分别报告构建、目标真机、账号/服务验证；模拟器结果不得冒充真机服务结果。
```

### 10.5 新建或重构 ArkUI V2 组件

```text
请在 [文件/feature] 使用 ArkUI V2 完成 [组件目标]。

先说明状态 owner：
- owned UI state -> @Local
- 外部输入 -> @Param，必填加 @Require
- 子组件输出 -> @Event
- 树级依赖 -> 仅在必要时 @Provider/@Consumer
- 可观察类 -> @ObservedV2/@Trace
- 精准副作用 -> @Monitor，说明异步/合并语义

禁止引入无理由 V1 装饰器；禁止子组件直接修改 @Param；禁止把业务数据放入应用环境全局状态。
检查组件创建、可见、冻结、复用、销毁时的定时器/监听/异步结果。
验证快速输入、重复切换、返回、窗口变化、大字体、焦点和读屏。
```

### 10.6 诊断“UI 数据变化但不刷新”

```text
请先诊断，不要修改代码。

问题：[复现步骤]
预期：[预期]
实际：[实际]

从用户动作追到 handler、owner 实例、被修改字段、V2 装饰器、父子输入输出、build 读取、组件挂载/冻结/复用状态和异步回调时序。
重点核对 @ObservedV2 类的目标字段是否有 @Trace、@Param 数据源是否可观察、子组件是否错误修改输入、@Monitor 是否被误认为同步逐次触发、旧请求是否覆盖新状态。

输出根因、证据位置、最小修复建议和需要的验证；静态证据不足时不要直接断言运行时根因。
```

### 10.7 诊断构建失败

```text
请诊断以下 HarmonyOS 构建失败，除非我明确授权，否则不要修改文件或清缓存：
[完整命令、cwd、product/module/mode、第一条错误及上下文]

先把错误分为环境、依赖、配置/schema、资源、ArkTS、Native、签名或操作异常。
定位第一条因果错误及其项目文件，不从最后一行 build failed 反推。
核对当前 SDK、Hvigor、JDK、配置、依赖和官方错误码。
不要删除 oh_modules/.hvigor/build 来试运气，不要输出签名敏感值。

给出：根因证据、最小修复、风险、原命令复验方式和仍需验证的范围。
```

### 10.8 生命周期/泄漏审查

```text
请只读审查 [范围] 的生命周期与资源清理。

盘点所有 on/off、observer、timer、player、camera、sensor、PixelMap、Node、Worker/Task、网络/模型请求和 Native handle。
对每项列：创建位置、owner、重复创建条件、释放位置、异常路径、页面关闭/Ability 后台/窗口销毁行为、过期回调保护。

只报告有源码证据的问题。没有真机/Profiler 证据时写“泄漏风险”或“待验证”，不要写“已经泄漏”。
```

### 10.9 代码审查

```text
请审查 [diff/commit/文件]，不要自动修改。

优先查：
1. target/compatible、@since、SystemCapability、权限和设备范围；
2. 配置/路由/资源一致性；
3. ArkUI V2 owner、输入输出和更新时序；
4. 生命周期、重复监听、异步乱序和资源释放；
5. mock/本地/服务真实性；
6. 安全、隐私、日志和签名信息；
7. phone/tablet/2in1、键鼠、返回、安全区、主题、大字体、无障碍；
8. 测试是否覆盖真实行为，验证声明是否超过证据。

每个 finding 给严重度、文件:行号、触发条件、影响和修复方向。没有可定位证据则不要报告为事实。
```

### 10.10 `KangxiaobanAI` 专用实施提示词

```text
在 D:\Coding\KangxiaobanAI_OC\KangxiaobanAI 完成 [需求]。

必须遵守根 AGENTS.md，并先核对当前配置；不要依赖旧报告。默认目标是单 entry 产品，当前 target API 24、compatible API 23，设备为 phone/tablet/2in1，核心 UI 是 ArkUI V2 + HDS。

保留认证壳 Router 边界和应用内共享 NavPathStack；未经批准不加第一层 tab；不替换 HDS 根壳；不复制样例工程；不重复创建全窗口 safe-area owner。
GlobalInfoModel 只放环境/壳状态；业务数据不得塞入全局。当前登录、任务、消息、入住和 AI 的本地演示行为不得描述为真实服务。
新增 API 做 @since/SystemCapability/API23 兼容核验；新增监听先补 owner/teardown；新增权限需完整申请与拒绝路径。

实施后报告改动文件、行为、配置/权限/路由变化、测试、准确 build product/mode、真机/服务未验证项。不要读取或输出签名敏感内容。
```

---

## 11. AI 代码审查总清单

### 11.1 工作树与范围

- [ ] 目标顶层项目/product/module 明确。
- [ ] 已记录 branch、git status 和用户已有修改。
- [ ] 未修改样例、生成物、签名或无关文件。
- [ ] diff 是完成需求所需的最小 coherent boundary。

### 11.2 配置与 API

- [ ] target/compatible/runtime OS 来自当前 profile。
- [ ] module type、deviceTypes、mainElement、pages、Ability/Extension 一致。
- [ ] 每个新增 API 的 import、成员/重载、参数、返回值已从当前 SDK/官方参考确认。
- [ ] 成员和相关枚举/字段 `@since` 不超过允许范围，或已有明确兼容策略。
- [ ] SystemCapability、设备、应用类型、普通/系统应用开放范围已核对。
- [ ] 未从旧样例复制已废弃 import、装饰器、配置或方法。

### 11.3 ArkTS / ArkUI V2

- [ ] 没有用 `any`、忽略类型检查或强转掩盖真实类型问题。
- [ ] V1/V2 代际与周围代码一致。
- [ ] `@Local/@Param/@Require/@Event` 的 owner 与方向明确。
- [ ] `@ObservedV2/@Trace` 配合正确；普通字段未被假定可刷新 UI。
- [ ] `@Monitor` 没有更新循环，也没有被当成同步事务回调。
- [ ] AppStorageV2/持久化/业务仓库/服务端状态未混淆。
- [ ] build/builder 中没有不必要的昂贵计算和不稳定对象创建。

### 11.4 生命周期与异步

- [ ] UIAbility、WindowStage、窗口、页面、弹层 owner 区分清楚。
- [ ] 每个 listener/observer/timer/subscription 都有对称 cleanup。
- [ ] player/camera/sensor/PixelMap/Node/Native 资源按官方顺序释放。
- [ ] 重复 initialize/复用/窗口重建不会重复注册。
- [ ] 异步请求有取消或过期结果保护。
- [ ] 重复提交、乱序、超时和 retry 不会制造错误成功态。

### 11.5 权限、安全和隐私

- [ ] 权限真实必要、最小化、未废弃。
- [ ] 权限配置、reason/usedScene、ACL/Profile、运行时申请完整。
- [ ] 拒绝、撤销、设置页返回和不支持状态有 UI 路径。
- [ ] 非相关功能在拒绝后仍可使用。
- [ ] 日志、通知、剪贴板、缓存和错误信息不含敏感数据。
- [ ] 未引入证书、密码、token、私有端点或本机绝对秘密路径。

### 11.6 导航、响应式和体验

- [ ] Router/Navigation/sheet/cover/pane/Want 的选择符合 owner。
- [ ] route name、builder、source、typed params 和 back 一致。
- [ ] 系统栏、安全区、导航指示条、键盘、cutout/fold 使用实时值。
- [ ] phone/tablet/2in1 与窗口 resize 路径检查。
- [ ] 触摸、鼠标、键盘、返回、焦点、hover、selected 状态检查。
- [ ] 深浅主题、大字体、语言、对比度、读屏标签和顺序检查。
- [ ] 动画可中断；Reduce Motion/降级路径按风险考虑。

### 11.7 数据、服务与业务真相

- [ ] mock、本地内存、Preferences/RDB、远端服务标识准确。
- [ ] DTO/domain/UI model 分开，缺失值、单位、时区和枚举明确。
- [ ] loading/empty/error/denied/offline/retry/conflict/session expired 已建模。
- [ ] 成功态来自真实 owner；动画/定时器/本地更新不冒充服务确认。
- [ ] 身份、角色、租户、授权在 UI 之外有真实约束设计。
- [ ] AI 建议可取消、可审核、有失败路径；高后果操作需要人类确认。

### 11.8 测试与交付

- [ ] 测试覆盖变化的规则/状态/交互，不是模板字符串断言。
- [ ] 精确 product/module/mode 构建结果已记录。
- [ ] 真机型号/系统/窗口/输入/权限状态已记录，或明确待验证。
- [ ] 真实服务成功、失败、超时、权限、重复和乱序已验证，或明确待验证。
- [ ] diff、git status、生成物和新增警告已复查。
- [ ] 最终报告没有把 Static 写成 Build、Device 或 Service。

---

## 12. 禁止事项与 AI 幻觉清单

下面任一行为出现，评审应默认阻止合并，直到获得真实证据或产品批准。

### 12.1 API 幻觉

- 禁止编造 Kit 名、import 路径、类名、方法名、枚举值、参数字段、错误码或释放方法。
- 禁止看到相似 Android/iOS/Web API 后按 HarmonyOS 命名风格“翻译”一个接口。
- 禁止只看类的 `@since`，忽略成员、重载、参数字段和枚举值版本。
- 禁止把 `SystemCapability` 当权限，或把权限当设备能力。
- 禁止把官网最新文档直接当当前项目 SDK 声明。
- 禁止把一个样例可编译推断为当前产品、设备和应用类型都可用。
- 禁止为了通过编译使用 `any`、忽略类型检查、任意强转或伪造声明文件。

### 12.2 架构幻觉

- 禁止因为出现 `Service`、`Repository`、`Manager` 名字就宣称真实服务已实现。
- 禁止把 AppStorageV2 描述为数据库、云同步或业务持久化。
- 禁止把 `deviceTypes` 描述为已经完成多端体验或分布式能力。
- 禁止把 UI 角色字符串描述为 RBAC/授权。
- 禁止把本地数组、定时器或动画回调描述为后台成功。
- 禁止把规划目录、接口草案或 TODO 描述为 Implemented。
- 禁止用旧报告覆盖当前 profile 和源码事实。

### 12.3 生命周期幻觉

- 禁止认为页面离开后匿名监听会自动解绑。
- 禁止只清理成功路径，不清理失败、取消、替换和销毁路径。
- 禁止使用新的匿名函数去 `off` 旧匿名监听，并声称已解绑。
- 禁止把 Ability 前后台、WindowStage 销毁和组件不可见视为同一事件。
- 禁止忽略旧异步结果覆盖新会话。

### 12.4 权限与安全禁区

- 禁止为未来可能需求预申请权限。
- 禁止应用启动时一次性索取所有敏感权限。
- 禁止在用户拒绝后循环弹窗或阻断无关功能。
- 禁止复制样例权限、Client ID、包名、证书指纹或 Profile。
- 禁止输出、提交或总结签名口令、token、身份证、健康数据、私有端点。
- 禁止以日志完整性为由记录敏感 payload。

### 12.5 验证幻觉

- 禁止把静态搜索写成“构建成功”。
- 禁止把构建成功写成“真机已验证”。
- 禁止把预览器/模拟器写成目标硬件真机验证。
- 禁止把 UI 出现成功文案写成服务确认。
- 禁止把历史产物或别的 product 构建写成本次目标成功。
- 禁止没有指标就写“性能已优化”。
- 禁止没有遍历/覆盖证据就写“所有菜单都已阅读”。

### 12.6 操作禁区

- 禁止为“干净”执行 destructive Git 或递归清理用户工作树。
- 禁止遇到构建错误就先删缓存、依赖和构建目录。
- 禁止修改样例来证明产品能力。
- 禁止同时大改 UI、状态、服务、导航和模块架构，除非任务明确要求且有分阶段验证。
- 禁止新增第一层 tab、权限、Ability、route、HAR/HSP、依赖或全局 key 而不说明完整影响。

---

## 13. `KangxiaobanAI` 项目执行卡

这张卡只适用于当前项目；其他 HarmonyOS 工程不得直接套用。

### 13.1 当前静态基线

- 默认交付项目：`KangxiaobanAI`。
- 产品性质：HarmonyOS NEXT 智慧养老高保真本地交互原型。
- 当前 profile：target API 24、compatible API 23、Stage 模型。
- 主模块：单 `entry` 模块，设备声明 phone/tablet/2in1。
- 启动：Ability 加载 Login，登录后进入 Main。
- UI：ArkUI V2 + HDS，根 HDS Navigation，手机 HDS Tabs，宽屏角色 workspace。
- Router：仅认证壳边界；应用内使用共享 NavPathStack 或已有局部呈现。
- 数据：大量本地 mock；没有真实网络/repository/RDB/WebSocket/model gateway 证据。
- 权限：主模块当前没有受限权限声明。
- 验证：除非有当次记录，不得默认已构建、真机或服务验证。

### 13.2 改动前必须回答

1. 需求属于手机、宽屏还是两者？角色矩阵是否支持？
2. 是否改变四个第一层 phone tabs 或根 HDS shell？
3. 是否改变认证 Router 边界或共享 NavPathStack？
4. 是否影响 720vp/1180vp 等当前布局边界和 device type 判断？
5. 是否新增 API 24-only 能力？API 23 策略是什么？
6. 是否新增监听？统一 teardown 在哪里？
7. 是否新增权限/Kit/AGC/账号/硬件？
8. 是否把本地状态变成真实服务？repository、DTO、错误和幂等怎样设计？
9. 是否会把成功文案说得比证据更强？
10. 哪些设备、输入、安全区、主题、大字体和读屏场景要真机验证？

### 13.3 改动中固定规则

- 默认继续 `@ComponentV2` 和 V2 数据方向。
- 不把长者、任务、消息、入住和 DTO 放入 `GlobalInfoModel`。
- 不复制 API 17/20 的 V1 样例装饰器到 API 24 核心代码。
- 不替换 HDS 根壳为自绘 dashboard，不增加结构性 sidebar/top bar。
- 不重复拥有全窗口沉浸/安全区扩展。
- 不把底部 navigation inset 加到整个 persistent viewport。
- 不把定时器/动画/本地数组更新写成真实提交。
- 不读取或输出签名敏感内容。

### 13.4 当前高风险待验证

- WindowUtil 监听注册缺少已观察到的对称 teardown；修改窗口链时优先处理 owner 设计。
- compatible API 23；API 24-only 成员必须有兼容决定。
- 手机医师/管理仍为 WIP，不得宣称三角色手机端完整。
- 消息、任务、入住和 AI 仍缺真实服务状态机。
- 产品测试仍不足以证明核心业务行为。
- 读屏、大字、深色、窗口重建、性能和全设备矩阵需要当次真机证据。

更完整的源码映射见 [`kangxiaobanai-adaptation.md`](./kangxiaobanai-adaptation.md)。

---

## 14. 标准交付报告模板

```markdown
## 结果
[一句话说明行为结果，不先讲过程]

## 改动
- [文件:符号]：行为变化
- 配置/权限/路由/依赖：无 / 具体说明

## API 证据
- API：
- 官方链接：
- import/member/overload：
- @since / compatible 策略：
- SystemCapability / device：
- permission / AGC / hardware：

## 验证
- Static-confirmed：
- Build-verified：[product/module/mode/SDK/命令/结果]
- Device-verified：[设备/系统/窗口/输入/场景] 或“未执行”
- Service-verified：[真实服务场景] 或“未执行”
- Performance-verified：[指标] 或“未执行”

## 风险与待办
- [明确未验证项]
- [兼容/权限/生命周期/安全/服务风险]

## 工作树
- 用户原有修改：已保留
- 本任务修改文件：
- 生成物/敏感信息：未加入
```

### 14.1 好的结论示例

- “已在源码中实现 API 24 的某功能；目标模块 debug 构建通过。由于 compatible API 为 23，API 23 真机降级仍待验证。”
- “静态确认监听注册和回调 owner；未运行窗口重建，不能确认不存在重复监听。”
- “本地任务状态可切换；没有后台请求，因此不称为任务已提交。”
- “权限声明和拒绝 UI 已实现；尚未在目标设备、真实账号和 AGC 配置下验证。”

### 14.2 不合格结论示例

- “应该支持所有鸿蒙设备。”
- “API 看起来没问题。”
- “编译器没报红，所以真机可用。”
- “点击后显示成功，接口已经接通。”
- “用了 AppStorageV2，所以数据已持久化。”
- “官方样例这样写，复制过来即可。”

---

## 15. 官方页面快速索引

以下链接是本手册重点工作流的官方入口。具体 API 仍需进入对应 Kit 的 API 参考核对精确签名。

- [应用开发导读](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-guide)
- [应用开发准备](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-overview)
- [app.json5 配置文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-configuration-file)
- [module.json5 配置文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/module-configuration-file)
- [ArkTS 编程规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-coding-style-guide)
- [从 TypeScript 到 ArkTS 的适配规则](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide)
- [状态管理 V1 和 V2 更新机制差异](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-v1-v2-update-difference)
- [`@Local`：组件内部状态](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-local)
- [`@Param`：组件外部输入](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-param)
- [`@Event`：规范组件输出](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-event)
- [`@Provider/@Consumer`](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-provider-and-consumer)
- [`@ObservedV2/@Trace`](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-observedv2-and-trace)
- [`@Monitor`](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-monitor)
- [AppStorageV2](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-appstoragev2)
- [状态管理 V1/V2 混用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-v1-v2-mixusage)
- [UIAbility 组件生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uiability-lifecycle)
- [窗口生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/window-lifecycle)
- [自定义组件生命周期（推荐）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-custom-components-new-lifecycle)
- [应用权限管控概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-permission-mgmt-overview)
- [向用户申请授权](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/request-user-authorization)
- [手动设置授权](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/open-permission-on-setting)
- [构建系统生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-life-cycle)
- [编译构建错误码](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-errorcode)
- [使用日志记录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-log)
- [ArkTS 代码调试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-debug-arkts)
- [HiLog 日志分析](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-setup-hilog)
- [使用 Profiler 进行性能调优](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-profiler-introduction)

---

## 16. 最后一道 AI 自检

在输出任何 HarmonyOS 修改或结论前，Agent 应逐句问自己：

1. 这句话是官方事实、工程方法、项目规则，还是待验证？
2. 我能给出当前源码/配置/SDK/官方页面的位置吗？
3. 我是否把类的版本误当成成员的版本？
4. 我是否把 SystemCapability、权限、设备硬件和服务配置混为一谈？
5. 我是否保持了 ArkUI V2 的 owner、输入和输出？
6. 我创建的每个监听、定时器、任务和资源在哪里结束？
7. 我是否让旧异步结果有机会覆盖新状态？
8. 我是否把本地 UI 状态说成服务端事实？
9. 我声称的 Build、Device、Service、Performance 是否各有真实证据？
10. 我是否泄漏、覆盖或提交了用户已有修改和敏感信息？

任一答案不清楚，就把结论降级为“待验证”，回到证据链继续查。可靠的 AI 编程不是“代码看起来像 HarmonyOS”，而是每一个接口、状态、生命周期、权限和验证结论都能沿证据链回到当前工程与当前平台。
