# 第 08 章 · HDS 设计系统（`@kit.UIDesignKit`）

> HDS = HarmonyOS Design System，华为官方的设计系统组件库。
>
> **本项目的 UI 几乎全部基于 HDS。** 不懂 HDS 就读不懂 `KangxiaobanAI` 的代码。
>
> HDS 的公开文档很少，**本章所有 API 全部从本机 SDK 逐条提取**：
> `sdk\default\hms\ets\api\@hms.hds.*.d.ets`

---

## 8.1 HDS 概述与选用理由

### 是什么

HDS 提供一整套「和系统原生 App 长得一模一样」的组件：

- 带**磨砂玻璃**效果的导航栏
- 滚动时**渐变模糊**的标题栏
- 统一规格的**列表行卡片**（左图标 + 中文字 + 右控件）
- **悬浮式**底部 Tab 栏
- 侧边栏、侧边菜单、SnackBar、ActionBar

### 为什么用它

| 自己手写 | 用 HDS |
|---|---|
| 磨砂效果要自己调 `backgroundBlurStyle` 参数 | 一行 `materialType: IMMERSIVE` |
| 滚动模糊要自己监听 offset 算透明度 | 一行 `enableScrollEffect: true` |
| 列表行的图标/文字/箭头间距要自己量 | `HdsListItemCard` 直接给对的 |
| 深色模式要自己适配 | 自动跟随 |
| 和系统 App 视觉不一致 | 完全一致 |

### 导入方式

```typescript
import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController,
  HdsListItemCard, PrefixIcon, SuffixArrow, SuffixText, SuffixButton, SuffixSwitch,
  HdsActionBar, ActionBarButton, ActionBarStyle,
  hdsMaterial, ScrollEffectType, IconSize, IconStyleMode, TextStyleMode,
  HdsNavigationTitleMode, HdsNavDestinationTitleMode,
  TitleBarContentOptions, TitleBarStyleOptions
} from '@kit.UIDesignKit';
```

**`@since 5.0.0(12)`** —— 从 API 12 开始提供。本项目 API 24，完全可用。

---

## 8.2 HDS 全部导出清单（SDK 实测）

### 导航类

```
HdsNavigation            带 HDS 样式的 Navigation
HdsNavigationAttribute   它的属性类型
HdsNavDestination        带 HDS 样式的 NavDestination
HdsNavDestinationAttribute
```

### 页签类

```
HdsTabs                  带 HDS 样式的 Tabs
HdsTabsController        控制器（切换页签、预加载）
HdsTabsAttribute / HdsTabsModifier
HdsTabsMiniBar           迷你页签栏
HdsTabsFloatingStyle     悬浮页签栏样式
HdsBarStyle / HdsBarMode / ExtendBarMode / HdsBarLayoutMode
HdsTabsBackgroundStyle / HdsBarWidthRangeOptions
HdsDividerStyle / DividerMode
HdsAnimationMode
```

### 列表类

```
HdsListItemCard          ★通用列表行卡片（本项目核心）
HdsListItemCardOptions / HdsListItemCardAttribute / HdsListItemCardModifier
HdsListItem              带滑动操作的列表项
HdsSwipeActionOptions    滑动操作配置
```

### 列表行的「前缀」组件（左侧）

```
PrefixItem（基类）
├── PrefixImage          图片
├── PrefixIcon           ★图标（本项目最常用）
├── PrefixBadge          角标
├── PrefixSwitch         开关
├── PrefixToggleButton   切换按钮
├── PrefixButton         按钮
└── PrefixCustomBuilder  自定义
```

### 列表行的「后缀」组件（右侧）

```
SuffixItem（基类）
├── SuffixText           ★纯文字
├── SuffixImage          图片
├── SuffixLoadingProgress 转圈
├── SuffixRadio          单选
├── SuffixCheckbox       复选
├── SuffixSwitch         ★开关
├── SuffixArrow          ★右箭头 >
├── SuffixBadge          角标
├── SuffixButton         ★按钮
├── SuffixIcon           图标
├── SuffixSubIcon        次级图标
├── SuffixSelect         下拉选择
├── SuffixToggleButton   切换按钮
├── SuffixBadgeAndArrow  角标 + 箭头
├── SuffixTextAndArrow   文字 + 箭头
├── SuffixArrowIconText  箭头 + 图标 + 文字
└── SuffixCustomBuilder  自定义
```

（标 ★ 者为本项目实际使用的组件。）

### 其它组件

```
HdsSideBar               侧边栏
HdsSideMenu              侧边菜单（含 MainItem / SubItem / Badge）
HdsActionBar             操作栏（底部按钮组）
HdsSnackBar              轻提示条
HdsVisualComponent       视觉特效组件（HdsSceneController / HdsSceneType）
MultiWindowEntryInAPP    应用内多窗口入口
```

### 工具命名空间

```
hdsMaterial              ★材质（磨砂/沉浸）
hdsDrawable              可绘制对象
hdsEffect                特效
symbolRegister           符号注册
```

