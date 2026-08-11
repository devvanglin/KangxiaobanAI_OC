# HarmonyOS 官方综合章：应用服务、AI、多端、自由流转与 NDK

> 核验日期：2026-08-10  
> 官方总入口：[HarmonyOS 应用开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts)  
> 菜单证据：[`coverage/menu-inventory.csv`](../coverage/menu-inventory.csv)、[`coverage/menu-tree.md`](../coverage/menu-tree.md)  
> 页面读取证据：[`coverage/page-status.csv`](../coverage/page-status.csv)、[`coverage/page-digests.jsonl`](../coverage/page-digests.jsonl)  
> 读者：使用 Codex、Claude 等编程 Agent 的开发者、架构师、评审者和测试人员

本章综合当前官网“开发”目录中五个容易被混为一谈的领域：应用服务、AI、一次开发多端部署、自由流转和 NDK。它保留完整直接类别和页面数量，但不逐页复印官方内容。每个 Kit 都从相同的工程问题展开：它解决什么问题、属于本地系统能力还是云服务、接入前需要什么、权限/设备/版本边界在哪里、谁拥有生命周期，以及怎样验证失败路径。

文中使用三类标签：

- `[官方事实]`：来自本次抓取到的官方菜单、正文摘要或路径迁移页；
- `[解释]`：把官方能力转成可执行的工程检查，不冒充官方原文；
- `[项目适配]`：只描述当前 `KangxiaobanAI` 工作树的使用边界。

涉及具体接口时，本章仍不是 API 参考。Codex/Claude 必须回到当前 SDK 与对应 API 参考核对 import、成员、重载、`@since`、`SystemCapability`、错误码和释放方法，不能从本章的能力描述反向编造接口。

---

## 1. 覆盖口径与正文页数

“正文页数”按 `menu-inventory.csv` 中 `has_document=True` 的菜单节点统计，包含直接 Kit 概览页及其全部正文后代，不包含纯分组节点。

| 当前“开发”直属栏目 | 直接类别 | 正文页数 | 本章处理方式 |
| --- | ---: | ---: | --- |
| 应用服务 | 28 个直接 Kit | 948 | 完整类别表，并逐 Kit 给出用途、前提、边界、生命周期与失败验证 |
| AI | 10 个直接 Kit | 948 | 完整类别表；特别区分系统 AI 服务、场景化控件、端侧模型框架和 Native 运行时 |
| 一次开发，多端部署 | 1 个路径迁移页 | 1 | 说明迁移后的 Best Practices 地址，并给出多设备工程协议 |
| 自由流转 | 1 个路径迁移页 | 1 | 说明迁移后的 Best Practices 地址，并区分跨端迁移与多端协同 |
| NDK开发 | 7 个直接主题 | 142 | 给出完整主题表，覆盖工具链、跨语言、ABI、资源、调试和硬件兼容 |
| 合计 | 47 个直接类别/主题 | 2040 | 本章综合范围 |

`[官方事实]` 当前“开发 > 一次开发，多端部署”和“开发 > 自由流转”各只保留一个路径调整页。正文分别迁移到：

- [最佳实践：一次开发，多端部署](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-overview)
- [最佳实践：自由流转](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-hopping)

因此，上表中的“1 页”只代表当前这棵左侧菜单里的重定向节点数，不代表迁移后主题只有一页。

---

## 2. 六种能力边界必须先分开

| 类型 | 真实含义 | 不能据此推断 |
| --- | --- | --- |
| 本地应用能力 | 业务代码、文件、模型或数据主要由当前进程/设备处理 | 不等于无需权限、不等于所有设备都支持 |
| 系统 Kit | HarmonyOS 提供系统服务、控件或统一入口 | 不等于纯本地；系统服务仍可能访问网络、账号或云端 |
| AGC/云服务 | 需在 AppGallery Connect 开通、配置应用身份、服务或服务器 | UI 调用成功不等于订单、消息或数据已由云端最终确认 |
| 模型推理 | 使用预置或开发者模型执行推理/训练/转换 | 不等于生成式大模型，也不等于结果正确、安全或适合高后果决策 |
| 分布式能力 | 多设备间发现、连接、迁移、协同或数据交互 | `deviceTypes`、响应式 UI 或同一账号不等于已经接入自由流转 |
| Native ABI | C/C++、动态库、Node-API/JSVM、目标 ABI 与硬件特性 | Native 不天然更快，也不自动兼容所有 HarmonyOS 设备 |

`[解释]` 评审一个“接入 Kit”的提交时，先问它属于哪一列。一个能力可以跨多列，例如 Call Service Kit 同时依赖应用自己的音视频网络、系统通话 UI 和 Push Kit；Live View 同时涉及云侧更新、Push 权益和系统关键界面展示；MindSpore Lite 是端侧模型运行框架，而 Core Vision 是系统提供的基础视觉服务，两者不能只因为都叫 AI 就采用同一接入方式。

---

## 3. 应用服务：28 个直接 Kit 完整表

| Kit | 页数 | 主类型 | 代表官方入口 |
| --- | ---: | --- | --- |
| Account Kit（华为账号服务） | 61 | 系统账号 + AGC 权限 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-kit-guide) |
| Ads Kit（广告服务） | 19 | 云广告 + 隐私授权 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ads-kit-guide) |
| AppGallery Kit（应用市场服务） | 84 | 应用市场/分发/商业服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/store-kit-guide) |
| App Linking Kit（应用链接服务） | 10 | 系统链接 + 应用市场服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-linking-kit-guide) |
| Calendar Kit（日历服务） | 6 | 本地系统数据 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/calendar-kit) |
| Call Service Kit（通话服务） | 11 | 系统通话体验 + Push + 应用网络 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/call-kit-guide) |
| Cloud Foundation Kit（云开发服务） | 67 | AGC 云函数/数据库/存储 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloud-foundation-kit-guide) |
| Contacts Kit（联系人服务） | 3 | 系统 Picker | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/contacts-kit) |
| Enterprise Space Kit（企业数字空间服务） | 16 | 企业 MDM/受限系统能力 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/enterprise-space-kit-guide) |
| File Manager Service Kit（文件管理服务） | 5 | 本地系统文件能力 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/file-manager-service-kit-guide) |
| Game Controller Kit（游戏控制器服务） | 5 | Native 外设输入 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/game-controller-kit) |
| Game Service Kit（游戏服务） | 42 | AGC 游戏服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/game-service-kit-guide) |
| Health Service Kit（运动健康服务） | 69 | 账号授权 + 敏感云数据 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/health-service-kit-guide) |
| IAP Kit（应用内支付服务） | 54 | 数字商品/订阅/商户服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/iap-kit-guide) |
| Live View Kit（实况窗服务） | 20 | Push 云更新 + 系统展示 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/live-view-kit-guide) |
| Location Kit（位置服务） | 16 | 系统传感/定位 + 可选开放能力 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/location-kit) |
| Map Kit（地图服务） | 63 | 地图组件 + 网络服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/map-kit-guide) |
| Notification Kit（用户通知服务） | 20 | 本地系统通知 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-kit) |
| Payment Kit（鸿蒙支付服务） | 71 | 实体商品/服务支付 + 商户云端 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/payment-kit-guide) |
| PDF Kit（PDF服务） | 26 | 本地系统文档服务/组件 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pdf-kit-guide) |
| Preview Kit（文件预览服务） | 10 | 系统预览 + Native 加速 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/preview-kit-guide) |
| Push Kit（推送服务） | 48 | 云到端消息通道 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-kit-guide) |
| Reader Kit（阅读服务） | 16 | 本地解析/排版/Native 渲染 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/reader-kit-guide) |
| Scenario Fusion Kit（融合场景服务） | 44 | 系统跨子系统场景组件 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/scenario-fusion-kit-guide) |
| Screen Time Guard Kit（屏幕时间守护服务） | 29 | 受限 ACL/设备管控 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/screen-time-guard-kit-guide) |
| Share Kit（分享服务） | 44 | 系统跨应用/跨端分享 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/share-kit-guide) |
| Wallet Kit（钱包服务） | 80 | 芯-端-云卡证/钥匙/票券 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/wallet-kit-guide) |
| Weather Service Kit（天气服务） | 9 | 云数据；当前系统应用开放 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/weather-service-kit-guide) |

### 3.1 Account Kit（61 页）

- `[官方事实]` 提供华为账号登录、静默登录、头像昵称、手机号、地址、发票抬头、风险等级及未成年人模式等能力。开发准备包含申请账号权限、配置签名/指纹和 Client ID；一键登录、手机号和地址等部分权限只向符合条件的企业开发者开放。
- `[解释]` 华为账号身份不能直接等同机构账号、租户、角色或业务授权。应用仍需建立自己的 session、用户映射、注销、token/授权失效和账号切换规则。
- `[解释]` 生命周期应覆盖发起登录、用户取消、授权回调、应用前后台、静默登录失败、scope 变化和退出账号。失败验证至少包括未开通权限、权限尚未生效、账号不可用、网络失败、用户拒绝及服务返回身份与本地账号冲突。
- `[项目适配]` `KangxiaobanAI` 当前登录只是本地定时器与角色字符串，没有 Account Kit、真实凭据、token、租户或 RBAC。不能把角色选择器改名为“华为账号登录”而不建立完整账号与机构身份边界。

