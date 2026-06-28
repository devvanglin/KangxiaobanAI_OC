# 悬浮工具箱

### 介绍
本示例介绍使用zIndex、gesture等接口实现悬浮工具箱效果

### 效果预览图

![](../../product/entry/src/main/resources/base/media/toolbox.gif)

**使用说明**

1.点击悬浮球，工具栏动效展开/关闭

2.拖拽悬浮球，悬浮球跟随手势滑动

3.长按悬浮球，禁用/启用悬浮球，不再响应/再次响应悬浮球本身的点击事件

4.点击屏幕，切换横竖屏，悬浮球根据位置等效切换

### 下载安装

1.模块oh-package.json5文件中引入依赖
```typescript
"dependencies": {
  "@ohos-cases/toolbox": "har包地址"
}
```
2.ets文件import自定义视图实现Tab效果组件
```typescript
import { FloatingWindow } from '@ohos-cases/toolbox'
```

### 快速使用

本节主要介绍了如何快速上手使用工具箱组件，包括构建工具箱组件以及常见自定义参数的初始化。

1.构建工具箱组件

在代码合适的位置使用FloatingWindow组件并传入对应的参数，后续将分别介绍对应参数的初始化。
```typescript
/**
 * 构建工具箱
 *
 * content: 工具箱内容
 * floatBall: 悬浮球样式
 * toolBoxAttribute: 工具箱属性
 * toolItemHeight: 工具项高度
 * maximumDistance: 工具项至悬浮球中心的最远距离
 */
FloatingWindow({
  toolList: this.toolList,
  floatBall: this.toolTouch,
  toolItemHeight: CommonConstants.TOOL_ITEM_HEIGHT,
  maximumDistance: CommonConstants.MAXIMUM_DISTANCE,
  clickListener: {
    onAction: (event: GestureEvent) => {
      animateTo({
        duration: 200
      }, () => {
        this.animationAttribute.visible = this.animationAttribute.visible === Visibility.Visible ? Visibility.Hidden : Visibility.Visible;
      })
    }
  },
  longClickListener: {
    onAction: (event: GestureEvent, isDisable: boolean) => {
      this.animationAttribute.visible = Visibility.Hidden;
    },
    onActionEnd: (event: GestureEvent, isDisable: boolean) => {},
    onActionCancel: (isDisable: boolean) => {}
  }
})
.height("250px")
.width("250px")
```

2.工具项UI创建

构建一个工具项的UI效果，其中动效参数以及一些必要的静态参数通过ToolInterface接口传入。
```javascript
@Builder
function tool($$: ToolInterface) {
  Image(($$.params as ImgParams).imgRes)
    .height(CommonConstants.TOOL_ITEM_HEIGHT)
    .width(40)
    .objectFit(ImageFit.Fill)
    .visibility(($$.animation as VisibleAnimation).visible)
    .onClick(() => {
      promptAction.showToast({
        message: '点击逻辑自行实现',
        duration: 2000
      })
    })
}
```

3.动效属性准备

通过实现一个继承于CustomAnimation的类，在该类中集成一些需要动态变化的属性参数，其中继承类必须用@Observed修饰。本例中主要集成了一个可见属性visible，通过visible改变工具项的显隐情况。
```typescript
@Observed
export class VisibleAnimation extends CustomAnimation{
  // 工具项可见属性
  private visible_: Visibility;

  constructor(visible: Visibility = Visibility.Hidden) {
    super();
    this.visible_ = visible;
  }

  get visible(): Visibility {
    return this.visible_;
  }

  set visible(visible: Visibility) {
    this.visible_ = visible;
  }
}
```

4.工具项输入参数准备

准备工具项需要传入的必要参数。通过实现一个继承CustomParams的类，在该类中集成需要传入工具项的必要属性。本例中主要集成了图片资源属性imgRes，通过传入Image组件显示对应图片实现条件渲染。

