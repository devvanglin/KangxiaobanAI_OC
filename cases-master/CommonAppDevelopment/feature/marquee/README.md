# 跑马灯案例

### 介绍

本示例介绍了文本宽度过宽时，如何实现文本首尾相接循环滚动并显示在可视区，以及每循环滚动一次之后会停滞一段时间后再滚动。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/marquee.gif) 

**使用说明**：

1.进入页面，检票口文本处，实现文本首尾相接循环滚动，且在同一可视区，滚动完成之后，停滞一段时间后继续滚动。

### 下载安装

1.模块oh-package.json5文件中引入依赖。
```typescript
"dependencies": {
  "marquee": "har包地址"
}
```

2.ets文件import自定义视图实现列表视图。

```typescript
import { MarqueeSection, MarqueeModify } from 'listexchange';
```
### 快速使用

本章节主要介绍了如何快速使用跑马灯视图效果组件。

1. 跑马灯内容视图。开发者可以根据自身业务场景设置文本的属性（字体大小、字体颜色、字体粗细等属性）

```typescript
 @example
 @Builder
 marqueeTextBuilder(marqueeText: ResourceStr) {
   Text(marqueeText)
 }
```

2. 构建跑马灯视图。在代码合适的位置使用MarqueeSection组件并传入对应的参数。
```typescript

MarqueeSection({
  marqueeTextBuilder: () => {
    this.marqueeTextBuilder(this.tripDataItem.ticketEntrance)
  },
  marqueeAnimationModifier: new MarqueeAnimationModifier(),
  marqueeScrollModifier: new MarqueeScrollModifier(display.isFoldable() ?
  $r('app.string.marquee_scroll_phone_width') : $r('app.string.marquee_scroll_tablet_width'),
     Constants.BLANK_SPACE)
})

```
其中MarqueeAnimationModifier参数为跑马灯滚动动画属性。
```typescript
export class MarqueeAnimationModifier {
  iterations: number;
  duration: number;
  tempo: number;
  playMode: PlayMode;
  delayTime: number;

  constructor(iterations: number = -1, duration: number = Constants.ANIMATION_DURATION, tempo: number = 1,
    playMode: PlayMode = PlayMode.Reverse, delayTime: number = Constants.DELAY_TIME) {
    this.iterations = iterations;
    this.duration = duration;
    this.tempo = tempo;
    this.playMode = playMode;
    this.delayTime = delayTime;
  }
}

```
MarqueeScrollModifier参数为跑马灯滚动文本属性
```typescript
export class MarqueeScrollModifier {
  scrollWidth: Length;
  space: number;

  constructor(scrollWidth: Length = Constants.DEFAULT_SCROLL_WIDTH, space: number = Constants.BLANK_SPACE) {
    this.scrollWidth = scrollWidth;
    this.space = space;
  }
}
```

### 属性(接口)说明

MarqueeAnimationModifier类属性

|     属性     |    类型    |                释义                 |       默认值       |
|:----------:|:--------:|:---------------------------------:|:---------------:|
| iterations |  number  |          执行次数，值为-1时重复执行           |       -1        |
|  duration  |  number  |           动画持续时间，单位为毫秒            |       10s       |
|   tempo    |  number  | 动画播放速度，值越大动画播放越快，值越小播放越慢，为0时无动画效果 |        1        |
|  playMode  | PlayMode |           控制跑马灯向左还是向右滚动           | PlayMode.Normal |
| delayTime  |  number  |    动画延迟播放时间，单位为ms(毫秒)，默认延时1s播放    |       1s        |

MarqueeScrollModifier类属性

|     属性      |   类型   |  释义   |       默认值       |
|:-----------:|:------:|:-----:|:---------------:|
| scrollWidth | Length | 滚动轴宽度 |        -        |
|    space    | number | 文本间隔  |        -        |

MarqueeSection视图属性

|            属性            |            类型            |     释义     | 默认值 |
|:------------------------:|:------------------------:|:----------:|:---:|
|    marqueeTextBuilder    |        () => void        |  跑马灯文本视图   |  -  |
| marqueeAnimationModifier | MarqueeAnimationModifier |  跑马灯动画属性类  |  -  |
|  marqueeScrollModifier   |  MarqueeScrollModifier   | 跑马灯滚动文本属性类 |  -  |

### 实现思路

由于ArkUI中的Marquee组件无法实现文本接替并显示在同一可视区的效果，它只能等文本完全消失在可视区之后，才会再次显示在可视区，
因此需要以下方案实现。

1. Text组件外层包裹一层Scroll组件，Scroll组件设置一定的百分比宽度值，并获取当前文本内容宽度和Scroll组件宽度，文本宽度大于
   Scroll组件宽度时，通过添加判断显示同样的文本，在偏移过程中可实现文本接替并显示在同一显示区的效果。源码参考[MarqueeSection.ets](./src/main/ets/utils/MarqueeSection.ets)

