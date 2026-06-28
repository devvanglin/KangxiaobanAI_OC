# 音乐播放转场一镜到底效果实现

### 介绍

音乐播放的Mini条播放栏在转场时的一镜到底动画是音乐播放器应用开发中常见的需求。本示例将介绍如何实现Mini条的一镜到底动画，如Mini条歌曲封面的缩放动画，Mini条的展开收起动画等。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/mini_player_animation.gif) 

**使用说明**

1. 打开首页，点击Mini条，可查看Mini条展开动画。
2. 点击全屏播放页左上角收起按钮，实现收起动画。
3. 点击Mini条展开全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分（即屏幕高度的前50%位置）时松手，可查看全屏播放页向上回弹动画。
4. 点击Mini条展开全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的下半部分（即屏幕高度的后50%位置）时松手，可查看全屏播放页向下收起动画。

### 实现思路

本例中一镜到底动画分两块：1.Mini条展开和收起的一镜到底动画 2.全屏播放页上下拖动的手势动画和松手后的回弹动画。
* Mini条展开和收起的一镜到底动画。本例中展开和收起动画(expandCollapseAnimation())大部分动画相同，且共用同一个动画对象animatorObject，主要有三部分动画组成。以Mini条展开动画为例，分为：

（1）Mini条歌曲封面缩放和X，Y轴偏移动画

（2）Mini条向上平移，高度拉伸，同时透明度降低动画

（3）全屏播放页向上平移，同时透明度增加动画

本例中使用@ohos.animator动画模块的AnimatorResult定义动画对象，通过创建AnimatorOptions动画选项，并传入create来创建Animator对象animatorObject。通过play()启动动画，在动画帧回调onframe中通过参数value获取动画进度，然后根据动画进度实时改变自定义动画相关属性AnimationInfo的值来实现Mini条展开和收起的一镜到底动画。

* 全屏播放页上下拖动的手势动画和松手后的回弹动画。

（1）本例中全屏播放页上下拖动的手势动画和Mini条收起动画实现方式类似。Mini条收起动画是在动画帧回调onframe中通过参数value获取动画进度，而拖动手势动画是在PanGesture拖动手势的onActionUpdate移动回调中，通过滑动偏移量event.offsetY，计算动画进度，然后根据动画进度实时改变自定义动画相关属性AnimationInfo的值来实现全屏播放页上下拖动的手势动画。

（2）本例中全屏播放页拖动松手后的回弹动画使用显示动画animateTo，在PanGesture拖动手势的onActionEnd手指抬起回调中，通过前面拖动手势动画中计算的动画过程中全屏播放页Y轴位置detailsPagePositionY。判断抬手时，当全屏播放页Y轴位置小于等于1/2屏幕高度，全屏播放页做向上回弹动画。当全屏播放页Y轴位置大于1/2屏幕高度时，做向下回弹动画。

1. Mini条展开和收起的一镜到底动画。使用@ohos.animator动画模块的AnimatorResult定义动画对象，通过创建AnimatorOptions动画选项，并传入create来创建Animator对象animatorObject。在动画帧回调onframe中通过参数value获取动画进度，然后根据动画进度实时改变自定义动画相关属性AnimationInfo的值来实现Mini条展开和收起的一镜到底动画。源码参考[MiniPlayerAnimation.ets](./src/main/ets/view/MiniPlayerAnimation.ets)。

```typescript
// 定义Animator类
this.animatorObject = animator.create(this.animatorOption);
// onfinish动画完成时回调
this.animatorObject.onfinish = () => {
  // 重置正在动画标志位
  this.animationData.isAnimating = false;
  ...
}
// onframe接收到动画帧时回调，value返回当前的动画进度。value的取值范围就是前面animatorOption中设定的动画插值起点begin到动画插值终点end。
this.animatorObject.onframe = (value: number) => {
  // 展开动画
  if (!this.animationData.isExpand) {
    // 计算当前动画进度占比。
    let progress: number = value / this.animationData.miniImgToDetailsPageImgDistance;
    // Mini条歌曲封面一镜到底动画过程中偏移的距离
    this.animationData.miniImgOffsetY = value;
    // 展开收起动画公共部分
    this.expandCollapseAnimation(progress);
  } else { // 收起动画
    // 展开动画过程和收起动画过程相反，所以这里用1-当前动画进度占比
    let progress: number = 1 - value / this.animationData.miniImgToDetailsPageImgDistance;
    // Mini条歌曲封面一镜到底动画过程中偏移的距离
    this.animationData.miniImgOffsetY = this.animationData.miniImgToDetailsPageImgDistance - value;
    // 展开收起动画公共部分
    this.expandCollapseAnimation(progress);
  }
}
```
2. Mini条展开和收起的一镜到底动画。通过play()启动动画。源码参考[HomePage.ets](./src/main/ets/model/HomePage.ets)。

