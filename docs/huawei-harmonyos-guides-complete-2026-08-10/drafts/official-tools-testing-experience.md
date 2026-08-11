# 官方工具、测试与体验建议：从“能写代码”到“可交付”

> 覆盖范围：官网左侧菜单的“工具”“测试”“体验建议”三大分区。  
> 快照日期：2026-08-10。  
> 详细逐页入口：`../FULL_PAGE_DIGESTS.md`；完整层级：`../coverage/menu-tree.md`。  
> 本章是工程化综合，不复制官网正文，不用一个摘要替代 838 个页面的逐页记录。

## 1. 覆盖基线

[官方事实] 本章对应的官方页面体量如下。

| 分区/根目录 | 正文页 | 正文字符 | 代码块 | 表格 | 提示/警告 | 图片 |
|---|---:|---:|---:|---:|---:|---:|
| 工具 | 757 | 1,587,532 | 2,405 | 503 | 643 | 2,767 |
| 测试 | 23 | 223,397 | 294 | 147 | 86 | 359 |
| 体验建议 | 58 | 30,750 | 0 | 248 | 0 | 0 |
| **合计** | **838** | **1,841,679** | **2,699** | **898** | **729** | **3,126** |

[解释] “工具”不是写完功能以后才看的附录。SDK、IDE、构建系统、依赖管理、签名、调试、测试、性能和发布共同决定代码是否真的可用。只检查 ArkTS 语法，不检查这些边界，最多能证明“文本像代码”，不能证明应用可构建、可运行或可发布。

### 1.1 工具分区的八棵子树

| 根目录 | 页面 | 工程问题 |
|---|---:|---|
| 开发环境搭建 | 128 | SDK、DevEco Studio、工程模板、仓库、离线环境 |
| 编写与调试应用 | 437 | 编辑、静态检查、预览、签名、设备、调试、日志、自测试 |
| 构建应用 | 62 | Hvigor、配置、product/target、产物、插件、混淆、报错 |
| 优化应用性能 | 37 | 帧、启动、内存、CPU、GPU、能耗、网络、并发 |
| 发布应用 | 2 | 发布准备、应用市场、运维分析 |
| 命令行工具 | 50 | Command Line Tools、codelinter、hstack、Emulator、hvigorw、ohpm、流水线 |
| AI Coding | 10 | DevEco Code、DevEco CLI |
| 使用 AI 智能辅助编程（不推荐） | 31 | 旧代 AI 辅助能力、智能体与本地知识库配置 |

### 1.2 测试与体验建议的子树

| 根目录 | 子类 | 页面 |
|---|---|---:|
| 应用测试 | 开发者测试服务概述 | 1 |
| 应用测试 | 单元测试和 UI 测试 | 8 |
| 应用测试 | 专项测试 | 14 |
| 应用体验建议 | 基础功能和兼容性 | 15 |
| 应用体验建议 | 稳定性 | 1 |
| 应用体验建议 | 性能 | 7 |
| 应用体验建议 | 功耗 | 10 |
| 应用体验建议 | 安全隐私 | 23 |
| 应用体验建议 | UX | 1 |
| 应用体验建议 | 概述 | 1 |

---

## 2. 工具链必须按一条依赖链理解

[官方事实] HarmonyOS 工程涉及 DevEco Studio、HarmonyOS SDK、JDK/JBR、Node.js、Hvigor/Hvigor 插件、ohpm、模块依赖与设备侧运行环境。不同版本组合会改变可用 API、构建参数、任务名、模拟器能力和诊断结果。

[解释] 处理工程问题时，应把工具链画成下面这条链，而不是把每个错误孤立看待：

```text
当前源码和配置
  -> SDK / API 版本
  -> 构建系统与插件版本
  -> 依赖解析与锁定结果
  -> debug/release/product/target/module
  -> 签名与设备环境
  -> HAP/HAR/HSP/APP 产物
  -> 安装、启动、测试、性能与发布结果
```

### 2.1 AI 开始工作前必须发现什么

[解释] Codex/Claude 不应先生成代码，再猜工程结构。最低发现顺序是：

