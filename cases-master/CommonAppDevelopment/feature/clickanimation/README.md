# 直播界面双击效果动画实现案例

### 介绍

本示例展示了如何通过使用[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)和[组件内转场 (transition)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-transition-animation-component-V5)实现双击或连续快速点击时的图标动画效果，增强用户交互体验。每次用户双击或连续快速点击特定区域时，都会动态显示图标并带有生动的动画效果，如图标放大淡出或向上移动淡出等。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/click_animation.gif)

**使用说明**

1. 背景视频播放：页面加载完成后，背景视频会自动循环播放。
2. 点击动画效果：用户双击或连续快速点击页面任意无遮挡的区域，除首次点击外设备轻微振动，在点击位置放大淡入随机图标，并带有抖动效果，然后图标放大淡出消失，每次触发动画页面右下角点赞数加一。

### 实现思路

ClickAnimationComponent是一个能够在用户进行双击或连续快速点击交互时展示图标动画，如图标放大淡出或向上移动淡出等动画效果的自定义功能组件。它使用LazyForEach动态加载控制点击时图标的上下树，并使用Stack布局使出现的图标可叠加显示。源码参考[ClickAnimationComponent.ets](./src/main/ets/components/ClickAnimationComponent.ets)。

1. 组件使用Stack布局承载背景视频和点击区域，以及可能存在的其他功能模块，其中背景视频和其他功能模块都可以由父组件使用BuilderParam传入进行自定义配置。
  ```ts
  // 视频背景插槽参数
  @BuilderParam videoBackgroundSlotParam: () => void = this.videoBackgroundSlot;
  // 其他功能模块插槽参数，可选
  @BuilderParam otherFunctionModuleSlotParam: () => void;
  
  build(){
    Stack() {
      // 背景视频插槽
      this.videoBackgroundSlotParam();
    
      // 点击效果区域
      Stack(){
        // ...
      }
    
      // 其他功能模块
      if (this.otherFunctionModuleSlotParam) {
        this.otherFunctionModuleSlotParam()
      }
    }
    .height($r('app.string.click_animation_full_size'))
    .width($r('app.string.click_animation_full_size'))
  }
  ```
2. 点击效果区域使用Stack组件，结合LazyForEach实现图像元素的动态上下树和叠加显示。
  ```ts
  // 点击效果区域
  Stack() {
    LazyForEach(this.data, (item: ClickIconItem, index: number) => {
      Image(item.icon)
        .width(this.iconWidth)
        .height(this.iconHeight)
        // ...
    }, (item: ClickIconItem, index: number) => item.id);
  }
  ```
3. 为点击效果区域添加TapGesture手势，当用户双击或连续快速点击区域时，如果点击间隔小于500ms，添加新的图标项到LazyForEach数据源末尾，此时如果父组件设置了点击回调，则执行回调。
  ```ts
  // 点击效果区域
  Stack() {
    LazyForEach(this.data, (item: ClickIconItem, index: number) => {
      // ...
    }, (item: ClickIconItem, index: number) => item.id);
  }
  .gesture(
    TapGesture({ count: 1 })
      .onAction((event: GestureEvent) => {
        // 通过isDoubleClick变量控制动画触发方式，首次触发动画需要双击，后续每次点击之间的间隔在500ms内时（配置多击时默认的超时时间）单击即可触发动画
        if (this.isDoubleClick) {
          // 添加新的图标项到数据源，并更新编号
          this.data.pushData({
            id: this.num.toString(),
            icon: this.iconArray[Math.floor(Math.random() * 5)],
            position: {
              x: event.fingerList[0].localX,
              y: event.fingerList[0].localY
            }
          });
          this.num++;
          if (this.isOpenVibration) {
            // 设置振动效果
            this.setVibrator();
          }
          // 如果父组件设置了点击回调，则执行回调
          if (this.clickCallback) {
            this.clickCallback();
          }
        } else {
          this.isDoubleClick = true;
        }
        // 防抖控制，每次点击后都重置定时器，最后一次点击后，延时500ms后，isDoubleClick恢复为false
        if (this.timeoutId !== null) {
          clearTimeout(this.timeoutId);
        }
        this.timeoutId = setTimeout(() => {
          this.isDoubleClick = false;
          this.timeoutId = null;
        }, 500);
      })
  )
  ```

