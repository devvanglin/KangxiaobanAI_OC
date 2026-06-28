# 悬浮窗拖拽和吸附动画

### 介绍

本示例使用position绝对定位实现应用内悬浮窗，并且通过animateTo结合curves动画曲线实现悬浮窗拖拽跟手和松手吸附边缘的弹性动画效果。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/float_window.gif)

**使用说明**

按住悬浮窗可以拖拽，松开后悬浮窗自动靠左或靠右，如果悬浮窗超出内容区上下边界，自动吸附在边界位置。 

### 实现思路

1. 悬浮窗组件使用Stack嵌套video布局，使用属性position绝对定位使组件悬浮。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts
Stack({ alignContent: Alignment.Bottom }) {
  Video({
    src: $rawfile('float_window_video.mp4'),
    controller: this.videoController
  })
    .controls(false)
    .autoPlay(true)
    .loop(true)
    .muted(true)
    .width($r('app.string.float_window_full_size'))
    .onClick(() => {
      this.videoController.requestFullscreen(true);
    })
    .borderRadius($r('app.integer.float_window_content_border_radius'))
  Text($r('app.string.float_window_live_text'))
    .width($r('app.string.float_window_full_size'))
    .fontSize($r('app.string.ohos_id_text_size_body1'))
    .fontColor($r('app.color.ohos_id_color_background'))
    .textAlign(TextAlign.Center)
    .backgroundColor($r('app.color.ohos_id_color_list_alert'))
    .borderRadius({
      bottomLeft: $r('app.integer.float_window_content_border_radius'),
      bottomRight: $r('app.integer.float_window_content_border_radius')
    })
}
.clip(true)
.border({
  width: $r('app.integer.float_window_border_width'),
  color: $r('app.color.ohos_id_color_background')
})
.borderRadius($r('app.string.ohos_id_corner_radius_default_l'))
.width(Constants.FLOAT_WINDOW_WIDTH)
.height(Constants.FLOAT_WINDOW_HEIGHT)
.backgroundColor($r('app.color.ohos_id_color_foreground'))
.position(this.edge)
.onTouch((event: TouchEvent) => {
  this.onTouchEvent(event);
})
```
2. 初始化时悬浮窗的position属性设置top和right，让悬浮窗靠右。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts
  @State edge: Edges = { top: Constants.INIT_POSITION_Y, right: Constants.PAGE_PADDING };
```
3. 父组件添加onAreaChange回调，获取父组件的宽高。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts    
  // 父组件宽度
  @State containerWidth: number = 0;
  // 父组件高度
  @State containerHeight: number = 0;
                      
  .onAreaChange((oldValue: Area, newValue: Area) => {
    // TODO：性能知识点：onAreaChange是高频回调，仅在父组件尺寸改变时获取新的父组件宽高，避免性能损耗
    if (oldValue.width !== newValue.width) {
      this.containerWidth = newValue.width as number;
    }
    if (oldValue.height !== newValue.height) {
      this.containerHeight = newValue.height as number;
    }
  })
```
4. 悬浮窗组件添加onTouchEvent回调，在手指按下时保存触摸点在窗口中的坐标，用于移动时悬浮窗位置的计算。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts
  // 拖拽移动开始时悬浮窗在窗口中的坐标，每次移动回调触发时更新
  private windowStartX: number = 0;
  private windowStartY: number = 0;

  case TouchType.Down: {
    // 获取拖拽开始时悬浮窗在窗口中的坐标
    this.windowStartX = event.touches[0].windowX;
    this.windowStartY = event.touches[0].windowY;
    break;
  }
```
5. 手指移动时，获取触摸点相对于应用窗口左上角的X和Y坐标，通过计算设置悬浮窗的position坐标实现拖拽，使用默认参数的弹性跟手动画曲线curves.responsiveSpringMotion结合animateTo实现跟手动画效果。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts
  case TouchType.Move: {
    const windowX: number = event.touches[0].windowX;
    const windowY: number = event.touches[0].windowY;
    // TODO：知识点：跟手动画，推荐使用默认参数的弹性跟手动画曲线curves.responsiveSpringMotion。
    animateTo({ curve: curves.responsiveSpringMotion() }, () => {
      // 判断当前edge中属性left和right哪个不为undefined，用于控制悬浮窗水平方向的位置
      if (this.edge.left !== undefined) {
        this.edge.left = this.edge.left as number + (windowX - this.windowStartX);
      } else {
        this.edge.right = this.edge.right as number - (windowX - this.windowStartX);
      }
      this.edge.top = this.edge.top as number + (windowY - this.windowStartY);
      this.windowStartX = windowX;
      this.windowStartY = windowY;
    })
    break;
  }
```

6. 手指抬起时，通过判断悬浮窗中心在水平方向位于窗口中心的左侧或右侧设置悬浮窗靠左或靠右，如果悬浮窗超出内容区上下边界，则将悬浮窗设置在边界位置，使用curves.springMotion弹性动画曲线实现吸附边界时的弹性动画效果。源码参考[FloatWindowMainPage.ets](./src/main/ets/pages/FloatWindowMainPage.ets)

```ts
  case TouchType.Up: {
    // 计算悬浮窗中心点在父组件中水平方向的坐标
    let centerX: number;
    if (this.edge.left !== undefined) {
      centerX = this.edge.left as number + Constants.FLOAT_WINDOW_WIDTH / 2;
    }else{
      centerX = this.containerWidth - (this.edge.right as number) - Constants.FLOAT_WINDOW_WIDTH / 2;
    }
    // TODO：知识点：通过判断悬浮窗在父组件中的位置，设置悬浮窗贴边，使用curves.springMotion()弹性动画曲线，可以实现阻尼动画效果
    animateTo({ curve: curves.springMotion() }, () => {
      // 判断悬浮窗中心在水平方向是否超过父组件宽度的一半，根据结果设置靠左或靠右
      if (centerX > (this.containerWidth / 2)) {
        this.edge.right = Constants.PAGE_PADDING;
        this.edge.left = undefined;
      } else {
        this.edge.right = undefined;
        this.edge.left = Constants.PAGE_PADDING;
      }
      // 判断悬浮窗是否超出内容区上下边界，根据结果将悬浮窗设置在边界位置
      if (this.edge.top as number < Constants.PAGE_PADDING) {
        this.edge.top = Constants.PAGE_PADDING;
      } else if (this.edge.top as number > this.containerHeight - Constants.FLOAT_WINDOW_HEIGHT - Constants.PAGE_PADDING) {
        this.edge.top = this.containerHeight - Constants.FLOAT_WINDOW_HEIGHT - Constants.PAGE_PADDING;
      }
    })
    break;
  }
```

### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
   floatwindow                                  // har类型
   |---/src/main/ets/common                        
   |   |---Constants.ets                        // 常量
   |---/src/main/ets/pages                        
   |   |---FloatWindowMainPage.ets              // 视图层-悬浮窗首页
   ```

### 模块依赖

1. 本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[绝对定位 (position)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-location-V5#ZH-CN_TOPIC_0000001884757742__position)

[显式动画 (animateTo)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-explicit-animation-0000001862687717)

[@ohos.curves (插值计算)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V1/js-apis-curve-0000001580185566-V1#ZH-CN_TOPIC_0000001666707716__curvesspringmotion9)