1. 确认工作目录与目标顶层项目。
2. 读取工程级 `build-profile.json5`、`oh-package.json5` 和 `hvigor-config.json5`（若存在）。
3. 读取 `AppScope/app.json5`。
4. 读取相关模块的 `module.json5`、模块级 `build-profile.json5`、`oh-package.json5`。
5. 确认 module 类型、product、target、deviceTypes、targetSdk、compatibleSdk。
6. 确认实际入口、路由、资源、依赖和 native 目录。
7. 再选择 API、装饰器、Kit、构建任务和验证命令。

[项目适配] `KangxiaobanAI` 当前源码配置是 target API 24、compatible API 23。任何“API 24 一定可用”的推断都必须区分“目标版本允许编译”与“最低兼容设备上可运行”。

### 2.2 工程模板只负责起点

[官方事实] 官网“工程创建”子树涵盖应用、元服务、不同设备、Native C++、云开发、Kit 示例、仓库等大量模板与向导。

[解释] 模板能够给出目录形状和默认配置，但不能覆盖一个长期演进项目的真实状态。AI 不能因为官方示例使用 `entry`、V1 状态装饰器或某个 API 版本，就强行改造当前项目以匹配模板。

### 2.3 离线、代理与仓库是可复现性问题

[官方事实] 官方工具文档单独提供离线环境、代理、ohpm 仓库与接口协议等说明。

[解释] “我这里能装依赖”不等于构建可复现。工程至少要记录：

- 使用的 SDK 与工具版本；
- 仓库来源和优先级；
- 是否需要代理、镜像或企业私服；
- 锁文件是否参与版本控制；
- CI 是否使用相同依赖解析策略；
- 离线构建需要预置哪些包。

代表页面：

- [工具概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-tools-overview)
- [下载与安装 DevEco Studio](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-software-install)
- [离线环境配置指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-no-network)
- [ohpm 仓库接口协议](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-interface-protocol)

---

## 3. 编辑、静态检查、预览与调试不是同一种验证

### 3.1 代码编辑与 Code Linter

[官方事实] “代码编辑”子树包含 296 页，是工具分区最大的单一子类，覆盖语言支持、API 检查、Code Linter 规则、快速修复、Native/ArkTS 跨语言生成和大量规则说明。

[解释] 静态检查的价值是尽早发现：

- 不受支持的语法或 API；
- 不安全或低性能模式；
- 资源、依赖、导入和配置不一致；
- ArkUI 状态和组件用法问题；
- 可维护性与规范问题。

它不能证明：运行时权限已经授权、系统服务可用、设备具备 SystemCapability、真实数据正确、页面在不同窗口尺寸无错位。

代表页面：

- [Code Linter 代码检查](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-code-linter)
- [Code Linter 规则变更说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-codelinter-rules-change)

### 3.2 Previewer 的证据边界

[官方事实] 预览器支持部分 UI API、数据模拟与预览检查，并有独立的可用 API 清单和限制说明。

[解释] 预览通过只能证明“该预览上下文能渲染”。以下内容仍需设备或模拟器：

- Ability 与窗口完整生命周期；
- 权限弹窗与拒绝路径；
- Kit 服务连接；
- 相机、麦克风、定位、蓝牙等硬件；
- 系统栏、安全区、键盘、折叠状态；
- 真正的触摸、鼠标、键盘、焦点和返回手势；
- 性能、内存、功耗与进程行为。

代表页面：

- [预览数据模拟](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-previewer-mock)
- [支持使用预览器的 API 清单](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-previewer-api-list)

### 3.3 真机、模拟器与仿真器

[解释] 三者承担不同证据：

| 环境 | 适合验证 | 不能轻易证明 |
|---|---|---|
| Previewer | 局部布局、资源、部分组件状态 | 完整系统行为 |
| 模拟器 | 多数应用流程、窗口、部分系统能力 | 全部硬件、真实功耗和厂商设备差异 |
| 仿真器/特定设备模拟 | 指定轻量设备形态 | 普通手机/平板的完整行为 |
| 真机 | 系统交互、硬件、性能、安装和签名 | 所有其他设备型号都一致 |

