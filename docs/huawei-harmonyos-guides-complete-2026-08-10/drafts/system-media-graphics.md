# HarmonyOS 系统、媒体、图形与 Web 工程手册

> 面向 Codex、Claude 与人类开发者的官方指南综合章  
> 官方入口：[ArkTS / HarmonyOS 指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts)  
> 官网目录与正文快照：2026-08-10  
> 本章直接覆盖：系统、媒体、图形、ArkWeb、窗口管理、屏幕管理、IME Kit  
> 当前项目映射：<code>D:\Coding\KangxiaobanAI_OC\KangxiaobanAI</code>

[官方事实] 本地语料库保存了官网左侧菜单的 5,694 个正文入口，5,694 个均成功读取，失败和待读取均为 0；正文合计 19,621,279 字符，包含 20,996 个代码块、5,018 张表、3,325 个提示或警告块和 11,339 张图片。SQLite 完整性、正文压缩数据、菜单与页面 slug 集合、第二次菜单差异检查均通过。

[解释] “读取完成”说明菜单入口与正文内容已经逐项落入可审计语料，不等于任何人可以凭一次总结记住全部接口。本章的作用是把 1,823 个相关正文入口组织成工程模型、决策规则、检查清单和官方回查索引；遇到具体接口签名、版本或设备差异时，仍应回到对应页面和当前 SDK 定义。

[项目适配] 当前 <code>KangxiaobanAI</code> 是 API 24 目标、API 23 兼容的单 entry HarmonyOS 应用，声明 phone、tablet、2in1，当前主模块没有 <code>requestPermissions</code>，也没有真实 Network Kit、WebSocket、Camera、Audio、Media、ArkWeb、AR 或 GPU 加速业务实现。本章不能被用来声称这些能力已经接入。

---

## 1. 证据范围、标记规则与使用方法

### 1.1 本章覆盖量

[官方事实] 下表数量来自 2026-08-10 的官网菜单和正文语料。系统中的 Input Kit、Multimodal Awareness Kit、Sensor Service Kit、Pen Kit 已包含在系统 1,054 页之内，不重复计数。

| 直接范围 | 正文页 | 本章用途 |
|---|---:|---|
| 系统 | 1,054 | 安全、网络、基础功能、硬件、调测调优 |
| 媒体 | 389 | 音频、编解码、播控、相机、图片、播放录制、媒体库、扫码、DRM、铃声、HDR |
| 图形 | 237 | 2D、3D、AR、空间建模、图形加速、GPU 引擎 |
| ArkWeb | 76 | Web 生命周期、进程、加载、交互、安全、媒体、调试 |
| 窗口管理 | 49 | 窗口类型、模式、生命周期、旋转、布局、焦点、层级、沉浸 |
| 屏幕管理 | 6 | Display 查询、旋转、刷新率、分辨率、折叠状态 |
| IME Kit | 12 | 输入法应用、自绘编辑框、安全模式、沉浸与焦点 |
| **合计** | **1,823** | 本章直接综合范围 |

[解释] 页面数量描述知识体量，不表示每个项目都需要接入这些 Kit。正确的开发顺序是先从业务场景反推最小能力，再检查 API、SystemCapability、设备、权限、区域、账号和发布限制。

[项目适配] 对当前项目而言，窗口、Display、安全区和多输入适配属于已有架构的延伸；网络、媒体、Web、AR、空间建模和 GPU 服务则属于新增系统能力，必须新增配置、服务边界、状态机、失败路径和相应验证，不能只在页面中添加一个 import。

### 1.2 三类陈述必须分开

[官方事实] 带有“官方事实”的内容是从本地保存的官方正文、菜单路径或官方页面标题归纳而来，页面链接用于回查原文。

[解释] 带有“解释”的内容是跨页面工程归纳，例如如何选择 Kit、怎样设计状态机、为何需要能力检测。它帮助开发，但不是新的平台契约。

[项目适配] 带有“项目适配”的内容只描述当前 <code>KangxiaobanAI</code> 工作树与建议落点。工作树变化后，应重新扫描配置和源码，不能把本章当永久不变的事实。

### 1.3 AI 使用本章的最短流程

[解释] Codex、Claude 或其他编程代理在实现能力前应依次完成：

1. 定位业务场景、用户动作和数据边界。
2. 查本章决策表，选择最小 Kit 或系统组件。
3. 打开对应官方页面，核对目标 API、兼容 API、设备和 SystemCapability。
4. 检查 <code>module.json5</code>、模块类型、依赖、权限和资源文案。
5. 明确对象所有者、生命周期、监听解绑、文件描述符和 native 资源释放。
6. 建立成功、拒绝、不支持、超时、中断、后台、恢复和销毁路径。
7. 将系统对象封装在 feature service 或 adapter 中，不让页面承担底层协议。
8. 分别完成静态、构建、真机和服务验证，并如实标注证据等级。

[项目适配] 当前项目应先保留现有 ArkUI V2、HDS Navigation、WindowUtil 和断点体系，再在真实功能根下添加 service、repository 或 adapter。不得把网络、媒体或硬件状态塞进 <code>GlobalInfoModel</code>。

---

## 2. 跨 Kit 工程合同

### 2.1 API 版本、设备与能力检测

[官方事实] HarmonyOS 官方页面经常分别声明“从某 API 版本开始支持”“仅支持某些设备”“某设备新增支持”或“不支持时返回 801”。同一 Kit 内不同特性也可能有不同设备和版本范围。AR Engine、Graphics Accelerate、XEngine、Spatial Recon、Multimodal Awareness、Pen、相机格式和编解码规格都不能只凭 Kit 名判断可用性。

[解释] 编译期能找到类型，只能证明当前 SDK 提供声明，不能证明运行设备拥有硬件、驱动、系统服务或已开放特性。能力判断应分四层：

| 层次 | 要回答的问题 | 常见证据 |
|---|---|---|
| SDK 层 | 当前代码是否能编译 | target/compatible SDK、接口 since 标记 |
| 系统层 | 运行系统是否暴露能力 | SystemCapability、API 版本保护 |
| 设备层 | 当前硬件是否支持 | 设备能力查询、格式列表、特性列表 |
| 业务层 | 当前用户和场景能否使用 | 权限、账号、区域、网络、策略、资源状态 |

[项目适配] 当前目标 API 24、兼容 API 23。引入 API 24 专属接口时，必须为 API 23 运行路径设计能力判断或降级；若业务不允许降级，应先由产品明确提高 compatible SDK，而不是让应用在旧设备上运行到调用点再崩溃。

### 2.2 权限不是一次性配置

[官方事实] [应用权限管控概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-permission-mgmt-overview)要求最小化申请权限，敏感权限在业务执行前动态申请，用户拒绝某权限后，无关功能应继续可用。用户主动撤销已授权权限时，系统通常会终止对应应用进程。

[官方事实] [声明权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions)规定权限在模块 <code>module.json5</code> 的 <code>requestPermissions</code> 中逐项声明；申请 user_grant 或 manual_settings 权限时，需要填写多语言 reason 和 usedScene。

[官方事实] [向用户申请授权](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/request-user-authorization)要求每次执行敏感操作前检查授权状态，动态授权弹窗应由用户明确触发，并在获得授权后再继续操作。

[解释] 权限实现至少包含“声明、解释、检查、请求、拒绝、永久拒绝或设置引导、撤销后恢复、无权限降级”八个部分。只写 <code>requestPermissions</code> 或只调用授权弹窗都不完整。

[项目适配] 当前主模块没有任何 <code>requestPermissions</code>。新增相机、麦克风、运动感知或网络能力时，应先制作权限矩阵并经产品确认。不能为了未来可能使用而一次申请相机、麦克风、相册、位置和传感器。

### 2.3 优先使用场景化授权

[官方事实] [安全控件概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/security-component-overview)说明 PasteButton 和 SaveButton 通过用户点击提供场景化特权。Photo Picker 选择媒体不要求应用获得整个媒体库读取权限，CameraPicker 拉起系统相机也不要求应用拥有相机权限。

[解释] 如果业务只是“用户选择一张照片”“用户把生成图片保存到媒体库”“用户拍一张照片后返回”，优先使用系统 Picker 或安全控件。只有持续扫描、自定义取景、专业参数控制或批量媒体管理才考虑更广权限。

[项目适配] 当前项目未来若增加长者头像、健康报告图片或证件拍摄，应先区分选择、保存、系统拍摄和自定义相机四类场景。头像选择不应演变成全媒体库读取授权，保存报告图片不应默认申请受限写权限。

### 2.4 生命周期与资源所有权

[官方事实] Web、Camera、AVPlayer、AVRecorder、AVCodec、Sensor、Multimodal Awareness、Display、Window、Input 和 native 图形对象都存在创建、注册或启动与停止、解绑或释放的配对关系。部分对象还跨线程、跨进程或持有硬件资源。

[解释] 每个能力都应写出所有权表：

| 对象 | 创建者 | 启动时机 | 暂停或后台行为 | 销毁动作 |
|---|---|---|---|---|
| 网络请求 | feature service | 用户动作或刷新 | 可取消或忽略过期结果 | destroy/cancel |
| WebSocket | connection manager | 会话建立 | 心跳、重连、离线策略 | close 与移除监听 |
| Camera 会话 | camera service | 获得授权且页面可见 | 停止预览或按业务保活 | 停止输出、释放会话和输入 |
| 播放器 | media service/store | source 准备完成 | 暂停、音频中断处理 | stop/reset/release |
| 传感器订阅 | feature owner | 场景进入 | 后台取消或降频 | off，使用同一回调引用 |
| Display/Window 监听 | shell 或 window owner | 窗口建立 | 持续或按需要暂停 | 对称 off |
| native Buffer | native owner | surface 可用 | 等待同步信号 | unmap/release |

