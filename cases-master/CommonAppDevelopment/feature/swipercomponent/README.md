# 多层级轮播图方案

### 介绍

本示例介绍使用ArkUI[stack](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V2/ts-container-stack-0000001427584888-V2)
组件实现多层级轮播图。该场景多用于购物、资讯类应用。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/swiper_component.gif" width="200">

**使用说明**

1. 加载完成后显示轮播图可以左右滑动。

### 下载安装

1.模块oh-package.json5文件中引入依赖。
```typescript
"dependencies": {
  "swipercomponent": "har包地址"
}
```
2.ets文件import列表视图组件。
```typescript
import { SwiperSection } from 'swipercomponent';
```

### 快速使用

本章节主要介绍了如何快速使用SwiperSection组件来实现一个自定义轮播图效果。

1. 数据准备。设置SwiperItemViewType（轮播图属性配置）以及初始化轮播图数据。其中SwiperItemViewType包含SwiperData（轮播项数据类）以及
   contentBuilder（轮播项视图）两个属性。
```typescript
class SwiperItemViewType {
  data: SwiperData;
  contentBuilder: WrappedBuilder<[SwiperData]>;

  constructor(data: SwiperData, contentBuilder: WrappedBuilder<[SwiperData]>) {
    this.data = data;
    this.contentBuilder = contentBuilder;
  }
}
```
SwiperData包含imageSrc（图片路径-必传）、name（轮播图标题名称）、appUri（功能模块地址）以及param（传递的参数）。
开发者可以使用以上默认的属性配置，也可以自行配置SwiperItemViewType和SwiperData的属性。
根据以上属性初始化数据。
```typescript
aboutToAppear(): void {
  let swiperData: SwiperData[] = [
    new SwiperData($r('app.media.swipercomponent_mp_chart'), $r('app.string.swipercomponent_swiper_data1'),
      'barchart/BarChartPage'),
    new SwiperData($r('app.media.swipercomponent_lottie'), $r('app.string.swipercomponent_swiper_data2'),
      'lottieview/LottieComponent'),
    new SwiperData($r('app.media.swipercomponent_component_tack'), $r('app.string.swipercomponent_swiper_data3'),
      'componentstack/ComponentStack')];
  swiperData.forEach((item: SwiperData) => {
    this.swiperListView.push(new SwiperItemViewType(item, wrapBuilder(SwiperItemView)))
  })
}
```
2. 构造单个轮播图项的自定义组件（SwiperItemView）。开发者需要传递SwiperData（轮播图数据）参数。

```typescript
@Builder
function SwiperItemView(swiperItemData: SwiperData) {
  ···
}

```

3. 构造自定义轮播视图。

```typescript
SwiperSection({
  swiperListView: this.swiperListView,
  currentIndex: this.currentIndex,
  swiperAnimationDuration: CommonConstants.SWIPER_ANIMATION_DURATION,
  swiperSwitchDuration: CommonConstants.SWIPER_SWITCH_DURATION,
  isLoop: CommonConstants.SWIPER_IS_LOOP,
  indicatorBuilder: () => {
    this.indicatorBuilder();
  },
  swiperItemHandle: (swiperItemData: SwiperData) => {
    // TODO:点击swiper逻辑处理
    // 点击轮播图Item时，根据点击的模块信息，将页面放入路由栈
    DynamicsRouter.pushUri(swiperItemData.appUri, swiperItemData.param);
  }
})
```

### 属性(接口)说明

SwiperData类属性

|    属性    |              类型              |   释义    | 默认值 |
|:--------:|:----------------------------:|:-------:|:---:|
| imageSrc |         ResourceStr          |  图片路径   |  -  |
|   name   |         ResourceStr          | 轮播图标题名称 |  -  |
|  appUri  |            string            | 功能模块地址  |  -  |
|  param   |            string            |  跳转参数   |  -  |

SwiperItemViewType类属性

|       属性       |              类型              |   释义    | 默认值 |
|:--------------:|:----------------------------:|:-------:|:---:|
|      data      |          SwiperData          |  轮播项数据  |  -  |
| contentBuilder | WrappedBuilder<[SwiperData]> | 轮播项视图组件 |  -  |

SwiperSection组件属性