---

## 8.3 `hdsMaterial`：材质系统（磨砂玻璃）

### 完整定义（SDK 原文）

```typescript
declare namespace hdsMaterial {
  enum MaterialType {
    NONE = 0,
    ADAPTIVE = 100,      // 自适应
    IMMERSIVE = 101      // 沉浸式 ★本项目全用这个
  }
  enum MaterialLevel {
    EXQUISITE = 0,       // 精致（模糊最强，性能开销最大）
    GENTLE = 1,          // 柔和
    SMOOTH = 2,          // 平滑
    ADAPTIVE = 10        // 自适应（按设备性能自动选）★本项目全用这个
  }
  function getSystemMaterialTypes(): Array<MaterialType>;
}
```

### 本项目的标准配置

```typescript
systemMaterialEffect: {
  materialType: hdsMaterial.MaterialType.IMMERSIVE,
  materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
}
```

**这一组配置就是本项目所有磨砂效果的来源**，出现在：

- `pages/MainPage.ets` 的 `HdsNavigation.titleBar()` 和 `HdsTabs.barFloatingStyle()`
- `pages/AiChatPage.ets` 的 `titleBarStyle()`
- `pages/HealthExpandPage.ets` 的 `titleBarStyle()`
- `pages/ResidentDetailPage.ets` 的 `titleBarStyle()`
- `pages/MineDetailPage.ets` 的 `titleBarStyle()`
- `component/TabPageView.ets` 的 `taskExpandTitleBarStyle()`

**为什么用 `ADAPTIVE` 而不是 `EXQUISITE`**：
`EXQUISITE` 模糊质量最高但 GPU 开销最大，低端机会掉帧。
`ADAPTIVE` 让系统按设备能力自动降级，是**生产环境的正确选择**。

---

## 8.4 `ScrollEffectType`：滚动特效

### 完整定义（SDK 原文）

```typescript
export declare enum ScrollEffectType {
  COMMON_BLUR = 0,               // 普通模糊
  GRADUAL_BLUR = 1,              // 渐进模糊
  GRADIENT_BLUR = 2,             // ★渐变模糊（本项目全用这个）
  IMMERSIVE_GRADIENT_BLUR = 3    // 沉浸渐变模糊
}
```

### 本项目的标准配置

```typescript
scrollEffectOpts: {
  enableScrollEffect: true,
  scrollEffectType: ScrollEffectType.GRADIENT_BLUR
}
```

**效果**：页面往上滚时，标题栏底部会出现一条**渐变的模糊带**，
内容从模糊中「浮出来」，这是鸿蒙系统 App 的标志性视觉。

### 仅配置 `scrollEffectOpts` 并不足够

要让标题栏知道「用户滚到哪了」，必须把 **Scroller 绑给它**：

```typescript
HdsNavigation(this.pathStack) { }
  .bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [])
  //  ↑ 传入一个 Scroller 数组
```

**本项目怎么准备这些 Scroller**（`model/TabsBarModel.ets`）：

```typescript
export const PAGE_SCROLLER_MAP: Map<PageKeyEnum, Scroller[]> = new Map([
  [PageKeyEnum.ADAPTIVE_TAB, new Array(4).fill(null).map(() => new Scroller())],
  //                          ↑ 4 个 Tab 各准备一个 Scroller
]);
```

**页面里怎么取用**（`component/TabPageView.ets`）：

```typescript
private currentScroller(): Scroller | undefined {
  return PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex];
}

// 然后传给 Scroll 组件
Scroll(this.currentScroller()) { /* 内容 */ }
```

**完整链条**：

```
预创建 4 个 Scroller（TabsBarModel）
        ↓
TabPageView 把对应的 Scroller 绑给自己的 Scroll 组件
        ↓
HdsNavigation.bindToScrollable([这 4 个 Scroller])
        ↓
用户滚动 → Scroller 上报 offset → HdsNavigation 计算模糊强度 → 标题栏渐变模糊
```

**如果漏了 `bindToScrollable`**：`enableScrollEffect: true` 也不会生效，标题栏永远是静态的。

### 还有一个 `bindToNestedScrollable`

```typescript
bindToNestedScrollable(scrollers: Array<NestedScrollInfo>): HdsNavigationAttribute;
```

用于嵌套滚动场景（外层 Scroll 里套内层 List）。

---

## 8.5 `HdsNavigation`：HDS 版导航容器

### 类型定义

```typescript
export declare type HdsNavigationInterface = (pathInfos?: NavPathStack) => HdsNavigationAttribute;
export declare const HdsNavigation: HdsNavigationInterface;
```

### 全部方法（SDK 实测，29 个）