```typescript
if (this.animatorObject) {
  ...
  // 启动动画。这里为展开动画。
  this.animatorObject.play();
  this.animationInfo.isAnimating = true;
}
```
3. 全屏播放页上下拖动的手势动画。和Mini条收起动画实现方式类似。Mini条收起动画是在动画帧回调onframe中通过参数value获取动画进度，而拖动手势动画是在PanGesture拖动手势的onActionUpdate移动回调中，通过滑动偏移量event.offsetY，计算动画进度，然后根据动画进度实时改变自定义动画相关属性AnimationInfo的值来实现全屏播放页上下拖动的手势动画。源码参考[DetailsPage.ets](./src/main/ets/model/DetailsPage.ets)。

```typescript
.onActionUpdate((event?: GestureEvent) => {
  if (this.animationInfo.isAnimating) {
    // 如果正在Mini条展开收起的一镜到底动画过程中，不触发手势动画
    return;
  }
  if (event) {
    // 向下滑动，offsetY为正，单位vp
    if (event.offsetY >= 0) {
      // 动画进度。向下滑动和Mini条收起动画类似.这里动画进度用1-全屏播放页下滑偏移量offsetY/Mini条距离屏幕顶部的高度miniDistanceToTop计算得到
      let progress: number = 1 - event.offsetY / this.animationInfo.miniDistanceToTop;
      // 全屏播放页下滑偏移量小于等于Mini条距离屏幕顶部的高度，做类似收起动画的滑动效果
      if (event.offsetY <= this.animationInfo.miniDistanceToTop) {
        // Mini条歌曲封面一镜到底动画过程中偏移的距离
        this.animationInfo.miniImgOffsetY = this.animationInfo.miniImgToDetailsPageImgDistance * progress;
        if (progress < Constants.ANIMATION_PROGRESS) {
          // 为了达到更好的动画效果。动画进度0%-30%时，全屏播放页Y轴偏移距离和Mini条，Mini条歌曲封面保持相同的偏移距离
          this.animationInfo.detailsPageOffsetY = this.animationInfo.miniImgOffsetY;
          // Mini条透明度。动画进度0%-30%时，Mini条透明度从1降低到0。动画进度30%-100%时，Mini条透明度为0。
          this.animationInfo.miniPlayerOpacity = 1 - progress / Constants.ANIMATION_PROGRESS;
        } else {
          // 由于动画进度0%-30%时改变了原全屏播放页的偏移距离。所以需要在动画进度30%-100%时重新计算全屏播放页Y轴偏移距离，以达到在动画进度100%时全屏播放页能偏移到屏幕顶部位置。
          this.animationInfo.detailsPageOffsetY = this.animationInfo.miniDistanceToTop * progress -
            (this.animationInfo.miniDistanceToTop - this.animationInfo.miniImgToDetailsPageImgDistance) *
            Constants.ANIMATION_PROGRESS * ((1 - Constants.ANIMATION_PROGRESS) - (progress -
            Constants.ANIMATION_PROGRESS)) / (1 - Constants.ANIMATION_PROGRESS);
          this.animationInfo.miniPlayerOpacity = 0;
        }
        // Mini条动画过程中高度拉伸大小
        this.animationInfo.miniChangeHeight = this.animationInfo.miniImgOffsetY;
        // Mini条歌曲封面动画过程中尺寸变化量
        this.animationInfo.miniImgOffsetSize = (Constants.DETAILS_PAGE_IMG_SIZE - Constants.MINI_IMG_SIZE) * progress;
        // Mini条歌曲封面动画过程中X轴偏移量。
        this.animationInfo.miniImgOffsetX = ((this.animationInfo.screenWidth - Constants.MINI_IMG_SIZE -
        this.animationInfo.miniImgOffsetSize) / 2 - Constants.MINI_POSITION_X - Constants.MINI_IMG_MARGIN_LEFT) * progress;
        /**
         * 动画进度0%-30%时，全屏播放页透明度从0上升到1。和前面Mini条透明度变化相反。
         * 为了达到更好的动画效果。在一开始全屏播放页出现时透明度快速变大。这里在动画进度0%-5%时，全屏播放页透明度从0上升到0.5，在动画进度5%-30%时
         * ，全屏播放页透明度从0.5上升到1.
         */
        if (progress <= Constants.PROGRESS_PERCENTAGE_FIVE) {
          this.animationInfo.detailsPageOpacity = progress * (1 - Constants.DETAILS_PAGE_INTERIM_OPACITY) / Constants.PROGRESS_PERCENTAGE_FIVE;
        } else if (progress < Constants.ANIMATION_PROGRESS) { // 动画进度0.1-0.3，透明度从0.5变1
          this.animationInfo.detailsPageOpacity = (progress - Constants.PROGRESS_PERCENTAGE_FIVE) * (1 -
          Constants.DETAILS_PAGE_INTERIM_OPACITY) / (Constants.ANIMATION_PROGRESS - Constants.PROGRESS_PERCENTAGE_FIVE) +
          Constants.DETAILS_PAGE_INTERIM_OPACITY;
        } else {
          this.animationInfo.detailsPageOpacity = 1;
        }
        // 动画过程中全屏播放页Y轴位置。全屏播放页Y轴位置=屏幕高度-全屏播放页Y轴偏移距离-Mini条距离屏幕底部的高度（Mini条高度+TabBar高度+底部非安全区域高度（导航栏高度））
        this.animationInfo.detailsPagePositionY = this.animationInfo.screenHeight - this.animationInfo.detailsPageOffsetY - this.animationInfo.miniDistanceToBottom;
        // 动画过程中全屏播放页Y轴位置如果在0-1/2屏幕高度，全屏播放页收起按钮父容器Row的透明度从0上升到1。动画过程中全屏播放页Y轴位置如果大于1/2屏幕高度，则全屏播放页收起按钮父容器Row的透明度为0。
        if (this.animationInfo.detailsPagePositionY <= this.animationInfo.screenHeight / 2) {
          this.animationInfo.detailsPageTopOpacity = 1 - this.animationInfo.detailsPagePositionY / (this.animationInfo.screenHeight / 2);
        } else {
          this.animationInfo.detailsPageTopOpacity = 0;
        }
      } else {
        // 全屏播放页下滑偏移量大于Mini条距离屏幕顶部的高度时，不再滑动。更新相关动画参数。
        this.animationInfo.detailsPageOpacity = 0;
        this.animationInfo.miniPlayerOpacity = 1;
        this.animationInfo.miniImgOffsetY = 0;
      }
    }
    else {
      // 如果全屏播放页已经滑到顶部位置，不再上滑。
      this.animationInfo.detailsPageOffsetY = this.animationInfo.screenHeight - this.animationInfo.miniDistanceToBottom;
    }
  }
})
```