[项目适配] <code>WindowUtil</code> 已注册 windowSizeChange 和 avoidAreaChange，但当前没有对称解绑。任何新增 Display、fold、keyboard、sensor 或媒体监听都必须先明确唯一所有者，避免再制造一套无法清理的全局监听。

### 2.5 异步、线程与进程

[官方事实] ArkWeb 使用多进程模型；AVCodec 以性能为目标提供 C 接口；图形 NativeWindow、Buffer、VSync 和 GPU 管线涉及 native 生命周期；网络、媒体和硬件接口大量使用 Promise、回调或事件。

[解释] UI 线程只负责状态提交和轻量交互，不应同步执行大图解码、视频转码、模型加载、复杂加密、长循环或大文件读写。回调结果进入 UI 前要检查页面是否仍存活、请求是否仍是最新一代、资源是否已释放。

[项目适配] 当前 AI 页面已有本地定时回复。若改成网络流式响应，应把连接、分片合并、取消、重试和会话代次放入 service/store，页面只消费可观察状态；不得在组件销毁后继续写 <code>@Local</code>。

### 2.6 错误是状态机的一部分

[官方事实] 官方指南会区分权限错误、参数错误、能力不支持、设备忙、连接错误、解码错误、资源释放错误和服务异常。多模态动作感知等能力在设备不支持时可能返回 801。

[解释] 不应把所有异常都转换为“操作失败”。面向用户至少区分：

- 设备不支持：隐藏入口或说明替代路径；
- 尚未授权：解释用途并由用户触发申请；
- 用户拒绝：保留其他功能，提供稍后处理；
- 资源被占用：允许重试或返回；
- 网络不可用：保留草稿、离线提示和重试；
- 数据无效：不继续进入解码、渲染或持久化；
- 系统中断：保存可恢复状态并等待合适时机；
- 开发错误：记录可定位日志，不向用户展示内部堆栈。

[项目适配] 当前项目许多交互通过定时器立即进入成功态。接入真实 Kit 后，必须新增 running、success、failed、cancelled 等真实状态，只有底层操作确认完成后才能显示“已提交”“已保存”或“发送成功”。

### 2.7 性能、功耗和内存

[官方事实] 图形、媒体、传感器、ArkWeb 和网络页面都包含性能或资源约束。过度绘制会增加 CPU/GPU 负载；高帧率提高流畅度也增加功耗；大图、视频帧、Web 渲染进程和媒体缓冲会显著占用内存；高频传感器订阅会增加功耗。

[解释] 优化目标不能只写“更快”。需要量化：

| 场景 | 主要指标 | 典型退化 |
|---|---|---|
| 页面与 2D | 帧时间、掉帧、过绘、布局次数 | 重复背景、深层嵌套、频繁重建 |
| Web | 首屏、白屏、进程内存、崩溃 | 多实例、重页面、桥接高频调用 |
| 图片 | 峰值内存、解码时间、目标尺寸 | 原图全量解码、重复 PixelMap |
| 视频 | 首帧、卡顿、缓冲、功耗 | 错误格式假设、频繁 seek |
| 相机 | 开启时间、预览稳定、温升 | 长时间占用、未释放输出 |
| 传感器 | 上报频率、功耗、噪声 | 无节制高频订阅 |
| 网络 | 延迟、吞吐、失败率、流量 | 大文件使用普通 request、无限重试 |

[项目适配] 当前项目尚无这些真实负载。新增能力后必须用目标设备测量，不得把“使用硬件加速”“使用零拷贝”或“预加载”直接写成性能已经改善。

### 2.8 隐私与敏感数据

[官方事实] 相机、麦克风、照片、视频、位置、动作、传感器、Web、扫码、设备安全和认证能力可能处理个人数据或敏感设备数据。官方部分 Kit 提供独立的个人数据处理说明。

[解释] 数据流应明确回答：采集什么、为何采集、在哪里处理、保存多久、传给谁、如何删除、失败时是否残留、日志是否包含内容、截图或调试工具是否会泄露数据。

[项目适配] 智慧养老业务中的长者身份、健康、风险、联系人、图片、声音和视频具有更高敏感性。任何媒体上传、Web 内容、扫码识别或远程通信设计都应默认不记录原始内容到普通日志，不把真实数据放进测试夹具，不让 AI 提示词包含不必要的身份信息。

---

## 3. 系统分支全景

### 3.1 五大分支

[官方事实] 系统分支共有 1,054 页，结构如下。

| 系统直接子类 | 页面 | 主要问题域 |
|---|---:|---|
| 安全 | 511 | 权限、访问控制、密钥、密码学、认证、证书、数据与设备安全 |
| 网络 | 170 | IP 网络、短距通信、分布式、远场通信、网络加速与协同 |
| 调测调优 | 144 | 性能分析、调试命令、测试能力 |
| 基础功能 | 123 | 基础服务、算法、并发、输入、企业管理、内核与桌面能力 |
| 硬件 | 106 | 传感器、多模态、手写笔、穿戴、车、驱动、机械设备、熄屏导航 |

[解释] “系统”不是一个可统一导入的单一 Kit。它是多个权限等级、开放范围、设备依赖和语言接口完全不同的能力集合。

[项目适配] 当前项目优先相关的是权限、Network Kit、Input、Sensor、Multimodal Awareness、Window/Display 调优。企业 MDM、驱动、车机、机械设备、Wear Engine 或安全企业套件只有在产品范围明确扩展后才应评估。

### 3.2 安全分支地图

[官方事实] 安全 511 页的直接子类包括：

| 子类 | 页面 |
|---|---:|
| Crypto Architecture Kit | 143 |
| Universal Keystore Kit | 123 |
| Device Security Kit | 69 |
| Enterprise Data Guard Kit | 28 |
| 程序访问控制 | 27 |
| Device Certificate Kit | 27 |
| Asset Store Kit | 24 |
| 密码自动填充服务 | 15 |
| User Authentication Kit | 15 |
| Online Authentication Kit | 14 |
| Enterprise Threat Protection Kit | 13 |
| Data Protection Kit | 7 |
| Confidential Space Kit | 4 |
| 应用加密 | 1 |

[解释] 这些能力不能互相替代：

- 应用权限解决“应用能否访问某项系统数据或能力”；
- 安全控件和 Picker 解决“用户在明确场景中临时授权”；
- Asset Store 面向短敏感明文，如 token、账号和密码类数据；
- HUKS 面向密钥生成、导入、使用、访问控制和安全硬件边界；
- Crypto Architecture 提供算法框架，不等于密钥已经安全存储；
- User Authentication 验证当前设备用户，不等于远端账号登录；
- Online Authentication 面向 FIDO、Passkey 等在线认证链路；
- Device Certificate 管理或校验证书，不负责签发 CA 证书；
- Device Security 与企业安全 Kit 往往有准入、企业或特定场景要求。

[项目适配] 当前 mock 登录不能通过加入 User Authentication 就变成真实账号系统。合理架构是：后台账号认证负责 session；必要时 User Authentication 对本机敏感操作做再认证；token 存储根据威胁模型选择 Asset Store；服务端真实性和传输安全另行设计。

### 3.3 密钥、算法、资产和认证的选择

[官方事实] [Asset Store Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/asset-store-kit-overview)将其定位为短敏感数据的安全存储与管理。[Universal Keystore Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/huks-overview)提供密钥生成、导入、销毁、协商、派生、加解密、签名验签和访问控制。[Crypto Architecture Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/crypto-architecture-kit-intro)提供统一密码算法框架，并说明其对象不支持多线程并发操作。

[解释] 常见错误是把 token 当普通 Preferences 字符串、把自制加密当安全存储、把哈希当加密、在应用中硬编码密钥、重复使用 nonce/IV，或跨线程共享不支持并发的密码对象。

[项目适配] 如果未来接入真实登录，应先写威胁模型和数据分类。普通 UI 偏好可继续使用 Preferences；访问 token、刷新凭据和本地加密密钥不能沿用同一存储策略。不得把密钥、证书口令或 token 写入源码、构建配置、日志和 AI 对话。

### 3.4 Network Kit：HTTP 与流式请求

[官方事实] [使用 HTTP 访问网络](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/http-request)区分了小数据请求和流式传输：数据量较小时可用 <code>HttpRequest.request</code>，大文件上传或下载且需要进度时使用 <code>requestInstream</code>。从 API 22 起支持在请求响应生命周期关键节点加入 HTTP 拦截器。

[解释] 网络层需要独立处理 URL、方法、header、超时、取消、重试、状态码、业务错误、序列化、日志脱敏和请求代次。拦截器适合统一认证、跟踪和错误映射，但不能在其中静默无限重试，也不能记录敏感正文。

[项目适配] AI 对话若接入 HTTP 流或 SSE，应建立 <code>AiConversationRepository</code> 或同等边界，页面只接收消息状态。图片、报告或视频上传应使用适合大文件和进度的路径，不应把整个文件读成字符串后放入普通请求。

### 3.5 WebSocket 生命周期