### 3.2 Ads Kit（19 页）

- `[官方事实]` 提供横幅、原生、激励、插屏、开屏、贴片等广告形态，以及 OAID/转化跟踪。当前开发准备明确涉及网络权限；获取匿名设备标识还涉及用户授权的应用跟踪同意权限及对应 reason/Ability 配置。
- `[解释]` 广告对象通常有加载、可展示、展示、点击、关闭、奖励、失效等状态。必须由广告回调和服务规则驱动，不能因页面出现占位框就发放奖励。
- `[解释]` 验证无填充、网络断开、用户不同意个性化、页面销毁、重复加载、前后台切换和奖励回调重复。隐私声明、同意状态和非个性化广告路径必须独立于商业成功率。
- `[项目适配]` 智慧养老工作台当前无广告业务。没有明确商业需求、隐私评估和产品批准，不应加入 Ads Kit 或设备标识能力。

### 3.3 AppGallery Kit（84 页）

- `[官方事实]` 覆盖数字商品、市场推荐、按需分发、生态查询、应用更新、归因、隐私管理、图标管理和应用评论。不同子服务有独立开关、商品/事件配置、签名和模拟器差异。
- `[解释]` 不能把 AppGallery Kit 当成一个单 API。接入前先确定是更新、归因、动态分发还是数字商品，并只开通对应服务。市场未安装、区域不支持、应用未上架、商品未配置和签名身份不匹配都应有降级。
- `[解释]` 数字商品的权益发放、更新检测、归因和按需模块下载分别有不同生命周期。商业数据必须由可信服务结果确认，不使用客户端单一回调作为财务最终凭据。
- `[项目适配]` 当前项目没有应用市场服务、动态 feature 分发、归因或数字商品。不要因主工程只有一个 entry 模块就提前引入动态模块。

### 3.4 App Linking Kit（10 页）

- `[官方事实]` 支持应用已安装时拉起目标应用，未安装时走网页或应用市场，并提供直达市场、延迟链接和聚合链接等能力。开发准备包含基本应用准备和开通 App Linking 服务。
- `[解释]` 链接参数是外部不可信输入。必须做 allow-list、长度/类型校验、登录与租户检查、过期和幂等处理；未安装、浏览器回退、安装后首次启动及重复点击都要验证。
- `[解释]` 生命周期从链接生成/发布、系统解析、目标启动、参数消费到返回。禁止把任意 URL 参数直接变成数据库操作或高权限页面跳转。
- `[项目适配]` 当前主模块没有 route map、deep link 或通知落地入口。若新增，应同时定义 named route、参数类型、未登录落地、返回和无效链接体验。

### 3.5 Calendar Kit（6 页）

- `[官方事实]` 提供日历账户、日程以及一键服务日程管理。应用创建的日历账户有唯一 ID；删除账户会影响与其关联的日程。
- `[解释]` 日程是用户数据。调用前要按实际 API 核对权限、设备与版本，不从“系统日历可见”推断应用可任意读取。写入前明确时区、全天事件、重复规则、提醒、更新与删除语义。
- `[解释]` 生命周期包括创建/获取账户、创建/更新日程、提醒和清理。验证账户不存在、日程重复、时区/夏令时、权限撤销、进程重启和用户在系统日历侧修改数据。
- `[项目适配]` 当前任务和交班是本地 mock，不是系统日历事件。是否同步日历属于新的产品与隐私决定，不能自动实现。

### 3.6 Call Service Kit（11 页）

- `[官方事实]` 统一管理应用内音视频来电/去电的系统体验，包括来电横幅、接听/拒接、静音、挂断、锁屏和通话胶囊。后台来电还要求先开通 Push Kit；具体场景权限需逐项声明。
- `[解释]` Call Service Kit 不替应用提供完整音视频信令和媒体后端。应用仍需处理呼叫 ID、对端身份、响铃、接通、媒体建立、挂断原因、多路来电和服务端状态。
- `[解释]` 生命周期必须是明确状态机，例如 Incoming/Outgoing、Ringing、Connecting、Connected、Ended/Failed。验证 Push 延迟、重复来电、另一设备接听、应用被杀、锁屏、权限拒绝、网络切换和媒体失败。
- `[项目适配]` 当前项目没有通话服务、Push、媒体会话或后台信令，不得仅画一个来电页面就宣称接入 Call Service Kit。

### 3.7 Cloud Foundation Kit（67 页）

- `[官方事实]` 提供按需云函数、云数据库、云存储和预加载，并支持 DevEco Studio 端云一体化开发。各服务需要单独开通；云资源涉及认证、权限和按量计费。
- `[解释]` 它是远端基础设施，不是本地 repository 的同义词。需要定义环境隔离、数据模型、访问规则、迁移、备份、配额、成本、可观测性和数据驻留。
- `[解释]` 验证冷启动、超时、并发、函数重试、数据库冲突、存储中断、鉴权失败、配额/计费上限和区域服务不可用。客户端成功提示必须基于真实云端结果或明确的离线队列状态。
- `[项目适配]` 当前没有云函数、云数据库或云存储。若作为养老机构后台，必须先设计租户隔离、健康数据安全、审计与离线策略，而不是从页面直接调用云数据库。

### 3.8 Contacts Kit（3 页）

- `[官方事实]` 当前目录重点是使用系统 picker 管理联系人。Picker 让用户主动选择目标联系人，适合减少应用对全量通讯录的访问。
- `[解释]` 应使用返回的最小字段完成当前动作，不长期缓存无关联系人。所选 API 的权限、返回字段和 URI 生命周期仍需以当前参考为准。
- `[解释]` 验证用户取消、未选择、联系人被删除/修改、返回字段为空、页面重建和大字体/读屏。不要把 picker 取消当错误，也不要在取消后自动打开第二次授权。
- `[项目适配]` 当前长者紧急联系人是本地 mock 字段。导入系统联系人会改变数据来源和隐私边界，需产品批准和字段映射。

### 3.9 Enterprise Space Kit（16 页）

- `[官方事实]` 面向企业 MDM 应用管理企业数字空间、空间互传、工作空间、事件订阅和访问限制。当前指南给出的边界包括中国境内、PC/2in1、HarmonyOS 6.0 及以上、企业 MDM 发布证书/Profile 和所需权限。
- `[解释]` 这是企业受管设备能力，不是普通应用的“第二个文件夹”。必须验证企业环境、MDM 身份、空间当前状态、跨空间数据策略和后台空间可访问性。
- `[解释]` 订阅空间事件必须对称取消。验证空间切换、企业 token 失效、策略变更、文件互传被拒、工作空间删除、设备未受管和系统版本不足。
- `[项目适配]` 当前声明 phone/tablet/2in1，但不是企业 MDM 应用，也没有企业数字空间配置。不得将其列为已支持的 2in1 能力。

### 3.10 File Manager Service Kit（5 页）

- `[官方事实]` 提供删除公共目录文件到回收站、获取文件图标和解析快捷方式。当前简介标明中国境内，适用于 phone、tablet、PC/2in1；模拟器从 5.1.0(18) 起支持但与真机有差异。
- `[解释]` 文件 URI、授权和快捷方式目标都有生命周期。操作前确认用户意图，防止路径穿越、失效 URI、重复删除和把回收站操作误写成永久删除。
- `[解释]` 验证文件不存在、无写权限、公共目录不可用、快捷方式循环/目标丢失、模拟器与真机差异及大文件图标加载。
- `[项目适配]` 当前产品没有文件管理业务。养老档案导入应优先使用用户选择器和受控数据映射，不应自动扫描公共目录。

### 3.11 Game Controller Kit（5 页）

- `[官方事实]` 以 C/C++ 监听手柄上下线、按键和轴事件。当前简介标明中国境内，支持 phone、tablet、PC/2in1、TV。
- `[解释]` 它同时属于硬件输入和 Native ABI。需要保存设备 identity、处理热插拔、轴死区、按键重复、多个控制器和窗口失焦；回调注册与释放必须由同一 owner 管理。
- `[解释]` 验证设备在操作中断开、多个同型号手柄、轴漂移、按键映射差异、休眠唤醒、前后台和不支持设备。模拟输入不能替代真手柄验证。
- `[项目适配]` 当前智慧养老工作台没有游戏控制器场景，也没有 Native 模块，不应引入。

### 3.12 Game Service Kit（42 页）

