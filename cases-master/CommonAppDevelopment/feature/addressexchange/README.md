
# 地址交换动画

### 介绍

本示例介绍使用显式动画 **animateTo** 实现左右地址交换动画。该场景多用于机票、火车票购买等出行类订票软件中。

### 效果预览图

![address_exchange](../../product/entry/src/main/resources/base/media/address_exchange.gif)

**使用说明**
1. 加载完成后显示地址交换动画页面，点击中间的图标，左右两边地址交换。
### 下载安装

1. 模块oh-package.json5文件中引入依赖

   ```json5
   "dependencies": {
     "addressexchange": "har包地址"
   }
   ```

2. ets文件import自定义视图实现文件压缩效果组件。

   ```ts
   import { AddressExchangeComponent } from './AddressExchangeComponent';
   ```

### 快速使用

本节主要介绍如何快速上手使用地址交换组件，包括构建地址交换组件以及常见自定义参数的初始化。

1. 数据准备，自定义左侧地址、右侧地址以及交换图标的样式。

   ```ts
   /**
    * 左侧的地址
    * @param $$ { AddressBuilderParams } 偏移距离
    */
   @Builder
   leftAddressBuilder() {
     Text($r('app.string.address_exchange_address_left'))
       .width($r('app.string.address_exchange_address_width'))
       .textAlign(TextAlign.Center)
       .fontSize($r('app.string.address_exchange_font_size'))
       .onClick(() => {
         promptAction.showToast({
           message: $r('app.string.address_exchange_other_function'),
           duration: this.toastDuration
         });
       })
   }
   
   /**
    * 右侧的地址
    * @param $$ { AddressBuilderParams } 偏移距离
    */
   @Builder
   rightAddressBuilder() {
     Text($r('app.string.address_exchange_address_right'))
       .width($r('app.string.address_exchange_address_width'))
       .textAlign(TextAlign.Center)
       .fontSize($r('app.string.address_exchange_font_size'))
       .onClick(() => {
         promptAction.showToast({
           message: $r('app.string.address_exchange_other_function'),
           duration: this.toastDuration
         });
       })
   }
   
   /**
    * 点击即可交换的图标
    */
   @Builder
   exchangeIcon() {
     Image($r('app.media.address_exchange_airplane'))
       .size({
         height: $r('app.integer.address_exchange_airplane_size'),
         width: $r('app.integer.address_exchange_airplane_size')
       })
     Image($r('app.media.address_exchange_recycle'))
       .id('translate_image')
       .size({
         height: $r('app.integer.address_exchange_recycle_size'),
         width: $r('app.integer.address_exchange_recycle_size')
       })
       .rotate({ angle: this.rotateAngle })
   }
   ```
   