[官方事实] [使用 WebSocket 访问网络](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/websocket-connection)描述客户端的 create、connect、open、message、send、close、error 生命周期。WebSocket 服务端能力从 API 23 起支持全设备，此前仅支持 TV。

[解释] 实时连接至少需要：

1. 单一连接所有者；
2. 连接中、已连接、断开中、已断开和失败状态；
3. 鉴权完成前禁止发送业务消息；
4. 心跳与服务端超时；
5. 前后台策略；
6. 网络切换后的重连；
7. 指数退避与上限；
8. 会话代次，丢弃旧连接回调；
9. 用户退出时主动关闭；
10. 消息去重、顺序和幂等策略。

[项目适配] 当前消息和 AI 回复都是本地插入。接入 WebSocket 后，不能把 <code>on('message')</code> 直接写进页面并在每次重建时重复注册。消息状态还应区分 sending、sent、failed、received 和已读。

### 3.6 网络连接安全

[官方事实] [网络连接安全配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/network-connection-security-configuration)建议使用 TLS 并正确验证 CA。面向互联网用户的应用建议只信任系统预置 CA；企业内网可按域名配置信任应用管理的 CA；用户安装 CA 适合调试版本或明确企业场景。高安全场景可进一步评估证书 Pinning。

[解释] “使用 HTTPS”不等于连接一定安全。错误的信任范围、关闭校验、把调试 CA 带入 release、Pinning 无轮换策略，都会制造风险或可用性事故。

[项目适配] 涉及长者和机构数据时，应把网络安全配置、域名、证书策略、日志脱敏和环境隔离纳入发布审查。调试抓包能力不得自动进入 release 构建。

### 3.7 其他网络家族

[官方事实] 网络 170 页还包括 Connectivity、Network Boost、Remote Communication、NearLink、Service Collaboration、Distributed Service、Accessory、Telephony 和网络调试调优。

[解释] 选择边界如下：

| 家族 | 主要场景 | 必查限制 |
|---|---|---|
| Connectivity | 蓝牙、WLAN、NFC、融合短距 | 权限、系统应用限制、无线状态、设备能力 |
| Distributed Service | 设备发现、认证、分布式硬件或组件 | 同账号/可信关系、设备范围、生命周期 |
| Remote Communication | 场景化远场通信 | 服务开通、账号、网络和接口范围 |
| Network Boost | 链路感知或加速 | 设备、合作范围、系统策略 |
| NearLink | 星闪连接 | 硬件与系统版本 |
| Service Collaboration | 设备或服务协同 | 场景准入、上下游协议 |
| Telephony | 蜂窝通信 | 设备类型、权限、系统或默认应用限制 |
| Accessory | 生态配件接入 | 合作资质、地区和设备 |

[项目适配] 当前产品没有分布式或外设控制实现。不能因为业务名称里有“设备监测”就推断已经有设备 API。先确认养老设备是否提供 HarmonyOS Kit、标准蓝牙协议、局域网协议或云 API，再选择连接层。

### 3.8 基础功能分支

[官方事实] 基础功能 123 页由 Basic Services 57、FAST 16、Function Flow Runtime 15、MDM 9、Input 7、Kernel Enhance 7、Desktop Extension 5、Linx 3、Service Support 3 构成。

[解释] 常见边界：

- Basic Services 覆盖系统基础服务，不等于业务基础库；
- FFRT 面向任务并发调度，不应被当成普通 Promise 的语法替代；
- FAST 和 Linx 提供算法或性能能力，先证明瓶颈再接入；
- MDM 面向企业设备管理，通常涉及企业权限与部署条件；
- Kernel Enhance、Desktop Extension 常有设备、系统或应用类型限制；
- Input Kit 管理多输入设备和事件，不负责业务表单验证。

[项目适配] 当前项目最相关的是 Input Kit 和并发边界。只有出现经测量的 CPU 密集瓶颈时，才评估 FAST、FFRT 或 Linx；不得为“看起来更专业”引入 native 或并发复杂度。

### 3.9 硬件分支

[官方事实] 硬件 106 页由 Wear Engine 33、Pen 22、Driver Development 13、Car 11、Sensor 11、Multimodal Awareness 6、AOD Navigation 5、Mechanic 4 构成。

[解释] 硬件能力的共同前提是“设备真实存在并支持”。同名传感器在不同设备上的范围、采样率、精度和坐标表现可能不同；模拟器只能验证有限的代码路径。

[项目适配] 当前 phone/tablet/2in1 产品可以评估 Sensor、Pen 和 Multimodal Awareness 的增强体验，但必须提供无传感器、无手写笔和不授权时的基础操作路径。Wear、Car、Driver、Mechanic、AOD 不在当前产品声明范围内。

### 3.10 调测调优分支

[官方事实] 调测调优 144 页包括 Performance Analysis Kit 107、调试命令 34、Test Kit 2。

[解释] 调优应遵循“复现、采样、定位、修改、对比、回归”。单次日志、单张截图或肉眼感觉不能证明性能问题已解决。调试命令和系统跟踪输出也可能包含路径、进程、设备或用户数据，需要控制留存和分享范围。

[项目适配] 新增媒体、Web 或图形能力后，应分别记录冷启动、首帧、内存峰值、稳定帧率、后台行为和资源释放。静态检查通过不能替代真机性能数据。

---

## 4. 窗口、Display、Input、IME 与多模态专项

### 4.1 窗口管理全景

[官方事实] 窗口管理 49 页包括窗口类型 13、窗口模式 11、窗口基础能力 9、其他开发场景 6、启动页 4，以及概述、元数据、术语、常见问题和日志定位。

[官方事实] [窗口开发概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/window-overview)推荐 Stage 模型。触摸和鼠标事件依据窗口位置与尺寸分发，键盘事件分发给焦点窗口；窗口大小限制由产品配置决定。

[解释] 窗口开发需同时考虑：

- 主窗口、子窗口、系统窗口等类型；
- 全屏、悬浮、分屏、自由窗口等模式；
- create、show、hide、destroy 生命周期；
- 旋转、尺寸、密度和 avoid area 变化；
- 是否可触摸、是否可获焦；
- Z 轴层级与遮挡；
- 沉浸画布和交互避让的不同责任；
- 键盘、鼠标、触摸和手写笔的焦点路径。

[项目适配] 当前项目使用 Stage 模型和主窗口，<code>MainPage</code> 负责认证壳内的沉浸状态，<code>WindowUtil</code> 负责尺寸和避让区。新功能不能在子页面重复拥有全屏状态，也不能用固定数值代替实时状态栏、导航指示条和键盘高度。

### 4.2 窗口生命周期与监听

[官方事实] [窗口基础能力](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/window-basic-capabilities)将生命周期、旋转、布局、焦点、层级和沉浸列为基础能力。

[解释] 监听函数必须保存稳定引用。若注册时使用匿名函数、解除时重新创建另一个匿名函数，通常无法解除原监听。窗口重建、Ability 重建和页面反复进入都应检查是否重复注册。

[项目适配] 修改 <code>WindowUtil</code> 前应先补清初始化次数、WindowStage 销毁、监听引用和 teardown 所有权。仅添加更多监听而不处理既有生命周期，会扩大风险。

### 4.3 Display 属性与折叠状态

[官方事实] [使用 Display 实现屏幕属性查询及状态监听](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/screenproperty-guideline)提供默认或全部 Display 查询，并可读取分辨率、物理与逻辑密度、刷新率、屏幕尺寸、旋转方向和角度；还可监听显示设备、旋转、分辨率、刷新率及折叠状态变化。

[解释] Window 与 Display 不等价。Window 描述应用当前可用区域，Display 描述物理或逻辑显示设备。响应式布局优先依据窗口可用宽度，只有确实需要屏幕硬件属性时才查询 Display。

[项目适配] 当前断点体系正确地围绕窗口宽度和设备类型工作。未来如加入折叠态、外接屏或刷新率自适应，应把 Display 作为补充输入，不能用屏幕分辨率直接推断当前应用窗口宽度。

### 4.4 Input Kit

[官方事实] [Input Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/input-overview)说明系统对触控板、触摸屏、鼠标和键盘驱动事件进行归一化，并提供输入设备列表、鼠标光标等能力。模拟器与真机存在差异。

[官方事实] Input 分支还包括输入设备、系统功能键优先响应、鼠标光标、Native 事件监听和 Native 事件拦截。

[解释] 输入适配不等于给所有区域加 <code>onClick</code>。完整交互需要考虑：

| 输入 | 必须核对 |
|---|---|
| 触摸 | 命中区、手势冲突、边缘返回 |
| 鼠标 | hover、光标、右键、滚轮 |
| 键盘 | Tab 顺序、Enter/Space、方向键、Esc |
| 触控板 | 滚动、惯性、缩放与手势冲突 |
| 手写笔 | 压感、倾角、悬浮、笔迹预测、误触 |
| 系统功能键 | 是否允许应用优先处理、退出与恢复路径 |

[项目适配] phone、tablet、2in1 的声明意味着 2in1 需要键鼠焦点和悬停验证。自绘卡片或胶囊若只实现触摸点击，会在键盘和无障碍场景中不可操作。

### 4.5 IME Kit

[官方事实] [IME Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-intro)区分输入法应用、自绘编辑框和系统输入法管理能力，并提供固定态、悬浮态和状态栏 Panel 等能力。部分管理接口需要系统权限或只能由当前输入法调用。