[项目适配] `KangxiaobanAI` 支持 phone、tablet、2in1。任何 UI 改动至少要给出三个形态的验证状态；只在一个 Previewer 尺寸截图不能称为“多端验证通过”。

### 3.4 调试、热重载和冷启动

[解释] 热重载/增量调试用于缩短反馈时间，但它可能保留进程、状态或缓存。涉及以下问题时必须做冷启动或重装验证：

- Ability 启动顺序；
- 全局状态初始化；
- 数据迁移；
- 权限首次请求；
- `module.json5`、资源与构建配置；
- Native 库加载；
- release 混淆；
- 首帧和启动性能。

### 3.5 日志与第一因果错误

[官方事实] 官方文档覆盖 hilog、设备日志、故障日志、AppFreeze、异常堆栈解析和 hstack。

[解释] 排障时应保留完整上下文，并寻找第一条具有因果意义的错误。后续数十条错误可能只是依赖解析、编译或启动失败的连锁反应。

推荐记录：

- 命令与工作目录；
- SDK/JDK/Node/Hvigor/ohpm 版本；
- product、target、module、buildMode；
- 第一条错误及其前后日志；
- 退出码；
- 产物路径；
- 复现步骤；
- 是否只发生在 debug、release、模拟器或真机。

代表页面：

- [日志分析](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-setup-hilog)
- [查看 AppFreeze 日志](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-faultlog-appfreeze)
- [异常堆栈解析原理](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-exception-stack-parsing-principle)
- [堆栈解析工具 hstack](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-hstack)

---

## 4. 签名：能构建和能安装之间的安全边界

[官方事实] 调试签名、发布签名、证书和 profile 决定应用是否能安装、调试或发布；工具文档对调试签名有独立说明。

[解释] 编程 AI 处理签名时必须遵守：

- 不打印证书密码、私钥密码、token 或完整本机证书路径；
- 不把本地签名配置复制到示例或提交中；
- 不以“为了构建成功”为由生成、替换或提交生产签名；
- 区分未签名构建、调试签名安装和正式发布签名；
- 报告构建结果时说明产物是否签名。

[项目适配] `KangxiaobanAI/build-profile.json5` 当前没有固定 `signingConfigs`。因此静态检查或未签名编译不能冒充“已生成可发布 HAP”。

代表页面：[配置调试签名](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-signing)

---

## 5. Hvigor 构建模型

### 5.1 构建配置的三个坐标

[官方事实] HarmonyOS 构建围绕 product、module/target、buildMode 组织；工程级和模块级 `build-profile.json5` 分担不同配置。

[解释] AI 在给出构建命令前必须回答：

1. 构建哪个 product？
2. 构建哪个 module 与 target？
3. 使用 debug 还是 release？

若这三个坐标没有确定，命令成功也可能生成了错误产物。

代表页面：

- [工程级 build-profile.json5](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-build-profile-app)
- [模块级 build-profile.json5](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-build-profile)
- [hvigor-config.json5](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-set-options)

### 5.2 产物语义

[官方事实] 常见构建任务面向 HAP、HAR、HSP 和 APP 等不同产物。

[解释] 产物名称不是后缀差异，而是架构和交付边界：

| 产物 | 主要用途 | 验证关注点 |
|---|---|---|
| HAP | 可安装应用模块 | module 类型、签名、设备类型、权限 |
| HAR | 静态共享包 | 公共导出、资源冲突、依赖膨胀、API 兼容 |
| HSP | 动态共享包 | 运行时依赖、版本与部署组合 |
| APP | 发布包集合 | 多模块组合、签名、发布配置 |

### 5.3 常用命令的正确表述

[官方事实] `hvigorw` 是 Hvigor 的 wrapper，可安装/调用匹配的构建工具与插件。官方页面列出 `assembleHap`、`assembleApp`、`assembleHsp`、`assembleHar`、`test`、`onDeviceTest` 等任务及参数。

[解释] 命令示例只能作为形状，最终以当前工程 wrapper 和 `hvigorw --help` 为准：

```powershell
./hvigorw.bat assembleHap --no-daemon
./hvigorw.bat test -p module=kanxiaoban@default
./hvigorw.bat onDeviceTest -p module=kanxiaoban@default
```