```typescript
titleBar(options?: HdsNavigationTitleBarOptions)         // ★标题栏配置
titleMode(value: HdsNavigationTitleMode)                  // ★标题模式
hideTitleBar(hide: boolean, animated?: boolean)           // ★隐藏标题栏
hideBackButton(value: boolean)                            // ★隐藏返回按钮
navDestination(builder: NavDestinationBuilder)            // ★目的地构造器
mode(value: NavigationMode)                               // ★Stack/Split/Auto
bindToScrollable(scrollers: Array<Scroller>)              // ★绑定滚动条
bindToNestedScrollable(scrollers: Array<NestedScrollInfo>)
ignoreLayoutSafeArea(types?, edges?)                      // ★安全区
toolbarConfiguration(value, options?)
hideToolBar(hide, animated?)
navBarWidth(value: Length)
navBarWidthRange(value: NavBarWidthRangeOptions)
navBarPosition(value: NavBarPosition)
hideNavBar(value: boolean)
minContentWidth(value: Dimension)
divider(style: NavigationDividerStyle | null)
systemBarStyle(originalStyle, scrollEffectStyle)
recoverable(recoverable: Optional<boolean>)
dynamicHideTitleBar(value: DynamicHideParams)             // 动态隐藏标题栏
enableDragBar(isEnabled: Optional<boolean>)
enableModeChangeAnimation(isEnabled: Optional<boolean>)
customNavContentTransition(delegate: CustomTransitionDelegate)   // 自定义转场
withTheme(value: WithThemeOptions)
splitPlaceholder(placeholder: ComponentContent)
enableVisibilityLifecycleWithContentCover(isEnabled)
onNavBarStateChange(callback: Callback<boolean>)
onNavigationModeChange(callback: Callback<NavigationMode>)
onTitleModeChange(callback: Callback<HdsNavigationTitleMode>)
```

### `HdsNavigationTitleMode` 枚举（SDK 原文）

```typescript
export declare enum HdsNavigationTitleMode {
  FREE = 0,     // 自由模式（大标题滚动时缩小）
  FULL = 1,     // 完整模式（大标题）
  MINI = 2,     // ★迷你模式（小标题，本项目用这个）
  MODAL = 3     // 模态模式
}
```

### `titleBar()` 的参数结构（层层嵌套，要看清）

```typescript
export declare interface HdsNavigationTitleBarOptions {
  padding?: PaddingOptions;
  style?: TitleBarStyleOptions;              // ← 样式（材质、滚动特效）
  content?: TitleBarContentOptions;          // ← 内容（标题、菜单、返回键）
  enableHoverMode?: boolean;
  avoidLayoutSafeArea?: boolean;
  enableComponentSafeArea?: boolean;
}

export declare interface TitleBarContentOptions {
  title?: HdsNavigationTitle;                // 标题
  menu?: HdsNavigationMenuContentOptions;    // 右侧菜单
  backIcon?: HdsNavigationBackButtonItemOptions;   // 左侧返回图标
  stackBuilder?: CustomBuilder;              // ★完全自定义标题区
  stackBuilderComponent?: ComponentContent;
  stackBuilderContent?: BuilderType;
  bottomBuilder?: BottomBuilderParams;       // 标题栏下方的额外区域
  divider?: HdsNavigationDividerParams;
  subIcon?: HdsNavigationBadgeIconOptions;
}

export declare interface TitleBarStyleOptions {
  systemMaterialEffect?: SystemMaterialParams;   // 材质
  scrollEffectOpts?: ScrollEffectOptions;        // 滚动特效
  // ... 还有更多样式字段
}
```

### 本项目的完整用法（`pages/MainPage.ets`）

```typescript
HdsNavigation(this.pathStack) {
  if (this.isWideLayout()) { this.wideShell() }
  else { this.phoneTabs() }
}
.mode(NavigationMode.Stack)
.navDestination(this.destinationBuilder)
.titleBar({
  content: {
    title: {
      mainTitle: this.getCurrentPageTitle(),     // 标题跟随当前 Tab
    },
    menu: { value: [] },                          // 空菜单（占位，保持布局对称）
  },
  style: {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
    },
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
  },
})
.bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [])
.hideBackButton(true)                            // 首页不要返回按钮
.hideTitleBar(this.isWideLayout(), true)         // ★宽屏隐藏标题栏（用自己的顶栏）
.titleMode(HdsNavigationTitleMode.MINI)
.ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
.width('100%')
.height('100%')
```

**逐行解读**：

| 行 | 作用 |
|---|---|
| `HdsNavigation(this.pathStack)` | 绑定导航栈 |
| `{ ... }` 里的内容 | NavBar（首页内容），按断点分叉 |
| `.mode(Stack)` | 详情盖住首页（不分栏） |
| `.navDestination(...)` | 名字 → 组件的映射 |
| `.titleBar({content, style})` | 标题文字 + 磨砂 + 滚动模糊 |
| `.bindToScrollable(...)` | 让标题栏知道滚动位置 |
| `.hideBackButton(true)` | 首页没有上一页，不显示返回 |
| `.hideTitleBar(this.isWideLayout(), true)` | **宽屏时隐藏**（第二个参数 = 带动画） |
| `.titleMode(MINI)` | 小标题模式 |
| `.ignoreLayoutSafeArea(...)` | 布局忽略安全区（沉浸式） |