```typescript
export class ImgParams extends CustomParams {
  // 图片资源
  private imgRes_: PixelMap | ResourceStr | DrawableDescriptor;

  constructor(imgRes: PixelMap | ResourceStr | DrawableDescriptor) {
    super();
    this.imgRes_ = imgRes;
  }

  get imgRes(): PixelMap | ResourceStr | DrawableDescriptor {
    return this.imgRes_;
  }
}
```

5.构建一个工具项

新建一个CustomTool类，向其中传入四个参数——工具项UI、工具项相对于悬浮球的偏移、悬浮球位于角落时工具项相对于悬浮球中心的偏移以及属性集AttributeSet。

```typescript
this.toolList[0] =
  new CustomTool(wrapBuilder(tool), { x: 60, y: CommonConstants.MAXIMUM_DISTANCE / 2 },
    { x: CommonConstants.MAXIMUM_DISTANCE / 2, y: CommonConstants.MAXIMUM_DISTANCE * Math.cos(30 / 180 * Math.PI) },
  new AttributeSet(this.animationAttribute, new ImgParams($r('app.media.AI_circle_viewfinder'))));
```

6.悬浮球初始化

本小节主要介绍了如何绘制悬浮球样式。本示例中主要实现了两个button嵌套来实现悬浮球样式的绘制，其中需要传入一个ToolTouchInterface参数，内部包含了悬浮球是否禁用的属性。
```typescript
@Builder
toolTouch($$: ToolTouchInterface) {
  Button(){
    Button()
      .height(CommonConstants.EIGHTY_PERCENT)
      .width(CommonConstants.EIGHTY_PERCENT)
      .backgroundColor($$.isDisable ? Color.Red : Color.Gray)
      .opacity(0.5)
  }
  .height(CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .backgroundColor($$.isDisable ? 0xFFA28F : 0xD3D3D3)
    .opacity(0.5)
}
```

### 属性(接口)说明

FloatingWindow组件属性

|         属性         |        类型         |           释义           |       默认值        |
|:------------------:|:-----------------:|:----------------------:|:----------------:|
|      toolList      |   CustomTool[]    |         工具箱UI          |        -         |
|     floatBall      |    () => void     |         悬浮球UI          |        -         |
|  toolBoxAttribute  | ToolBoxAttribute  |         工具箱属性          |        -         |
|     threshold      | number or string  | 悬浮球开始吸边的距离阈值（以手机宽度为基准） |       18%        |
|   toolItemHeight   |      number       |       工具项高度        |        40        |
|  maximumDistance   |      number       |       工具项至悬浮球中心的最远距离        |        80        |
|       level        |      number       |       悬浮球的堆叠优先级        | Number.MAX_VALUE |
|   clickListener    |   ClickListener   |       悬浮球点击事件监听器       |        -         |
| longClickListener  | LongClickListener |       悬浮球长按事件监听器       |        -         |
|    dragListener    |   DragListener    |       悬浮球拖拽事件监听器       |        -         |

CustomTool类属性

|        属性         |               类型                |           释义           |    默认值    |
|:-----------------:|:-------------------------------:|:----------------------:|:---------:|
|      builder      | WrappedBuilder<[ToolInterface]> |         工具项UI          |     -     |
|      offset       |             Offset              |      工具项相对于悬浮窗的偏移      |     -     |
|   cornerOffset    |             Offset              | 悬浮球位于角落时工具项相对于悬浮球中心的偏移 |     -     |
|   attributeSet    |          AttributeSet           |         工具项属性集         | undefined |

Offset属性

| 属性 |   类型   |  释义   | 默认值 |
|:--:|:------:|:-----:|:---:|
| x  | number | 横坐标偏移 |  -  |
| y  | number | 总坐标偏移 |  -  |

AttributeSet类属性

|    属性     |       类型        |        释义         |    默认值    |
|:---------:|:---------------:|:-----------------:|:---------:|
| animation | CustomAnimation | 动效参数集（用于UI修改的参数）  | undefined |
|  params   |  CustomParams   | 静态参数集（用于工具项必要的参数） | undefined |

ClickListener属性