- `[官方事实]` 提供基础游戏服务、场景感知和近场快传等能力，并涉及 AGC、签名、应用身份、账号区域、备案/防沉迷及部分 ACL/开放能力。具体前提取决于游戏或小游戏场景。
- `[解释]` 不能从一个子场景的权限复制到所有游戏。先选定账号、玩家、成就、场景感知或近场传输等实际能力，再核对其服务开关和设备范围。
- `[解释]` 验证未登录、账号区域不符、服务未开通、网络失败、玩家记录冲突、近场中断、后台恢复和未成年人规则。服务端玩家/成就状态不能只信客户端。
- `[项目适配]` 当前项目不是游戏，无使用理由。

### 3.13 Health Service Kit（69 页）

- `[官方事实]` 是基于华为账号和用户授权的运动健康数据开放平台。接入需申请服务、按数据类型申请读写权限、通过开发者资质审核并配置 Client ID；不同开放等级和开发者类型有不同限制。
- `[解释]` 健康数据是高敏感数据。必须做最小 scope、明确用途、撤销和删除、单位/时区/数据来源、分页/增量、去重和异常值处理。医疗结论不能直接由原始运动数据或 AI 推断代替专业判断。
- `[解释]` 验证 scope 部分授权、授权撤销、账号切换、测试用户限制、数据为空/延迟、设备来源重复、时区和单位不一致、上传失败和资格未通过。
- `[项目适配]` 当前长者生命体征和健康记录是本地 mock，不是 Health Service Kit 数据。养老机构临床/照护数据还需要独立的合法性、机构授权和业务后台设计。

### 3.14 IAP Kit（54 页）

- `[官方事实]` 用于数字商品、消耗品、非消耗品和订阅。接入涉及商户服务、商品配置、应用身份、手动签名、沙盒测试；设备/地区支持与版本相关，部分嵌入式收银台还需开放能力审批。
- `[解释]` 购买是财务状态机：创建购买、用户确认、支付结果、服务端验单、权益发放、消费/确认、退款/撤销、订阅续期与过期。客户端回调不能成为唯一发货依据。
- `[解释]` 验证取消、重复购买、待处理、网络中断、回调丢失、收银台恢复、退款、跨设备恢复、订阅续期失败和沙盒/生产配置混用。
- `[项目适配]` 当前无数字商品或订阅。养老服务费更接近真实服务/实体服务支付，不能错误使用 IAP 替代 Payment Kit 或机构账务系统。

### 3.15 Live View Kit（20 页）

- `[官方事实]` 实况窗用于在锁屏、通知中心和状态栏等关键界面持续展示有明确开始、更新和结束的实时任务。当前指南标明面向 HarmonyOS 5 及以上 phone/tablet；接入还涉及 Push 权益、数据处理位置、实况窗服务权益、联调测试和正式权限评审。
- `[解释]` 实况窗不是普通通知，也不适合天气提示、静态待办或权限状态。业务必须有稳定 task ID、开始时间、状态节点、更新节流、最终结束和过期清理。
- `[解释]` 验证 Push 丢失/乱序/重复、任务已结束仍显示、服务端状态回退、多端重复展示、应用卸载/账号切换、权限未获批和模板审核不通过。
- `[项目适配]` 当前任务与入住流程没有后台状态源、Push 或服务端 task ID，不能仅用本地定时器生成实况窗。

### 3.16 Location Kit（16 页）

- `[官方事实]` 提供设备位置、正/逆地理编码和地理围栏。当前权限指导列出精准位置、模糊位置和后台位置；后台持续定位还涉及相应长时任务。室内高精度定位、位置语义等部分能力需在 AGC 申请开放能力。
- `[解释]` 默认选择满足业务的最低精度与最短持续时间。一次定位和连续订阅是不同生命周期；连续订阅必须有明确 stop，后台定位必须有可见、合理的用户价值。
- `[解释]` 验证用户仅授予模糊位置、关闭系统定位、室内/无卫星、位置超时、旧位置、权限撤销、后台限制、围栏重复/延迟及坐标系转换。
- `[项目适配]` 当前无位置功能和权限。若为上门照护、巡访或紧急事件引入，必须先确定是否真的需要精准/后台位置及数据保留策略。

### 3.17 Map Kit（63 页）

- `[官方事实]` 提供地图组件、交互、覆盖物、POI 搜索、地理编码、路径规划、静态图、Picker、导航跳转、离线地图和计算工具。当前开发准备要求开通地图服务并正确签名；指南说明从 HarmonyOS 5.0.2(14) 起不再要求配置公钥指纹和 Client ID，但服务开关和签名仍需完成。
- `[解释]` 显示地图不一定需要设备位置；只有“我的位置”等业务才按 Location Kit 申请最小权限。中国大陆与其他区域坐标系差异、地图数据资质、离线包版本和网络缓存必须单独处理。
- `[解释]` 验证服务未开通、网络断开、地图组件销毁重建、搜索无结果、路线失败、坐标系混用、离线数据过期、覆盖物资源释放及模拟器差异。
- `[项目适配]` 当前无地图、定位、上门路线或机构分布功能。Map sample 只能作为参考，不能复制其中签名或位置权限。

### 3.18 Notification Kit（20 页）

- `[官方事实]` 提供本地通知授权、渠道、角标、发布、更新、取消、跨设备协同通知和通知设置入口。本地通知通道依赖应用进程；进程终止后的云侧离线通知应接入 Push Kit。通知数量、大小和频率存在系统规格。
- `[解释]` 通知是外部入口。内容应最小化，不在锁屏泄漏健康、身份或聊天详情；点击参数需校验，登录失效时先进入安全落地页。渠道分类和用户关闭状态应被尊重。
- `[解释]` 验证首次授权、拒绝/撤销、渠道关闭、重复 ID 更新、超规格、快速频发、应用前后台、进程终止、点击过期通知和跨设备重复。
- `[项目适配]` 当前无通知权限、渠道或深链路由。任务提醒若新增，需要真实任务源、named route 和隐私安全文案，不能由本地 mock 产生“正式照护提醒”。

### 3.19 Payment Kit（71 页）

- `[官方事实]` 面向实体商品或服务支付，并覆盖基础支付、平台合单、免密、数字人民币、通用收银台、绑卡和身份验证等场景。开发准备包括商户入网/商户号、开通服务、AppID 绑定、证书、端侧配置和云侧服务。
- `[解释]` 支付核心必须在可信服务器创建订单、保存幂等键、验签/查询最终状态并驱动履约。端侧只负责展示和拉起收银台，不持有服务端密钥，也不凭单次客户端回调确认到账。
- `[解释]` 验证取消、支付中断、结果未知、重复回调、订单过期、金额/币种不一致、证书轮换、服务端通知重放、退款和沙盒/生产隔离。
- `[项目适配]` 当前无收费、订单、商户或服务端。入住流程展示的服务类别与费用说明不是支付订单；任何收款接入都需要机构、合同、财务和审计设计。

### 3.20 PDF Kit（26 页）

- `[官方事实]` 包含 PDF 文档加载/保存、内容/批注/水印/书签/加密处理等 pdfService 能力，以及用于预览、搜索和批注的 PdfView。当前简介标明中国境内，支持 phone、tablet、PC/2in1，模拟器与真机有差异。
- `[解释]` 文件 owner 应明确 URI/文件描述符、临时副本、编辑状态、保存目标和释放时机。密码、签名和受保护文档不得通过日志或临时目录泄漏。
- `[解释]` 验证损坏/加密/超大 PDF、权限失效、磁盘不足、保存中断、页面快速切换、组件销毁和搜索/批注一致性。
- `[项目适配]` 若用于养老报告或知情同意书，必须先确定文档来源、签署/审计要求和敏感文件清理；当前没有 PDF 业务。

### 3.21 Preview Kit（10 页）

- `[官方事实]` 提供图片、音视频、文本、HTML、Office 等文件预览，以及 C/C++ 文件打开/缓存加速；Office 预览由外部能力支撑。目录中“文件打开加速状态感知”已标记废弃。
- `[解释]` 预览不等于应用拥有文件。应保留用户授权 URI 的有效期，按需创建临时资源并及时清理；不要继续采用已废弃状态感知路径。
- `[解释]` 验证格式不支持、文件损坏、URI 授权失效、WPS/外部能力不可用、大文件首开、缓存过期、Native 缓存清理和“使用其他应用打开”返回。
- `[项目适配]` 当前无附件/档案预览。若增加，优先建立受控附件模型和访问审计，避免把机构文件复制到公共目录。

### 3.22 Push Kit（48 页）

- `[官方事实]` 建立云端到终端的系统级推送通道，即使应用进程不存在也可下发消息。开发准备包含接入规范、开通服务、场景化消息权益和 Push Token。Token 可变化，需在应用服务器更新，且不得用于跟踪用户。
- `[解释]` Push Token 是设备上某应用实例的投递地址，不是用户 ID。服务器需维护 token 版本、账号/租户绑定、注销与失效；payload 最小化并由应用登录态再次鉴权。
- `[解释]` 验证 token 刷新、注销后旧 token、重复/乱序、离线缓存、通知权限关闭、应用升级/重装、设备地区变化、服务限流、点击过期消息和服务端重试。
- `[项目适配]` 当前没有 Push、后端或通知落地路由。不得在本地消息数组上增加“Push 已接入”标签。