---

## 8.6 `HdsNavDestination`：HDS 版目的地页

### `HdsNavDestinationTitleMode`（SDK 原文）

```typescript
export declare enum HdsNavDestinationTitleMode {
  MINI = 100,     // ★迷你（本项目用）
  MODAL = 101     // 模态
}
```

**注意数值和 `HdsNavigationTitleMode` 不同**（100/101 vs 0/1/2/3），不要混用。

### 本项目的标准用法（`pages/HealthExpandPage.ets`）

```typescript
build() {
  Column() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.End }) {
        Scroll() { /* 内容 */ }
        AlphabetIndexer({ /* ... */ })
      }
      .width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hideBackButton(true)
    .titleBar({
      enableComponentSafeArea: false,           // ★关键：不要让 titleBar 自己避让
      style: this.titleBarStyle(),
      content: this.titleBarContent()
    })
  }
  .width('100%').height('100%')
  .backgroundColor($r('sys.color.background_secondary'))
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .padding({ top: this.globalInfoModel.statusBarHeight })    // ★自己加 padding
  .geometryTransition('healthCard')
  .transition(TransitionEffect.OPACITY)
}
```

**为什么 `enableComponentSafeArea: false` + 手动 `padding`**：

如果让 HDS 自己避让安全区，它会加一层 padding；
你外面又加了 `.padding({top: statusBarHeight})`，**就会双重避让**，标题栏被推得很低。

**本项目的统一策略**：**关掉组件自动避让，全部由页面根节点统一控制。**

### 提取的标题栏样式函数（本项目的通用套路）

```typescript
private titleBarStyle(): TitleBarStyleOptions {
  return {
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR
    }
  };
}

private titleBarContent(): TitleBarContentOptions {
  return {
    title: { mainTitle: '老人健康状态' },
    menu: {
      value: [{
        content: {
          icon: $r('sys.symbol.xmark'),
          isEnabled: true,
          action: () => { this.onClose(); }
        }
      }]
    }
  };
}
```

**把它们抽成方法而不是内联**，好处是 `build()` 干净，而且多个页面可以复制同一套。

### 高级用法：自定义标题区 `stackBuilder`

`pages/AiChatPage.ets`：

```typescript
@Builder
private titleBarTitleBuilder() {
  Row() {
    AiTitleLabel({ text: this.titleBarTitleText(), compact: true })
      .width('100%')
  }
  .width('100%')
  .height('100%')
  .padding({ left: 64, right: 112 })         // ← 手动给左右图标让位
  .alignItems(VerticalAlign.Center)
  .hitTestBehavior(HitTestMode.Transparent)  // ← ★点击穿透，不挡住下面的按钮
}

private titleBarContent(): TitleBarContentOptions {
  return {
    stackBuilder: (): void => this.titleBarTitleBuilder(),   // ★完全自定义标题区
    backIcon: {
      label: '打开菜单',
      icon: $r('sys.symbol.line_3_horizontal'),   // ← 返回位置放的是「菜单」图标
      type: IconStyleMode.SMALL,
      isEnabled: true,
      action: () => { this.openHistoryDrawer(); }
    },
    menu: {
      value: [
        {
          content: {
            label: '新建对话',
            icon: $r('sys.symbol.square_and_pencil'),
            type: IconStyleMode.SMALL,
            isEnabled: true,
            action: () => { this.startNewConversation(); }
          }
        },
        {
          content: {
            label: '关闭',
            icon: $r('sys.symbol.xmark'),
            type: IconStyleMode.SMALL,
            isEnabled: true,
            action: () => { this.closeChatPage(); }
          }
        }
      ]
    }
  };
}
```

**三个关键技巧**：

1. **`stackBuilder`** 让你完全接管标题区（这里放了一个带 AI 渐变效果的自定义标签）
2. **`padding({ left: 64, right: 112 })`** 手动避开左边 1 个图标（64）和右边 2 个图标（112）
3. **`hitTestBehavior(HitTestMode.Transparent)`** 让自定义标题区不拦截点击，
   否则会挡住下面的返回/菜单按钮

### `IconStyleMode` 枚举（SDK 原文）

```typescript
export declare enum IconStyleMode {
  SMALL = 100,
  NORMAL = 101,
  LARGE = 102
}
```

---

## 8.7 `HdsListItemCard`：通用列表行

### 完整配置项（SDK 原文）

```typescript
export declare interface HdsListItemCardOptions {
  prefixItem?: PrefixItem;               // 左侧
  textItem?: TextItemOptions;            // 中间文字
  suffixItem?: SuffixItem;               // 右侧
  onClick?: OnClickCallback;
  cardHeight?: Dimension;
  cardWidth?: Dimension;
  cardBackgroundColor?: ResourceColor;
  cardBorderRadius?: Dimension;
  cardPrefixMargin?: Dimension;          // 左侧内容的外边距
  cardSuffixMargin?: Dimension;          // 右侧内容的外边距
  hoverBorderRadius?: Dimension;         // 悬停时的圆角
  enable?: boolean;
  cardId?: string;
  accessibilityOptions?: AccessibilityOptions;
}
```