不要因为网上或旧文档出现某个参数，就假设当前 wrapper 支持。先记录版本，再查询帮助或官方对应版本说明。

代表页面：[命令行构建工具（hvigorw）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-commandline)

### 5.4 构建生命周期、任务和插件

[官方事实] 官方构建章节覆盖构建生命周期、任务图、定制构建、Hvigor 插件、插件上下文和基础构建 API。

[解释] 自定义插件应满足：

- 输入、输出和副作用明确；
- 任务依赖可追踪；
- 不依赖开发者本机的隐式路径；
- 不在日志中泄露密钥；
- 增量构建条件正确；
- CI 和本地行为一致；
- 插件版本与 Hvigor 版本兼容。

代表页面：

- [构建系统生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-life-cycle)
- [开发 Hvigor 插件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-plugin)
- [基础构建能力](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-api)

### 5.5 混淆加固不是最后一刻的开关

[官方事实] release 构建可配置混淆；混淆可能改变反射、名称查找、动态访问和堆栈可读性。

[解释] 开启混淆后至少验证：

- 路由与动态加载；
- 序列化/反序列化；
- Native/ArkTS 导出；
- Web JSBridge；
- 日志与崩溃符号；
- Kit 回调；
- release 设备上的主流程。

代表页面：[混淆加固](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-build-obfuscation)

### 5.6 构建报错排查顺序

[解释] 推荐顺序：

1. 锁定第一条错误。
2. 检查环境变量与工具版本。
3. 检查 JSON5/模块/product/target 配置。
4. 检查依赖解析和仓库。
5. 检查 ArkTS/API/资源错误。
6. 检查签名与设备安装。
7. 只在证据指向缓存时做窄范围清理。

不应先删除整个工程的 `build`、`.hvigor`、`oh_modules` 和锁文件来“碰碰运气”。

代表页面：

- [编译构建常见问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-faqs)
- [配置错误码](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-errorcode-00303-1)

---

## 6. ohpm 与依赖治理

[官方事实] 命令行工具中有 44 页专门覆盖 ohpm，包含配置、清单、安装、发布、缓存、仓库和命令。

[解释] 依赖治理的核心不是“能下载”，而是：

- 名称与版本约束明确；
- 锁定结果可复现；
- 依赖来源可信；
- transitive dependencies 可审计；
- HAR/HSP/Native 依赖边界清楚；
- 升级有兼容性测试；
- 私服 token 不进入源码和日志。

### 6.1 AI 修改依赖时的最低动作

1. 读取当前 `oh-package.json5` 与锁文件。
2. 确认依赖是工程级还是模块级。
3. 确认包支持当前 SDK、设备和 ArkTS 代际。
4. 说明为何需要新依赖，避免为一个小函数引入大包。
5. 执行安装并检查锁文件变化。
6. 运行静态检查、构建和相关测试。
7. 报告新增许可证、网络和发布风险。

代表页面：

- [oh-package.json5](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-oh-package-json5)
- [ohpmrc](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-ohpmrc)
- [ohpm install](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-ohpm-install)

---

## 7. 性能：先测量，再定位，再修改，再复测

### 7.1 统一性能闭环

[官方事实] DevEco Profiler/Insight 提供实时监控和深度录制，并按 Frame、ArkUI、Launch、Snapshot、Allocation、ComMemory、Energy、ArkWeb、Network、Concurrency、GPU、Time、CPU 等模板分析。

[解释] 正确闭环是：

```text
固定设备/版本/场景
  -> 记录基线
  -> 用时间线或采样定位热点
  -> 提出一个可证伪假设
  -> 做最小修改
  -> 同场景重复测量
  -> 对比指标与行为回归
```

仅凭源码长度、循环数量或“看起来复杂”不能宣布性能问题已经修复。

### 7.2 工具与问题映射