### 3.23 Reader Kit（16 页）

- `[官方事实]` 提供 txt、epub、mobi、azw、azw3 等电子书解析、富文本排版和阅读页组件；阅读交互包含 Native/OpenGL 渲染能力。
- `[解释]` 解析器、排版结果、字体、快照和 Native 渲染资源都需要 owner。对不可信电子书限制文件大小、嵌套资源、路径和 CSS/HTML 内容，防止资源耗尽和越界访问。
- `[解释]` 验证损坏/不支持格式、超大章节、自定义字体丢失、旋转/窗口 resize、进度恢复、快速翻页、后台恢复和 Native 资源释放。
- `[项目适配]` 当前不是阅读器。养老知识库如果只展示短文档，不应因官方有 Reader Kit 就引入完整电子书引擎。

### 3.24 Scenario Fusion Kit（44 页）

- `[官方事实]` 基于 ArkUI 提供场景化 Button、Input、API、路径转换和智能填充等跨子系统组件。不同场景可能需要对应权限；模拟器和真机支持能力有差异。
- `[解释]` “一行代码启用”不代表免除业务校验。系统组件返回的数据仍需验证，智能填充应由用户明确触发并允许查看/更改，权限设置按钮不能替代首次授权流程。
- `[解释]` 验证功能在目标设备/API 是否支持、用户拒绝、设置页返回、填充数据为空/过期、焦点/键盘/读屏和组件销毁。不要用场景化组件制造虚假的完成状态。
- `[项目适配]` 当前 HDS/ArkUI UI 已有自定义输入与设置流程。引入前要证明它改善具体场景，并保持 ArkUI V2/HDS 代际一致。

### 3.25 Screen Time Guard Kit（29 页）

- `[官方事实]` 提供用户授权、应用选择、守护策略、应用访问限制等能力；当前支持 phone/tablet。核心管理权限是受限 ACL，需要在 AGC 申请，并重新生成包含该权限的 Profile 后手动签名。
- `[解释]` 这是高后果设备管控能力。策略 owner 必须记录授权主体、管控对象、起止/总时长、启停和撤销，且不能限制系统允许清单、管控应用自身等不允许范围。
- `[解释]` 验证 ACL 未获批、用户取消授权、策略冲突、设备时间变化、应用 token 失效、管控应用卸载、系统重启和紧急解除路径。
- `[项目适配]` 当前养老工作台不是家长控制/设备管控应用，没有申请理由。不得为了“老人防沉迷”擅自接入受限 ACL。

### 3.26 Share Kit（44 页）

- `[官方事实]` 提供文本、图片、视频等跨应用、跨端分享，包含系统分享、碰一碰和隔空传送。目标应用需在配置中声明可处理的数据/组件；跨端分享还依赖系统推荐、设备和目标能力。
- `[解释]` 分享由用户确认，取消不是失败。仅分享用户选择的最小内容；临时 URI 权限、文件有效期和接收方不可信边界必须明确。
- `[解释]` 验证没有目标应用、用户取消、目标应用崩溃、设备离线、跨端中断、文件过大/权限失效、重复分享和敏感信息预览泄漏。
- `[项目适配]` 当前没有分享入口。长者健康/身份资料属于高敏感数据，不能把通用系统分享作为默认导出方式。

### 3.27 Wallet Kit（80 页）

- `[官方事实]` 覆盖数字车钥匙、交通卡、园区卡、会员卡、酒店房卡、出行凭证、门票和通用凭证，是芯-端-云协同能力。不同产品线分别需要企业项目、服务申请、服务号、公钥/服务器回调、发行方资料和联调。
- `[解释]` Wallet Kit 不是通用键值存储。每类凭证都有发行、添加、激活、更新、使用、挂失/删除和服务端回调生命周期；密钥和 Client Secret 只能留在安全服务端。
- `[解释]` 验证服务未审批、设备/NFC/区域不支持、账号切换、重复发卡、回调重放、卡状态不一致、离线使用、设备丢失和证书/公钥轮换。
- `[项目适配]` 当前无门禁卡、会员卡或钱包服务。养老院门禁若要接入，需要硬件、发行方、权限、服务端和机构安全方案，不能只加一张 UI 卡片。

### 3.28 Weather Service Kit（9 页）

- `[官方事实]` 提供天气预报、分钟级降水、预警、生活指数、天文和潮汐等云数据。当前指南明确写明：仅面向系统应用开放，暂不对外开放；支持多类设备。若使用当前位置，还需通过 Location Kit 获取经纬度并遵循其权限。
- `[解释]` 普通三方应用不能因为能看到文档就假定可接入。若未来开放，也要处理位置精度、单位、时区、城市/POI、缓存时效、网络和预警来源。
- `[解释]` 失败验证包括开放范围不满足、服务未开通、Profile 鉴权失败、网络失败、位置为空、天气数据过期和地区数据差异。
- `[项目适配]` `KangxiaobanAI` 是普通应用原型，当前不得规划直接使用此 Kit；如需天气，应另选经批准的数据源并明确服务条款。

---

## 4. AI：10 个直接 Kit 完整表

| Kit | 页数 | 主类型 | 代表官方入口 |
| --- | ---: | --- | --- |
| Agent Framework Kit（智能体框架服务） | 4 | 系统智能体入口 + A2A | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/harmony-agent-framework-kit-guide) |
| CANN Kit（CANN异构计算框架服务） | 848 | 端侧异构推理/训练/算子/工具链 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cann-kit-guide) |
| Core Speech Kit（基础语音服务） | 5 | 系统基础语音 AI 服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-speech-kit-guide) |
| Core Vision Kit（基础视觉服务） | 11 | 系统基础视觉 AI 服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-vision-kit-guide) |
| Intents Kit（意图框架服务） | 51 | 系统智慧分发 + AGC 上架配置 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/intents-kit-guide) |
| MindSpore Lite Kit（昇思推理框架服务） | 11 | 开发者模型端侧推理/训练 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/mindspore-lite-kit) |
| Natural Language Kit（自然语言理解服务） | 4 | 系统文本语义能力 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/natural-language-kit-guide) |
| Neural Network Runtime Kit（Neural Network运行时服务） | 3 | Native 跨芯片推理运行时 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/neural-network-runtime-kit) |
| Speech Kit（场景化语音服务） | 4 | 场景化语音 UI 控件 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/speech-kit-guide) |
| Vision Kit（场景化视觉服务） | 7 | 场景化视觉 UI/交互服务 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/vision-kit-guide) |

`[解释]` CANN Kit 的 848 页包含大量模型转换、端侧部署、单算子、AscendC、LLM 和接口/算子说明，因此 AI 栏目总页数恰好也是 948。数量大不代表每个应用都应选择 CANN；先根据模型来源、目标硬件、端侧隐私、性能和维护能力选择抽象层。

### 4.1 Agent Framework Kit（4 页）

- `[官方事实]` 提供 Function 组件拉起已在小艺开放平台上线的智能体，以及通过 AgentAbilityExtension 实现智能体间 A2A 任务、消息和产物通信。当前简介标明适用于中国境内。
- `[解释]` 它是系统智能体发现/协作框架，不等于在应用里嵌入任意大模型。必须明确智能体身份、能力描述、请求参数、授权、任务 ID、产物类型和跨应用信任。
- `[解释]` 生命周期包括发现/拉起、创建任务、交换消息、生成产物、取消/结束和 Extension 销毁。验证目标智能体未安装/未上线、A2A 对端超时、重复任务、用户取消、产物不可信和对端权限不足。
- `[项目适配]` 当前 AI 页面是本地固定文本，没有小艺智能体、Function、AgentAbilityExtension 或 A2A。不得把现有 `AiChatPage` 宣称为 Agent Framework Kit 客户端。

### 4.2 CANN Kit（848 页）

- `[官方事实]` 面向 Kirin 平台在端侧统一调度 NPU/CPU，覆盖模型优化、转换、端侧部署、单算子、AscendC 和 LLM 能力。开发准备涉及模型转换工具、受支持模型格式和转换环境；模型需转换为目标离线格式后部署。
- `[解释]` CANN 是模型与硬件工程，不是 UI Kit。接入前记录原始框架/算子、输入输出 shape/data type、精度基线、转换工具版本、目标芯片、内存/功耗预算和 CPU fallback。
- `[解释]` 生命周期是加载模型/算子、分配输入输出、执行、同步结果、释放 buffer/context/model。验证模型转换失败、算子不支持、动态 shape、NPU 不可用、内存不足、并发推理、热切换、精度漂移、长时间功耗和异常释放。
- `[项目适配]` 当前没有模型文件、CANN、NPU 推理或 Native AI 管线。为养老 AI 引入前，先证明业务模型、安全评估和设备硬件需求；固定模板回复不需要 CANN。

### 4.3 Core Speech Kit（5 页）