|    属性    |              类型               |   释义   | 默认值 |
|:--------:|:-----------------------------:|:------:|:---:|
| onAction | (event: GestureEvent) => void | 点击事件响应 |  -  |

LongClickListener属性

|       属性       |                        类型                         |   释义   | 默认值 |
|:--------------:|:-------------------------------------------------:|:------:|:---:|
|    onAction    | (event: GestureEvent, isDisable: boolean) => void | 长按开始回调 |  -  |
|  onActionEnd   | (event: GestureEvent, isDisable: boolean) => void | 长按结束回调 |  -  |
| onActionCancel |           (isDisable: boolean) => void            | 长按取消回调 |  -  |

DragListener属性

|       属性      |              类型               |   释义   | 默认值 |
|:-------------:|:-----------------------------:|:------:|:---:|
| onActionStart | (event: GestureEvent) => void | 拖拽开始回调 |  -  |
| onActionUpdate | (event: GestureEvent) => void | 拖拽过程回调 |  -  |
|  onActionEnd  | (event: GestureEvent) => void | 拖拽结束回调 |  -  |

ToolTouchInterface属性

|    属性     |   类型    |   释义    | 默认值 |
|:---------:|:-------:|:-------:|:---:|
| isDisable | boolean | 是否禁用工具箱 |  -  |

ToolInterface属性

|    属性     |       类型        |  释义  |    默认值    |
|:---------:|:---------------:|:----:|:---------:|
|  params   |  CustomParams   | 静态参数 | undefined |
| animation | CustomAnimation | 动效参数 | undefined |

### 实现思路

#### 1.悬浮球手势交互

悬浮球手势交互主要分为3个部分：1.单击展开/收回工具栏；2.长按启用/禁用工具栏；3.工具栏跟手滑动且具有吸边效果。对于三种不同的手势事件，本案例通过使用gesture接口以及GestureGroup集成三种不同的手势，并通过设置集成模式为GestureMode.Exclusive使手势之间互斥。

```typescript
Column() {
  this.floatBall({ isDisable: this.isDisable });
}
.gesture(
  GestureGroup(GestureMode.Exclusive,
    ...
  )
)
```

1.1 单击展开/收回工具栏

单击展开/收回工具栏主要是通过TapGesture手势事件实现，并在clickListener的响应事件中通过切换状态变量visible实现工具栏显隐切换。

```typescript
TapGesture()
  .onAction((event: GestureEvent) => {
    console.log(`TapGesture`)
    this.clickListener.onAction(event);
  })

clickListener: {
  onAction: (event: GestureEvent) => {
    animateTo({
      duration: 200
    }, () => {
      this.animationAttribute.visible = this.animationAttribute.visible === Visibility.Visible ? Visibility.Hidden : Visibility.Visible;
    })
  }
}
```

1.2 长按启用/禁用工具栏

长按启用/禁用工具栏主要是通过LongPressGesture手势事件实现，在响应事件时通过修改状态变量isDisable实现工具栏禁用/启用逻辑并执行对应的UI变化逻辑。

```typescript
LongPressGesture()
  .onAction((event: GestureEvent) => {
    console.log(`LongPressGesture Start`)
    // TODO: 工具箱禁用逻辑
    this.isDisable = !this.isDisable;
    vibrator.startVibration({
      type: 'preset',
      effectId: 'haptic.clock.timer',
      count: 1,
    }, {
      id: 0,
      usage: 'alarm'
    }, (error: BusinessError) => {
    })
    this.longClickListener.onAction(event, this.isDisable);
  })
  .onActionEnd((event: GestureEvent) => {
    console.log(`LongPressGesture End`);
    this.longClickListener.onActionEnd(event, this.isDisable);
  })
  .onActionCancel(() => {
    console.log(`LongPressGesture Cancel`)
    this.longClickListener.onActionCancel(this.isDisable);
  })

longClickListener: {
  onAction: (event: GestureEvent, isDisable: boolean) => {
    this.animationAttribute.visible = Visibility.Hidden;
  },
  onActionEnd: (event: GestureEvent, isDisable: boolean) => {},
  onActionCancel: (isDisable: boolean) => {}
}
```