[解释] 普通业务应用使用 TextInput/TextArea，不等于需要开发输入法应用。只有自绘编辑框必须自行实现文本插入、删除、选择、光标移动、组合文本和输入法绑定等完整协议。

[项目适配] 当前项目没有自研输入法需求。聊天输入、搜索框和表单应优先使用 ArkUI 标准文本组件，并处理键盘高度、提交键、焦点切换和大字体；不要为了样式完全自绘编辑器。

### 4.6 输入法安全模式

[官方事实] [输入法安全模式介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-security)说明基础模式下 InputMethodExtensionAbility 不能使用网络、相机、麦克风、定位、剪贴板、多媒体、联系人、账号、健康数据、分布式等可能泄露个人数据的能力，也不能把数据传出进程；IME、ArkUI、窗口、图形和屏幕管理等基础输入能力仍可使用。

[解释] 输入法扩展不能假设自己总处于完整体验模式。若某功能依赖被限制能力，需在 onCreate 查询安全模式并调整功能呈现。

[项目适配] 当前产品不是输入法应用，本规则主要作为边界提醒：若未来使用第三方或自研输入法能力，不得通过输入法扩展采集长者健康、聊天或账号数据。

### 4.7 不可获焦窗口与键盘

[官方事实] [不可获焦窗口中输入框与输入法交互指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/use-inputmethod-in-not-focusable-window)指出获得焦点是正常使用输入法的必要条件；不可获焦窗口无法正确接收键盘事件，直接在其中放置输入框会造成输入同步异常。

[解释] 悬浮工具窗如果既要保持主窗焦点又要支持输入，必须按官方建议设计主窗、子窗和焦点转移关系，而不是不断调用“显示键盘”接口。

[项目适配] 当前 AI cover 是根壳内呈现，不应为聊天输入另建不可获焦悬浮窗。若未来引入全局悬浮助手，焦点和 IME 必须作为架构问题先验证。

### 4.8 Multimodal Awareness

[官方事实] [Multimodal Awareness Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/multimodalawareness-kit-intro)要求应用主动订阅感知服务，并在场景结束时主动取消订阅；能力依赖设备传感器和相关权限。

[官方事实] [获取用户动作开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/motion-guidelines)说明操作手能力从 API 15 支持，握持手从 API 20 支持；操作手涉及 <code>ACTIVITY_MOTION</code> 或 <code>DETECT_GESTURE</code>，设备不支持可返回 801，并要求 on/off 对称。

[解释] 感知结果是概率性、设备相关的上下文，不应直接作为安全或医疗结论。应用应处理未知、无数据、权限拒绝、传感器不可用、订阅中断和噪声抖动。

[项目适配] 可把操作手或握持状态用于辅助调整操作位置，但不能据此判断长者身体能力、跌倒风险或护理等级。任何健康推断都需要明确的合规数据源和专业验证。

### 4.9 Sensor Service

[官方事实] [传感器开发概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/sensor-overview)说明传感器坐标基于设备自然方向，应用应结合 Display 旋转理解数据；不同传感器可能需要不同权限。

[解释] 传感器代码应指定采样频率、节流和滤波策略，并在 UI 不可见或业务结束后取消订阅。横竖屏变化后，不能继续按旧坐标解释加速度或姿态。

[项目适配] 当前项目没有传感器业务。若增加跌倒检测或活动监测，不应仅凭端侧单一传感器阈值直接报警；需要误报漏报评估、设备能力检测、后台策略、数据留存和人工复核流程。

### 4.10 Pen Kit

[官方事实] [Pen Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pen-introduction)覆盖手写套件、报点预测、一笔成形、取色和手写交互等能力，具体特性具有设备与 API 限制。

[解释] 手写笔增强应建立在普通触摸、键盘输入仍可完成业务的基础上。笔迹预测改善体验但不代表原始采样更准确；保存笔迹还涉及坐标、缩放、撤销栈和隐私。

[项目适配] 若 2in1 医师工作台未来支持签字或批注，应先确定签字的法律效力与保存格式。原型笔迹不能被描述为合法电子签名。

---

## 5. 媒体分支全景与工程选择

### 5.1 媒体目录

[官方事实] 媒体分支共有 389 页。

| 子类 | 页面 |
|---|---:|
| Camera Kit | 72 |
| Audio Kit | 60 |
| Image Kit | 57 |
| Media Kit | 56 |
| AVCodec Kit | 45 |
| Scan Kit | 34 |
| AVSession Kit | 27 |
| Media Library Kit | 27 |
| DRM Kit | 6 |
| Ringtone Kit | 3 |
| 媒体开发概览 | 1 |
| HDR Vivid | 1 |

[解释] 媒体问题应先按“采集、处理、播放、系统控制、媒体库、识码、版权”拆分，而不是统一称为“多媒体”。

[项目适配] 当前项目没有媒体权限和媒体对象。每新增一种媒体能力，都要单独确认用户价值、权限、文件来源、存储位置、上传策略和资源释放。

### 5.2 场景到 Kit 的选择

[官方事实] [媒体开发概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/multimedia-development-overview)给出音频、视频、相机、图片、媒体库等能力入口。

[解释] 推荐选择表：

| 业务需求 | 首选能力 | 不应默认选择 |
|---|---|---|
| 播放完整音视频 | Media Kit / AVPlayer | 直接手写编解码管线 |
| 录制音视频 | Media Kit / AVRecorder | 只创建 Camera 输出 |
| 简短提示音 | SoundPool 或适配的音频播放能力 | 为一个提示音创建重型播放器 |
| 专业低时延音频 | Audio Kit | 普通 UI 定时器模拟 |
| 原子编解码、封装、解封装 | AVCodec Kit | 把 AVPlayer 当编码器 |
| 系统播控与后台音频 | AVSession Kit + 对应后台任务 | 只让播放器留在后台 |
| 拉起系统拍照 | CameraPicker | 申请 CAMERA 后自建取景 |
| 自定义相机预览和参数 | Camera Kit | CameraPicker |
| 解码、编辑、编码图片 | Image Kit | 在 UI 组件中逐像素处理 |
| 用户选择照片或视频 | Photo Picker | 申请全媒体库读取 |
| 保存生成媒体 | SaveButton 或授权保存流程 | 默认申请受限写权限 |
| 扫码直达或系统扫码 | Scan Kit 默认能力 | 自建相机扫码页面 |
| 自定义连续扫码 | Scan Kit 自定义扫码 + Camera | 仅使用图片识码 |
| DRM 节目授权解密 | DRM Kit | 自制版权协议 |

### 5.3 Audio Kit

[官方事实] [Audio Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/audio-kit-intro)覆盖场景化播放和录制、低时延、音效模式、音振协同等能力。

[解释] 音频实现需区分音频流类型、用途、焦点或中断、路由变化、耳机拔出、蓝牙切换、音量、静音、采样参数和后台行为。录音还应处理权限、麦克风占用、输入设备切换和文件完成性。

[项目适配] 未来若 AI 助手增加语音输入或播报，语音采集、语音识别、合成与播放是四个不同阶段。页面不应同时持有录音器、网络上传和播放器；应由语音会话服务统一协调取消和中断。

### 5.4 AVCodec Kit

[官方事实] [AVCodec Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avcodec-kit-intro)提供原子编解码、封装与解封装能力，基于性能考虑提供 C 接口，并支持 buffer、零拷贝和硬件加速路径。

[官方事实] [AVCodec 支持的格式](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avcodec-support-formats)列出格式与规格，但具体能力强依赖设备，应运行时查询能力，不能把表格当成所有设备保证。

[解释] 只有在 AVPlayer、AVRecorder 或系统高级能力无法满足时，才应承担编解码管线。实现者要处理输入输出 buffer 所有权、时间戳、关键帧、EOS、格式变化、错误回调、flush、stop 和 destroy。

[项目适配] 当前项目没有 native 媒体层。若只是播放护理视频或上传录音，不需要先引入 AVCodec。引入 C/C++ 前应明确普通 Media Kit 无法满足的可测需求。

### 5.5 AVSession 与后台播放

[官方事实] [AVSession Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-overview)用于统一系统音视频展示与控制。后台音频需要有效 AVSession 和长时任务；未正确接入时，后台播放可能被系统暂停。

[解释] AVSession 不负责解码媒体，它描述当前媒体、播放状态和控制命令，并连接系统播控入口。元数据、实际播放器状态和系统控制回调必须保持一致。

[项目适配] 若未来添加照护音频、课程或语音播报，只有明确需要后台持续播放时才接入 AVSession 和长时任务。短提示音或页面内一次播报不应默认长期占用后台。

### 5.6 Camera Kit

[官方事实] [Camera Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-overview)说明 CameraPicker 适用于拉起系统相机拍摄照片或视频且无需相机权限；专业相机应用则围绕相机设备输入、会话配置和输出管理构建。

[官方事实] [申请相机开发权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preparation)说明自定义相机使用 CAMERA；带声音录像还需 MICROPHONE；写入地理元数据涉及 MEDIA_LOCATION。读取媒体优先 Picker，保存优先安全控件；READ_IMAGEVIDEO 和 WRITE_IMAGEVIDEO 属于受限能力。

[解释] 自定义相机的最小状态模型包括：查询设备、选择输入、创建会话、添加输入与输出、提交配置、启动预览或拍摄、处理中断、停止、释放。每一步都可能失败，切换前后摄像头通常需要重配资源。