### `TextItemOptions`（中间文字区，支持三行 + 前后缀符号）

```typescript
export declare interface TextItemOptions {
  primaryText?: TextOptions;                     // ★主标题
  primaryPrefixSymbol?: TextSymbolGlyphOptions;  // 主标题前的小图标
  primarySuffixSymbol?: TextSymbolGlyphOptions;  // 主标题后的小图标
  primaryPrefixSubSymbol?: TextSymbolGlyphOptions;
  primarySuffixSubSymbol?: TextSymbolGlyphOptions;
  secondaryText?: TextOptions;                   // ★副标题
  secondaryPrefixSymbol?: TextSymbolGlyphOptions;
  secondarySuffixSymbol?: TextSymbolGlyphOptions;
  secondaryPrefixSubSymbol?: TextSymbolGlyphOptions;
  secondarySuffixSubSymbol?: TextSymbolGlyphOptions;
  description?: TextOptions;                     // 第三行描述
  descriptionPrefixSymbol?: TextSymbolGlyphOptions;
  descriptionSuffixSymbol?: TextSymbolGlyphOptions;
  descriptionPrefixSubSymbol?: TextSymbolGlyphOptions;
  descriptionSuffixSubSymbol?: TextSymbolGlyphOptions;
  customBuilder?: CustomBuilder;                 // 完全自定义
  accessibilityOptions?: AccessibilityOptions;
}
```

### 结构示意

```
┌───────────────────────────────────────────────────┐
│  [prefixItem]   primaryText          [suffixItem] │
│                 secondaryText                      │
│                 description                        │
└───────────────────────────────────────────────────┘
   ↑ 左              ↑ 中                  ↑ 右
   PrefixIcon        三行文字              SuffixArrow
   PrefixImage                             SuffixSwitch
   PrefixSwitch                            SuffixText
   ...                                     SuffixButton ...
```

### 本项目的 4 种典型用法

**① 图标 + 双行文字 + 箭头（PC 侧边栏用户信息）**

```typescript
// pages/MainPage.ets
HdsListItemCard({
  prefixItem: new PrefixIcon({
    iconSize: IconSize.SYSTEM_ICON,
    iconValue: {
      symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
        .fontColor([$r('sys.color.icon_secondary')])
    }
  }),
  textItem: {
    primaryText: { text: '李护工' },
    secondaryText: { text: '白班 08:00-18:00' }
  },
  suffixItem: new SuffixArrow(),
  cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
  cardHeight: 56,
  cardBorderRadius: 12,
  cardPrefixMargin: 0,
  cardSuffixMargin: 0
})
```

**② 导航项（带选中态）**

```typescript
// pages/MainPage.ets 的 pcNavItemExpanded
HdsListItemCard({
  prefixItem: new PrefixIcon({
    iconSize: IconSize.SYSTEM_ICON,
    iconValue: {
      symbol: new SymbolGlyphModifier(item.symbol)
        .fontColor([isActive ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        //          ↑ 用 Modifier 动态改颜色
    }
  }),
  textItem: { primaryText: { text: item.label } },
  suffixItem: item.badge ? new SuffixText({ text: item.badge }) : new SuffixArrow(),
  //          ↑ 有角标显示数字，没有显示箭头
  cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
    $r('sys.color.ohos_id_color_background_transparent'),
  cardHeight: 48,
  cardBorderRadius: 12,
  cardPrefixMargin: 4,
  cardSuffixMargin: 0
})
.focusable(true)
.focusOnTouch(true)
.onClick(() => { this.handleNavClick(item); })
```

**③ 只有图标（侧边栏折叠态）**

```typescript
HdsListItemCard({
  prefixItem: new PrefixIcon({ /* ... */ }),
  // 不传 textItem 和 suffixItem
  cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
    $r('sys.color.ohos_id_color_background_transparent'),
  cardHeight: 48,
  cardBorderRadius: 12,
  cardPrefixMargin: 0,
  cardSuffixMargin: 0
})
```

**④ 文字 + 右侧按钮（健康列表行）**

```typescript
// component/HealthListCard.ets
HdsListItemCard({
  textItem: {
    primaryText: { text: repeatItem.item.name },
    secondaryText: {
      text: `${repeatItem.item.age}岁 · ${repeatItem.item.room} · ${repeatItem.item.bed}`
    }
  },
  suffixItem: new SuffixButton({
    text: '查看',
    textColor: $r('sys.color.interactive_active')
  }),
  cardBorderRadius: 0,
  cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
  cardHeight: 68,
  cardPrefixMargin: -5,        // ★负边距，把内容往左拉
  cardSuffixMargin: -14,       // ★负边距，把按钮往右拉
  hoverBorderRadius: 0
})
```