4. 全屏播放页拖动松手后的回弹动画。使用显示动画animateTo，在PanGesture拖动手势的onActionEnd手指抬起回调中，通过前面拖动手势动画中计算的动画过程中全屏播放页Y轴位置detailsPagePositionY。判断抬手时，当全屏播放页Y轴位置小于等于1/2屏幕高度，全屏播放页做向上回弹动画。当全屏播放页Y轴位置大于1/2屏幕高度时，做向下回弹动画。源码参考[DetailsPage.ets](./src/main/ets/model/DetailsPage.ets)。

```typescript
.onActionEnd(() => { // 手指抬起后触发回调
  if (this.animationInfo.isAnimating) {
    // 正在动画过程中，不执行手势回弹动画
    return;
  }
  // TODO 知识点：本例中全屏播放页拖动松手后的回弹动画使用显示动画animateTo，在PanGesture拖动手势的onActionEnd手指抬起回调中，通过前面拖动手势动画中计算的动画过程中全屏播放页Y轴位置detailsPagePositionY。判断抬手时，当全屏播放页Y轴位置小于等于1/2屏幕高度，全屏播放页做向上回弹动画。当全屏播放页Y轴位置大于1/2屏幕高度时，做向下回弹动画。
  animateTo({
    duration: Constants.REBOUND_ANIMATION_DURATION,
    curve: Curve.LinearOutSlowIn,
    onFinish: () => {
      // 向下的回弹动画结束后，重置动画相关标志位。
      if (this.animationInfo.detailsPagePositionY > this.animationInfo.screenHeight / 2) {
        this.animationInfo.isExpand = false;
        this.animationInfo.miniDistanceToBottom = 0;
        this.animationInfo.miniImgOpacity = 1;
        this.animationInfo.miniImgAnimateOpacity = 0;
      }
    }
  }, () => {
    if (this.animationInfo.detailsPagePositionY <= this.animationInfo.screenHeight / 2) {
      // 在上半屏幕手指抬起后,设置向上回弹动画属性
      this.animationInfo.detailsPageOffsetY = this.animationInfo.screenHeight - this.animationInfo.miniDistanceToBottom;
      this.animationInfo.miniImgOffsetY = this.animationInfo.miniImgToDetailsPageImgDistance;
      this.animationInfo.miniImgOffsetSize = Constants.DETAILS_PAGE_IMG_SIZE - Constants.MINI_IMG_SIZE;
      this.animationInfo.miniImgOffsetX = ((this.animationInfo.screenWidth - Constants.MINI_IMG_SIZE - this.animationInfo.miniImgOffsetSize) / 2 - Constants.MINI_POSITION_X - Constants.MINI_IMG_MARGIN_LEFT);
      this.animationInfo.detailsPageTopOpacity = 1;
    } else {
      // 在下半屏幕手指抬起后,设置向下回弹动画属性
      this.animationInfo.detailsPageOffsetY = 0;
      this.animationInfo.miniImgOffsetY = 0;
      this.animationInfo.miniImgOffsetSize = 0;
      this.animationInfo.miniPlayerOpacity = 1;
      this.animationInfo.miniImgOffsetX = 0;
      this.animationInfo.detailsPageOpacity = 0;
      this.animationInfo.miniChangeHeight = 0;
    }
  })
})
```
### 高性能知识点