[项目适配] 长者头像、资料照片优先 CameraPicker 或 Photo Picker。只有需要连续扫码、实时预览、专业参数或专用叠加层时，才考虑 Camera Kit，并必须在页面离开和应用后台时释放相机。

### 5.7 Image Kit

[官方事实] [Image Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-overview)覆盖 PixelMap、Picture、图片编解码、编辑、元数据和 HDR。PixelMap 可用于裁剪、缩放、旋转、镜像及直接显示；Picture 可包含主图、辅助图和元数据。

[解释] 大图处理的核心风险是峰值内存。应按目标显示尺寸解码、避免同时保留原始字节与多个全尺寸 PixelMap、复用或及时释放对象，并决定是否保留 EXIF、位置和 HDR 元数据。

[项目适配] 头像和报告缩略图应生成合适尺寸，不应把相机原图长期放在 ArkUI 状态中。上传前还应按业务决定去除位置等不必要元数据。

### 5.8 Media Kit

[官方事实] [Media Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/media-kit-intro)覆盖 AVPlayer、AVRecorder、ScreenCapture、媒体元数据、视频缩略图、转码和轻量媒体引擎等能力；它不承担 UI、图形渲染或媒体库管理职责。

[解释] 播放器和录制器应按官方状态机调用，不能在任意状态直接 seek、play、stop 或 release。UI 按钮是否可用应由真实媒体状态决定，而不是只由“用户上次点了什么”决定。

[项目适配] 若增加护理视频或远程培训播放，应把媒体 source、播放器状态、缓冲、错误和释放放入独立 owner。页面切换、屏幕旋转和宽窄布局切换不得创建多个同时播放的实例。

### 5.9 Media Library Kit

[官方事实] [Media Library Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-overview)覆盖相册和图片视频资源管理。[使用 Picker 选择媒体资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-photoviewpicker)说明 Picker 本身无需媒体权限。[保存媒体库资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-savebutton)介绍通过安全控件或授权弹窗保存，避免直接申请 WRITE_IMAGEVIDEO。

[解释] URI、文件描述符和媒体资产不是普通字符串路径。调用方应在授权范围和生命周期内使用，完成后关闭文件描述符，不假设可永久访问或可直接拼接为本地路径。

[项目适配] 当前项目若允许选择报告附件，应保存业务需要的副本或稳定引用策略，并明确用户删除源媒体后的行为。不能把临时选择 URI 当成永久数据库字段而不验证。

### 5.10 Scan Kit

[官方事实] [Scan Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scan-introduction)区分扫码直达、默认扫码、自定义扫码和图像识码；不同方式支持的设备范围不同，自定义扫码界面需要相机权限。

[官方事实] [Scan Kit 个人数据处理说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scan-personal-data)用于回查扫码场景的数据处理边界。

[解释] 扫码结果是不可信输入。识别出 URL、身份字符串、设备编号或业务指令后，应做格式、来源、租户、有效期和权限校验，不能直接导航、绑定设备或执行操作。

[项目适配] 若用于长者腕带、床位或设备二维码，二维码只能提供索引或签名载荷，最终权限与数据归属必须由业务服务验证。离线 mock 数据不能冒充已完成绑定。

### 5.11 DRM、Ringtone 与 HDR

[官方事实] DRM Kit 面向受保护节目的插件、证书、许可证、授权和解密；Ringtone Kit 面向系统铃声设置；媒体分支还包含 HDR Vivid 开发入口。

[解释] 这些能力属于明确专用场景。DRM 不是普通文件加密；Ringtone 不等于应用内通知音；HDR 需要从采集、编码、解码、色彩空间到显示链路整体支持。

[项目适配] 当前产品没有对应需求。未来若只是播放机构视频、发出任务提示音或显示普通照片，不应直接引入 DRM、Ringtone 或 HDR 全链路。

---

## 6. 图形分支全景与渲染边界

### 6.1 图形目录

[官方事实] 图形分支共有 237 页。

| 子类 | 页面 |
|---|---:|
| Graphics Accelerate Kit | 82 |
| ArkGraphics 2D | 61 |
| AR Engine | 59 |
| XEngine Kit | 18 |
| ArkGraphics 3D | 10 |
| Spatial Recon Kit | 7 |

[解释] “图形”包含普通 2D 绘制、native surface、3D 场景、AR 空间理解、游戏加速和特定 GPU 特性。它们的抽象层和准入条件不同。

[项目适配] 当前产品以 ArkUI/HDS 为主，普通界面不应为了视觉效果转成 native 绘制或 3D。只有标准组件和 Canvas 无法满足的明确场景才评估更底层图形能力。

### 6.2 ArkGraphics 2D

[官方事实] [ArkGraphics 2D 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkgraphics2d-introduction)涵盖 Drawing、图像效果、色域、HDR、可变帧率，以及 NativeWindow、Buffer、Image、VSync 等绘制显示能力。

[解释] ArkUI 组件负责布局、语义、交互和直接上屏；Drawing 更适合复杂自定义图形，绘制结果还需要合适的显示载体。NativeWindow/Buffer 属于更底层所有权，必须处理申请、映射、同步、提交和释放。

[项目适配] 健康趋势、简图和仪表优先使用 ArkUI/Canvas，并保留无障碍文本。只有大量点线、特殊合成或 native 数据管线证明 ArkUI 不足时，才进入 ArkGraphics 2D native 层。

### 6.3 色彩、HDR 与可变帧率

[官方事实] ArkGraphics 2D 提供色域管理、HDR 和基于内容的可变帧率能力。高变化内容适合更高帧率，低变化内容可降低帧率以平衡功耗；能力还依赖显示硬件。

[解释] 颜色值正确不代表最终显示一致。需考虑资源色彩空间、解码结果、渲染目标、系统色彩管理和显示设备。帧率请求也不是强制保证，系统会综合资源和设备策略。

[项目适配] 当前工作台是信息密集型业务 UI，不应常驻高帧率动画。动画完成或页面不可见后，应停止主动刷新；“减少动态效果”设置还应真正影响动画消费者。

### 6.4 过度绘制

[官方事实] [过度绘制调试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/overdraw-dfx-guidelines)指出深层嵌套和重复背景会增加 CPU/GPU 负载，建议减少被遮挡内容的绘制并扁平化层级。

[解释] 透明度和模糊不会自动造成问题，但多个全屏半透明层、每层独立背景、阴影和滤镜很容易增加离屏渲染与合成成本。优化前应使用工具定位，而不是凭代码行数猜测。

[项目适配] 当前 HDS 根壳使用系统材质和连续背景。新增页面不得叠加自绘模糊顶栏、白色结构面板和全屏阴影来重复已有层级；应保持一个清晰的画布和必要业务表面。

### 6.5 ArkGraphics 3D

[官方事实] [ArkGraphics 3D 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkgraphics3d-overview)提供 Scene、Camera、Light、glTF 资源、材质或 Shader、动画与后处理等基础 3D 场景能力，并支持自动场景和自定义场景。

[解释] 3D 资源不仅是一个模型文件，还包括纹理、材质、动画、相机、光照、坐标、加载进度、内存和销毁。交互还需完成 2D 输入到 3D 射线或对象选择的映射。

[项目适配] 当前养老工作台没有 3D 需求。若未来展示房间、设备或训练模型，应先证明 3D 比图片、视频或 2D 示意图更有效，并提供低性能设备降级。

### 6.6 AR Engine

[官方事实] [AR Engine 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-overview)覆盖运动跟踪、平面与语义、环境 Mesh、深度、图像跟踪、几何重建、人脸与人体等特性。应用应使用 SystemCapability 或特性查询判断可用性；Phone、Tablet 为主要设备范围，API 23 起新增 TV 支持，但特性仍因设备而异。

[官方事实] [AR 开发准备](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-preparations)涉及 Camera、Accelerometer、Gyroscope 权限或能力，不支持时可返回 801。[AR Engine 个人数据处理说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-personal-privacy)用于回查数据边界。

[解释] AR 需要相机、运动传感器、会话、跟踪状态、渲染 surface 和 3D 内容协作。暂时失去跟踪、光线不足、权限撤销、设备过热和后台切换都必须处理。

[项目适配] 当前项目不得把 AR 作为默认核心流程。若做康复动作辅助或空间指引，必须有非 AR 替代流程，并明确它是辅助展示而不是医疗诊断。

### 6.7 Spatial Recon

[官方事实] [Spatial Recon Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/spatial-recon-introduction)提供 3DGS 等空间重建模型加载与处理能力，并存在地区和设备限制，通常与 ArkGraphics 3D 联合使用。

[解释] 能加载模型不等于能在设备上高质量重建。采集、模型生成、文件大小、GPU/内存、隐私、区域与分发都需要单独确认。

[项目适配] 当前项目没有空间重建数据链。不得仅凭一个样例模型宣称已具备房间建模或养老环境数字孪生能力。

### 6.8 Graphics Accelerate

[官方事实] [Graphics Accelerate Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/graphics-accelerate-introduction)覆盖游戏渲染、资源、启动和伴随服务。具体特性按版本和设备开放，例如部分游戏能力在后续版本增加 TV 或 PC/2in1。

[解释] 超帧、VRS、资源预下载或预启动都有集成条件和质量代价。插帧可能增加响应时延或出现拖影；预下载和预启动会消耗网络、存储、内存或后台资源。