**🔑 负 margin 的技巧**：`HdsListItemCard` 自带内边距，
如果你的外层容器已经有 padding，会显得内容缩得太靠里。
用负的 `cardPrefixMargin` / `cardSuffixMargin` 把它「拉」回去，视觉对齐。

**⑤ 带开关（设置页）**

```typescript
// pages/MineDetailPage.ets（示意）
HdsListItemCard({
  textItem: { primaryText: { text: '减少动效' } },
  suffixItem: new SuffixSwitch({
    isOn: this.reduceMotion,
    onChange: (isOn: boolean) => { this.reduceMotion = isOn; }
  })
})
```

### `IconSize` 枚举（SDK 原文）

```typescript
export declare enum IconSize {
  SMALL_ICON = 1,     // 小图标
  SYSTEM_ICON = 2     // ★系统标准图标（本项目全用这个）
}
```

### `PrefixIcon` 构造参数

```typescript
new PrefixIcon({
  iconSize: IconSize.SYSTEM_ICON,
  iconValue: {
    symbol: new SymbolGlyphModifier($r('sys.symbol.xxx')).fontColor([color])
    // 或者
    // image: { src: $r('app.media.xxx') }
  }
})
```

### 常用 Suffix 组件

```typescript
new SuffixArrow()                                         // 右箭头 >
new SuffixText({ text: '3' })                             // 文字
new SuffixButton({ text: '查看', textColor: $r('...') })   // 按钮
new SuffixSwitch({ isOn: true, onChange: (v) => {} })     // 开关
new SuffixBadgeAndArrow({ /* ... */ })                     // 角标 + 箭头
new SuffixTextAndArrow({ /* ... */ })                      // 文字 + 箭头
new SuffixCheckbox({ /* ... */ })
new SuffixSelect({ /* ... */ })
new SuffixCustomBuilder({ /* ... */ })                     // 完全自定义
```

---

## 8.8 `HdsTabs`：HDS 版页签

### 方法列表（SDK 实测）

```typescript
vertical(value: boolean)                     // 竖向页签（侧边）
barPosition(value: BarPosition)              // Start / End
scrollable(value: boolean)
barMode(value: HdsBarMode, options?)
barWidth(value: Length) / barHeight(value: Length)
animationDuration(value: number)
onChange(event: Callback<number>)            // ★切换回调
onSelected / onUnselected
onTabBarClick(event: Callback<number>)
onContentWillChange(handler)
onAnimationStart(handler)
divider(value: Optional<HdsDividerStyle>)
barOverlap(value: boolean)                   // ★内容延伸到 bar 下面
barBackgroundColor(value: ResourceColor)
barBackgroundEffect(options: BackgroundEffectOptions)
barBackgroundBlurStyle(style: BlurStyle, options?)
barBackgroundStyle(backgroundStyle)
barFloatingStyle(barFloatingStyle?)          // ★悬浮样式（磨砂 + 上浮）
blurStrategy(value: BlurStrategy)
cachedMaxCount(count: number, mode: TabsCacheMode)
```

### `HdsTabsController`

```typescript
export declare class HdsTabsController extends TabsController {
  // 继承 TabsController 的方法：
  changeIndex(index: number): void;       // 切换到第几个
  preloadItems(indices: Array<number>): Promise<void>;   // ★预加载
}
```

### 本项目的完整用法（`pages/MainPage.ets`）

```typescript
private controller: HdsTabsController = new HdsTabsController();
private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.ADAPTIVE_TAB) ?? [];

@Builder
private phoneTabs() {
  HdsTabs({ controller: this.controller }) {
    TabContent() {
      TabPageView({
        currentTabIndex: 0,
        pageKey: PageKeyEnum.ADAPTIVE_TAB,
        config: this.pageConfigs[0],
        onSwitchTab: (index: number) => { this.switchTab(index); },
        onOpenAiChat: () => { this.openAiChat(); }
      })
    }
    .tabBar(this.tabsBar[0])           // ← 用预先构造好的 BottomTabBarStyle

    TabContent() { TabPageView({ currentTabIndex: 1, /* ... */ }) }.tabBar(this.tabsBar[1])
    TabContent() { TabPageView({ currentTabIndex: 2, /* ... */ }) }.tabBar(this.tabsBar[2])
    TabContent() { TabPageView({ currentTabIndex: 3, /* ... */ }) }.tabBar(this.tabsBar[3])
  }
  .barOverlap(true)                    // ★内容延伸到 TabBar 下面（配合磨砂）
  .vertical(false)                     // 横向（底部）
  .onChange((index: number) => { this.updateTabSelection(index); })
  .barPosition(BarPosition.End)        // 在底部
  .barFloatingStyle({                  // ★悬浮样式
    barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ?
      this.globalInfoModel.naviIndicatorHeight : $r('sys.float.padding_level8'),
      // ↑ 有导航条就贴导航条上方，没有就留 16vp
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
  })
  .onAttach(() => {
    try {
      this.controller.preloadItems([0, 1, 2, 3]);    // ★预加载全部 4 个 Tab
    } catch (error) {
      Logger.error(TAG, 'OnAttach preloadItems failed');
    }
  })
}
```