- `[官方事实]` 提供文本转语音和语音识别，支持 phone、tablet、PC/2in1，当前简介有地区、语言、时长和模拟器版本限制；个人数据说明要求开发者告知用户并取得合法基础。
- `[解释]` 基础语音服务由系统提供，不等于开发者自带模型，也不能仅从“云端不存储”推断整个处理链完全离线。实时麦克风输入需逐接口核对录音权限和音频格式。
- `[解释]` 生命周期包括初始化、开始、流式输入/回调、暂停/取消、最终结果和释放。验证无麦克风权限、音频焦点冲突、无声/噪声、网络或系统服务异常、超时、部分/最终结果乱序、页面关闭后回调和不支持语言。
- `[项目适配]` 当前没有 TTS/ASR。长者场景若新增语音，必须覆盖听力/口音、误识别、隐私和人工确认，不能让识别文本直接触发照护操作。

### 4.4 Core Vision Kit（11 页）

- `[官方事实]` 提供 OCR、人脸检测/比对、主体分割、多目标识别、骨骼点、超分和文本搜图等基础视觉能力。处理对象是应用提供的图片；个人数据说明要求开发者承担用户告知与数据主体权利。
- `[解释]` 基础视觉输出是置信度和结构化结果，不是身份、诊断或安全事实。输入来源若为相机/相册，需分别核对权限、Picker 和图像 URI 生命周期。
- `[解释]` 生命周期包括准备图像、初始化能力、执行、解析结果、取消/销毁。验证旋转、色彩/像素格式、过大/过小图片、无人脸/多人脸、遮挡、低置信度、并发、页面退出、内存峰值和结果误用。
- `[项目适配]` 当前无 OCR、人脸或图像分析。养老健康判断、身份核验等高后果场景不得只依赖单次视觉结果。

### 4.5 Intents Kit（51 页）

- `[官方事实]` 建立 HarmonyOS 意图标准，将应用/元服务功能分发到小艺对话、搜索和建议等系统入口，覆盖习惯/事件/位置推荐、技能调用和本地搜索。接入需在 AGC 申请能力并完成意图 Schema、上架配置等工作；当前支持设备和地区有明确限制。
- `[解释]` 意图调用和意图共享不是普通 deep link。共享内容必须最小化、可撤回、不过期；被系统调用时仍需验证参数、登录、租户、权限和业务幂等。
- `[解释]` 验证能力未获批、Schema/路由不匹配、系统未发现、用户数据过期、重复调用、未登录、目标内容删除、位置/事件权限不足和上架配置漂移。
- `[项目适配]` 当前没有意图定义、共享、系统搜索或技能调用。新增入口不得绕开登录和机构权限。

### 4.6 MindSpore Lite Kit（11 页）

- `[官方事实]` 是 HarmonyOS 内置轻量化 AI 引擎，支持多设备与多处理器；Wearable 当前仅支持 CPU 推理。第三方模型需按支持列表转换为 `.ms` 等目标格式，再在 ArkTS/C++ 侧执行推理或端侧训练。
- `[解释]` 它适合开发者自有模型的端侧部署。接入清单包括模型许可证、转换版本、算子支持、量化/精度、ABI、输入预处理、线程数、delegate/后端选择、内存和热管理。
- `[解释]` 生命周期是加载 model/context、创建 session、分配 tensor、推理、读取结果、释放。验证模型损坏、算子不支持、NPU fallback、不同设备精度/性能、并发、进程后台、内存泄漏和模型升级兼容。
- `[项目适配]` 当前没有 `.ms` 模型或推理 runtime。若未来做端侧风险检测，必须保留确定性安全规则、模型版本和人工确认。

### 4.7 Natural Language Kit（4 页）

- `[官方事实]` 当前提供分词和实体抽取，支持特定设备、地区、语言和实体类型。同一用户并发调用同一特性存在限制，可能返回系统繁忙或排队。
- `[解释]` 它是系统文本语义能力，不等于聊天模型。执行位置、数据处理和具体并发/长度限制要按所用特性核对；实体抽取结果必须视为候选值。
- `[解释]` 验证空文本、超长文本、不支持语言、同用户并发、系统繁忙、混合语言、敏感实体、误抽取和页面关闭后结果。重要日期、手机号或证件号必须让用户确认。
- `[项目适配]` 当前本地 AI 模板没有 NLP Kit。若用于从交班文本抽取实体，应先定义字段、置信度、纠错和数据保留。

### 4.8 Neural Network Runtime Kit（3 页）

- `[官方事实]` NNRt 是面向 AI 推理框架和高级应用开发者的 Native 跨芯片运行时，负责在线构图/离线模型、模型编译、执行和共享内存管理。在线构图更通用但首次加载较慢；硬件离线模型更快但绑定特定硬件。
- `[解释]` 这是低层 Native 接口，不是普通 ArkUI 业务首选。需要掌握模型图、硬件驱动、tensor、共享内存、ABI、同步和线程安全；优先评估 MindSpore Lite 是否已经满足需求。
- `[解释]` 验证无兼容 AI 硬件、模型编译失败、shape/data type 错误、共享内存不足、首次加载、并发 executor、设备差异、driver 错误和所有 Native 资源释放。
- `[项目适配]` 当前无 Native 和 AI runtime，不应直接从 NNRt 起步。

### 4.9 Speech Kit（4 页）

- `[官方事实]` 提供朗读控件和 AI 字幕控件，属于场景化语音服务。当前简介列出 phone/tablet/PC/2in1、地区、PCM/采样率和部分机型不支持等边界。
- `[解释]` 场景化控件封装了 UI 与基础能力，但应用仍需管理内容来源、音频流、权限、可访问性、取消和失败 UI。不能把“控件已显示”当成语音服务可用。
- `[解释]` 验证不支持机型、初始化失败、音频格式不符、用户中止、前后台、耳机/音频焦点、字幕延迟、长内容、页面销毁和 Reduce Motion/读屏。
- `[项目适配]` 当前无朗读或字幕。养老场景可能有价值，但必须先在真实目标设备和长者可用性场景验证。

### 4.10 Vision Kit（7 页）

- `[官方事实]` 提供人脸活体、卡证识别、文档扫描和 AI 识图等场景化能力；当前有地区、设备、横屏/分屏、证件种类和图像质量限制，部分能力涉及试用/计费政策，需在接入时重新核对。
- `[解释]` 它处理人脸、证件和视频等高敏感数据。必须有明确用途、告知同意、最小保存、失败/取消、攻击防护和人工复核；活体通过不等于业务身份已授权。
- `[解释]` 验证相机/相册拒绝、横屏/分屏不支持、弱光/反光/遮挡、证件不支持、用户退出、活体攻击、网络/服务失败、重复识别、组件销毁和数据清理。
- `[项目适配]` 当前登录和入住没有真实身份核验。即便接入 Vision Kit，也需要机构业务身份、授权与后台审计，不能用人脸结果替代 RBAC。

---

## 5. 一次开发，多端部署

### 5.1 当前官网路径事实

- `[官方事实]` 当前“开发”左侧树只有 [一次开发，多端部署文档路径调整](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/multi-device-overview-path-change) 这 1 个正文节点。
- `[官方事实]` 路径迁移到 [最佳实践 > 多设备开发 > 一次开发，多端部署](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-overview)。迁移页说明优化后的内容从体验设计、页面开发和功能开发等方面提供端到端指导。

### 5.2 “一次开发”不等于“一套固定界面”

`[解释]` 正确目标是共享业务与设计语言，并针对设备能力、窗口、输入和使用距离做适配：

| 维度 | 必须确认 | 典型失败 |
| --- | --- | --- |
| 交付 | product、module、HAP/HAR/HSP、deviceTypes | 只声明设备但对应 product/module 不可安装 |
| 窗口 | 最小/最大/自由窗口、旋转、折叠、分屏 | 用设备名称代替实际窗口宽度 |
| 布局 | 断点、Grid、List/Detail、信息密度、safe area | 平板只是放大的手机；PC 空白或过宽 |
| 输入 | 触摸、鼠标、键盘、手势、遥控、焦点/hover | 只有 onClick，无键盘/焦点路径 |
| 导航 | phone tabs、wide Navigation/sidebar、返回 | resize 后导航栈丢失或进入无出口页面 |
| 资源 | 尺寸、密度、方向、语言、字体、媒体能力 | 固定像素、硬编码系统栏、图片模糊 |
| 状态 | 页面/feature/app 状态，窗口重建和进程恢复 | 断点切换重新创建组件导致草稿丢失 |
| 功能 | 每个 Kit 的设备、版本、权限、SystemCapability | UI 有入口，但目标设备根本不支持 API |
| 性能 | 启动、预加载、列表、媒体、内存/能耗 | 为所有端预加载所有页面和模型 |
| 无障碍 | 大字体、读屏、对比度、减少动效 | 视觉适配完成但不可操作 |

### 5.3 多端实现协议