| 现象 | 首选证据 |
|---|---|
| 启动慢 | Launch 时间线、Ability/首帧、同步初始化 |
| 滚动卡顿 | Frame/ArkUI、主线程长任务、布局/绘制 |
| 内存持续增长 | Snapshot、Allocation、对象保留链、监听器/定时器 |
| Native 内存异常 | Allocation Native、符号与资源释放 |
| UI 组件不释放 | ComMemory、页面销毁和组件引用 |
| 高功耗 | Energy、CPU/GPU/网络/定位/后台活动 |
| Web 加载掉帧 | ArkWeb 分析、资源、JS 与桥接 |
| 网络慢 | Network 瀑布、DNS/连接/请求/缓存 |
| 并发拥塞 | Concurrency、TaskPool/Worker、队列等待 |
| GPU 异常 | GPU 活动或 Graphics Profiler 抓帧 |

代表页面：

- [性能问题定界：实时监控](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/realtime-monitor)
- [性能问题定位：深度录制](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/deep-recording)
- [Frame 分析](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-insight-session-frame)
- [ArkTS 内存泄漏分析](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-arkts-memory-leak-analysis)
- [内存分析介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-insight-session-allocations-memory)

### 7.3 常见根因清单

[解释] AI 排查性能时应检查：

- 主线程同步 I/O、JSON 解析、大数组处理；
- 重复订阅、窗口监听器、定时器或回调未释放；
- 状态粒度过大导致无关组件刷新；
- 列表一次性创建、图片解码尺寸不合适；
- 频繁对象分配、闭包和缓存无限增长；
- 每次构建重复计算可缓存派生值；
- 动画属性触发布局而非合成；
- 网络轮询、后台任务或定位没有退避；
- Native 资源、文件描述符、媒体对象未释放。

---

## 8. 发布与运维

[官方事实] 发布流程包含应用信息、包、签名、隐私与权限声明、测试、审核和上架后的运维分析。

[解释] “构建成功”距离“可发布”至少还差：

- release 构建与正式签名；
- 版本号、包名、设备与分发配置；
- 权限和隐私声明；
- 账号、支付、推送等 AGC/服务配置；
- 功能、兼容、稳定、性能和安全测试；
- 混淆后的主流程；
- 崩溃、冻屏、性能和用户反馈监控；
- 回滚或紧急修复方案。

代表页面：

- [发布应用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-publish-app)
- [运维分析](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-operation-and-services)

---

## 9. AI Coding：把模型当协作者，不当证据来源

### 9.1 两套官方目录要区分

[官方事实] 当前菜单同时存在“AI Coding”（DevEco Code、DevEco CLI）与“使用 AI 智能辅助编程（不推荐）”。后者的“不推荐”是官网当前目录名称的一部分。

[解释] 选择工具时，应优先当前主推路径。旧代功能页面仍可用于理解迁移或历史行为，但不能自动成为新项目基线。

代表页面：

- [DevEco Code Agent 模式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-deveco-code-agent)
- [DevEco Code 常用配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-deveco-code-common-configure)
- [DevEco CLI 常用命令](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-deveco-cli-options)

### 9.2 AI 输出的可信度规则

[解释] AI 生成代码、测试或修复建议以后，必须独立核对：

- API 是否存在，`@since` 是否满足 compatible SDK；
- import 的 Kit 与模块依赖是否正确；
- SystemCapability 与设备是否支持；
- 权限是否声明、申请并处理拒绝；
- 生命周期与线程是否正确；
- ArkUI V1/V2 是否混用；
- 错误码、取消、超时和资源释放是否覆盖；
- 示例是否来自同一 API 代际；
- 是否通过实际静态检查、构建、测试与设备验证。

### 9.3 AI 不应自动执行的动作

- 覆盖用户未提交改动；
- 删除锁文件、缓存或构建目录作为第一步；
- 写入或打印签名秘密；
- 开通 AGC、支付、账号、云服务或上传包；
- 把 mock 定时器改名为“AI 服务”后宣称已接入；
- 把 Previewer 截图当真机性能证据；
- 根据旧示例降低/提高 SDK 或切换状态管理代际。

---

## 10. 测试体系

### 10.1 测试不是一个命令

[官方事实] 官方测试目录覆盖单元测试、UI 测试、Python UI 测试、性能、稳定性、命令行执行和多类专项测试。

[解释] 推荐分层：

