# HarmonyOS / ArkTS / ArkUI / HDS 完全指南

> 面向零基础开发者与 AI Agent 的完整技术文档。
>
> 目标：读者在阅读后可独立理解并修改本仓库的 `KangxiaobanAI` 项目，
> 并具备从零构建鸿蒙应用的能力。

---

## 0. 信息来源与可信度声明

本文档基于以下信息源撰写，按可信度由高到低排列：

| 优先级 | 来源 | 说明 |
|---|---|---|
| 最高 | **本机 SDK 的类型声明文件** | `C:\Program Files\Huawei\DevEco Studio\sdk\default\` 下的 `.d.ts` / `.d.ets`。编译器实际依据的 API 定义，准确性最高。 |
| 高 | **本仓库的真实源码** | `KangxiaobanAI/` 主项目 + 20 个官方示例工程（`transitions-collection`、`cases`、`ResponsiveLayout` 等）。均为可实际运行的工程代码。 |
| 中 | **联网检索的公开资料** | 用于交叉验证概念性描述（状态管理 V2 语义、ArkTS 适配规则、geometryTransition 原理）。 |
| 中 | 我的既有知识 | 用于说明设计动因与写法的实际影响。 |

**关于华为官网**：撰写期间 `developer.huawei.com` 被本机网络策略拦截，无法直接获取原文。
概念性内容已通过公开技术资料交叉验证，与 SDK 声明一致。

**因此**：本文中凡是**具体 API 签名、枚举值、组件名**，均来自本机 SDK 实测提取，可直接采用；
凡是涉及**规则编号的完整枚举、官方措辞**的部分，我会标注「以 DevEco 的 linter 报错为准」。

**排版约定**：

| 标记 | 含义 |
|---|---|
| ★ | 关键项，实践中必须注意 |
| 🔴 | 严重问题 / 已超出合理规模 |
| 🟡 | 需要关注 |
| 🟢 | 已知但影响有限 |
| ⚠️ | 常见误区或已知缺陷 |

**版本信息**：

- 本机安装的 SDK：`HarmonyOS 26.0.0 Beta1`（apiVersion 26）
- 本仓库 `KangxiaobanAI` 项目的配置：`targetSdkVersion = compatibleSdkVersion = 6.1.1(24)`，即 **API 24**
- 也就是说：**SDK 比项目新**。SDK 里带 `@since 26` 标注的 API，在 API 24 的项目里用不了。
  文中已标注关键 API 的 `@since`，超过 24 的需要留意。

---

## 1. 阅读路线图

### 路线 A：我是完全的新手，从没写过鸿蒙

按顺序读：

```
00 → 01 → 02 → 04 → 03（当字典查）→ 05 → 07 → 06 → 09 → 10 → 11 → 12
```

### 路线 B：我会写前端（React / Vue / Flutter），只想快速上手

```
02（看差异）→ 01（看 ArkTS 的坑）→ 05（状态管理，和 React 很像但不一样）→ 04 → 07 → 06
```

### 路线 C：我是 AI / Agent，要修改这个仓库的代码

必读，按顺序：

```
14（项目全景）→ 05（状态管理V2，本项目铁律）→ 09（一多适配，本项目核心模式）
→ 08（HDS，本项目 UI 全靠它）→ 06（一镜到底）→ 13（避坑）→ 15（速查）
```

### 路线 D：我只想搞明白「一镜到底」怎么做

直接读 `06-动画与一镜到底.md`，那一章是自包含的。

---

## 2. 全部章节

| 文件 | 讲什么 | 适合谁 |
|---|---|---|
| [00-零基础世界观.md](./00-零基础世界观.md) | 鸿蒙是什么、ArkTS 是什么、这一堆名词到底谁是谁、装什么软件、第一个 App | 完全新手 |
| [01-ArkTS语言完全指南.md](./01-ArkTS语言完全指南.md) | 语法从零讲起；ArkTS 相对 TypeScript **砍掉了什么**、为什么砍、报错了怎么改 | 所有人 |
| [02-声明式UI原理.md](./02-声明式UI原理.md) | 「声明式」到底什么意思、`build()` 的规则、链式属性、UI 是怎么被重新渲染的 | 所有人 |
| [03-组件大全.md](./03-组件大全.md) | SDK 里 **110 个内置组件 + 33 个高级组件**逐个讲：干嘛的、最小例子、常用属性、坑 | 当字典查 |
| [04-布局系统.md](./04-布局系统.md) | Row/Column/Stack/Flex/Grid/RelativeContainer/List/尺寸单位/安全区，把东西摆到正确位置 | 所有人 |
| [05-状态管理V2.md](./05-状态管理V2.md) | `@Local @Param @Once @Event @Monitor @Computed @Provider @Consumer @ObservedV2 @Trace` + `AppStorageV2/PersistenceV2`，以及和 V1 的对照 | **重点** |
| [06-动画与一镜到底.md](./06-动画与一镜到底.md) | 属性动画/显式动画/转场动画/曲线；**6 种一镜到底完整实现** | **重点** |
| [07-导航与模态.md](./07-导航与模态.md) | router / Navigation+NavPathStack / NavDestination / bindSheet / bindContentCover / Dialog，什么时候用哪个 | **重点** |
| [08-HDS设计系统.md](./08-HDS设计系统.md) | `@kit.UIDesignKit`：HdsNavigation / HdsNavDestination / HdsTabs / HdsListItemCard / hdsMaterial 全解 | 本仓库必读 |
| [09-一多适配.md](./09-一多适配.md) | 一次开发多端部署：断点、栅格、响应式、折叠屏、PC；本项目的「双布局分叉」模式 | 本仓库必读 |
| [10-资源与主题.md](./10-资源与主题.md) | `resources/` 目录、`$r()`、深色模式、多语言、系统 token 体系 | 所有人 |
| [11-应用框架与生命周期.md](./11-应用框架与生命周期.md) | Stage 模型、UIAbility、module.json5、Context、Window、权限 | 所有人 |
| [12-工程化构建与调试.md](./12-工程化构建与调试.md) | hvigor、build-profile、oh-package、模块类型、linter、单元测试、签名打包 | 中级 |
| [13-性能与避坑清单.md](./13-性能与避坑清单.md) | 性能红线、常见报错→原因→改法对照表、本仓库已知缺陷清单 | **重点** |
| [14-康小伴项目全景拆解.md](./14-康小伴项目全景拆解.md) | 用本仓库真实代码，把上面所有知识点串成一条线 | 本仓库必读 |
| [15-速查手册.md](./15-速查手册.md) | 一页纸速查：装饰器、生命周期、常用属性、曲线参数 | 随时翻 |

---

## 3. 整体认知框架

```
鸿蒙 App
  └── 用 ArkTS 这门语言写          ← 语言（TypeScript 的严格子集）
       └── 用 ArkUI 这套框架画界面  ← UI 框架（声明式，类似 SwiftUI/Compose）
            └── 用 HDS 这套组件库    ← 华为官方设计系统的现成组件（可选，但本项目全用它）
                 └── 跑在 Stage 模型上 ← App 的运行骨架（UIAbility + Window + Page）
                      └── 用 hvigor 构建 ← 打包工具（相当于 gradle / webpack）