4. Image组件设置transition转场动画实现图标的动画效果。
   - 为显示图标的Image组件设置transition属性实现转场动画，在入场动画结束后，从数据源移除对应的图标数据，保证图标数据不会一直累积。
    ```ts
    LazyForEach(this.data, (item: ClickIconItem, index: number) => {
      Image(item.icon)
        .width(this.iconWidth)
        .height(this.iconHeight)
        .position({
          x: item.position.x !== undefined ? (item.position.x as number) - this.iconWidth / 2 : 0,
          y: item.position.y !== undefined ? (item.position.y as number) - this.iconHeight / 2 : 0,
        })
        .rotate({ angle: this.iconRotateAngle * (Math.random() * 2 - 1) })
        .transition(
          this.getAnimation(),
          (transitionIn: boolean) => {
            // 入场动画结束后，从数据源移除数据
            if (transitionIn) {
              this.data.shiftData();
            }
          }
        )
    }, (item: ClickIconItem, index: number) => item.id);
    ```
   - 根据设定的动画类型（ScaleUpAndFadeOut 或 MoveUpAndFadeOut），应用不同的动画效果。
    ```ts
    getAnimation(): TransitionEffect {
      if (this.animationType === IconAnimationType.ScaleUpAndFadeOut) {
        // ...
      } else {
        // ...
      }
    }
    ```
   - 动画类型为ScaleUpAndFadeOut时，入场动画使用combine函数组合设置透明度、缩放比例和旋转角度的过渡动画，实现图标放大抖动淡入的效果，出场动画同时设置透明度和缩放比例的过渡动画，实现图标放大淡出的效果。。
    ```ts
    if (this.animationType === IconAnimationType.ScaleUpAndFadeOut) {
      // TODO：知识点：使用TransitionEffect.asymmetric()方法设置不同的出入场动画，实现两种不同的动画效果，并利用combine函数实现透明度、位移和缩放组合的转场效果。
      return TransitionEffect.asymmetric(
        // 入场动画配置：放大抖动淡入
        // 出场动画配置：放大淡出
        TransitionEffect.OPACITY.animation({
          duration: this.scaleUpAndFadeOutOptions.transitionInDuration,
          curve: Curve.Linear
        })
          .combine(TransitionEffect.scale({
            x: this.scaleUpAndFadeOutOptions.transitionInScale,
            y: this.scaleUpAndFadeOutOptions.transitionInScale
          }).animation({ duration: this.scaleUpAndFadeOutOptions.transitionInDuration, curve: Curve.EaseOut }))
          .combine(TransitionEffect.rotate({
            angle: this.scaleUpAndFadeOutOptions.transitionInRotateAngle
          }).animation({ curve: this.scaleUpAndFadeOutOptions.transitionInRotateCurve })),
        TransitionEffect.OPACITY.animation({
          duration: this.scaleUpAndFadeOutOptions.transitionOutDuration,
          curve: Curve.EaseIn
        })
          .combine(TransitionEffect.scale({
            x: this.scaleUpAndFadeOutOptions.transitionOutScale,
            y: this.scaleUpAndFadeOutOptions.transitionOutScale
          }).animation({ duration: this.scaleUpAndFadeOutOptions.transitionOutDuration, curve: Curve.EaseOut })))
    } else {
      // ...
    }
    ```
   - 动画类型为MoveUpAndFadeOut时，入场动画设置透明度、旋转角度和缩放比例的过渡动画，实现图标缩小抖动淡入的效果，出场动画同时设置透明度、位移和缩放比例的过渡动画，实现图标放大淡出和位移的效果。
    ```ts
    if (this.animationType === IconAnimationType.ScaleUpAndFadeOut) {
      // ...
    } else {
      return TransitionEffect.asymmetric(
        // 入场动画配置：缩小抖动淡入
        // 出场动画配置：放大淡出和位移
        TransitionEffect.OPACITY.animation({
          duration: this.moveUpAndFadeOutOptions.transitionInDuration,
          curve: Curve.Linear
        })
          .combine(TransitionEffect.scale({
            x: this.moveUpAndFadeOutOptions.transitionInScale,
            y: this.moveUpAndFadeOutOptions.transitionInScale
          }).animation({ duration: this.moveUpAndFadeOutOptions.transitionInDuration, curve: Curve.EaseOut }))
          .combine(TransitionEffect.rotate({
            angle: this.moveUpAndFadeOutOptions.transitionInRotateAngle
          }).animation({ curve: this.moveUpAndFadeOutOptions.transitionInRotateCurve })),
        TransitionEffect.OPACITY.animation({
          duration: this.moveUpAndFadeOutOptions.transitionOutDuration,
          curve: Curve.EaseIn
        })
          .combine(TransitionEffect.translate({ x: 0, y: this.moveUpAndFadeOutOptions.transitionOutTranslateY })
            .animation({ duration: this.moveUpAndFadeOutOptions.transitionOutDuration, curve: Curve.EaseOut }))
          .combine(TransitionEffect.scale({
            x: this.moveUpAndFadeOutOptions.transitionOutScale,
            y: this.moveUpAndFadeOutOptions.transitionOutScale
          }).animation({ duration: this.moveUpAndFadeOutOptions.transitionOutDuration, curve: Curve.EaseOut }))
      )
    }
    ```