[项目适配] 当前业务应用没有游戏渲染瓶颈。不能为了“GPU 加速”接入游戏服务。普通 ArkUI 卡顿应先用 Profiler、过绘和状态重建分析定位。

### 6.9 XEngine

[官方事实] [XEngine Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/xengine-kit-introduction)提供基于特定 GPU 的超分、VRS、Subpass Shading、光线追踪和高性能 Shader 等能力。

[解释] 产品页列出的能力不是所有 GPU、所有设备和所有应用均可调用的普遍保证。必须逐特性核对硬件、驱动、API、开放范围和回退路径。

[项目适配] 当前 phone/tablet/2in1 声明不能证明设备具备马良 GPU 或 XEngine 特性。除非有明确 3D/游戏场景和目标设备清单，否则不应接入。

---

## 7. ArkWeb 专项

### 7.1 目录全景

[官方事实] ArkWeb 共有 76 页，主要分支包括：

| 分支 | 页面 |
|---|---:|
| 管理网页交互 | 10 |
| 管理网页加载与浏览记录 | 9 |
| 处理网页内容 | 9 |
| 设置基本属性和事件 | 8 |
| 在应用中使用前端页面 JavaScript | 6 |
| Web 调试维测 | 6 |
| Web 渲染和布局 | 5 |
| 网络安全与隐私 | 5 |
| 使用网页多媒体 | 5 |
| 网页文件上传与下载 | 3 |
| 同层渲染 | 3 |
| 简介、进程、生命周期、离线 Web、扩展通信、术语和抛滑丢帧 | 若干 |

[解释] ArkWeb 不是“放一个 URL 就结束”。一个可发布的 Web 容器至少涉及加载策略、导航、进程、存储、Cookie、权限、文件、媒体、JS 桥、安全、调试和销毁。

[项目适配] 当前项目没有 Web 组件。若未来只是显示少量帮助文本，优先原生页面或系统浏览器；只有需要内嵌、受控交互或既有 Web 业务时才引入 ArkWeb。

### 7.2 简介与网络权限

[官方事实] [ArkWeb 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-component-overview)说明 Web 组件可嵌入网页、构建浏览器类场景或小程序宿主，并提供加载、生命周期、属性事件、JS 交互、安全隐私和调试能力。访问在线网页需声明 <code>ohos.permission.INTERNET</code>，Web 标准支持还取决于随 HarmonyOS 版本变化的 ArkWeb 内核版本。

[解释] 不能用桌面 Chrome 的结果推断目标设备 ArkWeb 一定支持同一 Web API、CSS 或 WebAssembly 特性。需要在目标系统内核版本上测试。

[项目适配] 如果内嵌机构帮助中心，应建立允许域名、外链策略、下载策略和错误页。当前无 INTERNET 权限，加入 Web 页面前必须同步更新权限与隐私说明。

### 7.3 多进程模型

[官方事实] [ArkWeb 进程](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web_component_process)描述应用进程、Web 渲染进程、Web GPU 进程、孵化进程和 Foundation 进程。移动设备默认共享渲染进程以节省内存，2in1 默认独立渲染进程以提高安全与稳定性。

[解释] 多 Web 实例共享进程可以省内存，但一个渲染进程异常可能影响多个实例；独立进程提高隔离但消耗更多资源。选择应基于页面信任边界和实测内存。

[项目适配] 未来若宽屏同时打开多个 Web 业务面板，必须测量进程数和内存，不能沿用 HDS Tabs 的“全部预加载”思路无条件预建多个 Web。

### 7.4 Web 生命周期

[官方事实] [Web 组件的生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-event-sequence)指出 Controller 在 <code>onControllerAttached</code> 前不可调用相关接口；<code>onPageEnd</code> 不保证下一帧 DOM 已经呈现；组件析构会销毁 Web、Controller 绑定和 JS 运行环境。

[解释] 正确顺序是：

1. 组件出现前设置适合的全局或早期配置；
2. Controller 绑定后再调用允许的控制接口；
3. 区分主 frame 与子 frame 的加载事件；
4. 区分网络加载结束、DOM 事件和视觉呈现；
5. 页面离开时停止业务桥接、解除回调并决定是否保活；
6. 销毁后不再使用旧 Controller。

[项目适配] 不应把 WebViewController 放入永久全局对象后跨组件复用。若需要保活，应采用官方离线 Web 或明确的 owner，而不是让已销毁页面的 Controller 留在 AppStorage。

### 7.5 JavaScript 桥

[官方事实] ArkWeb 提供 JavaScriptProxy 等应用与网页交互能力，并有前端页面 JavaScript、消息通信和扩展通信相关指南。

[解释] JS 桥是安全边界。应只暴露最小、固定、版本化的方法，校验参数和来源，禁止将任意 native 方法或文件路径暴露给不可信网页。异步结果应带请求 ID，页面导航后要拒绝旧页面回调。

[项目适配] 若 Web 页面需要调用长者、任务或账号能力，不能直接暴露 repository。应建立受限 facade，并在 native 侧执行角色、租户和对象权限检查。

### 7.6 加载、导航与历史

[官方事实] ArkWeb 目录包含 URL 加载、离线页面、加载拦截、请求拦截、历史记录、前进后退和页面内容处理等指南。

[解释] 导航策略至少要决定：

- 哪些 scheme 和域名允许；
- 外部链接留在 Web 还是交给系统；
- 重定向和新窗口如何处理；
- SSL、证书和混合内容策略；
- 加载失败、离线和超时页面；
- 返回键优先 Web 历史还是应用导航；
- 登录态 Cookie 和退出时清理范围。

[项目适配] HDS NavPathStack 与 Web 历史是两套栈。若接入 Web，必须明确 back 行为，避免用户一次返回直接退出整个功能或在两套历史之间循环。

### 7.7 文件上传与下载

[官方事实] ArkWeb 提供文件上传界面、下载处理和相关交互指南。

[解释] 上传应优先通过系统 Picker 获取用户明确选择的资源；下载要校验 MIME、文件名、大小、存储位置和用户确认。网页提供的文件名、Content-Type 和 URL 都是不可信输入。

[项目适配] 涉及健康报告时，不允许 Web 页面自由读取应用沙箱或任意媒体。下载文件也不应自动打开或导入业务记录，必须经过类型与权限校验。

### 7.8 Web 媒体与同层渲染

[官方事实] ArkWeb 目录包含网页多媒体、媒体播放托管和同层渲染能力。

[解释] Web 视频、原生播放器和 ArkWeb 进程会共同竞争音频焦点、GPU、解码器和内存。同层渲染用于解决特定组件组合，不是普通布局的默认方案。

[项目适配] 当前项目若播放培训视频，应先在原生 Media Kit 与 Web 播放之间选择一个主路径。不要同时保留隐藏 Web 视频和原生播放器。

### 7.9 Web 安全、隐私与调试

[官方事实] [管理 Web 组件的网络安全与隐私](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-manage-cyber-security-privacy)覆盖本地资源跨域、智能防跟踪、广告过滤和坚盾守护模式。ArkWeb 还提供 DevTools、崩溃信息、白屏定位、自动化测试和抛滑丢帧事件等维测入口。

[解释] 调试模式、远程调试、宽松跨域、测试证书和详细请求日志都应限定在调试环境。正式环境需要最小化 Cookie、缓存、Web 存储、定位、相机、麦克风和文件授权。

[项目适配] 如果 Web 内容包含机构系统登录，退出应用账号时应明确是否同步清理 Web Cookie 和存储。不得让测试环境 Cookie 或调试入口进入正式包。

---

## 8. 常见工程决策树

### 8.1 用户需要一张照片

[解释] 按以下顺序判断：

1. 从已有照片中选择：Photo Picker。
2. 让用户现场拍一张：CameraPicker。
3. 应用生成图片并让用户保存：SaveButton 或官方授权保存流程。
4. 需要连续预览、扫码、曝光或对焦控制：Camera Kit。
5. 需要裁剪、压缩、去元数据：Image Kit。
6. 需要上传：在选择或处理完成后交给网络 service。

[项目适配] 每一步都应保留取消路径。用户取消 Picker 不是错误，不能弹“操作失败”。

### 8.2 需要音视频

[解释] 按以下顺序判断：

1. 只是播放文件或 URL：AVPlayer。
2. 只是录制：AVRecorder。
3. 短提示音：SoundPool 或适合的轻量能力。
4. 低时延专业音频：Audio Kit。
5. 后台播控：在播放器之上接 AVSession 和长时任务。
6. 自定义格式管线：AVCodec。
7. 需要媒体库选择或保存：Media Library。
8. 受版权保护节目：DRM。

[项目适配] 不要因为后续“可能支持更多格式”而一开始就实现 AVCodec。

### 8.3 需要绘制

[解释] 按以下顺序判断：

1. 标准界面：ArkUI/HDS。
2. 小型自定义图表或形状：Canvas/Drawing。
3. native 数据直接上屏或复杂 buffer 管线：ArkGraphics 2D native。
4. 可交互三维场景：ArkGraphics 3D。
5. 现实空间跟踪：AR Engine。
6. 空间重建模型：Spatial Recon。
7. 已证明的游戏级 GPU 瓶颈：再评估 Graphics Accelerate 或 XEngine。

[项目适配] 当前绝大多数护理工作台界面应停留在第 1 或第 2 层。

### 8.4 需要网页

[解释] 按以下顺序判断：