1. `[解释]` 先定义共同 domain/use case，再定义各设备 shell；不要在每个页面复制业务规则。
2. `[解释]` 以窗口和输入能力表达布局需求，设备类型只作为能力边界之一。
3. `[解释]` 功能不支持时提供真实降级或隐藏入口，不能展示一个永远失败的按钮。
4. `[解释]` 把系统栏、导航指示条、键盘、cutout/fold 作为实时 inset，不用固定高度。
5. `[解释]` resize 时保持用户任务和导航上下文；如果必须重建，先定义草稿恢复。
6. `[解释]` 同一业务在 phone/tablet/2in1/TV/wearable 上可能需要不同交互，不强求像素一致。
7. `[解释]` 对每个声明设备分别构建和真机验证；一个 product 成功不能代表所有端。

### 5.4 多端最小验证矩阵

```text
设备/系统/API：
窗口：竖屏、横屏、分屏、自由窗口、最小/最大宽度
输入：触摸、鼠标、键盘、遥控/手势（若适用）
主题与内容：深浅色、大字体、长文本、多语言
导航：冷启动、返回、深入口、resize 前后状态
权限/Kit：支持、拒绝、不支持、被撤销
性能：冷启动、首屏、列表滚动、转场、内存
```

`[项目适配]` `KangxiaobanAI` 的 `deviceTypes` 是 phone/tablet/2in1，核心存在 phone tabs 与宽屏 workspace，但这只证明源码和配置分支。未给出当次真实设备、窗口和输入证据时，不能称为“三端已验证”。手机医师/管理员仍是 WIP，phone 横屏也不应因为变宽自动冒充 tablet workspace。

---

## 6. 自由流转：跨端迁移与多端协同

### 6.1 当前官网路径事实

- `[官方事实]` 当前“开发”左侧树只有 [自由流转文档路径调整](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hopping-path-change) 这 1 个正文节点。
- `[官方事实]` 路径迁移到 [最佳实践 > 多设备开发 > 自由流转](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-hopping)。迁移页明确提到两类实践：跨端迁移和多端协同。

### 6.2 两类能力不能混为一谈

| 类型 | 目标 | 状态特点 | 关键失败 |
| --- | --- | --- | --- |
| 跨端迁移 | 将当前任务从源设备转移到目标设备继续 | 通常有单一当前 owner，需要移交上下文 | 目标不支持、迁移中断、源/目标同时继续、上下文过期 |
| 多端协同 | 多设备同时参与同一任务，各承担不同角色 | 多 owner/多通道，需要同步、冲突和断连处理 | 设备离线、消息乱序、角色冲突、重复执行、部分设备失败 |

`[解释]` 响应式 UI 是“同一设备上适配不同窗口”，自由流转是“多个设备之间迁移或协作”。声明 `deviceTypes`、共享账号、局域网可见或存在分布式样例，都不能证明产品已接入自由流转。

### 6.3 自由流转生命周期

```text
Idle
  -> Discover/Select target
  -> Authenticate/Authorize peer
  -> Negotiate capability and version
  -> Prepare transferable/collaborative state
  -> Transfer or Start collaboration
  -> Confirm ownership/session
  -> Active
  -> Pause/Reconnect/Conflict resolution
  -> Finish/Cancel/Disconnect
  -> Revoke temporary grants and clean resources
```

具体 API、Ability、权限和数据通道必须按迁移后的官方实践与当前 SDK 核验，本章不假设一个通用接口。

### 6.4 迁移状态契约

`[解释]` 只迁移继续任务所需的最小状态：

- 稳定业务 ID，而不是整个 UI 对象图；
- 当前步骤、筛选、草稿和必要滚动/播放位置；
- 数据版本、过期时间和 schema version；
- 用户、租户、角色和目标设备重新授权结果；
- 尚未确认的操作和幂等键；
- 不可迁移资源的重建策略，例如窗口、相机、播放器、Native handle。

敏感数据不能因为设备属于同一用户就无条件传输。目标设备仍需满足账号、机构、角色、设备信任、屏幕隐私和本地存储政策。

### 6.5 多端协同契约

`[解释]` 必须定义：

- 会话 ID、设备 ID、参与角色和主/从或对等模型；
- 消息序号、确认、重放、去重和断线重连；
- 哪个设备能发起高后果动作；
- 共享状态的冲突与最终一致性；
- 一台设备离开时由谁接管；
- 临时权限、通道、监听和缓存的结束清理。

### 6.6 自由流转失败验证

- [ ] 源/目标系统或应用版本不一致。
- [ ] 目标设备没有所需 Kit/SystemCapability/硬件。
- [ ] 目标设备锁定、账号不同、租户/角色不允许。
- [ ] 发现后设备离线，传输进行到一半中断。
- [ ] 迁移确认丢失，源端和目标端同时认为自己是 owner。
- [ ] 相同消息重复、乱序、过期或重放。
- [ ] 敏感数据在目标端残留，退出/断连后未清理。
- [ ] 协同期间网络切换、进程重启、窗口重建。
- [ ] 用户主动取消或拒绝目标设备。

`[项目适配]` 当前产品没有分布式设备发现、迁移、协同会话、跨设备数据服务或相应权限。phone/tablet/2in1 是 UI 交付声明，不是自由流转。养老/健康数据若未来跨端，还需机构设备信任、审计、最小数据和离线撤销方案。

---

## 7. NDK 开发：142 页完整结构

### 7.1 直属主题与页面数

| NDK 直属主题 | 页数 | 代表官方入口 | 主要内容 |
| --- | ---: | --- | --- |
| NDK开发导读 | 1 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ndk-development-overview) | 适用场景、前置知识、目录和常用模块 |
| 创建NDK工程 | 1 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/create-with-ndk) | DevEco Studio Native C++ 工程与目录 |
| 构建NDK工程 | 7 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/build-with-ndk) | CMake/DevEco/命令行、预构建库、毕昇、动态库 |
| 代码开发 | 116 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/coding) | 标准库、Node-API、JSVM、Longque-JS、OpenMP、资源/包管理 |
| 编译工具链 | 8 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/build-toolchain) | GN、CMake、Make、Configure、lycium、线程与跨语言参数 |
| 调试和性能分析 | 4 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/debugging-profiling) | 内存错误检测和 LLDB |
| 硬件兼容性 | 5 | [入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hardware-compatibility) | HarmonyOS ABI、CPU 特性和 Neon |
| 合计 | 142 |  |  |

### 7.2 NDK 适用与不适用

- `[官方事实]` HarmonyOS NDK 是 Native API、编译脚本和工具链的集合，只覆盖部分底层能力，不提供 ArkTS/JS API 的完整能力。
- `[官方事实]` 官方导读建议在性能敏感计算或需要 CPU 特性专项优化的场景使用；对于希望尽可能广泛兼容 HarmonyOS 设备的应用，不建议无必要引入 NDK。
- `[解释]` 先测量再下沉 Native。JSON 映射、普通表单、网络编排、页面状态和数据库 CRUD 通常不因改成 C++ 自动更快，反而增加 ABI、内存安全、崩溃和发布成本。

### 7.3 NDK 接入前证据卡

```text
必须下沉 Native 的瓶颈及测量证据：
ArkTS/系统 Kit 无法满足的原因：
Native API/库及 @since/SystemCapability：
目标设备与 ABI：
CPU/NPU/GPU 特性和 fallback：
CMake/GN/Make/Configure 入口：
三方库许可证、源码和供应链来源：
预构建库各 ABI 产物：
ArkTS <-> Native 边界：Node-API / JSVM / 其他
线程模型：
内存/handle owner：
错误转换与崩溃隔离：
debug/release/真机/性能验证：
```

### 7.4 工程、构建与包

`[解释]` NDK 模块至少要核对：

- `src/main/cpp`、CMake/其他构建脚本和模块 build profile 的真实关系；
- 动态/静态库是否被目标 HAP/HAR 正确打包；
- 每个目标 ABI 是否有匹配产物，不能把主机库或另一个架构库打包进去；
- include、compile definition、visibility、C++ runtime 和链接顺序；
- debug/release 优化、符号、strip、混淆与崩溃符号化；
- 三方库的版本、补丁、许可证、漏洞和可重复构建；
- Windows/macOS/Linux 主机构建差异与交叉编译工具链路径。

“本机 CMake 成功”不能证明 DevEco/Hvigor 最终 HAP 已包含正确库；必须检查目标产物和真机加载。

### 7.5 ArkTS/JS 与 C/C++ 跨语言边界

`[官方事实]` NDK 目录包含 Node-API、JSVM-API 和 Longque-JS-API 等跨语言开发指导。

`[解释]` 边界设计原则：

1. 使用窄、稳定、显式类型的接口，不把巨大 ArkTS 对象图传入 Native；
2. 明确字符串编码、数组/buffer 长度、可空性、所有权和对齐；
3. Native 不长期持有无生命周期策略的 JS/ArkTS 对象引用；
4. 环境销毁、模块卸载和回调取消时释放 reference、callback 和 handle；
5. Native 子线程不能直接操作 ArkUI；按官方线程通信路径回到允许的线程；
6. C++ 异常、errno/状态码和 Native 错误要转换成稳定的 ArkTS 错误模型；
7. 同一异步操作只完成一次，处理取消、超时和页面销毁后的回调；
8. 日志不输出原始内存、密钥、健康数据或完整文件内容。