**四个关键点**：

| 配置 | 作用 |
|---|---|
| `.barOverlap(true)` | 内容滚到 TabBar 下面（磨砂效果才有意义） |
| `.barFloatingStyle({...})` | TabBar 悬浮 + 磨砂（不是贴底的实心条） |
| `barBottomMargin` 动态取值 | 有手势导航条就贴它上面，没有（如 PC）就留标准间距 |
| `.onAttach(() => preloadItems([0,1,2,3]))` | 一次性预加载全部 Tab，切换零延迟 |

**`preloadItems` 的权衡**：预加载所有 Tab 会增加首次启动时的内存和耗时。
本项目只有 4 个 Tab、数据是 mock 的，所以全加载没问题。
如果 Tab 内容重（比如有网络请求），应该只预加载相邻的。

### TabBar 样式怎么构造（`model/TabsBarModel.ets`）

```typescript
export class TabsBarModel {
  private static pageTabBarStyleMap: Map<PageKeyEnum, BottomTabBarStyle[]> = new Map();

  public static getTabBarByPage(pageKey: PageKeyEnum): BottomTabBarStyle[] {
    const tabBarStyleList: BottomTabBarStyle[] = [];
    if (!TabsBarModel.pageTabBarStyleMap.has(pageKey)) {      // ★缓存：只构造一次
      const tabBarList = PAGE_BAR_MAP.get(pageKey);
      if (tabBarList) {
        tabBarList.forEach((item: BarItem) => {
          const tabBarStyle = new BottomTabBarStyle({
            normal: new SymbolGlyphModifier(item.normalSymbolResource)
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
              .fontColor([item.normalColor]),
            selected: new SymbolGlyphModifier(item.selectedSymbolResource)
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
              .fontColor([item.selectedColor])
          }, item.label)
            .labelStyle({
              unselectedColor: item.normalColor,
              selectedColor: item.selectedColor,
            });
          tabBarStyleList.push(tabBarStyle);
        });
      }
      TabsBarModel.pageTabBarStyleMap.set(pageKey, tabBarStyleList);
    }
    return TabsBarModel.pageTabBarStyleMap.get(pageKey) ?? [];
  }
}
```

**为什么要缓存**：`BottomTabBarStyle` 和 `SymbolGlyphModifier` 都是对象，
每次 `build()` 重建会产生大量垃圾对象。缓存后只构造一次。

**⚠️ 命名陷阱**（本项目的历史遗留问题）：

```typescript
$r('app.string.tab_music')     // 实际显示的是「长者」
$r('app.string.tab_message')   // 实际显示的是「任务」
```

这两个资源 key 是从音乐 App 模板继承来的，**名字和实际含义不符**。
改代码时**不要相信 key 名，要看 `string.json` 里的实际值**。

---

## 8.9 `HdsActionBar`：操作栏

```typescript
import { HdsActionBar, ActionBarButton, ActionBarStyle } from '@kit.UIDesignKit';
```

本项目在 `pages/AiChatPage.ets` 里 import 了它（用于聊天输入区的操作按钮）。

```typescript
HdsActionBar({
  buttons: [
    new ActionBarButton({ /* ... */ }),
  ],
  style: ActionBarStyle.XXX
})
```

---

## 8.10 其它 HDS 组件（本项目未使用）

### `HdsSideBar` / `HdsSideMenu`

```typescript
import { HdsSideBar, HdsSideMenu, HdsSideMenuMainItem, HdsSideMenuSubItem } from '@kit.UIDesignKit';
```

**本项目没用**，PC 侧边栏是手写的（`pages/MainPage.ets` 的 `pcSidebar()`）。
手写的好处是可以精确控制折叠动画和布局细节。

### `HdsSnackBar`

```typescript
import { HdsSnackBar, SnackBarOperationType, SnackBarIconType } from '@kit.UIDesignKit';
```

带操作按钮的轻提示（比 Toast 强）。

### `HdsVisualComponent`

```typescript
import { HdsVisualComponent, HdsSceneController, HdsSceneType, DualEdgeFlowLightWithMaskParam } from '@kit.UIDesignKit';
```

视觉特效组件（流光、遮罩等），用于 AI 场景的高级动效。

### `HdsListItem` + `HdsSwipeActionOptions`

带滑动操作（左滑删除等）的列表项。

### `MultiWindowEntryInAPP`

应用内多窗口入口（PC 场景）。

---

## 8.11 HDS 使用规范

### 规范 1：标题栏「三件套」永远一起写

```typescript
private titleBarStyle(): TitleBarStyleOptions {
  return {
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR
    }
  };
}
```

配上 `.bindToScrollable([...])`，效果才完整。

### 规范 2：`HdsNavDestination` 页面统一配置