```

一句话版本：

> **ArkTS 是语言，ArkUI 是画界面的框架，HDS 是现成好看的组件，Stage 模型是 App 的骨架，hvigor 负责打包。**

---

## 4. 仓库结构

```
KangxiaobanAI_OC/                        ← 仓库根目录（一个「工作区」，不是一个工程）
├── KangxiaobanAI/          ★★★ 唯一可以修改的正式项目（康小伴AI，智慧养老）
├── docs/HarmonyOS完全指南/   ← 你正在读的东西
├── AGENTS.md               ← 仓库的完整工作约定（69KB，权威）
├── CLAUDE.md               ← AGENTS.md 的精简版
│
└── 以下全部是【只读参考示例】，永远不要改，只能抄思路：
    ├── transitions-collection/   ← 一镜到底转场合集（6 种官方实现）
    ├── cases/CommonAppDevelopment/ ← 165 个功能案例合集（规模最大）
    ├── ResponsiveLayout/          ← 一多适配（双栏/三栏/栅格/侧边栏）
    ├── MusicHome/                 ← 多设备（手机/平板/PC/手表/TV）音乐应用
    ├── NavigationSettings/        ← Navigation 导航范例
    ├── Spatialization/            ← 空间音频
    ├── MultiDeviceCommunication/  ← 分布式多设备通信
    ├── MultiCommunityApplication/ ← 多模块社区应用
    ├── HarmonyOSComponentUXExamples-dev/ ← 组件 UX 示例
    ├── sample_in_harmonyos/       ← 官方大型示例
    ├── multi-convenient-life/     ← 一多生活服务
    ├── multi-tab-navigation/      ← 多 Tab 导航
    └── *-kit-sample-code-*/       ← 各种 Kit（地图/推送/账号/视觉）的官方 demo