### 7.6 Native 生命周期与资源所有权

| 资源 | owner 必须回答的问题 |
| --- | --- |
| Native addon/module | 何时初始化，环境销毁/热重载时怎样清理 |
| JS reference/callback | 谁创建、线程在哪、何时 delete/release |
| malloc/new/buffer | 谁分配、谁释放、异常/早退是否覆盖 |
| fd/socket/map | close 时机，线程中断和进程后台行为 |
| model/context/tensor | shape、buffer、同步、并发和释放顺序 |
| player/codec/window/surface | 生命周期 owner、前后台、窗口销毁 |
| Worker/OpenMP/thread | join/cancel、回调、进程退出和竞争条件 |
| prebuilt library global state | 多实例、可重入、卸载和静态析构 |

具体释放函数必须从当前 Native API 参考确认，不能根据其他平台命名猜测。

### 7.7 ABI、CPU 特性与 Neon

`[官方事实]` NDK 硬件兼容章节专门覆盖 HarmonyOS ABI、CPU 特性和 Neon 指令扩展。

`[解释]`

- 编译时优化不能假定所有目标设备拥有同一 CPU 特性；
- 如使用特定指令，提供运行时能力判断或通用实现 fallback；
- 结构体布局、对齐、整数宽度、枚举和 C++ ABI 不能跨边界凭主机结果推断；
- 预构建库必须与目标 ABI、API 和 C++ runtime 匹配；
- Native 文件格式、序列化和网络协议使用固定宽度类型与显式字节序；
- 真机矩阵至少覆盖实际发布的芯片/ABI，不用模拟器替代指令与性能验证。

### 7.8 Native 调试和性能

- `[官方事实]` 当前 NDK 目录包含 C/C++ 内存错误检测和 LLDB 调试；工具目录另有 ASan/HWASan/TSan、日志和 Profiler 指导。
- `[解释]` 崩溃应保存设备/系统、ABI、build ID、符号文件、Native backtrace 和触发输入。没有符号化堆栈时，不根据最后一个 ArkTS 调用点猜根因。
- `[解释]` 性能优化需记录 ArkTS 基线、Native 后指标、跨语言调用次数、拷贝字节数、线程/CPU、内存和能耗。一次调用更快但因频繁跨语言或拷贝导致整体变慢，也是不合格。
- `[解释]` 压力验证包括并发、取消、重复初始化、进程前后台、低内存、大输入、损坏输入、线程竞争和连续运行。

### 7.9 NDK 禁止事项

- 禁止因“C++ 更专业”而无测量下沉业务代码。
- 禁止只为调用一个简单系统能力创建 Native 桥，而该能力已有 ArkTS API。
- 禁止把桌面 Linux 库直接当 HarmonyOS 可用库。
- 禁止只打包一个 ABI 并声称全设备兼容。
- 禁止跨线程直接操作 ArkUI。
- 禁止把 JS/ArkTS 对象指针长期缓存而无环境清理。
- 禁止忽略输入长度、整数溢出、路径、文件和不可信模型。
- 禁止在 Native 日志/崩溃附件中泄漏敏感数据。

`[项目适配]` 当前 `KangxiaobanAI` 生产模块没有 `cpp`、CMake、Native 依赖或 ArkTS-Native 桥证据。现有 UI、mock 数据、导航和状态问题都不构成引入 NDK 的理由。只有出现可重复测量、ArkTS/系统 Kit 无法满足的瓶颈后，才建立独立 Native ownership boundary。

---

## 8. 常见能力选择：不要因为名称相近就选错 Kit

### 8.1 Notification、Push 与 Live View

| 需求 | 优先能力 | 原因 |
| --- | --- | --- |
| 应用进程运行时发布本地通知 | Notification Kit | 本地系统通知通道 |
| 应用进程不存在时由云端触达 | Push Kit | 云到端系统长连接和 token |
| 有开始、动态更新、明确结束的进行中任务 | Live View Kit | 关键界面持续任务状态；通常还依赖 Push/权益 |

三者可以组合，但不能互相代替。Live View 不是把普通通知换一个卡片样式，Push 收到也不代表业务状态正确，Notification 点击也需要安全路由。

### 8.2 IAP、Payment 与 AppGallery 数字商品

| 交易对象 | 优先能力 | 验证重点 |
| --- | --- | --- |
| 应用内数字商品/订阅 | IAP Kit | 商品配置、购买恢复、订阅、服务端验单 |
| 实体商品或真实服务 | Payment Kit | 商户订单、证书、云侧查询、履约和退款 |
| 应用市场分发/市场数字商品与生态服务 | AppGallery Kit 对应子服务 | 先确认具体市场能力与服务开关 |

`[解释]` “都是支付”不能作为选择依据。商品性质、商户关系、上架规范、服务器和结算责任决定能力边界。

### 8.3 Location、Map 与 Weather

- Location Kit 回答设备在哪里或围栏是否触发；
- Map Kit 负责地图显示、搜索、路线、静态图和 Picker；
- Weather Service Kit 根据位置等输入返回天气，但当前只向系统应用开放。

显示地图不自动需要当前位置；获取当前位置不自动需要地图；普通三方应用也不能因为已有 Location/Map 就调用 Weather Service Kit。

### 8.4 Core Speech 与 Speech

- Core Speech Kit 是 TTS/ASR 基础能力，适合应用自行设计语音流程；
- Speech Kit 是朗读/AI 字幕等场景化控件，包含系统交互封装。

选择基础 API 还是场景控件取决于 UI 控制、音频管线、设备限制和可访问性，而不是哪个名字更短。

### 8.5 Core Vision 与 Vision

- Core Vision Kit 提供 OCR、人脸、分割、目标、骨骼点等基础结果；
- Vision Kit 提供活体、卡证、扫描、AI 识图等完整场景交互。

场景控件降低交互开发成本，但会带来更明确的设备、方向、证件、计费和敏感数据边界；基础 API 则要求应用自己建立相机/选图、引导和复核。

### 8.6 MindSpore Lite、CANN 与 NNRt

| 层级 | 适用对象 | 代价 |
| --- | --- | --- |
| MindSpore Lite | 一般端侧模型部署、跨设备/多后端推理 | 模型转换、算子和性能适配 |
| CANN | Kirin/NPU 深度优化、算子、训练、LLM 与异构工具链 | 平台/模型/算子工程复杂度高 |
| NNRt | 推理框架或需要直接对接 AI 硬件的高级 Native 开发者 | 最低层 ABI、图、共享内存和硬件责任 |

默认从满足需求的最高抽象层开始。没有测量和硬件需求，不应直接选择 NNRt 或自定义算子。

### 8.7 多端部署、Share 与自由流转

- 多端部署：同一产品在不同设备/窗口适配；
- Share Kit：用户把内容分享给应用或设备；
- 自由流转：任务跨端迁移或多个设备协同执行。

系统分享成功只证明内容交给目标，不代表协同会话；响应式布局也不代表任务可以迁移。

---

## 9. Codex / Claude 接入检查表

### 9.1 所有 Kit 的共同入口检查

- [ ] 已确认真实业务目标，不从 Kit 名称反推需求。
- [ ] 已从当前 profile 读取 target/compatible SDK 和设备声明。
- [ ] 已核对 Kit/import、实际成员/重载、参数、返回、错误。
- [ ] 已核对成员和参数/枚举的 `@since`，不是只看类版本。
- [ ] 已核对 `SystemCapability`、地区、设备、三方/系统应用开放范围。
- [ ] 已确认是本地系统服务、AGC/云、模型框架、分布式还是 Native。
- [ ] 已确认权限、ACL/Profile、服务开关、账号、商户、资质和指纹/签名前提。
- [ ] 已定义 loading、取消、拒绝、超时、离线、不支持、重试和最终成功。
- [ ] 已列出监听、token、session、buffer、文件、模型、Native handle 的 owner 与 teardown。
- [ ] 已设计真机/真实账号/真实服务验证，模拟器不冒充全部设备。

### 9.2 AGC/云服务专项

- [ ] 项目、应用、Client/App ID 和服务环境对应正确。
- [ ] 服务开关、权益、资质、企业/商户身份已真实获批。
- [ ] 调试与发布签名、Profile、公钥指纹按当前服务要求配置；敏感值不进源码或报告。
- [ ] 测试/沙盒/生产环境隔离，服务端密钥只在安全后端。
- [ ] 定义客户端身份、用户身份、租户、角色和服务端授权。
- [ ] 定义超时、重试、幂等、乱序、回调验签、配额和成本上限。
- [ ] 服务端最终状态可查询，不以单次客户端回调作为财务/投递最终凭据。
- [ ] 用户注销、token 轮换、证书轮换、服务撤销和数据删除有流程。

### 9.3 系统数据、权限和高敏感能力专项