1.3 工具栏跟手滑动且具有吸边效果

工具栏跟手滑动通过PanGesture手势实现，在事件响应的开始阶段，初始化偏移参数；然后，在事件响应阶段，通过求取当前偏移量与上一次偏移量之间的差值实现悬浮球的滑动；最终在事件响应结束阶段，通过计算悬浮球与屏幕边缘的距离来实现悬浮球的吸附效果。

```typescript
PanGesture()
  .onActionStart((event: GestureEvent) => {
    this.offsetX_ = 0;
    this.offsetY_ = 0;
  })
  .onActionUpdate((event: GestureEvent) => {
    // 保证悬浮球保持在屏幕内
    let curX = Math.max(this.offsetX! + event.offsetX - this.offsetX_, -this.leftMargin);
    let curY = Math.max(this.offsetY! + event.offsetY - this.offsetY_, this.topMargin);
    curX = Math.min(curX, this.screenW - this.cW - this.leftMargin - this.initialX);
    curY = Math.min(curY, this.screenH - this.cH - this.avoidSysHeight - this.avoidNavHeight - this.initialY);
    this.offsetX_ += curX - this.offsetX!;
    this.offsetY_ += curY - this.offsetY!;
    this.offsetX = curX;
    this.offsetY = curY;
    // 更新工具栏水平展开方向和垂直方向位置，用于动态调整工具项偏移量
    let left: number = this.offsetX!;
    let leftMargin: number = left;
    let rightMargin: number = this.screenW - leftMargin - this.cW;
    this.unfoldDirection = leftMargin <= rightMargin ? Direction.RIGHT : Direction.LEFT;
    // 当悬浮球工具项超过上下边界时重排工具项
    if (this.offsetX !== undefined && this.offsetY !== undefined) {
      if (this.offsetY + this.cH / 2 - this.toolItemHeight / 2 - this.maximumDistance  <= this.topMargin) {
        this.verticalAlignment = VerticalAlignment.TOP;
      } else if (this.offsetY - this.cH / 2 + this.toolItemHeight / 2 + this.maximumDistance >=
        this.screenH - this.cH - this.avoidSysHeight - this.avoidNavHeight - this.initialY) {
        this.verticalAlignment = VerticalAlignment.BOTTOM;
      } else {
        this.verticalAlignment = VerticalAlignment.DEFAULT;
      }
    }
  })
  .onActionEnd((event: GestureEvent) => {
    let left: number = this.offsetX!;
    // 吸附效果实现
    this.closeToBorder(left, left + this.cW, 0, this.screenW, this.realThreshold);
  })
```

### 高性能知识点

无

### 工程结构&模块类型

```
toolbox                                      // har类型
|---common
|   |---CommonConstants.ets                  // 内置常量定义 
|---model
|   |---AttributeSet.est                     // 工具项属性集
|   |---ChildTool.est                        // 工具项组件
|   |---ClickListener.est                    // 悬浮球点击事件监听器
|   |---CustomAnimation.est                  // 动效参数集
|   |---CustomParams.est                     // 静态参数集
|   |---CustomTool.est                       // 自定义工具项
|   |---DragListener.est                     // 悬浮球拖拽事件监听器
|   |---LongClickListener.est                // 悬浮球长按事件监听器
|   |---Offset.ets                           // 偏移类
|   |---ToolInterface.est                    // 工具项UI入参
|   |---ToolTouchInterface.est               // 悬浮球UI入参
|---pages
|   |---ImgParams.ets                        // 自定义静态参数集
|   |---LoadingHUD.ets                       // lottie动画
|   |---ToolBoxView.ets                      // 工具箱页面
|   |---VisiableAnimation.ets                // 自定义动效属性集
|---utils
|   |---FloatingWindow.ets                   // 工具箱组件 
|---FeatureComponent.ets                     // AppRouter入口文件
```

### 参考资料

[gesture](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-gesture-settings-V13)
[zIndex](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-universal-attributes-z-order-V13#zindex)