```

**铁律：只有 `KangxiaobanAI/` 是交付目标，其余全是只读参考。**

---

## 5. 装饰器速记表

| 装饰器 | 一句话 | 记忆法 |
|---|---|---|
| `@Entry` | 这个页面是路由入口 | Entry = 入口 |
| `@ComponentV2` | 这是一个 V2 版自定义组件 | 本项目所有组件都写这个 |
| `@Local` | 组件自己的私有状态，变了就重新渲染 | Local = 本地 |
| `@Param` | 从父组件传进来的参数，**子组件不能改** | Param = 参数 |
| `@Once` | 和 `@Param` 连用，只接受一次初值，之后父组件改了也不同步 | Once = 只一次 |
| `@Require` | 和 `@Param` 连用，表示「父组件必须传」 | Require = 必填 |
| `@Event` | 子组件回调父组件用的函数 | Event = 事件 |
| `@Monitor('x')` | `x` 变了就跑一次这个函数 | Monitor = 监视 |
| `@Computed` | 派生值，依赖变了才重算，有缓存 | Computed = 计算属性 |
| `@Provider()` | 我提供一个数据，后代随便拿 | 祖先播种 |
| `@Consumer()` | 我拿祖先提供的数据 | 后代收割 |
| `@ObservedV2` | 这个 class 里的字段可以被观察 | 给类用的 |
| `@Trace` | `@ObservedV2` 类里，**只有加了这个的字段**变化才会触发 UI 刷新 | Trace = 追踪 |
| `@Builder` | 可复用的 UI 片段（一个「UI 函数」） | Builder = 造 UI |
| `@Styles` | 可复用的一组样式 | Styles = 样式 |
| `@Extend(Text)` | 给某个具体组件扩展链式方法 | Extend = 扩展 |

**警告**：本项目**禁止**使用 V1 的 `@State / @Prop / @Link / @Observed / @Watch / @Provide / @Consume`。
你会在只读示例工程里大量看到它们（那些示例是 V1 写的），**不要抄进 KangxiaobanAI**。

---

## 6. 问题定位决策树

```
报错了 / 不知道怎么写
│
├─ 是语法/类型报错（arkts-xxx / TS 报错）？   → 看 01 章「ArkTS 限制清单」+ 13 章「报错对照表」
├─ UI 不刷新？                              → 看 05 章「不刷新的 7 个原因」
├─ 不知道用哪个组件？                        → 看 03 章「组件大全」按场景索引
├─ 位置摆不对 / 高度塌陷？                    → 看 04 章「布局系统」
├─ 动画不流畅 / 一镜到底不生效？               → 看 06 章「一镜到底 6 个必检项」
├─ 页面跳转怎么写？                          → 看 07 章「三套导航机制怎么选」
├─ 平板/PC 上很丑？                          → 看 09 章「一多适配」
├─ 颜色/文字/图标怎么取？                     → 看 10 章「资源与主题」
├─ 编译/打包/签名问题？                       → 看 12 章「工程化」
└─ 想知道本项目某段代码为什么这么写？           → 看 14 章「项目全景拆解」
```

---

## 7. 写给 AI / Agent 的特别说明

如果你是一个大模型或 Agent，正准备修改这个仓库，请注意以下**硬约束**（违反了会被 review 打回）：

1. **只能改 `KangxiaobanAI/products/entry/src/main/ets` 下的文件。**
2. **只能用状态管理 V2**（`@ComponentV2` / `@Local` / `@Param` / `@Event` / `@Monitor` / `@Computed` / `@Provider` / `@Consumer` / `@ObservedV2` / `@Trace`）。
   一旦你写出 `@State`、`@Prop`、`@Link`、`@Watch`、`@Observed`、`@Provide`、`@Consume`，就是错的。
3. **全局状态只能放 `GlobalInfoModel`**，而且只放「会话 / 环境 / 窗口 / 角色」四类。业务数据留在组件里。
4. **不要新增一级 Tab**。新功能从已有功能根进入，走 `NavPathStack` 或浮层。
5. **不要把「本地数组增删」说成「已保存到服务器」**。这是个纯本地原型，没有网络层、没有真实鉴权。
6. **不要打印或提交任何 `build-profile.json5` 里的证书路径和密码。**
7. **不要提交** `.hvigor/` `build/` `oh_modules/` `.idea/` 和任何生成文件。
8. **构建状态要如实说**，分四档：`已实现` / `已构建验证` / `已真机验证` / `仅规划`。
   只跑通 `product=default` 不等于其他设备形态能构建。

---

## 8. 版本与维护

- 编写日期：2026-07-26
- 依据的项目状态：git `main` 分支，最近提交 `5a1a01a feat: 完善养老医师入住办理流程`
- 依据的 SDK：`HarmonyOS 26.0.0 Beta1 (API 26)`，项目目标 `API 24`
- 已知文档漂移：仓库里的 `KANGXIAOBANAI_ARKTS_DEEP_PROJECT_REPORT.md` 写的是 API 23，**那是旧的**，
  以 `build-profile.json5` 为准（API 24）。**永远不要为了迎合旧文档去改代码。**

---

下一步 → [00-零基础世界观.md](./00-零基础世界观.md)