- [ ] 使用 Picker/系统控件是否能避免广泛权限。
- [ ] 权限只在用户触发具体动作时申请，拒绝后无关功能仍可用。
- [ ] 每次敏感操作前重新检查，因为权限可能撤销。
- [ ] 位置、联系人、健康、人脸、证件、支付和企业数据采用最小字段与最短保留。
- [ ] 锁屏通知、日志、剪贴板、缓存、临时文件和截图不泄漏。
- [ ] 高后果结果需要人工确认和审计，不由 AI/视觉/文本抽取直接执行。

### 9.4 AI 服务与模型专项

- [ ] 明确使用系统预置 AI 还是开发者自有模型。
- [ ] 明确端侧、系统服务或云端处理；不从 Kit 名称猜执行位置。
- [ ] 记录模型/服务版本、输入输出、语言/格式/shape、设备和地区限制。
- [ ] 记录精度基线、低置信度、无结果、偏差和误用边界。
- [ ] 端侧模型记录转换工具、算子、量化、后端、内存/功耗和 fallback。
- [ ] 流式/异步结果有 session/request ID，旧结果不能覆盖新会话。
- [ ] 页面退出、取消、前后台和模型升级时释放 session/tensor/buffer。
- [ ] 高后果建议可解释、可复核、可撤销，并保留确定性安全规则。

### 9.5 多端与自由流转专项

- [ ] 多端 UI 和跨设备协同被明确区分。
- [ ] 每个设备/窗口/输入的功能与降级矩阵已定义。
- [ ] 迁移/协同的账号、租户、角色、设备信任和授权已定义。
- [ ] transferable state 使用稳定业务 ID 与 schema version，不传 UI 对象图。
- [ ] owner 转移、重复、乱序、断线、取消和回滚有协议。
- [ ] 断连后撤销临时权限、通道、监听和缓存。
- [ ] 源/目标设备和版本组合经过真实测试。

### 9.6 NDK 专项

- [ ] 有测量证明必须下沉 Native。
- [ ] 目标 ABI/CPU 特性和通用 fallback 明确。
- [ ] 每个预构建库来源、版本、许可证、漏洞和 ABI 产物可审计。
- [ ] ArkTS/Native 参数、编码、长度、可空、所有权和线程明确。
- [ ] 环境销毁时删除 reference/callback/handle。
- [ ] Native 子线程不直接操作 ArkUI。
- [ ] 大小、边界、整数溢出、路径和损坏输入已测试。
- [ ] debug/release 真机加载、符号化崩溃和性能指标已验证。

### 9.7 可复制提示词

```text
请为 [项目/product/module] 只读评估是否应接入 [Kit/多端/自由流转/NDK能力]，不要先写代码。

必须输出：
1. 当前 target/compatible SDK、module type、deviceTypes 和工作树状态；
2. 能力分类：本地、系统Kit、AGC/云、模型推理、分布式或Native ABI；
3. 官方入口、精确 import/API/重载、@since、SystemCapability；
4. 设备、地区、普通/系统应用、企业/商户/资质、权限/ACL/Profile/AGC前提；
5. 数据、账号、租户、隐私和安全边界；
6. 初始化、活跃、取消、失败、销毁及资源释放状态机；
7. 成功、拒绝、离线、不支持、重复、乱序、撤销和真机/服务验证矩阵；
8. 对现有架构的最小改动边界与不接入的替代方案。

任何未从当前 SDK 或官方文档确认的字段写“未确认”，不得编造 API、权限、错误码或设备支持。
```

---

## 10. `KangxiaobanAI` 当前项目适配总表

| 领域 | 当前静态事实 | 本章结论 |
| --- | --- | --- |
| SDK/版本 | target SDK 为 `6.1.1(24)`，compatible SDK 为 `6.1.0(23)` | 采用 API 24 新能力前必须逐成员核对 `@since` 与 `SystemCapability`；若 API 23 设备仍在支持范围内，必须提供版本判断、兼容实现或明确可用的降级路径，不能只因 target SDK 为 API 24 就假定运行端具备该能力 |
| 应用服务 | 生产依赖为空；主模块无受限权限；未见 Account/Push/Map/Payment/Health 等真实 Kit 接入 | 所有 28 Kit 均不能描述为已接入；只有明确需求后逐 Kit 评估 |
| 账号 | 登录接受本地非空账号密码并用角色字符串进入 Main | 不是 Account Kit、机构认证或 RBAC |
| 云/后台 | 未见网络层、repository、云函数、云数据库、WebSocket | Cloud Foundation、Push、支付、钱包、实况窗均未实现 |
| AI | 定时器和固定文本生成本地回复 | 不是 Agent Framework、CANN、Core Speech/Vision、Intents、MindSpore、NNRt 或模型服务 |
| 多端 UI | 声明 phone/tablet/2in1；存在 phone/wide 分支 | 属于响应式源码基线，不等于所有设备真机完成 |
| 自由流转 | 未见设备发现、迁移、协同会话或分布式数据 | 未接入；deviceTypes 不能作为证据 |
| Native | 未见 cpp/CMake/Native 依赖或跨语言桥 | 未接入 NDK；当前问题没有 Native 必要性证据 |
| 业务数据 | 长者、任务、消息、入住、管理/医师记录多为本地 mock | 不得通过接入一个 Kit 就跳过 repository、授权和服务端架构 |

### 10.1 适合当前项目优先评估的方向

`[解释]` “优先评估”不是授权自动接入：

1. Notification/Push：只有真实任务/消息后台建立后，才评估提醒与离线触达；
2. Account Kit：只有明确华为账号与机构账号映射、租户和 RBAC 后评估；
3. PDF/Preview：只有真实报告/附件数据模型、权限和审计后评估；
4. Core Speech/Speech：若有无障碍朗读或语音输入需求，先做设备与长者可用性验证；
5. Intents/Agent Framework：只有真实业务服务和安全落地路由后评估系统入口；
6. Health Service Kit：不能替代机构健康档案，需要单独资质、授权和数据治理；
7. Map/Location：只有上门照护/路线等明确场景，并证明最小位置精度后评估。

### 10.2 当前明确不应直接接入

- Weather Service Kit：当前官方只面向系统应用开放；
- Game Controller/Game Service：无产品场景；
- Ads：无广告商业模式且与照护工作台定位不符；
- Screen Time Guard：无受限设备管控授权场景；
- Enterprise Space：当前不是企业 MDM/PC 企业空间应用；
- Wallet/IAP/Payment：没有商户、商品、订单和安全后端；
- CANN/NNRt/NDK：没有模型、硬件或性能测量证明；
- 自由流转：没有设备信任、迁移/协同协议和数据安全设计。

---

## 11. 本章交付与复核规则

### 11.1 AI 输出最低要求

任何后续 Agent 引用本章时，必须同时给出：

- 选择的具体 Kit/主题，而不是只写“应用服务”或“AI”；
- 当前项目 SDK、设备和应用类型；
- 当前官方入口和精确 API 证据；
- 服务/权限/资质/地区/设备前提；
- 生命周期和失败验证；
- `Implemented`、`Build-verified`、`Device-verified`、`Service-verified` 的分层结论。

### 11.2 禁止性结论

- “HarmonyOS 自带，所以不需要配置或权限。”
- “这是系统 Kit，所以数据只在本地。”
- “页面能显示，所以 AGC 服务已开通。”
- “拿到了支付/购买回调，所以已到账并可发货。”
- “声明了 phone/tablet/2in1，所以完成一次开发多端部署。”
- “可以分享给另一台设备，所以实现了自由流转。”
- “用了 AI Kit，所以结果可信且可以自动执行。”
- “改成 C++ 就一定更快。”
- “样例支持该设备，所以当前产品也支持。”

### 11.3 本章自身覆盖检查

- [x] 应用服务 28 个直接 Kit 全部列出并逐项说明。
- [x] AI 10 个直接 Kit 全部列出并逐项说明。
- [x] 五个栏目正文数量与口径明确。
- [x] 多端与自由流转迁移后的官方地址明确。
- [x] NDK 7 个直属主题及 142 页结构完整列出。
- [x] 本地能力、系统 Kit、AGC/云、模型推理、分布式和 Native ABI 已区分。
- [x] 每个 Kit 均包含用途、接入边界、生命周期/失败验证和项目适配。
- [x] 明确 `KangxiaobanAI` 当前未接入真实应用服务、AI 模型/服务、自由流转或 Native。

---

## 12. 最终工程口诀

```text
先定能力类型，再选 Kit；
先查开放范围，再写 import；
先查 @since 与 SystemCapability，再谈兼容；
先开通 AGC/权限/资质，再谈服务成功；
先定义 owner 与 teardown，再注册监听和资源；
先定义失败、取消、重复和乱序，再画成功页；
多端 UI 不等于自由流转，系统 AI 不等于自有模型；
Native 需要测量、ABI 和内存证据，不需要崇拜；
本地 mock 不等于真实服务，构建成功不等于真机或云端成功。
```
