# KangxiaobanAI_OC 项目记忆文件

> 生成日期: 2026-06-30
> 工作目录: `d:\KangxiaobanAI_OC`
> 项目总数: 17 个（含 1 个总览文档）
> 技术栈: HarmonyOS / ArkTS / ArkUI / HDS

---

## 目录总览

```
KangxiaobanAI_OC/
├── KangxiaobanAI/                    # 核心业务项目：康小伴AI护工端
├── MusicHome/                        # 多设备音乐应用（三层架构典范）
├── sample_in_harmonyos/              # HMOS代码工坊 - 官方示例集合APP
├── cases/                            # 180+功能案例 + 性能优化文档库
├── MultiDeviceCommunication/         # 多设备即时通讯界面
├── MultiCommunityApplication/        # 多设备社区评论界面
├── NavigationSettings/               # 多设备设置界面
├── ResponsiveLayout/                 # 响应式布局教科书
├── multi-tab-navigation/             # 12种Tab导航样式
├── transitions-collection/           # 7种一镜到底转场动效
├── Spatialization/                   # 沉浸光感/HDS新视觉
├── multi-convenient-life/            # 便捷生活多端页面
├── map-kit_-sample-code_-demo-arkts/ # 地图服务Kit演示
├── visionkit-sample-code-arkts/      # 人脸活体检测Kit演示
├── push-kit-sample-code-clientdemo-arkts/ # 推送服务Kit演示
├── HarmonyOSComponentUXExamples-dev/ # 组件UX示例
└── ARKTS_HARMONYOS_OFFICIAL_SAMPLES_GUIDE.md # 学习指南总文档
```

---

## 一、核心业务项目

### KangxiaobanAI（康小伴AI护工端）

| 属性 | 值 |
|------|-----|
| **包名** | `com.gxoc.kxbai` |
| **技术栈** | ArkUI V2 (`@ComponentV2`)、HDS、AppStorageV2 |
| **目标用户** | 养老院护工、护理站、值班主管 |
| **入口文件** | `products/entry/src/main/ets/pages/MainPage.ets` |

**核心功能模块**:
1. **首页总览** - 待办(18)、风险观察(6)、闭环率(92%)
2. **长者画像** - 风险分层与陪护建议
3. **任务闭环** - 交接班、时段排程
4. **入住登记** - 资料核验、床位安排、照护计划
5. **我的** - 班次、绩效、培训、偏好设置

**技术架构**:
- `@Provider('mainPageStack')` - 路由栈注入
- `AppStorageV2.connect(GlobalInfoModel)` - 全局状态
- `HdsNavigation` + `HdsTabs` - HDS设计体系导航
- **手机端**: 底部悬浮Tab + MiniBar（入住登记快捷入口）
- **宽屏端**: 左侧边栏导航 + 右侧内容区
- `BreakpointType<T>` - 断点响应式工具

**关键目录**:
```
KangxiaobanAI/
├── AppScope/app.json5              # 应用级配置
├── products/entry/src/main/ets/
│   ├── pages/MainPage.ets          # 主页面入口
│   ├── component/
│   │   ├── CheckInFlowPage.ets     # 入住登记流程
│   │   ├── TabPageView.ets         # Tab页视图
│   │   └── WaterFlowView.ets       # 瀑布流视图
│   ├── model/
│   │   ├── GlobalInfoModel.ets     # 全局信息模型
│   │   ├── TabPageModel.ets        # Tab页配置模型
│   │   └── TabsBarModel.ets        # 底部Tab栏模型
│   ├── util/
│   │   ├── BreakpointSystem.ets    # 断点系统
│   │   ├── MaterialUtil.ets        # 材质工具
│   │   ├── WindowUtil.ets          # 窗口工具
│   │   └── PreferenceManager.ets   # 持久化管理
│   └── common/CommonConstants.ets  # 常量定义
```

---

## 二、官方大型示例应用

### sample_in_harmonyos（HMOS代码工坊）

| 属性 | 值 |
|------|-----|
| **定位** | 华为官方开源示例集合APP |
| **产品入口** | phone / pc / tv / wearable |
| **特色** | 组件库实时预览、Sample一键下载集成 |

**Feature 模块**:
- `features/componentlibrary` - 组件库（预览区+属性调整+代码展示）
- `features/devpractices` - 开发实践样例
- `features/exploration` - 最佳实践文章
- `features/mine` - 我的页面
- `features/abilitycommon` - Ability公共
- `features/commonbusiness` - 公共业务
- `features/widgetcommon` - 卡片公共