ClickAnimationSamplePage基于ClickAnimationComponent组件，通过自定义背景内容和上方叠加的其他UI元素构建了一个完整的直播双击点赞场景，并且可以通过传入参数自定义动画行为，例如调整动画速度、改变图标尺寸等。源码参考[ClickAnimationSamplePage.ets](./src/main/ets/views/ClickAnimationSamplePage.ets)。

1. 引入功能组件ClickAnimationComponent，并初始化相关参数，其中animationType为动画类型，videoBackgroundSlotParam和otherFunctionModuleSlotParam为UI插槽元素，clickCallback为父组件设置的点击回调。
  ```ts
  ClickAnimationComponent({
    animationType: this.animationType,
    videoBackgroundSlotParam: this.videoBackgroundSlotParam,
    otherFunctionModuleSlotParam: () => {
      this.otherFunctionModuleSlotParam();
    },
    clickCallback: this.clickCallback
  })
  ```

2. 通过设置点击回调，可以在每次点击触发图标动画后执行特定操作，例如更新点赞计数。
  ```ts
  // 点击回调
  private clickCallback: () => void =
    () => {
      // 每次触发动画，点赞数+1
      this.likeNumber++;
    };
  ```


### 高性能知识点

点击时出现的图标数据通过[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V1/arkts-rendering-control-lazyforeach-0000001580345086-V1)进行动态加载，并在入场动画结束后从数据源移除数据，以提升性能。

### 工程结构&模块类型

   ```
   clickanimation                                  // har类型
   |---/src/main/ets/components                       
   |   |---ClickAnimationComponent.ets             // 封装的点击图标动画功能组件
   |---/src/main/ets/model                        
   |   |---ClickIconDataModel.ets                  // 数据模型层-点击图标动画功能组件的类型定义和LazyForEach数据模型 
   |   |---ReviewDataModel.ets                     // 数据模型层-场景页面的类型定义和LazyForEach数据模型 
   |---/src/main/ets/mock                        
   |   |---MockData.ets                            // mock数据
   |---/src/main/ets/utils                        
   |   |---Logger.ets                              // 日志工具类
   |---/src/main/ets/views                        
   |   |---ClickAnimationSamplePage.ets            // 视图层-点击动画场景主页面
   ```

### 模块依赖

1. 本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-rendering-control-lazyforeach-V5)

[组件内转场 (transition)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-transition-animation-component-V5)

[振动开发指导(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/vibrator-guidelines-V5)