1. 少量静态说明：原生 Text、RichText 或资源。
2. 外部页面且无需嵌入：系统浏览器。
3. 受控内嵌网页：ArkWeb。
4. 原生与 Web 双向交互：最小 JS 桥。
5. 多实例、离线、同层渲染或媒体托管：确认前四层已经无法满足并做性能测试。

[项目适配] “开发更快”不是唯一判断。还要计算登录态、隐私、无障碍、深浅模式、返回栈和长期维护成本。

### 8.5 需要设备或动作感知

[解释] 按以下顺序判断：

1. UI 输入事件：ArkUI 事件。
2. 输入设备列表、系统键、鼠标光标：Input Kit。
3. 原始加速度、陀螺仪等：Sensor Service。
4. 系统融合后的静止、操作手、设备状态：Multimodal Awareness。
5. 手写笔增强：Pen Kit。
6. 设备间通信：根据协议再选择 Connectivity、Distributed 或厂商云 API。

[项目适配] 业务应能在能力缺失时继续工作，不能把某个传感器或手写笔设为进入护理核心流程的唯一入口。

### 8.6 需要安全存储或认证

[解释] 按以下顺序判断：

1. 非敏感偏好：Preferences。
2. 短敏感明文：评估 Asset Store。
3. 密钥及密钥操作：HUKS。
4. 通用密码算法：Crypto Architecture。
5. 设备本地用户确认：User Authentication。
6. 服务账号与 session：后台认证协议。
7. Passkey/FIDO：Online Authentication 及服务端。
8. 证书解析、校验或管理：Device Certificate。

[项目适配] 这些能力可以组合，但不能相互冒充。设备指纹认证成功不等于服务端已经授予护工访问某位长者的权限。

---

## 9. KangxiaobanAI 适配矩阵

### 9.1 当前静态基线

[项目适配] 当前工程事实：

| 项目 | 当前状态 |
|---|---|
| target SDK | 6.1.1(24) |
| compatible SDK | 6.1.0(23) |
| 模块 | 单 entry，模块名 kanxiaoban |
| 设备 | phone、tablet、2in1 |
| 签名 | 当前根构建配置存在本地签名配置；敏感材料不纳入本文，AI 不得回显或复制 |
| 状态体系 | ArkUI V2 |
| 导航 | 认证边界 router，业务 HDS Navigation/NavPathStack |
| 窗口 | WindowUtil 管理尺寸、避让区与沉浸 |
| 权限 | 主模块无 requestPermissions |
| 网络 | 无真实 HTTP、WebSocket、repository |
| 媒体 | 无 Camera、Audio、Media、Media Library 业务 |
| Web | 无 ArkWeb |
| 图形 | 主要为 ArkUI/HDS，无 AR、3D 或 GPU 服务 |
| 数据 | 大量本地 mock；非真实服务或持久化业务 |

[解释] 因此，本章中大部分 Kit 是“可选架构知识”，不是当前实现说明。

### 9.2 可能需求与落点

[项目适配] 下面矩阵用于未来需求评审。

| 需求 | 最小候选能力 | 配置与权限 | 新增所有者 | 必测 |
|---|---|---|---|---|
| AI 文本服务 | Network Kit HTTP/SSE 或 WebSocket | INTERNET、TLS 配置 | conversation repository/service | 超时、取消、断网、重复、退出 |
| 长者头像选择 | Photo Picker + Image Kit | 通常无需媒体库广泛权限 | profile media service | 取消、大图、旋转、元数据 |
| 现场拍照 | CameraPicker | 通常无需 CAMERA | profile media service | 相机取消、回传、进程恢复 |
| 自定义扫码 | Scan Kit + Camera | CAMERA | scan service | 不支持、拒绝、重复码、伪造码 |
| 语音输入 | Audio/录音 + 识别服务 | MICROPHONE、可能 INTERNET | voice session service | 中断、耳机、后台、取消、隐私 |
| 音频播报 | Audio/Media | 按场景决定后台任务 | playback service | 焦点、中断、蓝牙、释放 |
| 培训视频 | Media Kit | INTERNET 或本地资源访问 | media playback owner | 首帧、seek、后台、旋转 |
| 内嵌帮助中心 | ArkWeb | INTERNET | web feature owner | 域名、返回栈、Cookie、下载 |
| 手写批注 | Pen + Drawing/Image | 设备能力；按存储决定权限 | annotation feature | 无笔、缩放、撤销、导出 |
| 动作或姿态辅助 | Sensor/Multimodal | 对应权限和能力 | awareness service | 801、噪声、旋转、功耗 |
| AR 指引 | AR Engine + 3D | Camera/传感器、能力查询 | AR session owner | 跟踪丢失、温升、降级 |

### 9.3 权限矩阵模板

[解释] 每次新增权限都应填完整下表，而不是只写权限名。

| 字段 | 必填内容 |
|---|---|
| 业务动作 | 哪个用户动作触发 |
| 权限名 | 官方完整权限字符串 |
| 授权类型 | system_grant、user_grant 或 manual_settings |
| reason | 用户可理解的多语言用途 |
| usedScene | Ability 与 inuse/always |
| 请求时机 | 明确按钮之后，不在启动时批量请求 |
| 拒绝路径 | 保留哪些功能，如何稍后重试 |
| 永久拒绝 | 是否需要设置引导 |
| 撤销恢复 | 进程重启和状态恢复 |
| 无权限替代 | Picker、安全控件、手工输入或其他路径 |
| 数据处理 | 采集、保存、上传、删除、日志 |
| 验证设备 | 型号、系统、导航方式和窗口形态 |

[项目适配] 当前权限为零是一个清晰基线。任何权限增加都应在变更说明中列出原因和替代方案。

### 9.4 推荐代码边界

[解释] 新能力建议使用以下依赖方向：

    ArkUI Page / Component
        -> Feature ViewModel or Store
        -> UseCase
        -> Repository interface
        -> HarmonyOS Kit adapter / Remote data source / Local data source

[项目适配] 页面层负责呈现和用户意图；adapter 层封装 Camera、Media、Web、Sensor 等系统对象；repository 负责业务数据；UseCase 负责权限与业务规则。不要让 <code>TabPageView.ets</code> 或其他超大组件直接管理底层 Kit 全生命周期。

### 9.5 老年照护的额外安全边界

[项目适配] 对长者相关功能必须额外检查：

- 字体和触控目标是否适合低视力或运动能力下降用户；
- 相机、录音、视频是否有清晰的正在采集提示；
- 健康和身份数据是否最小化采集；
- 扫码或设备感知结果是否需要人工确认；
- 传感器结果是否会被误当成医学判断；
- 网络失败时是否保留草稿并避免重复提交；
- Web 页面是否可访问不受控外链；
- 日志、截图和崩溃报告是否带有真实个人信息；
- 护工、医师和管理角色是否由服务端授权，而不是 UI 字符串；
- AI 建议是否明确为辅助信息并保留人工决策。

---

## 10. Codex / Claude 实施与审查清单

### 10.1 修改前

[解释] AI 在修改代码前必须回答：

- 目标顶层工程和模块是什么；
- 当前 target/compatible SDK 是多少；
- 目标设备和窗口形态是什么；
- 官方页面是否声明 API、设备、地区或合作限制；
- 是否有 SystemCapability 或运行时能力查询；
- 是否需要权限，能否用 Picker 或安全控件替代；
- 系统对象由谁创建、持有和释放；
- 后台、切屏、旋转、窗口重建时会发生什么；
- 数据是否敏感，是否进入网络、文件、日志或 Web；
- 当前工程是否已有同代实现或可复用 adapter；
- 哪些测试只能真机完成。

[项目适配] 修改前还要检查脏工作树，保留用户改动，不读取或输出签名秘密。

### 10.2 实现中

[解释] AI 实现时应遵守：

- UI 不直接解析网络 DTO；
- UI 不直接持有多个底层媒体或硬件对象；
- 监听注册和解除使用同一函数引用；
- 异步结果检查 owner 是否存活及请求代次；
- 所有资源有明确 release、close、off 或 destroy；
- 权限弹窗由明确用户动作触发；
- 用户拒绝不破坏无关业务；
- 不支持能力有可理解的降级；
- 错误码映射为可操作状态；
- 日志不包含 token、密钥、证件、聊天、健康或媒体原文；
- 大文件使用流式路径并可取消；
- 大图按目标尺寸解码；
- Web 桥只暴露白名单能力；
- native buffer、codec 和 surface 的所有权不含糊；
- 状态文案只反映真实完成结果。

### 10.3 静态验收

[解释] 静态检查至少包括：

- <code>module.json5</code> 权限、reason、usedScene 和 Ability 名称一致；
- 导入的 Kit 与业务实际使用一致；
- API 版本保护和 SystemCapability 路径存在；
- listener、timer、request、socket 和 native 资源有清理；
- 页面销毁后不会继续写 UI 状态；
- source、URI、fd、PixelMap、播放器、相机和 Web Controller 生命周期清楚；
- 失败、取消、拒绝、不支持和空数据路径存在；
- mock 成功文案已改为真实状态；
- 隐私说明与数据流一致；
- 没有回显签名、证书、token 或密钥。

### 10.4 构建验收

[解释] 构建通过只能说明该工作树在注明 SDK 和构建模式下编译打包成功。应记录：