**Common 模块**:
- 账号管理、数据库、推送服务、路由管理、存储管理、埋点、更新服务

---

### cases（鸿蒙应用开发案例集）

| 属性 | 值 |
|------|-----|
| **定位** | 最大的案例集合，180+功能案例 |
| **架构** | common / feature / product 三层架构 |
| **文档** | 60+篇性能优化文章 |

**Feature 分类（180+个）**:

| 分类 | 代表案例 |
|------|----------|
| **UI基础** | customview、skeletondiagram、watermark、imagemosaic、eraser、palette |
| **导航弹窗** | customdialog、limitedheightbottomdialog、navdestinationdialog、navigationinterceptor |
| **动画手势** | cuberotateanimation、clickanimation、pageflip、waterripples、dragandexchange |
| **媒体** | shortvideo、videocache、videocreategif、danmakuplayer、mediafullscreen |
| **Web/H5** | h5cache、customkeyboardtoh5、webpagesnapshot、webpdfviewer |
| **文件数据** | bigfilecopy、compressfile、databaseupgrade、nativerawfile |
| **系统Kit** | bluetooth、faceandfingerprintunlocking、vibrateeffect、mapthumbtack、customscan |
| **多端适配** | foldablescreencases、immersive、keyboardavoid、diggingholescreen |
| **性能** | customreusablepool、highlyloadedcomponentrender、imperativedynamiclayouts、operaterdbintaskpool |

**性能文档库** (`docs/performance/`):
- 高性能编程、高效并发、N-API开发
- LazyForEach优化、组件复用、状态管理
- 冷启动优化、布局优化、Web性能优化
- CPU/内存/帧率/启动/时延 Profiler工具
- SmartPerf、HiDumper、ArkUI Inspector

---

## 三、三层架构多端应用示例

> 均采用 products（产品层）/ features（特性层）/ common（公共层） 三层架构

### MusicHome（多设备音乐界面）

| 属性 | 值 |
|------|-----|
| **设备覆盖** | 手机/平板、PC、TV、智能穿戴（6种形态） |
| **状态管理** | `@ComponentV2` + `AppStorageV2.connect(MusicAppState)` |
| **播放状态** | 队列、索引、进度、音量、全屏开关、miniBar状态 |

**模块划分**:
```
MusicHome/
├── common/musicbasic/              # 基础HAR：数据、状态、工具
├── features/
│   ├── player/                     # 播放器：全屏页、歌词、音频
│   ├── playlist/                   # 歌单：详情、分栏、迷你条
│   └── recommendation/             # 推荐：首页、宽屏面板
└── products/
    ├── default/                    # 手机/平板入口
    ├── pc/                         # PC入口
    ├── tv/                         # TV入口
    └── watch/                      # 穿戴入口
```

---

### MultiDeviceCommunication（多设备即时通讯）

| 属性 | 值 |
|------|-----|
| **产品** | default（手机/平板）、pc |
| **四大Tab** | 消息、联系人、社交、我的 |
| **导航** | HdsNavigation + HdsTabs（API 601+）/ 原生Navigation（低版本） |

**Feature 模块**: `message` / `social` / `user` / `commonui`

---

### MultiCommunityApplication（多设备社区评论）

| 属性 | 值 |
|------|-----|
| **产品** | default、pc |
| **四大Tab** | 关注、热点、视频、我的 |
| **布局** | WaterFlow瀑布流 + SideBarContainer大屏侧边栏 |

**Feature 模块**: `contentcommunity` / `socialcommunity` / `commoncommunityui`

---

### NavigationSettings（多设备设置界面）

| 属性 | 值 |
|------|-----|
| **产品** | default、pc |
| **技术亮点** | `@ComponentV2` 参数化页面（`@Param` `@Event`）+ ViewModel |
| **页面层级** | 设置首页 → WLAN/更多连接 → 详情页 |

---

## 四、UI/UX 专项演示

### ResponsiveLayout（响应式布局教科书）

| 属性 | 值 |
|------|-----|
| **布局场景** | 12种 |
| **核心工具** | `WidthBreakpointType<T>` 断点类型类 |

**布局清单**:
1. 列表布局（List + lanes）
2. 瀑布流布局（WaterFlow + columnsTemplate）
3. 轮播布局（Swiper）
4. 宫格布局（Grid）
5. 侧边栏（SideBarContainer）
6. 单/双栏布局（Navigation分栏）
7. 三分栏布局（SideBarContainer + Navigation）
8. 聊天双栏、日历三栏、邮箱三栏
9. 挪移布局（GridRow/GridCol栅格）
10. 缩进布局（GridRow/GridCol栅格）
11. 底部/侧边导航（Tabs）