|           属性            |          类型          |     释义      |  默认值   |
|:-----------------------:|:--------------------:|:-----------:|:------:|
|     swiperListView      | SwiperItemViewType[] |   轮播视图数据    |   -    |
|      currentIndex       |        number        |    当前索引值    |   0    |
| swiperAnimationDuration |        number        |  轮播图切换动画时间  | 800ms  |
|  swiperSwitchDuration   |        number        |  轮播图切换间隔时间  | 5000ms |
|         isLoop          |       boolean        | 轮播图是否自动循环播放 |  true  |
|    indicatorBuilder     |         void         |  导航点自定义视图   |   -    |
|    swiperItemHandle     |         void         |  点击轮播图处理逻辑  |   -    |

### 实现思路

1. 通过Stack组件和offsetX实现多层级堆叠。源码参考[SwiperSection.ets](src/main/ets/utils/SwiperSection.ets)

```typescript
 Stack() {
   // LazyForEach必须在容器组件内使用，仅有List、Grid、Swiper以及WaterFlow组件支持数据懒加载，其他组件仍然是一次性加载所有的数据。
   ForEach(this.swiperListView, (item: SwiperItemViewType, index: number) => {
     Column() {
        item.contentBuilder.builder(item.data)
     }
     .shadow(ShadowStyle.OUTER_DEFAULT_SM)
     .backgroundColor(Color.White)
     .borderRadius(CommonConstants.SWIPER_BORDER_RADIUS)
     .clip(true)
     .offset({
       x: this.getOffSetX(index),
       y: 0
     })
     .blur(index !== this.currentIndex ? CommonConstants.SWIPER_BLUR_VALUE : 0)
     // TODO: 知识点:通过animateTo实现动画并且同时改变currentIndex数据中间值来判断组件zIndex实现切换动画
     .zIndex(this.halfCount + 1 - Math.abs(this.getImgCoefficients(index)))
     .width($r('app.string.swipercomponent_swiper_stack_width'))
     .height(index !== this.currentIndex ? $r('app.string.swipercomponent_swiper_stack_height1') :
     $r('app.string.swipercomponent_swiper_stack_height2'))
     .onClick(() => {
        // 点击轮播图Item时，根据点击的模块信息，将页面放入路由栈
        this.swiperItemHandle(item.data);
     })
   }, (item: SwiperItemViewType) => JSON.stringify(item))
}
  ```

2. 通过手势控制调用显式动画同时修改数据中间值currentIndex来修改组件zIndex提示组件层级实现动画切换效果。[SwiperSection.ets](src/main/ets/utils/SwiperSection.ets)

```typescript
Stack(){
  // ...
}
.gesture(
   PanGesture({ direction: PanDirection.Horizontal })
     .onActionStart((event: GestureEvent) => {
       if (this.isLoop) {
         clearInterval(this.swiperInterval);
       }
       this.offsetX = event.offsetX;
     })
     .onActionEnd((event: GestureEvent) => {
       logger.info(`onActionEnd start`);
       let isLeft: boolean = event.offsetX < this.offsetX;
       if (event.offsetX - this.offsetX >= CommonConstants.SWIPER_LEFT_SCROLL ||
         event.offsetX - this.offsetX <= CommonConstants.SWIPER_RIGHT_SCROLL) {
         this.startAnimation(isLeft, this.swiperAnimationDuration);
       }
       if (this.isLoop) {
         this.swiperInterval = setInterval(() => {
           this.startAnimation(true, this.swiperAnimationDuration);
         }, this.swiperSwitchDuration);
       }
     })
)
startAnimation(isLeft: boolean, duration: number): void {
  animateTo({
    duration: duration,
  }, () => {
   const tempIndex: number = isLeft ? this.currentIndex + 1 : this.currentIndex - 1 + this.swiperListView.length;
   this.currentIndex = tempIndex % this.swiperListView.length;
  })
}       

  ```

### 高性能知识点

**不涉及**

### 工程结构&模块类型

   ```
   functionalscenes                                // har类型
   |---common
   |   |---CommonConstants.ets                     // 常量 
   |---components
   |   |---mainpage
   |   |   |---SwiperMainPage.ets                 // 轮播页面
   |   |---model
   |   |   |---SwiperData.ets                      // 轮播数据模型和数据控制器 
   |---utils
   |   |---Logger.ets                              // 日志
   |   |---SwiperSection.ets                       // 轮播组件

   ```

### 模块依赖

**不涉及**

### 参考资料

1.[lazyForeach参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V2/arkts-rendering-control-lazyforeach-0000001524417213-V2)
2.[animationTo参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V2/ts-explicit-animation-0000001478341181-V2)