| 层 | 验证对象 | 典型内容 |
|---|---|---|
| 纯逻辑单元测试 | 函数、规则、映射 | 边界值、错误分支、确定性 |
| 组件/状态测试 | ViewModel、store、组件状态 | 状态转换、事件、异步完成 |
| Instrument Test | 设备侧模块行为 | 上下文、资源、数据库、Kit 包装 |
| UI 自动化 | 页面和交互链 | 定位、点击、输入、返回、断言 |
| 专项测试 | 性能、稳定、兼容、安全、功耗 | 长时间、压力、多设备、异常环境 |
| 服务联调 | AGC/后端/真实账号 | 鉴权、回调、幂等、失败恢复 |

### 10.2 单元测试与 UI 测试

[官方事实] 官方分别提供单元测试框架、UI 测试框架、ArkTS/Python 方式与命令行执行指导。

[解释] 好测试应：

- 每个用例验证一个可描述行为；
- 不依赖用例执行顺序；
- 控制时钟、网络、随机数和存储；
- 对异步等待设置明确超时；
- 使用稳定的可访问语义定位，而非脆弱坐标；
- 失败信息能说明期望、实际和上下文；
- 清理测试产生的数据和监听器。

代表页面：

- [单元测试框架使用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/unittest-guidelines)
- [UI 测试框架使用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/uitest-guidelines)
- [应用 UI 测试（基于 Python）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hypium-python-guidelines)
- [命令行执行测试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/command-testing)

### 10.3 稳定性测试

[官方事实] 稳定性测试关注长时间运行、遍历、冻屏、崩溃、内存泄漏与资源变化。官网页面建议稳定性基础质量测试的最佳测试时长可设置为 8 小时；实际任务参数仍需按当前工具页面核对。

[解释] 稳定性不等于“启动十分钟没崩”。至少覆盖：

- 反复进入/退出页面；
- 前后台切换；
- 旋转、窗口缩放和折叠状态；
- 网络断开、慢网和恢复；
- 权限拒绝与撤销；
- 大数据量、低内存和存储不足；
- 长时间定时器、推送或媒体行为；
- 监听器、文件、数据库、媒体和 Native 资源释放。

代表页面：

- [稳定性测试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/stability-testing)
- [wukong 稳定性工具使用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/wukong-guidelines)

### 10.4 性能测试与分析不是一回事

[解释] 性能测试回答“指标是否达标”，Profiler 回答“时间和资源花在哪里”。两者缺一不可。先用固定场景复现指标，再用工具定位；修复后回到相同场景复测。

代表页面：[HiSmartPerf Device 性能使用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/smartperf-guidelines)

### 10.5 当前项目的测试缺口

[项目适配] `KangxiaobanAI` 当前测试仍主要是模板断言。它们不能证明登录角色、导航栈、宽窄屏切换、任务状态、消息未读、入院表单、AI cover、Preferences 或安全区行为。AI 若修改这些功能，应优先增加行为测试，而不是只运行现有模板后宣布“测试通过”。

---

## 11. 体验建议是验收规则，不只是视觉建议

### 11.1 规则表的阅读方法

[官方事实] 体验建议大量使用表格，分别给出描述、规则/建议、适用设备、应用形态和检测方式。

[解释] 不能只摘一个数字。每条规则必须一起记录：

- 规则还是建议；
- 适用设备；
- 应用还是元服务；
- 时间起点和终点；
- 前置网络/账号/数据条件；
- 使用哪种测试工具；
- 当前快照日期。

### 11.2 性能阈值示例

[官方事实] 以下是 2026-08-10 快照中“时延”“帧率”页面的代表性规则；官网更新时应重新核对。

| 场景 | 当前快照规则示例 |
|---|---:|
| 应用启动加载完成 | ≤ 1100 ms |
| 元服务启动加载完成 | ≤ 340 ms |
| 应用/元服务内点击响应 | ≤ 100 ms |
| 应用内点击操作完成 | ≤ 900 ms |
| 元服务/小程序内点击操作完成 | ≤ 1400 ms |
| 抛滑触屏响应（速度 > 300 mm/s） | ≤ 80 ms |
| 拖滑触屏响应（速度 < 100 mm/s） | ≤ 60 ms |
| 应用/元服务滑动卡顿率 | ≤ 5 ms/s |