---

### multi-tab-navigation（Tab导航样式合集）

**12种导航样式**:
1. 常见底部导航
2. 舵式底部导航
3. TabContent视频内容滑动
4. 可滑动+更多按钮
5. 下划线样式
6. 背景高亮样式
7. 文字样式
8. 双层嵌套样式（两种实现）
9. 常见侧边导航
10. 抽屉式侧边导航
11. 居左对齐样式

---

### transitions-collection（转场动效合集）

**7种一镜到底转场**:
1. **多模态页面转场** - bindSheet + bindContentCover + TransitionEffect
2. **搜索一镜到底** - geometryTransition 绑定同一id
3. **卡片一镜到底** - customNavContentTransition + componentSnapshot
4. **图片一镜到底** - NodeContainer + NodeController 跨节点迁移（双指放大/查看大图/半模态）
5. **视频一镜到底** - NodeController + customNavContentTransition
6. **列表一镜到底** - geometryTransition
7. **图书翻页一镜到底** - customNavContentTransition

---

### Spatialization（沉浸光感/HDS新视觉）

**三大场景**:
1. **沉浸光感** - 标题栏光感材质强弱切换
2. **自适应悬浮导航** - MiniBar展开/折叠（<600vp折叠，>600vp展开）
3. **智感握姿** - 结合MultimodalAwarenessKit，根据握持状态调整Tab位置

---

### multi-convenient-life（便捷生活多端页面）

**三类业务页面**:
- 点餐列表页（左侧分类+右侧菜品）
- 图文详情页（轮播+描述+评论）
- 生活主页

---

## 五、Kit 能力演示

| 项目 | Kit | 核心能力 |
|------|-----|----------|
| **map-kit_-sample-code_-demo-arkts** | Map Kit | 地图展示、移图、Marker/Polygon覆盖物、静态图、路径规划、地点搜索、选点控件 |
| **visionkit-sample-code-arkts** | Vision Kit | 人脸活体检测（startLivenessDetection + getInteractiveLivenessResult） |
| **push-kit-sample-code-clientdemo-arkts** | Push Kit | Push Token、通知消息、撤回、卡片刷新、TTS、后台消息、实况窗、通话消息、服务卡片 |

---

## 六、技术栈速查

### ArkUI 状态管理

**V1 装饰器**:
- `@State` - 组件内部状态
- `@Prop` / `@Link` - 父子单向/双向
- `@Provide` / `@Consume` - 跨层级注入
- `@ObjectLink` + `@Observed` - 对象引用观察
- `@StorageProp` / `@StorageLink` - AppStorage全局
- `@LocalStorageProp` / `@LocalStorageLink` - 页面级LocalStorage

**V2 装饰器**（新项目推荐）:
- `@ComponentV2` - V2组件
- `@Local` - 内部响应式状态
- `@Param` / `@Require @Param` - 外部参数/必传
- `@Event` - 事件回调
- `@Provider` / `@Consumer` - V2依赖注入
- `@Env(SystemProperties.BREAK_POINT)` - 系统环境订阅
- `@Monitor('state.field')` - 状态字段监听
- `@ObservedV2` + `@Trace` - 可观察模型类
- `AppStorageV2.connect(ModelClass, key, factory)` - 全局V2状态

### 路由体系

| 方式 | 适用场景 | API |
|------|----------|-----|
| 传统router | 简单页面跳转 | `getUIContext().getRouter().pushUrl()` |
| Navigation + NavPathStack | 标准多页面 | `Navigation(pathStack)` + `.navDestination()` |
| HDS Navigation | HDS设计体系 | `HdsNavigation(pathStack)` + `HdsNavDestination` |

**命名路由**: `router_map.json` 中声明 `name` → `pageSourceFile` + `buildFunction`

### 多端适配

```typescript
// 断点读取
@Env(SystemProperties.BREAK_POINT) widthBreakpoint: WidthBreakpoint;

// 断点工具类模式
export class WidthBreakpointType<T> {
  constructor(public sm: T, public md: T, public lg: T, public xl: T) {}
  getValue(widthBp: WidthBreakpoint): T { ... }
}

// 窗口信息
window.Window.getWindowAvoidArea()    // 避让区域
display.getDefaultDisplaySync()      // 屏幕信息
display.isFoldable() / getFoldStatus() // 折叠屏
```

### HDS 设计体系