- [onActionUpdate](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/ts-basic-gestures-pangesture-0000001815767760-V4?catalogVersion=V4)是系统高频回调函数，避免在函数中进行冗余或耗时操作。例如应该减少或避免在函数打印日志，会有较大的性能损耗。
- [LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609) 进行数据懒加载优化,以降低内存占用和渲染开销。
- [@Reusable](https://docs.openharmony.cn/pages/v4.0/zh-cn/application-dev/performance/component-recycle.md/)复用组件优化，提升应用性能。

### FAQ

1. Mini条一镜到底动画为什么没有使用组件内隐式共享元素转场 (geometryTransition)的方式来实现。

   答：最初方案是使用geometryTransition实现Mini条里歌曲封面图的一镜到底动画，然后使用animateTo实现全屏播放页的展开收起动画，组合成一个完整的一镜到底动画。由于geometryTransition是隐式动画，歌曲封面图在动画过程中不可控。比如展开动画过程中，无法实现歌曲封面图一镜到底动画和Mini条向上平移动画保持同步。还存在歌曲封面图的一镜到底动画速度比全屏播放页向上平移的展开动画速度快，导致动画过程中歌曲封面图超出全屏播放页的问题。动画的可控性和效果不好，所以最终改用@ohos.animator动画模块的onframe方式，通过监听动画进度实时控制Mini条，歌曲封面图，全屏播放页的动画来实现一镜到底动画。

### 工程结构&模块类型

   ```
   miniplayeranimation                               // har类型
   |---view
   |   |---MiniPlayerAnimation.ets                   // 视图层-首页
   |---model
   |   |---HomePage.ets                              // 首页模块
   |   |---DetailsPage.ets                           // 全屏播放页模块
   |   |---AnimationInfo.ets                         // 动画参数类
   |   |---Constants.ets                             // 常量
   ```

### 模块依赖

本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

1. [插值计算](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/js-apis-curve-0000001774121126-V4?catalogVersion=V4)
2. [安全区域](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/ts-universal-attributes-expand-safe-area-0000001862687573-V4?catalogVersion=V4)
3. [拖动手势](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/ts-basic-gestures-pangesture-0000001815767760-V4?catalogVersion=V4)
4. [显式动画](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-explicit-animation-0000001862687717)
5. [动画模块](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-animator-0000001774280790)
6. [懒加载](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)
7. [组件复用](https://docs.openharmony.cn/pages/v4.0/zh-cn/application-dev/performance/component-recycle.md/)