[解释] 这些数字不是“所有页面统一 SLA”。例如启动完成的终点定义、动画/加载阶段、设备类型和测试工具都会影响结论。工程应保存原始测试报告，而不是只在 README 中写一个达标数字。

代表页面：

- [时延](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/performance-delay)
- [帧率](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/performance-frame-rate)
- [内存占用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/performance-memory-usage)

### 11.3 基础功能与兼容性

[官方事实] 该子树覆盖安装、启动、升级、卸载、资源、音频、视频、协议、设备和多种兼容性要求。

[解释] 最低矩阵包括：

- 首次安装、覆盖安装、升级与卸载；
- 冷启动、热启动、后台恢复；
- 深色/浅色、字体缩放、语言与区域；
- 不同分辨率、窗口尺寸、横竖屏、折叠状态；
- 触摸、鼠标、键盘、焦点与返回；
- 离线、慢网、无服务和权限拒绝；
- 音频焦点、媒体中断、耳机/蓝牙变化；
- 低电量、低存储和系统回收。

代表页面：

- [协议规格](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/protocol-specification)
- [音频规格](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/audio-specification)
- [设备兼容](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/device-compatible)

### 11.4 稳定性

[官方事实] 稳定性建议关注崩溃、无响应、冻屏、资源泄漏和长期可用性。

[解释] 交付报告应分开统计：

- crash；
- AppFreeze/ANR 类问题；
- 页面白屏或无法交互；
- 内存/句柄/线程持续增长；
- 数据丢失或状态损坏；
- 自动恢复和用户可恢复路径。

代表页面：[应用稳定性体验建议](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/experience-suggestions-stability)

### 11.5 功耗

[官方事实] 功耗建议分别覆盖前后台计算、绘制渲染、网络、定位和硬件资源使用。

[解释] 重点检查：

- 后台是否仍有无意义轮询、定时器或动画；
- 网络请求是否合并、缓存和退避；
- 定位、蓝牙、相机、麦克风是否按需开启并及时关闭；
- 高刷新、高帧率和 GPU 负载是否有场景必要性；
- 屏幕不可见时是否停止绘制和媒体；
- 任务是否符合后台任务类型和系统约束。

代表页面：

- [前台绘制渲染](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-foreground-render)
- [前台资源使用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-foreground-resource)
- [后台硬件资源使用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-background-hardware)

### 11.6 安全与隐私

[官方事实] 安全隐私体验建议有 23 页，涵盖组件安全、数据、网络、身份、通知、隐私政策、选择与同意等主题。

[解释] 最低原则：

- 最小权限和最小数据；
- 收集前透明告知；
- 对需要同意的处理取得明确选择；
- 拒绝后提供合理降级，而不是伪装成功；
- 允许撤回授权、删除或更正数据；
- 敏感信息不进入日志、剪贴板或明文存储；
- 导出组件、DeepLink、WebBridge 和 IPC 校验调用方与输入；
- 网络、证书、token、密钥和本地数据有完整生命周期。

代表页面：

- [组件安全](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-security-base)
- [隐私政策通知](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-privacy-policy)
- [选择和同意](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/standard-privacy-user-consent)

[项目适配] `KangxiaobanAI` 当前没有真实账号、医疗后端或 AI 服务。未来接入居民健康数据时，UI mock 模型不能直接当传输合同；必须新增授权、最小化、访问控制、审计、删除、错误与离线策略。

### 11.7 UX

[官方事实] UX 建议强调可理解、可操作、一致、及时反馈与不同设备上的完整体验。

[官方事实] 2026-08-10 浏览器复核的当前页面还明确列出：所有界面应响应系统返回操作；全屏界面提供返回、关闭或取消入口；点击热区不得小于 `40vp × 40vp`；窗口宽度达到 `840vp` 及以上时，底部导航应切换为侧边导航；同时需要处理挖孔区、底部导航条、状态栏、深色模式、多窗、折叠屏、鼠标/触控板和全键盘操作。具体适用形态与例外仍以该表格当前版本为准。

