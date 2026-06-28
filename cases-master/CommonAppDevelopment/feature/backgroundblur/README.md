# 背景模糊效果的自定义TabBar实现案例

### 介绍

在一些主页的场景中，为了实现更好的视觉体验，会给TabBar加上透明的背景模糊效果。本示例主要讲解如何使用系统提供的背景设置的能力，实现背景模糊的效果。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/background_blur.gif)

**使用说明**：

1. 上下滑动主页的图片，可以看到TabBar有透明模糊效果。

### 实现思路

**1：使用backgroundBrightness和backgroundBlurStyleTabBar属性实现TabBar背景模糊效果。**

在自定义的TabBar实现中，添加backgroundBrightness和backgroundBlurStyleTabBar属性，实现透明模糊效果。其中backgroundBrightness
属性可以控制背景的亮度等效果，backgroundBlurStyleTabBar属性控制背景的透明度等效果(详细介绍参考[官方资料](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-background-V5#backgroundblurstyle9))。

**2：实现底部TabBar页签的沉浸式效果。**

为了实现底部TabBar页签的沉浸式效果，需要在**所有**TabBar的嵌套路径中，添加expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
的属性设置。

具体代码可参考[CustomTabsComponent.ets](./src/main/ets/ets/pages/CustomTabsComponent.ets)。

```typescript
// 通过backgroundBrightness和backgroundBlurStyle实现底部tabBar的透明模糊效果
Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center }) {
  ForEach(this.tabsInfoList, (item: TabInfo, tabIndex: number) => {
    // 单独一个TabBar组件
    TabItem({
      tabInfo: item,
      tabBarIndex: tabIndex,
      selectedIndex: $selectedIndex,
    })
  })
}
.backgroundBrightness({
  rate: 0.5,
  lightUpDegree: 0.5
})
.backgroundBlurStyle(BlurStyle.Thin, {
colorMode: ThemeColorMode.LIGHT,
adaptiveColor: AdaptiveColor.DEFAULT,
scale: 1
})
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM]) // 实现沉浸式效果
```

### 高性能知识点

注意：当前动态模糊效果会对应用功耗尝试较大影响，请结合实际情况谨慎使用。

### 工程结构&模块类型

```
backgroundblur                          // har类型
|---model
|   |---TabInfo.ets                     // 模型层-Tabbar数据类型
|---pages
|   |---CustomTabsComponent.ets         // 视图层-自定义Tab组件
|   |---TabsSample.ets                  // 视图层-构造的展示场景
```
### 模块依赖

不涉及。

### 参考资料
[背景设置](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-background-V5)

[Tabs组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-tabs-V5)