2. 初始化地址交换动画配置（可选参数），默认动画曲线是弹性动画曲线，其余未配置。通过配置，可以更改动画的持续时间、播放速度、动画曲线等属性，参考文档：[AnimateParam对象说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-explicit-animation-V13#animateparam对象说明)。

   ```ts
   private translateAnimationParam: AnimateParam = { curve: curves.springMotion() };
   ```
   
3. 定义交换图标动画执行函数（可选参数），点击组件中间的图标，图标也会旋转伴随着动画，其中旋转动画是由该执行函数决定的，若未构建函数，则没有动画效果。
   ```ts
   /**
    * 图标旋转动画
    */
   iconAnimation(): void {
     // 图标一次旋转的角度
     const rotateAddAngle: number = 180;
     animateTo({ curve: curves.springMotion() }, () => {
       this.rotateAngle += rotateAddAngle;
     })
   }
   ```
   
4. 初始化组件的排列方向（可选参数，默认为横向排列）。
   ```ts
   private flexDirection: FlexDirection = FlexDirection.Row;
   ```
   
5. 定义单次偏移距离。
   ```ts
   // 单次偏移距离
   @State distance: number = this.rowWidth * 0.84;
   ```

6. 构建组件。

   ```ts
   /**
    * 构建地址交换组件
    * leftAddressBuilderParam：左侧地址模块
    * rightAddressBuilderParam：右侧地址模块
    * translateAnimationConfig：地址交换动画的配置
    * exchangeIconBuilderParam：交换图标模块
    * exchangeIconAnimationFunction：图标旋转动画执行函数
    * distance：单次偏移距离
    * flexDirection：地址交换组件容器Flex的排列方向
    */
   AddressExchangeComponent({
     leftAddressBuilderParam: this.leftAddressBuilder,
     rightAddressBuilderParam: this.rightAddressBuilder,
     translateAnimationParam: this.translateAnimationParam,
     exchangeIconBuilderParam: this.exchangeIcon.bind(this),
     exchangeIconAnimationFunction: this.exchangeIconAnimationFunction.bind(this),
     distance: this.distance,
     flexDirection: this.flexDirection
   })
   ```

### 属性(接口)说明

AddressExchangeComponent组件属性

| 属性                          | 类型           | 释义                           |              默认值              |
| ----------------------------- | -------------- | ------------------------------ | :------------------------------: |
| leftAddressBuilderParam       | WrappedBuilder | 左侧地址模块                   |                -                 |
| rightAddressBuilderParam      | WrappedBuilder | 右侧地址模块                   |                -                 |
| translateAnimationParam       | AnimateParam   | 地址交换动画的配置             | { curve: curves.springMotion() } |
| exchangeIconBuilderParam      | WrappedBuilder | 交换图标模块                   |                -                 |
| exchangeIconAnimationFunction | Function       | 图标旋转动画执行函数           |                -                 |
| distance                      | number         | 单次偏移距离                   |                -                 |
| flexDirection                 | FlexDirection  | 地址交换组件容器Flex的排列方向 |        FlexDirection.Row         |

### 实现思路

1. 创建左右两边Text组件显示地址。设置初始偏移量以及文本对齐方式。源码参考[AddressExchangeView.ets](./src/main/ets/view/AddressExchangeView.ets)。

```ts
/**
 * 左侧的地址
 */
@Builder
leftAddressBuilder() {
  Text($r('app.string.address_exchange_address_left'))
    .width($r('app.string.address_exchange_address_width'))
    .textAlign(TextAlign.Center)
    .fontSize($r('app.string.address_exchange_font_size'))
    .onClick(() => {
      promptAction.showToast({
        message: $r('app.string.address_exchange_other_function'),
        duration: this.toastDuration
      });
    })
}

/**
 * 右侧的地址
 */
@Builder
rightAddressBuilder() {
  Text($r('app.string.address_exchange_address_right'))
    .width($r('app.string.address_exchange_address_width'))
    .textAlign(TextAlign.Center)
    .fontSize($r('app.string.address_exchange_font_size'))
    .onClick(() => {
      promptAction.showToast({
        message: $r('app.string.address_exchange_other_function'),
        duration: this.toastDuration
      });
    })
}
```

2. 点击中间的图标时，修改是否切换的状态变量值和通过animateTo修改偏移量的值，来实现动态更新左右两边地址的显示，完成动画效果。源码参考[AddressExchangeComponent.ets](./src/main/ets/view/AddressExchangeComponent.ets)。

```ts
Stack() {
  this.exchangeIconBuilderParam();
}
.onClick(() => {
  this.swap = !this.swap
  // TODO 知识点：动画效果，修改偏移量，修改旋转角度，实现效果
  animateTo(this.translateAnimationParam, () => {
    if (this.swap) {
      this.translateOffset = this.distance;
    } else {
      this.translateOffset = this.zeroTranslate;
    }
  });

  if (this.exchangeIconAnimationFunction) {
    this.exchangeIconAnimationFunction();
  }
})

/**
 * 图标旋转动画
 */
exchangeIconAnimationFunction(): void {
  // 图标一次旋转的角度
  const rotateAddAngle: number = 180;
  animateTo({ curve: curves.springMotion() }, () => {
  this.rotateAngle += rotateAddAngle;
})
}
```

### 工程结构&模块类型

   ```
   addressexchange                                            // har类型
   |---view
   |   |---AddressExchangeView.ets                            // 视图层-地址交换动画页面 
   |   |---AddressExchangeComponent.ets                       // 地址交换组件
   ```

### 模块依赖

[**utils**](../../common/utils)

### 参考资料

[显式动画](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-explicit-animation-0000001861966629-V5)