[解释] 对 HarmonyOS/ArkUI，至少检查：

- 信息架构和返回路径稳定；
- 加载、空、失败、取消、成功状态真实；
- 触摸目标、键盘焦点、鼠标 hover 和屏幕朗读可用；
- 字体放大后不裁切；
- 深色模式和高对比度正确；
- 安全区、键盘和导航指示区域不遮挡交互；
- 动效与状态一致、可打断、不过度；
- 多端布局改变结构时仍保留任务连续性。

代表页面：[应用 UX 体验建议](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/experience-suggestions-ux)

---

## 12. 面向 Codex/Claude 的任务到验证映射

| 改动类型 | 最低静态验证 | 最低运行验证 | 风险验证 |
|---|---|---|---|
| ArkTS 纯逻辑 | Linter、类型、单元测试 | 相关调用链 | 边界与异常输入 |
| ArkUI 布局/状态 | 编译、预览、规则检查 | 真机/模拟器交互 | 多尺寸、字体、无障碍、返回 |
| Ability/生命周期 | 配置与入口一致 | 冷启动、前后台、销毁 | 重复监听、恢复、异常启动 |
| 数据持久化 | schema/映射/错误处理 | 写入、读取、升级、清理 | 并发、损坏、隐私 |
| 网络/Kit | 权限、依赖、Capability | 真服务成功和失败路径 | 超时、取消、重试、鉴权 |
| Native | ABI、CMake、导出、资源 | 目标架构设备运行 | 崩溃、ASan、线程、内存 |
| 构建配置 | JSON5、product/target | debug 与 release 构建 | 签名、混淆、CI |
| 性能优化 | 静态假设 | 同场景前后测量 | 多轮波动、功能回归 |
| 发布相关 | 清单和版本 | release 安装/主流程 | 隐私、审核、回滚 |

---

## 13. 交付证据词典

[解释] 最终报告只使用可核验词语：

| 词语 | 必须具备的证据 |
|---|---|
| 已实现 | 当前源码存在可追踪调用链 |
| 静态检查通过 | 给出实际工具、命令与结果 |
| 构建通过 | 给出 product/target/mode、退出码和产物 |
| 测试通过 | 给出测试集合、数量、环境和结果 |
| 模拟器验证 | 给出模拟器类型与场景 |
| 真机验证 | 给出设备形态/版本和操作场景 |
| 服务验证 | 给出真实配置与成功/失败响应证据 |
| 性能验证 | 给出设备、场景、工具、基线和修改后指标 |
| 发布验证 | 给出 release、签名、安装或审核阶段证据 |

“代码看起来正确”“预览能显示”“模板测试通过”不能替代其他层级。

---

## 14. 一份可直接复制给编程 AI 的验收提示词

```text
请先读取当前 HarmonyOS 工程配置和目标模块，不要根据示例猜 SDK、模块类型或状态管理代际。

实现完成后请分层报告：
1. 修改了哪些文件和所有权边界；
2. 官方 API/版本/SystemCapability/权限依据；
3. 静态检查结果；
4. 构建命令、退出码、模式和产物；
5. 单元/UI/专项测试结果；
6. 模拟器或真机验证的设备形态与场景；
7. 服务、性能、发布中尚未验证的事项。

不要把 Previewer、mock、模板测试、未签名构建或单设备截图表述为完整验证。
不要打印签名、token、密钥或本机敏感配置。
```

---

## 15. 本章结论

[解释] 官方“工具、测试、体验建议”共同构成 HarmonyOS 的交付闭环：

```text
正确环境
  -> 正确编辑与静态诊断
  -> 可复现依赖
  -> 明确构建坐标
  -> 正确签名与产物
  -> 分层测试
  -> 真机/服务/性能验证
  -> 隐私、安全和体验验收
  -> 发布与运维
```

[项目适配] 对 `KangxiaobanAI`，最重要的近期动作不是宣称“所有能力已完成”，而是继续保持原型与真实服务的边界，并为登录、导航、宽窄屏、任务、消息、入院表单、Preferences、AI cover 和生命周期建立行为测试与多设备验证矩阵。