- DevEco Studio 与 SDK 版本；
- target/compatible SDK；
- debug 或 release；
- 使用的设备 target；
- 是否签名；
- 产物路径；
- 编译警告；
- 依赖解析和 native ABI；
- 是否包含新增权限与资源。

[项目适配] 当前章节没有执行项目构建，因此不能声称本章中的任何新增能力已构建确认。

### 10.5 真机验收

[解释] 涉及系统、媒体、图形或 Web 的变更，至少覆盖适用项：

| 维度 | 场景 |
|---|---|
| 权限 | 首次允许、拒绝、设置撤销、进程重启 |
| 设备 | phone、tablet、2in1；支持与不支持设备 |
| 窗口 | 旋转、分屏、自由窗口、键盘、系统栏 |
| 输入 | 触摸、鼠标、键盘、触控板、手写笔 |
| 网络 | Wi-Fi/蜂窝切换、断网、慢网、TLS 失败 |
| 媒体 | 中断、耳机、蓝牙、后台、来电、资源占用 |
| 相机 | 前后摄像头、切后台、权限撤销、设备忙 |
| 图片 | 大图、旋转、HDR、低内存 |
| Web | 内核版本、返回栈、Cookie、上传下载、崩溃 |
| 图形 | 帧率、过绘、温升、内存、降级 |
| 传感器 | 旋转、采样率、无传感器、噪声 |
| 无障碍 | 大字体、读屏、焦点、减少动态效果 |

[项目适配] 只有在注明设备型号、系统版本和场景后，才能使用“真机确认”。

### 10.6 服务验收

[解释] 网络、账号、上传、扫码绑定和后台业务还需要服务验证：

- 真实环境鉴权；
- 角色、租户和对象权限；
- 成功、业务拒绝、超时、限流和重复请求；
- 消息顺序、幂等和重连；
- 上传完整性与恶意文件；
- 数据入库、读取、修改和删除；
- 审计与隐私请求；
- 服务端版本兼容；
- 退出和凭据失效。

[项目适配] 当前项目没有真实服务，因此任何本地按钮成功都只能称为本地原型行为。

### 10.7 禁止性检查

[解释] 发现以下模式时应停止并重新设计：

- 为一个 Picker 场景申请整个媒体库权限；
- 应用启动即批量申请敏感权限；
- 用 UI 角色字符串控制真实数据权限；
- 在页面 build 或重复出现路径注册监听；
- Web Controller、Camera 或播放器永久放入无清理的全局单例；
- 设备能力查询失败后仍继续调用；
- 把支持格式列表写死为所有设备保证；
- 用固定屏幕尺寸判断当前窗口布局；
- 用传感器结果直接作医疗结论；
- 把二维码内容直接当可信操作；
- 为普通业务界面引入游戏 GPU 服务；
- 在 release 信任用户 CA 或开启 Web 调试；
- 在日志输出 token、密钥、证件、健康或媒体内容；
- 静态检查后声称已真机、性能或服务确认。

---

## 11. 官方页面与检索关键词索引

### 11.1 安全与网络

[官方事实] 下表用于快速回到官方页面。关键词也适合在本地 <code>page-digests.jsonl</code>、SQLite 或官网搜索。

| 页面 | 官方链接 | 检索关键词 |
|---|---|---|
| 应用权限管控概述 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-permission-mgmt-overview) | 最小权限、撤销进程、system_grant、user_grant |
| 声明权限 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions) | requestPermissions、reason、usedScene |
| 向用户申请授权 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/request-user-authorization) | checkAccessToken、动态授权、设置引导 |
| 安全控件概述 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/security-component-overview) | PasteButton、SaveButton、场景化授权 |
| Asset Store Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/asset-store-kit-overview) | token、短敏感数据、安全存储 |
| HUKS 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/huks-overview) | 密钥、访问控制、签名、加密 |
| Crypto Architecture Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/crypto-architecture-kit-intro) | 算法、哈希、随机数、线程 |
| User Authentication Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/user-authentication-overview) | 指纹、人脸、锁屏口令、本地认证 |
| 使用 HTTP 访问网络 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/http-request) | request、requestInstream、拦截器 |
| 使用 WebSocket 访问网络 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/websocket-connection) | open、message、close、error、API 23 |
| 网络连接安全配置 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/network-connection-security-configuration) | TLS、系统 CA、用户 CA、Pinning |

### 11.2 窗口、输入与硬件

[官方事实] 这些页面用于窗口和多输入设计回查。

| 页面 | 官方链接 | 检索关键词 |
|---|---|---|
| 窗口开发概述 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/window-overview) | Stage、焦点、WindowLimits |
| 窗口基础能力 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/window-basic-capabilities) | 生命周期、旋转、层级、沉浸 |
| Display 属性查询及监听 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/screenproperty-guideline) | 分辨率、密度、刷新率、折叠 |
| Input Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/input-overview) | 触摸、鼠标、键盘、设备列表 |
| IME Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-intro) | 输入法应用、自绘编辑框、Panel |
| 输入法安全模式 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-security) | 基础模式、网络限制、隐私 |
| 不可获焦窗口输入 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/use-inputmethod-in-not-focusable-window) | focusable、TextInput、键盘 |
| Multimodal Awareness 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/multimodalawareness-kit-intro) | 订阅、取消、传感器、权限 |
| 获取用户动作 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/motion-guidelines) | 操作手、握持手、801、on/off |
| 传感器开发概述 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/sensor-overview) | 自然方向、Display 旋转、采样 |
| Pen Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pen-introduction) | 报点预测、一笔成形、取色 |

### 11.3 媒体

[官方事实] 这些页面用于媒体能力选择和隐私回查。

| 页面 | 官方链接 | 检索关键词 |
|---|---|---|
| 媒体开发概览 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/multimedia-development-overview) | Audio、Camera、Media、Image |
| Audio Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/audio-kit-intro) | 低时延、录音、音效、音振 |
| AVCodec Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avcodec-kit-intro) | C API、buffer、零拷贝、硬件加速 |
| AVCodec 支持格式 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avcodec-support-formats) | 格式、规格、运行时查询 |
| AVSession Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avsession-overview) | 系统播控、后台音频、长时任务 |
| Camera Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-overview) | CameraPicker、输入、会话、输出 |
| 相机开发权限 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preparation) | CAMERA、MICROPHONE、MEDIA_LOCATION |
| Image Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-overview) | PixelMap、Picture、HDR、元数据 |
| Media Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/media-kit-intro) | AVPlayer、AVRecorder、ScreenCapture |
| Media Library Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-overview) | 相册、媒体资源、MovingPhoto |
| Photo Picker | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-photoviewpicker) | 无媒体权限、选择图片视频 |
| 保存媒体库资源 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-savebutton) | SaveButton、WRITE_IMAGEVIDEO |
| Scan Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scan-introduction) | 默认扫码、自定义扫码、图像识码 |
| Scan 个人数据处理 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scan-personal-data) | 扫码、个人数据、隐私 |

### 11.4 图形与 AR

[官方事实] 这些页面用于图形层级和设备能力回查。

| 页面 | 官方链接 | 检索关键词 |
|---|---|---|
| ArkGraphics 2D 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkgraphics2d-introduction) | Drawing、NativeWindow、Buffer、VSync |
| 过度绘制调试 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/overdraw-dfx-guidelines) | overdraw、重复背景、GPU |
| ArkGraphics 3D 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkgraphics3d-overview) | Scene、Camera、Light、glTF |
| AR Engine 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-overview) | SystemCapability、特性、设备 |
| AR 开发准备 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-preparations) | Camera、Accelerometer、Gyroscope、801 |
| AR 个人数据处理 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-personal-privacy) | 相机、环境、人体、隐私 |
| Spatial Recon Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/spatial-recon-introduction) | 3DGS、地区、设备、ArkGraphics 3D |
| Graphics Accelerate 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/graphics-accelerate-introduction) | 超帧、资源、启动、游戏 |
| XEngine Kit 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/xengine-kit-introduction) | GPU、VRS、光线追踪、超分 |

### 11.5 ArkWeb

[官方事实] 这些页面用于 Web 容器设计回查。

| 页面 | 官方链接 | 检索关键词 |
|---|---|---|
| ArkWeb 简介 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-component-overview) | INTERNET、Web 组件、内核版本 |
| ArkWeb 进程 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web_component_process) | 渲染进程、GPU 进程、共享、独立 |
| Web 组件生命周期 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-event-sequence) | onControllerAttached、onPageEnd、析构 |
| Web 网络安全与隐私 | [打开](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-manage-cyber-security-privacy) | 跨域、防跟踪、过滤、坚盾 |

---

## 12. 最终工作原则

[官方事实] 官方文档把系统、媒体、图形和 Web 能力拆成大量按场景、版本、设备与权限划分的页面；不存在一个“导入 HarmonyOS 全能力”的统一做法。

[解释] 高质量实现的共同公式是：

    明确场景
      + 选择最小 Kit
      + 核对 API / 设备 / SystemCapability
      + 最小权限或场景化授权
      + 明确生命周期和资源所有权
      + 真实失败与降级状态
      + 性能和隐私边界
      + 分层验证

[项目适配] 对 <code>KangxiaobanAI</code>，近期最重要的不是一次加入更多 Kit，而是保持当前 HDS、ArkUI V2、窗口和响应式所有权清晰；当真实网络、媒体或设备需求出现时，再按 feature 建立小而可验证的系统 adapter，并把本地 mock 与真实服务状态严格区分。
