# 康小伴AI护工端 - 核心实现文档

> 本文档记录项目中 TabBar、MiniBar、沉浸式、响应式布局、一镜到底转场等核心技术的完整实现方案。

---

## 目录

1. [响应式布局与双布局分流](#1-响应式布局与双布局分流)
2. [TabBar 悬浮页签](#2-tabbar-悬浮页签)
3. [MiniBar 迷你栏](#3-minibar-迷你栏)
4. [沉浸式显示](#4-沉浸式显示)
5. [一镜到底转场动画](#5-一镜到底转场动画)
6. [键盘适配](#6-键盘适配)
7. [路由与页面栈管理](#7-路由与页面栈管理)

---

## 1. 响应式布局与双布局分流

### 1.1 断点系统

**断点来源**：`GlobalInfoModel.widthBreakpoint`（`@Trace` 字段），由 `WindowUtil` 监听 `windowSizeChange` 事件写入。

```typescript
// WindowUtil.ets
windowClass.on('windowSizeChange', (windowSize) => {
  WindowUtil.setWindowSize(windowSize);
});

public static setWindowSize(windowSize?: window.Size | window.Rect) {
  const globalInfoModel = AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, ...) ?? new GlobalInfoModel();
  globalInfoModel.widthBreakpoint = WindowUtil.uiContext.getWindowWidthBreakpoint();
  globalInfoModel.heightBreakpoint = WindowUtil.uiContext.getWindowHeightBreakpoint();
  AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => globalInfoModel);
}
```

**断点取值工具**：`BreakpointType<T>` 泛型值选择器

```typescript
// BreakpointSystem.ets
export class BreakpointType<T> {
  constructor(param: BreakpointTypeOptions<T>) {
    this.xs = param.xs ?? param.sm;   // xs 缺省回退到 sm
    this.sm = param.sm;
    this.md = param.md;
    this.lg = param.lg;
    this.xl = param.xl ?? param.lg;   // xl 缺省回退到 lg
  }
  public getValue(currentBreakpoint: WidthBreakpoint): T { ... }
}

// 使用示例
const padding = new BreakpointType<number>({ sm: 16, md: 24, lg: 28, xl: 32 });
const value = padding.getValue(globalInfoModel.widthBreakpoint);
```

### 1.2 双布局分流

**MainPage.build()** 根据 `isWideLayout()` 分流：

```typescript
// MainPage.ets
private isWideLayout(): boolean {
  const bp = this.globalInfoModel.widthBreakpoint;
  return bp === WidthBreakpoint.WIDTH_MD ||
    bp === WidthBreakpoint.WIDTH_LG ||
    bp === WidthBreakpoint.WIDTH_XL;
}

build() {
  HdsNavigation(this.pathStack) {
    if (this.isWideLayout()) {
      this.wideShell()    // 宽屏：侧边栏 + 顶栏 + 内容
    } else {
      this.phoneTabs()    // 手机：底部Tab + 内容
    }
  }
}
```

### 1.3 宽屏三栏布局

```typescript
// MainPage.ets - wideShell()
@Builder
private wideShell() {
  Row({ space: 0 }) {
    // 左：侧边栏
    Column() { this.pcSidebar() }
      .width(this.sidebarWidth())   // 展开288 / 折叠72
      .height('100%')

    // 右：顶栏 + 内容
    Column() {
      this.pcTopBar()               // 64vp 高顶栏
      Column() {
        TabPageView({ ... })        // 当前Tab内容
      }
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
}
```

### 1.4 侧边栏折叠动画

```typescript
private sidebarWidth(): number {
  return this.isSidebarCollapsed ? 72 : 288;
}

private toggleSidebar(): void {
  this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
    this.isSidebarCollapsed = !this.isSidebarCollapsed;
  });
}
```

### 1.5 TabPageView 内部分栏

```typescript
// TabPageView.ets - 长者页/任务页在宽屏下分栏
private isWideLayout(): boolean {
  return this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
    this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
    this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_XL;
}

private isExtraWideLayout(): boolean {
  return this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
    this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_XL;
}

// 分栏宽度
private listWidth(): number {
  return this.isExtraWideLayout() ? 380 : 320;  // 长者列表
}
```

### 1.6 页面内边距响应式

```typescript
// TabPageView.ets
private pagePadding(): number {
  return new BreakpointType<number>({ sm: 16, md: 24, lg: 28, xl: 32 })
    .getValue(this.globalInfoModel.widthBreakpoint);
}

private bottomPadding(): number {
  return this.isWideLayout() ? 36 : 124;  // 手机留底部Tab空间
}

private topPadding(): number {
  return this.isWideLayout() ? 0 : this.globalInfoModel.statusBarHeight + 16 + 40;
}
```

---

## 2. TabBar 悬浮页签

### 2.1 Tab 数据模型

```typescript
// TabsBarModel.ets
private static pageTabBarStyleMap: Map<PageKeyEnum, BottomTabBarStyle[]> = new Map();

public static getTabBarByPage(pageKey: PageKeyEnum): BottomTabBarStyle[] {
  if (!TabsBarModel.pageTabBarStyleMap.has(pageKey)) {
    const tabBarStyleList: BottomTabBarStyle[] = [];
    // 构造4个Tab样式...
    TabsBarModel.pageTabBarStyleMap.set(pageKey, tabBarStyleList);
  }
  return TabsBarModel.pageTabBarStyleMap.get(pageKey) ?? [];
}

// 单个Tab样式
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
```

### 2.2 HdsTabs 实现

```typescript
// MainPage.ets - phoneTabs()
@Builder
private phoneTabs() {
  HdsTabs({ controller: this.controller }) {
    TabContent() { TabPageView({ currentTabIndex: 0, ... }) }.tabBar(this.tabsBar[0])
    TabContent() { TabPageView({ currentTabIndex: 1, ... }) }.tabBar(this.tabsBar[1])
    TabContent() { TabPageView({ currentTabIndex: 2, ... }) }.tabBar(this.tabsBar[2])
    TabContent() { TabPageView({ currentTabIndex: 3, ... }) }.tabBar(this.tabsBar[3])
  }
  .barOverlap(true)                    // 底栏悬浮覆盖内容
  .vertical(false)
  .barPosition(BarPosition.End)
  .barFloatingStyle({
    barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0
      ? this.globalInfoModel.naviIndicatorHeight
      : $r('sys.float.padding_level8'),
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    miniBar: {
      miniBarBuilder: () => this.miniBarBuilder(),
      onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
        this.isMiniBar = miniBarStyle === HdsBarStyle.COLLAPSE;
      }
    }
  })
  .onChange((index: number) => {
    this.currentTabIndex = index;
  })
  .onAttach(() => {
    this.controller.preloadItems([0, 1, 2, 3]);  // 预加载所有Tab
  })
}
```

### 2.3 关键配置说明

| 配置 | 作用 |
|------|------|
| `barOverlap(true)` | 底栏悬浮在内容之上，内容需额外 padding |
| `barFloatingStyle.barBottomMargin` | 底栏距屏幕底部距离，适配导航指示条 |
| `systemMaterialEffect` | 沉浸式材质，`IMMERSIVE` + `ADAPTIVE` |
| `miniBar.miniBarBuilder` | 中间凸起按钮的自定义构建器 |
| `onBarStyleChange` | miniBar 展开/折叠回调 |
| `preloadItems` | 预加载所有 TabContent，提升切换流畅度 |

---

## 3. MiniBar 迷你栏

### 3.1 实现原理

MiniBar 是 HdsTabs 底部 Tab 栏中间的凸起按钮，由 `barFloatingStyle.miniBar` 配置触发。系统自动管理 Tab 栏与 MiniBar 的互斥展开：设备宽度 < 600vp 时 MiniBar 默认折叠，点击展开同时 Tab 栏折叠。

### 3.2 MiniBar 构建器

```typescript
// MainPage.ets
@Local isMiniBar: boolean = true;  // true=折叠态(仅图标), false=展开态(图标+文字)

@Builder
private miniBarBuilder() {
  Row({ space: 8 }) {
    SymbolGlyph($r('sys.symbol.plus'))
      .fontSize(22)
      .fontColor([$r('sys.color.white')])
      .backgroundColor($r('app.color.brand_blue'))
      .width(this.isMiniBar ? 36 : 44)
      .height(this.isMiniBar ? 36 : 44)
      .borderRadius(this.isMiniBar ? 18 : 22)

    if (!this.isMiniBar) {
      Column({ space: 4 }) {
        Text('入住登记')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text('预排 03  空床 12')
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
  }
  .width('100%')
  .padding({
    left: this.isMiniBar ? 6 : 4,
    right: this.isMiniBar ? 6 : 12,
    top: this.isMiniBar ? 4 : 8,
    bottom: this.isMiniBar ? 4 : 8
  })
  .onClick(() => {
    this.openCheckInFlow();  // 跳转入住登记页
  })
}
```

### 3.3 展开状态联动

```typescript
// barFloatingStyle 回调
miniBar: {
  miniBarBuilder: () => this.miniBarBuilder(),
  onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
    this.isMiniBar = miniBarStyle === HdsBarStyle.COLLAPSE;
    // isMiniBar 变化触发 miniBarBuilder 重新渲染
  }
}
```

---

## 4. 沉浸式显示

### 4.1 窗口沉浸式初始化

```typescript
// WindowUtil.ets
public static initialize(windowStage: window.WindowStage) {
  WindowUtil.windowClass = windowStage.getMainWindowSync();
  const uiContext = WindowUtil.windowClass.getUIContext();
  AppStorageV2.connect(UIContext, StorageKey.UI_CONTEXT, () => uiContext);
  WindowUtil.setImmersiveMode(false);
  WindowUtil.registerBreakpoint(WindowUtil.windowClass);
}

public static setImmersiveMode(enable: boolean): void {
  WindowUtil.windowClass.setWindowLayoutFullScreen(enable);
  WindowUtil.windowClass.setWindowSystemBarProperties({
    statusBarColor: '#00000000',        // 状态栏透明
    navigationBarColor: '#00000000'     // 导航栏透明
  });
}
```

### 4.2 安全区避让监听

```typescript
// WindowUtil.ets - registerBreakpoint()
windowClass.on('avoidAreaChange', (avoidAreaOption) => {
  if (avoidAreaOption.type === window.AvoidAreaType.TYPE_SYSTEM) {
    // 状态栏
    globalInfoModel.statusBarHeight = uiContext.px2vp(avoidAreaOption.area?.topRect?.height ?? 0);
  } else if (avoidAreaOption.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
    // 导航指示条
    globalInfoModel.naviIndicatorHeight = uiContext.px2vp(avoidAreaOption.area?.bottomRect?.height ?? 0);
  } else if (avoidAreaOption.type === window.AvoidAreaType.TYPE_KEYBOARD) {
    // 软键盘
    globalInfoModel.keyboardHeight = uiContext.px2vp(avoidAreaOption.area?.bottomRect?.height ?? 0);
  }
});
```

### 4.3 页面沉浸式应用

**方式一：expandSafeArea 扩展到安全区**

```typescript
// MainPage / ResidentDetailPage / HealthExpandPage 等
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
// 主动扩展到状态栏和导航条区域，再通过 padding 精确控制留白
.padding({ top: this.globalInfoModel.statusBarHeight })
```

**方式二：HdsNavigation 标题栏材质**

```typescript
// MainPage.ets
HdsNavigation(this.pathStack) { ... }
.titleBar({
  style: {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,  // 渐变模糊
    },
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,   // 沉浸式材质
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE   // 自适应级别
    },
  },
})
.ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
```

**方式三：HDS 材质探测与降级**

```typescript
// MaterialUtil.ets
public static isMaterialSupported(): boolean {
  return hdsMaterial.getSystemMaterialTypes().length > 0;
}

public static getSystemMaterialEffectOptions(): SystemMaterialEffectOptions {
  return {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
    color: undefined
  };
}

// 不支持 HDS 时降级
public static applyFallbackBackground(modifier: CommonModifier, options: FallbackOptions): CommonModifier {
  if (options.backgroundColor) modifier.backgroundColor(options.backgroundColor);
  if (options.backgroundBlurStyle) modifier.backgroundBlurStyle(options.backgroundBlurStyle);
  return modifier;
}
```

---

## 5. 一镜到底转场动画

### 5.1 核心原理

一镜到底（Shared Element Transition）通过 `geometryTransition` 绑定同一 ID 实现元素在两个页面间的无缝形变过渡。配合 `bindContentCover` 全屏模态和弹簧曲线动画。

### 5.2 起点与终点配置

```typescript
// 起点（列表项卡片）
.geometryTransition(id, { follow: true })        // follow:true 跟随终点形变
.transition(TransitionEffect.OPACITY)             // 配合淡入淡出

// 终点（全屏展开页）
.geometryTransition(id)                           // 不带 follow
.transition(TransitionEffect.OPACITY)
```

### 5.3 弹簧曲线参数

```typescript
import { curves } from '@kit.ArkUI';

// 打开：328/36（稍快）
curves.interpolatingSpring(0, 1, 328, 36)

// 关闭：342/38（稍慢，符合物理回弹感）
curves.interpolatingSpring(0, 1, 342, 38)
```

### 5.4 搜索一镜到底

**起点：首页搜索栏**

```typescript
// TabPageView.ets - homePage 中的搜索栏
Row() {
  SymbolGlyph($r('sys.symbol.magnifyingglass')) ...
  Text('搜索姓名、房间或设备') ...
}
.geometryTransition(this.geometryId, { follow: true })
.transition(TransitionEffect.OPACITY.animation({
  duration: 200,
  curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1)
}))
.onClick(() => { this.onSearchClicked(); })

.bindContentCover(this.isSearchPageShow, this.searchCoverBuilder, {
  modalTransition: ModalTransition.NONE,           // 禁用系统默认转场
  backgroundColor: 'rgba(0,0,0,0)'                 // 透明背景
})
```

**触发打开**

```typescript
private onSearchClicked(): void {
  this.geometryId = 'search';
  this.getUIContext().animateTo({
    duration: 100,
    curve: curves.interpolatingSpring(0, 1, 324, 38)
  }, () => {
    this.isSearchPageShow = true;
    this.homeSearchState.isSearchOpen = true;
  })
}
```

**触发关闭**

```typescript
private onArrowClicked(): void {
  const useGeo: boolean = this.geometryId !== '';
  if (useGeo) {
    // 有 geometryTransition：用弹簧曲线
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isSearchPageShow = false;
      this.homeSearchState.isSearchOpen = false;
      this.homeSearchText = '';
      this.geometryId = '';
    })
  } else {
    // 无 geometryTransition：退化为透明度渐变
    this.getUIContext().animateTo({
      duration: 300,
      curve: Curve.EaseInOut
    }, () => {
      this.isSearchPageShow = false;
      this.homeSearchState.isSearchOpen = false;
      this.homeSearchText = '';
    })
  }
}
```

**终点：searchCoverBuilder**

```typescript
@Builder
private searchCoverBuilder() {
  Column() {
    Row() {
      // 返回按钮（进入延迟150ms / 退出0ms）
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.opacity(0)
              .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200, delay: 150 }),
            TransitionEffect.opacity(0)
              .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200 }),
          ))
      }
      .onClick(() => { this.onArrowClicked(); })

      // 搜索框（终点 geometryTransition）
      Search({ value: this.homeSearchText, placeholder: '搜索姓名、房间或设备' })
        .geometryTransition(this.geometryId, { follow: true })
        .transition(TransitionEffect.OPACITY.animation({
          duration: 200,
          curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1)
        }))
        .defaultFocus(true)
    }

    // 搜索历史列表
    List() { ... }
  }
}
```

### 5.5 长者详情一镜到底

**起点：长者列表卡片**

```typescript
// TabPageView.ets - residentListRow
if (isExpanded) {
  Column() {}  // 选中态渲染空 Column 占位，承载 geometryTransition morph
    .geometryTransition(residentGeometryId(id), { follow: true })
    .transition(TransitionEffect.OPACITY)
} else {
  // 正常卡片渲染
  HdsListItemCard({ ... })
    .geometryTransition(residentGeometryId(id), { follow: true })
    .transition(TransitionEffect.OPACITY)
    .onClick(() => { this.openResidentDetail(resident); })
}

.bindContentCover(this.isResidentDetailShow, this.residentDetailCover, {
  modalTransition: ModalTransition.NONE,
  backgroundColor: 'rgba(0,0,0,0)',
  onWillDismiss: (dismissContentCoverAction) => {
    // 拦截物理返回
    if (dismissContentCoverAction.reason === DismissReason.PRESS_BACK) {
      this.closeResidentDetail();
    }
  }
})
```

**打开/关闭方法**

```typescript
private openResidentDetail(resident: ResidentData): void {
  this.selectedResident = resident;
  this.activeResidentGeometryId = residentGeometryId(resident.id);
  this.getUIContext().animateTo({
    curve: curves.interpolatingSpring(0, 1, 328, 36)   // 打开弹簧
  }, () => {
    this.isResidentDetailShow = true;
  })
}

private closeResidentDetail(): void {
  this.getUIContext().animateTo({
    curve: curves.interpolatingSpring(0, 1, 342, 38)   // 关闭弹簧
  }, () => {
    this.isResidentDetailShow = false;
    this.activeResidentGeometryId = '';
    this.selectedResident = null;
  })
}
```

**终点：ResidentDetailPage**

```typescript
// ResidentDetailPage.ets
@Param @Require resident: ResidentData;
@Param @Require geometryId: string;
@Event onClose: () => void = () => {};

build() {
  HdsNavDestination() {
    Stack({ alignContent: Alignment.End }) {
      Scroll() {
        Column({ space: 12 }) {
          // 14个业务卡片...
        }
      }
    }
  }
  .hideBackButton(true)
  .titleBar({
    title: { mainTitle: this.resident.name },
    menu: {
      value: [{
        content: {
          icon: $r('sys.symbol.xmark'),       // 右上角关闭按钮
          action: () => { this.onClose(); }
        }
      }]
    }
  })
  .geometryTransition(this.geometryId)               // 终点不带 follow
  .transition(TransitionEffect.OPACITY)
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .padding({ top: this.globalInfoModel.statusBarHeight })
}
```

### 5.6 健康卡片一镜到底

**起点：HealthListCard**

```typescript
// HealthListCard.ets
@Param isExpanded: boolean = false;
@Event onCardExpand: () => void = () => {};

if (this.isExpanded) {
  Column() {}  // 占位
    .geometryTransition('healthCard', { follow: true })
} else {
  // 正常卡片
  Row() { Text('老人健康状态') ... SymbolGlyph($r('sys.symbol.chevron_right')) }
    .onClick(() => { this.onCardExpand(); })
}
```

**终点：HealthExpandPage**

```typescript
// HealthExpandPage.ets
@Event onClose: () => void = () => {};

build() {
  HdsNavDestination() {
    Stack({ alignContent: Alignment.End }) {
      Scroll() {
        Column({ space: 12 }) {
          Repeat<ElderGroup>(this.elderGroups())
            .each((groupItem) => {
              // 楼层分组 + 长者列表
            })
        }
      }
      // 右侧 AlphabetIndexer 楼层索引
      AlphabetIndexer({ ... }).autoCollapse(true)
    }
  }
  .hideBackButton(true)
  .titleBar({
    title: { mainTitle: '老人健康状态' },
    menu: {
      value: [{
        content: {
          icon: $r('sys.symbol.xmark'),
          action: () => { this.onClose(); }
        }
      }]
    }
  })
  .geometryTransition('healthCard')                  // 硬编码 ID，不带 follow
  .transition(TransitionEffect.OPACITY)
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .padding({ top: this.globalInfoModel.statusBarHeight })
}
```

### 5.7 一镜到底通用模式总结

```typescript
// 通用打开方法
private openTransition(showFlag: string, geometryId: string): void {
  this.getUIContext().animateTo({
    curve: curves.interpolatingSpring(0, 1, 328, 36)
  }, () => {
    this[showFlag] = true;
  })
}

// 通用关闭方法
private closeTransition(showFlag: string, geometryId: string): void {
  this.getUIContext().animateTo({
    curve: curves.interpolatingSpring(0, 1, 342, 38)
  }, () => {
    this[showFlag] = false;
    this.geometryId = '';
  })
}

// 通用 bindContentCover 配置
.bindContentCover(isShow, coverBuilder, {
  modalTransition: ModalTransition.NONE,
  backgroundColor: 'rgba(0,0,0,0)',
  onWillDismiss: (action) => {
    if (action.reason === DismissReason.PRESS_BACK) {
      this.closeTransition();
    }
  }
})
```

---

## 6. 键盘适配

### 6.1 全局键盘高度监听

```typescript
// WindowUtil.ets
windowClass.on('avoidAreaChange', (avoidAreaOption) => {
  if (avoidAreaOption.type === window.AvoidAreaType.TYPE_KEYBOARD) {
    const globalInfoModel = AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, ...) ?? new GlobalInfoModel();
    globalInfoModel.keyboardHeight = WindowUtil.uiContext.px2vp(avoidAreaOption.area?.bottomRect?.height ?? 0);
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => globalInfoModel);
  }
});
```

### 6.2 页面消费键盘高度

```typescript
// LoginPage.ets
@Local keyboardOffset: number = 0;
@Local globalInfoModel: GlobalInfoModel = AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

// @Monitor 精确监听字段路径
@Monitor('globalInfoModel.keyboardHeight')
onKeyboardHeightChange(): void {
  this.getUIContext().animateTo({
    duration: 400,
    curve: Curve.EaseOut                    // EaseOut 平滑滑动，避免突跳
  }, () => {
    this.keyboardOffset = this.globalInfoModel.keyboardHeight;
  })
}

build() {
  Column() {
    // 顶部内容...
    Column() {
      // 表单内容...
    }
    .padding({ bottom: this.keyboardOffset })  // 动态底部 padding
  }
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  .padding({ top: this.globalInfoModel.statusBarHeight })
}
```

### 6.3 关键要点

| 要点 | 说明 |
|------|------|
| 不要用 `expandSafeArea(KEYBOARD)` | 会与手动位移冲突，导致双重避让 |
| 用 `@Monitor` 而非 `@Watch` | V2 体系下精确监听对象属性路径 |
| 用 `animateTo` 显式动画 | 控制动画时长和曲线，避免系统默认突跳 |
| `EaseOut` 曲线 400ms | 键盘弹出末段减速，符合自然感 |
| `keyboardOffset` 独立于 `keyboardHeight` | 让本页有独立的动画控制，不污染全局 |

---

## 7. 路由与页面栈管理

### 7.1 页面声明

```json
// main_pages.json
{
  "src": [
    "pages/LoginPage",
    "pages/MainPage"
  ]
}
```

### 7.2 入口加载

```typescript
// EntryAbility.ets
onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.loadContent('pages/LoginPage', (err) => {
    WindowUtil.initialize(windowStage);
  });
}
```

### 7.3 登录跳转

```typescript
// LoginPage.ets - replaceUrl 替换栈，防止返回到登录页
await router.replaceUrl({ url: 'pages/MainPage' });
```

### 7.4 NavPathStack 共享

```typescript
// MainPage.ets
@Provider('mainPageStack') pathStack: NavPathStack = new NavPathStack();

// 路由名常量
const CHECK_IN_ROUTE_NAME = 'CheckInRegister';
const SEARCH_ROUTE_NAME = 'SearchPage';

// 路由目标映射
@Builder
private destinationBuilder(name: string, param?: ESObject) {
  if (name === CHECK_IN_ROUTE_NAME) {
    CheckInFlowPage()
  } else if (name === SEARCH_ROUTE_NAME) {
    SearchPage()
  }
}

// 子组件通过 @Consumer 获取同一栈
// CheckInFlowPage.ets
@Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
```

### 7.5 跳转方法

```typescript
private openCheckInFlow(): void {
  this.pathStack.pushPath({ name: CHECK_IN_ROUTE_NAME });
}

private openSearchPage(): void {
  this.pathStack.pushPath({ name: SEARCH_ROUTE_NAME });
}
```

---

## 附录：技术栈速查

| 技术 | API/装饰器 | 说明 |
|------|-----------|------|
| 状态管理 V2 | `@ComponentV2` `@Local` `@Param` `@Event` `@Provider` `@Consumer` | 替代 V1 的 @State/@Prop/@Link/@Provide/@Consume |
| 可观察对象 | `@ObservedV2` `@Trace` `@Monitor` | 替代 V1 的 @Observed/@ObjectLink/@Watch |
| 全局存储 | `AppStorageV2.connect(Class, key, factory)` | 类型安全的全局状态连接 |
| HDS 导航 | `HdsNavigation` `HdsNavDestination` `HdsTabs` | HarmonyOS Design System |
| HDS 列表 | `HdsListItemCard` `PrefixIcon` `SuffixArrow` `SuffixText` | 统一列表卡片样式 |
| 材质 | `hdsMaterial.MaterialType.IMMERSIVE` `MaterialLevel.ADAPTIVE` | 沉浸式材质 |
| 转场动画 | `geometryTransition` `bindContentCover` `TransitionEffect` | 一镜到底 |
| 弹簧曲线 | `curves.interpolatingSpring(velocity, mass, stiffness, damping)` | 物理弹性动画 |
| 响应式 | `WidthBreakpoint` `BreakpointType<T>` `getWindowWidthBreakpoint()` | 断点适配 |
| 系统符号 | `sys.symbol.*` `SymbolGlyph` `SymbolGlyphModifier` | 矢量符号图标 |
| 系统令牌 | `$r('sys.color.*')` `$r('sys.float.*')` | 系统颜色/字号令牌 |

---

*本文档基于项目当前实现整理，随代码迭代更新。*
