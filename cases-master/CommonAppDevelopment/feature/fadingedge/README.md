# 边缘渐变实现

### 介绍

本案例介绍组件内容边缘渐变的实现，通常用于提示长列表滑动到边缘的场景。

### 效果预览图

![](../../product/entry/src/main/resources/base/media/fading_edge.gif)

**使用说明**

滑动列表的图片，当一侧边缘有渐变色时表示还没有滑动到边缘，该侧仍有内容可以浏览，当滑动到边缘时，渐变色消失。

### 实现思路

1. 创建要显示的底层页面。

```typescript
List({ space: Const.EXAMPLE_IMAGE_GAP }) {
  ForEach(this.textArray, () => {
    ListItem() {
      Image($r("app.media.fadingedge_example1"))
        .width($r('app.integer.fadingedge_example_image_width'))
        .height($r('app.integer.fadingedge_example_image_height'))
        .borderRadius($r('app.integer.fadingedge_example_image_border_radius'))
    }
  }, (item: number) => item.toString())
}
.listDirection(Axis.Horizontal)
.width($r('app.string.fadingedge_fill_size'))
.height($r('app.integer.fadingedge_list_height'))
.overlay(this.fadingOverlay())
.edgeEffect(EdgeEffect.None)
.scrollBar(BarState.Off)
```
2. 创建遮罩层自定义组件，实现见渐变边缘的效果。结合通用属性overlay和linearGradient实现渐变效果。
```typescript
@Builder
fadingOverlay() {
  Column()
    .width($r('app.string.fadingedge_fill_size'))
    .height($r('app.integer.fadingedge_list_height'))
      // TODO: 知识点: linearGradient 可以设置指定范围内的颜色渐变效果
    .linearGradient({
      angle: Const.OVERLAY_LINEAR_GRADIENT_ANGLE,
      colors: [
        [this.linearGradientBeginColor, Const.OVERLAY_LINEAR_GRADIENT_COLOR_POS[0]],
        [Const.BEGIN_COLOR, Const.OVERLAY_LINEAR_GRADIENT_COLOR_POS[1]],
        [Const.BEGIN_COLOR, Const.OVERLAY_LINEAR_GRADIENT_COLOR_POS[2]],
        [this.linearGradientEndColor, Const.OVERLAY_LINEAR_GRADIENT_COLOR_POS[3]],
      ]
    })
    .animation({
      curve: Curve.Ease,
      duration: Const.DURATION
    })
    .hitTestBehavior(HitTestMode.Transparent)
}
```
3. 通过list组件的onReachStart、onReachEnd和onDidScroll接口触发边缘渐变的改变。
```typescript
.onReachStart(() => {
  this.linearGradientBeginColor = Const.BEGIN_COLOR;
  this.linearGradientEndColor = Const.END_COLOR;
})
.onReachEnd(() => {
  this.linearGradientBeginColor = Const.END_COLOR;
  this.linearGradientEndColor = Const.BEGIN_COLOR;
})
.onDidScroll((scrollOffset: number, scrollState: ScrollState)=>{
  // 列表滑动到于中间位置时，两侧都有边缘渐变效果
  if(this.scroller.currentOffset().xOffset !== 0 && !this.scroller.isAtEnd()){
    this.linearGradientBeginColor = Const.END_COLOR;
    this.linearGradientEndColor = Const.END_COLOR;
  }
})
```

### 高性能知识点

**不涉及**

### 工程结构&模块类型

```shell
fadingedge                  // HAR类型
    ├─common
    |   ├─Constants.ets     // 项目中的常量
    ├─mainpage
    |   ├─MainPage.ets      // 入口主页
```

### 模块依赖

- [**路由模块**](../routermodule)
- [**utils**](../../common/utils)

### 参考资料

- [**linearGradient**](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-gradient-color-0000001815767728)
- [**overlay**](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-overlay-0000001815927516#ZH-CN_TOPIC_0000001815927516__overlay)