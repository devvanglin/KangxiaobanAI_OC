# 地图大头针选择位置并显示弹窗组件案例

### 介绍

本示例提供了大头针选择位置并显示弹窗组件的解决方案。该大头针组件分为三个状态，分别是静止态（地图移动过程中，大头针无动画）、加载态（地图停止移动，等待获取地址信息，大头针展示波纹动画表示数据加载中）、显示态（数据加载完成，弹窗显示地址相关信息）。开发者可根据需要直接引入该组件，根据具体使用场景，传入不同的数据，组件根据传入数据的情况显示不同的状态。由于使用场景中，大头针动画需要随时停止，因此选用[@ohos.animator](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-animator-V5)实现大头针的波纹和跳动动画。
### 效果图预览

![](../../product/entry/src/main/resources/base/media/component_instance_shared_in_pages.gif)

**使用说明**

1. 打开案例后，地图上会显示一个加载状态的大头针，显示波纹动画，表示正在获取该位置的地址信息，动画结束后大头针上方会弹出地址信息窗口，显示详细地址和地址实景图。
2. 大头针加载和静止时都可以拖动地图选择位置，按住拖动时大头针无动画且信息窗口消失，松手后大头针显示波纹动画，动画结束后大头针上方会弹出地址信息窗口，显示详细地址和地址实景图。
3. 地址信息窗口中实景图片和地址信息可以点击，点击后出现相应提示。

### 实现思路
#### 场景：大头针选择位置并显示弹窗组件

- 通过原生组件组合实现大头针图标[源码参考](src/main/ets/components/ThumbTackComponent.ets)。
```
  RelativeContainer() {
    Column()
      ...
      .zIndex(0)
      .alignRules({
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
        middle: { anchor: '__container__', align: HorizontalAlign.Center }
      })
      .id('invisiblePost')
    Column()
      ...
      .alignRules({
        bottom: { anchor: 'invisiblePost', align: VerticalAlign.Top },
        middle: { anchor: 'invisiblePost', align: HorizontalAlign.Center }
      })
      .id('tackPost')
    Button()
      ...
      .alignRules({
        center: { anchor: 'tackPost', align: VerticalAlign.Top },
        middle: { anchor: 'tackPost', align: HorizontalAlign.Center }
      })
    if ((this.thumbTackState === ThumbTackState.LOADING)) {
      Button()
        ...
        .id('little1Circle')
        .zIndex(this.whiteHatZIdx)
        .alignRules({
          center: { anchor: 'tackPost', align: VerticalAlign.Top },
          middle: { anchor: 'tackPost', align: HorizontalAlign.Center }
        })
    }
  }
```
- 通过[@ohos.animator](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-animator-V5)控制大头针的波纹动画及跳动动画[源码参考](src/main/ets/components/ThumbTackComponent.ets)。
```
 // 跳动动画
  createVerticalPostAnimation() {
    this.postOffsetAnimator = animator.create({
      // 100, 大头针针尖位置偏移动画持续时间100ms
      duration: 100,
      easing: 'fast-out-slow-in',
      // 200, 动画延时200ms执行
      delay: 200,
      fill: 'forwards',
      direction: 'alternate',
      iterations: 2,
      begin: 0,
      end: this.thumbTackWidth * ThumbTackCommonConstants.TACK_POST_ANIMATION_OFFSET_RATIO
    })

    ...
    
    this.postOffsetAnimator.onFrame = (value) => {
      this.tackPostOffset = value;
    }
    this.postHeightAnimator = animator.create({
      // 大头针针柄长度动画持续200ms
      duration: 200,
      easing: 'fast-out-slow-in',
      delay: 0,
      fill: 'forwards',
      direction: 'alternate',
      iterations: 2,
      begin: this.thumbTackWidth * ThumbTackCommonConstants.TACK_POST_HEIGHT_RATIO,
      end: this.thumbTackWidth * ThumbTackCommonConstants.TACK_POST_ANIMATION_HEIGHT_RATIO
    })
    
    ...
    
    this.postHeightAnimator.onFrame = (value) => {
      this.tackPostHeight = value;
    }
  }
```
- 通过[Path](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-drawing-components-path-V5)实现地址提示区域的不规则边框，[源码参考](src/main/ets/components/AddressPopUpComponent.ets)。
```
  // this.pathCmd = 'M0 0 C' + vp2px(2.5) + ' ' + vp2px(0) + ' ' + vp2px(5.6) + ' ' + vp2px(2.4) + ' '
  //  + vp2px(6.2) + ' ' + vp2px(4.9) + ' L' + vp2px(10) + ' ' + vp2px(20) + ' L0 ' + vp2px(20) + 'Z';
  Path({
    width: AddressPopupCommonConstants.TIP_AREA_HEIGHT,
    height: AddressPopupCommonConstants.TIP_AREA_HEIGHT,
    commands: this.pathCmd
  })
    .fill(this.addressTipBackgroundColor)
    .strokeOpacity(0)
```

### 高性能知识点
无

### 工程结构&模块类型

   ```
   mapthumbtack                                // har类型
   |---src/main/ets/components
   |   |---LocationAndPopupComponent.ets       // 视图层-大头针选择位置并显示弹窗组件 
   |   |---AddressPopUpComponent.ets           // 视图层-依赖的地址显示组件 
   |   |---ThumbTackComponent.ets              // 视图层-依赖的大头针组件 
   |---src/main/ets/model
   |   |---CommonConstants.ets                 // 模型层-通用常量 
   ```

### 模块依赖
本实例依赖common模块来实现[资源](../../common/utils/src/main/resources/base/element)的调用。

### 参考资料
[Path參考参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-drawing-components-path-V5)

[animator参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-animator-V5)