**包**: `@kit.UIDesignKit`
**核心组件**: `HdsNavigation`、`HdsTabs`、`HdsNavDestination`
**材质**: `hdsMaterial.MaterialType.ADAPTIVE/IMMERSIVE` + `MaterialLevel.ADAPTIVE`
**悬浮Tab**: `.barFloatingStyle({ barBottomMargin, systemMaterialEffect, miniBar })`
**版本分支**: `deviceInfo.distributionOSApiVersion >= 60100` 时启用高级HDS特性

### 工程架构

**三层架构标准分层**:
```
App/
├── AppScope/                # 应用全局配置
├── common/                  # 公共能力层（HAR）
│   └── xxxbase/             # 基础模块
├── features/                # 特性层（HAR）
│   ├── featureA/
│   └── featureB/
├── products/                # 产品层（HAP）
│   ├── default/             # 手机/平板
│   ├── pc/                  # PC
│   ├── tv/                  # 智慧屏
│   └── watch/               # 穿戴
└── libs/                    # 三方依赖
```

### 常用 Kit 导入

```typescript
// UI
import { HdsNavigation, HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
import { AppStorageV2 } from '@kit.ArkUI';

// 媒体
import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';

// 地图/定位
import { MapComponent, map, site, navi } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';

// 视觉AI
import { interactiveLiveness } from '@kit.VisionKit';

// 推送/通知
import { pushService } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';

// 网络/文件
import { request } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
```

---

## 七、开发工作流（记忆版）

1. **识别工程类型**: 单entry / 多product / 多HAR feature / 元服务 / 性能测试
2. **读配置**: `app.json5`（应用级）→ `module.json5`（模块、Ability、权限、路由表）
3. **找入口**: `EntryAbility.ets` 的 `onWindowStageCreate` → `loadContent`
4. **建映射**: `main_pages.json` / `router_map.json` → 页面名到源码
5. **改UI前**: 先找 `common/constants`、`model`、`viewmodel`、`utils`，复用已有模式
6. **HDS项目**: 优先用 `HdsNavigation/HdsTabs/HdsNavDestination`
7. **状态版本**: 项目用V1就保持V1，用V2就保持V2
8. **多端布局**: 优先断点 + WindowUtil + BreakpointType，不硬编码像素
9. **Kit调用**: 检查权限 → `canIUse` → 错误码 → `BusinessError`
10. **验证**: 静态路径/语法一致性检查 → 构建运行

---

## 八、快速回查表

| 需求 | 推荐参考项目/文件 |
|------|------------------|
| ArkUI新手入门 | `multi-tab-navigation/entry/src/main/ets/pages/Index.ets` |
| Navigation命名路由 | `map-kit_-sample-code_-demo-arkts/entry/src/main/ets/pages/Index.ets` |
| HDS悬浮Tab + MiniBar | `KangxiaobanAI/products/entry/src/main/ets/pages/MainPage.ets` |
| V2状态管理 + AppStorageV2 | `MusicHome/common/musicbasic/src/main/ets/model/MusicAppState.ets` |
| 多端窗口 + 避让区 | `ResponsiveLayout/entry/src/main/ets/utils/WindowUtil.ets` |
| 响应式布局大全 | `ResponsiveLayout/entry/src/main/ets/views/*` |
| 转场动画一镜到底 | `transitions-collection/entry/src/main/ets/pages/Index.ets` |
| 大型样例路由架构 | `sample_in_harmonyos/products/phone/src/main/ets/page/MainPage.ets` |
| 180+功能案例索引 | `cases/CommonAppDevelopment/feature/*/README.md` |
| 性能优化文章 | `cases/docs/performance/` |
| 三层架构典范 | `MusicHome/` |
| 总览学习文档 | `ARKTS_HARMONYOS_OFFICIAL_SAMPLES_GUIDE.md` |

---

## 九、版本与约束

| 项目 | HarmonyOS最低版本 | DevEco最低版本 |
|------|-------------------|----------------|
| KangxiaobanAI | 6.1.0 | 6.1.0 |
| MusicHome | 6.0.2 | 6.1.0 |
| Spatialization | 6.1.0 | 6.1.0 |
| NavigationSettings | 6.0.2 | 6.1.0 |
| MultiDeviceCommunication | 6.0.2 | 6.1.0 |
| ResponsiveLayout | 6.0.0 | 6.0.0 |
| transitions-collection | 5.0.5 | 5.0.5 |
| multi-tab-navigation | 5.0.5 | 5.0.5 |

---

*本文件作为项目记忆，用于快速回忆目录结构、技术选型和最佳实践。*