```typescript

  // TODO：知识点：使用Scroll组件和文本内容组件结合来判断文本宽度过宽时执行文本滚动，否则不执行
  Scroll() {
    Row() {
      Column() {
        this.marqueeTextBuilder()
      }
      .onAreaChange((oldValue, newValue) => {
        logger.info(`TextArea oldValue:${JSON.stringify(oldValue)},newValue:${JSON.stringify(newValue)}`);
        // 获取当前文本内容宽度
        let modePosition: componentUtils.ComponentInfo = componentUtils.getRectangleById('marquee');
        this.ticketCheckScrollWidth = Number(px2vp(modePosition.size.width));
        this.ticketCheckTextWidth = Number(newValue.width);
        if (this.ticketCheckTextWidth < this.ticketCheckScrollWidth) {
           return;
        }
        this.ticketCheckTextOffset =
           this.marqueeAnimationModifier.playMode === PlayMode.Normal ? 0 :
              -(2 * this.ticketCheckTextWidth + this.marqueeScrollModifier.space - this.ticketCheckScrollWidth);})
  
       // TODO：知识点：文本宽度大于Scroll组件宽度时显示。在偏移过程中可实现文本接替并显示在同一显示区的效果
      if (this.ticketCheckTextWidth >= this.ticketCheckScrollWidth) {
        Blank()
          .width(this.marqueeScrollModifier.space)
        this.marqueeTextBuilder()
      }
    }.offset({ x: this.ticketCheckTextOffset })
       .onAppear(() => {
          // 执行动画函数
          this.scrollAnimation();
       })
  }
  .width(this.marqueeScrollModifier.scrollWidth)
  .id('marquee')
  .alignRules({
    top: { anchor: '__container__', align: VerticalAlign.Top },
    left: { anchor: 'ticketEntrance', align: HorizontalAlign.End }
  })
  .align(Alignment.Start)
  .enableScrollInteraction(false)
  .scrollable(ScrollDirection.Horizontal)
  .scrollBar(BarState.Off)
```

2. 页面进来执行文本滚动函数scrollAnimation()，在指定的时间内完成文本的偏移，当循环一次之后，通过定时器setTimeout
   来实现停滞操作。源码参考[MarqueeSection.ets](./src/main/ets/utils/MarqueeSection.ets)

```typescript
 scrollAnimation() {
   // 文本宽度小于Scroll组件宽度，不执行滚动操作
   if (this.ticketCheckTextWidth < this.ticketCheckScrollWidth) {
      return;
   }
   animateTo({
     duration: this.marqueeAnimationModifier.duration,
     tempo: this.marqueeAnimationModifier.tempo,
     curve: Curve.Linear,
     onFinish: () => {
       // TODO：知识点：动画完成时，添加定时器，1s之后重新执行动画函数，达到停滞操作。
       this.ticketCheckTextOffset =
          this.marqueeAnimationModifier.playMode === PlayMode.Normal ? 0 :
             -(2 * this.ticketCheckTextWidth + this.marqueeScrollModifier.space - this.ticketCheckScrollWidth);
        if (this.marqueeAnimationModifier.iterations > 1) {
          if (this.count === this.marqueeAnimationModifier.iterations) {
            this.count = 1;
            return;
          }
          this.count++;
          // 次数为0或者1不重复执行
        } else if (this.marqueeAnimationModifier.iterations === 0 || this.marqueeAnimationModifier.iterations === 1) {
           return;
        }
        this.timer = setTimeout(() => {
          this.scrollAnimation();
        }, this.marqueeAnimationModifier.delayTime)
     }
   }, () => {
     // 文本偏离量
     this.ticketCheckTextOffset = this.marqueeAnimationModifier.playMode === PlayMode.Normal ?
       -(this.ticketCheckTextWidth + this.marqueeScrollModifier.space) :
       -(this.ticketCheckTextWidth - this.ticketCheckScrollWidth)
   })
 }
```
### 高性能知识点

本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)
进行数据懒加载，动态添加行程信息以及[显示动画animateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-attribute-animation-apis-0000001820879805)实现文本偏移。

### 工程结构&模块类型

```
marquee                                         // har类型
|---model
|   |---Constants.ets                           // 数据模型层-常量
|   |---DataSource.ets                          // 模型层-懒加载数据源
|   |---DataType.ets                            // 数据模型层-数据类型
|   |---MockData.ets                            // 数据模型层-模拟数据
|---utils
|   |---Logger.ets                              // 日志-日志打印
|   |---MarqueeSection.ets                      // 跑马灯视图
|---view
|   |---Marquee.ets                             // 视图层-应用主页面
```

### 模块依赖

本实例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[显示动画animateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-attribute-animation-apis-0000001820879805)

[数据懒加载LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)