```typescript
HdsNavDestination() { /* 内容 */ }
  .titleMode(HdsNavDestinationTitleMode.MINI)
  .hideBackButton(true)                                        // 浮层用自己的关闭按钮
  .titleBar({
    enableComponentSafeArea: false,                            // ★关掉自动避让
    style: this.titleBarStyle(),
    content: this.titleBarContent()
  })
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
```

外层容器再统一 `.padding({ top: statusBarHeight })`。

### 规范 3：图标一律用 `sys.symbol.*`

```typescript
$r('sys.symbol.house_fill')
```

不要用 `app.media.*` 的位图图标（除非是品牌 logo）。
系统符号会自动跟随深色模式、自动适配字号、支持多色渲染。

### 规范 4：颜色一律用 token

```typescript
$r('sys.color.font_primary')                          // 系统 token（优先）
$r('app.color.brand_blue')                            // 应用 token（品牌色）
$r('sys.color.ohos_id_color_background_transparent')  // 透明
```

不要写死 `'#1D63ED'`。第 10 章详讲。

### 规范 5：`HdsListItemCard` 的对齐用负 margin 修

```typescript
cardPrefixMargin: -5,
cardSuffixMargin: -14,
```

不要在外层加负 padding（那会影响点击热区）。

---

## 8.12 HDS 常见问题

### Q1：设了 `enableScrollEffect: true` 但标题栏不模糊？

漏了 `.bindToScrollable([scroller])`，或者 Scroller 没绑到实际滚动的组件上。

### Q2：标题栏被状态栏遮住 / 位置太低？

`enableComponentSafeArea` 和外层 `padding` 冲突了。统一策略：
`enableComponentSafeArea: false` + 外层手动 `padding({ top: statusBarHeight })`。

### Q3：`HdsListItemCard` 的内容和外面的对不齐？

用 `cardPrefixMargin` / `cardSuffixMargin`（可以是负数）微调。

### Q4：TabBar 挡住了内容？

用 `.barOverlap(true)` 让内容延伸过去，然后给内容底部留 padding：

```typescript
private bottomPadding(): number {
  return this.isWideLayout() ? 36 : 124;
}
```

### Q5：`HdsNavigationTitleMode` 和 `HdsNavDestinationTitleMode` 混用报错？

它们是**两个不同的枚举**，数值也不同（0/1/2/3 vs 100/101）。
`HdsNavigation` 用前者，`HdsNavDestination` 用后者。

### Q6：自定义标题区挡住了返回/菜单按钮？

加 `.hitTestBehavior(HitTestMode.Transparent)`。

### Q7：磨砂效果在低端机上很卡？

`materialLevel` 用 `ADAPTIVE` 而不是 `EXQUISITE`。

### Q8：HDS 组件在 Previewer 里显示不正常？

HDS 依赖运行时的系统材质能力，Previewer 支持有限。以真机/模拟器为准。

---

## 8.13 本章速查

```typescript
import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController,
  HdsListItemCard, PrefixIcon, SuffixArrow, SuffixText, SuffixButton, SuffixSwitch,
  hdsMaterial, ScrollEffectType, IconSize, IconStyleMode,
  HdsNavigationTitleMode, HdsNavDestinationTitleMode,
  TitleBarContentOptions, TitleBarStyleOptions
} from '@kit.UIDesignKit';

// —— 标题栏样式（复制粘贴用）——
private titleBarStyle(): TitleBarStyleOptions {
  return {
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR
    }
  };
}

// —— 标题栏内容（带关闭按钮）——
private titleBarContent(): TitleBarContentOptions {
  return {
    title: { mainTitle: '标题' },
    menu: {
      value: [{
        content: {
          icon: $r('sys.symbol.xmark'),
          isEnabled: true,
          action: () => { this.onClose(); }
        }
      }]
    }
  };
}

// —— 列表行 ——
HdsListItemCard({
  prefixItem: new PrefixIcon({
    iconSize: IconSize.SYSTEM_ICON,
    iconValue: { symbol: new SymbolGlyphModifier($r('sys.symbol.gearshape')).fontColor([$r('sys.color.icon_secondary')]) }
  }),
  textItem: {
    primaryText: { text: '主标题' },
    secondaryText: { text: '副标题' }
  },
  suffixItem: new SuffixArrow(),
  cardHeight: 56,
  cardBorderRadius: 12,
  cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
  cardPrefixMargin: 0,
  cardSuffixMargin: 0
})
.onClick(() => { })

// —— 悬浮磨砂 TabBar ——
HdsTabs({ controller: this.controller }) { /* TabContent × N */ }
  .barOverlap(true)
  .barPosition(BarPosition.End)
  .barFloatingStyle({
    barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ?
      this.globalInfoModel.naviIndicatorHeight : $r('sys.float.padding_level8'),
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
  })
  .onAttach(() => { this.controller.preloadItems([0, 1, 2, 3]); })
```

---

下一章 → [09-一多适配.md](./09-一多适配.md)
