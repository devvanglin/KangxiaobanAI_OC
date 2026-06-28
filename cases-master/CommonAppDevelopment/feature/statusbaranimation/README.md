# 状态栏动画实现案例

### 介绍

本案例展示了状态栏的动态交互效果。通过监听页面滚动事件 `onDidScroll`，随着页面的上下滚动，实现状态栏颜色的变化。搜索框会在滚动时流畅地展开或收起，并伴有自然的透明度过渡效果。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/status_bar_animation.gif)

**使用说明**

1. 进入页面开始加载，加载完成后显示整个界面,上下滚动页面即可。

### 实现思路

- **初始化和状态设置**  
在 `aboutToAppear()` 方法中，初始化了窗口模型 `windowModel`。启用沉浸式（设置全屏显示和状态栏为白色），获取状态栏高度存储在 `statusBarHeight` 变量中，从预定义的数据源 `LIST_DATA` 加载数据到 `dataSource`中。
    ```typescript
    aboutToAppear(): void {
      // 初始化窗口管理model
      const windowStage: window.WindowStage | undefined = AppStorage.get('windowStage');
      // 没有windowStage将无法执行下列逻辑
      if (!windowStage) {
        logger.error(TAG, 'windowStage init error!');
        return;
      }
      this.windowModel.setWindowStage(windowStage);
      // 设置沉浸模式及状态栏白色
      this.windowModel.setImmersive();
      // 获取顶部状态栏高度
      this.windowModel.getStatusBarHeight((statusBarHeight) => {
        logger.info(TAG, 'statusBarHeight is ' + statusBarHeight);
        this.statusBarHeight = px2vp(statusBarHeight);
      })
      // 组装数据源
      this.dataSource.pushArrayData(LIST_DATA)
    }
    ```

- **界面布局构造**  
  使用Stack控件使状态栏与列表重叠，并为列表添加滚动监听器，以根据滚动位置调整状态栏和导航栏的透明度及展开收起动效。
  ```typescript
  Stack({ alignContent: Alignment.Top }) {
    Row() {
      // 动态显示回顶部或位置天气控件
      if (this.isFlow) {
        this.topUpBuilder()
      } else {
        this.locationAndWeatherBuilder()
      }
      this.searchViewBuilder()
      this.toolViewBuilder()
    }
    .height(Constants.NAVIGATION_BAR_HEIGHT + this.statusBarHeight)
      .width(Constants.FULL_PERCENT)
      .padding({
        top: this.statusBarHeight
      })
      .zIndex(Constants.Z_INDEX_THREE)
  
    // TODO: 知识点：父组件的透明度Opacity影响子组件（如父类Opacity为0.5，若子组件为0.5时，子组件实际Opacity = 0.5*0.5）,此处Row来改变状态栏的透明度不受影响其它组件透明度
    Row() {
    }
    .backgroundColor($r("app.color.status_bar_animation_white"))
      .opacity(this.navigateBarOpacity)
      .height(Constants.STATUS_BAR_HEIGHT + this.statusBarHeight)
      .width(Constants.FULL_PERCENT)
      .zIndex(Constants.Z_INDEX_TWO)
  
    List({ scroller: this.scroller }) {
      // ...
    }
    // 隐藏滚动条
    .scrollBar(BarState.Off)
      // 渐变蓝色背景色
      .linearGradient({
        colors: [[Constants.LIST_LINEAR_GRADIENT_START_COLOR, Constants.LIST_LINEAR_GRADIENT_START],
          [Constants.LIST_LINEAR_GRADIENT_END_COLOR, Constants.LIST_LINEAR_GRADIENT_END]]
      })
      .height(Constants.FULL_PERCENT)
      .width(Constants.FULL_PERCENT)
  }
  .zIndex(Constants.Z_INDEX_ONE)
    .height(Constants.FULL_PERCENT)
    .width(Constants.FULL_PERCENT)
      // 扩展至所有非安全区域
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  ```
  
- **滚动事件处理**  
  通过监听页面滚动事件 `onDidScroll`，根据当前的滚动偏移量 yOffset 调整状态栏和导航栏的透明度。如果滚动超过了设定的阈值，则改变状态栏的颜色和展开收起动画。
  ```typescript
  .onDidScroll(() => {
    // TODO: 知识点：通过currentOffset来获取偏移量比较准确。
    const yOffset: number = this.scroller.currentOffset().yOffset;
    yOffset <= Constants.MAIN_SCROLLER_OFFSET_Y_ZERO ? this.negativeOffsetY = yOffset :
    Constants.MAIN_SCROLLER_OFFSET_Y_ZERO;
    // 判断导航栏和状态栏背景透明度变化
    yOffset >= Constants.MAIN_SCROLLER_OFFSET_Y_MAX + this.statusBarHeight ?
      this.navigateBarOpacity = Constants.NAVIGATION_BAR_OPACITY_MAX :
      this.navigateBarOpacity = Constants.NAVIGATION_BAR_OPACITY_MIN;
    this.navigateBarOpacity = yOffset / Constants.MAIN_SCROLLER_OFFSET_Y_MAX;
    // 判断当前的导航栏和图标颜色变化
    yOffset > this.statusBarHeight ?
      this.isWhiteColor = false : this.isWhiteColor = true;
    // 判断状态栏字体颜色变化
    yOffset > this.statusBarHeight ?
    this.windowModel.setSystemBarContentColor(Constants.StatusBarContentBlackColor) :
    this.windowModel.setSystemBarContentColor(Constants.StatusBarContentWhiteColor);
    // 判断导航栏动效变化
    yOffset >= this.statusBarHeight + Constants.MAIN_SCROLLER_OFFSET_STATUS_CHANGE ?
      this.isFlow = true : this.isFlow = false;
  })
  ```

### 高性能知识点

本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)进行数据懒加载，LazyForEach懒加载可以通过设置cachedCount属性来指定缓存数量，同时搭配[组件复用](https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-component-reuse-V5)能力以达到性能最优效果。

### 工程结构&模块类型

```
statusbaranimation                            // har类型
|---contants
|   |---Constants.ets                         // 常量定义 
|   |---Enums.ets                             // 枚举定义
|---mock
|   |---Mock.ets                              // 本地数据源
|---model
|   |---LazyDataSource.ets                    // 数据类懒加载
|   |---Model.ets                             // 列表数据模型 
|   |---ObservedArray.ets                     // 被观察数据对象包装
|   |---WindowModel.ets                       // 窗口管理model
|---utils
|   |---Logger.ets                            // 日志打印
|---view
|   |---ArticleList.ets                       // 文章列表组件 
|   |---Banner.ets                            // Banner页面组件 
|   |---StatusBarAnimation.ets                // 主页面                    
```

### 模块依赖

本实例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印以及路由模块来[注册路由](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)。

### 参考资料

[onDidScroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-scrollable-common-V5#ondidscroll12)

[属性动画 (animation)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-animatorproperty-V5)

[RelativeContainer](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-relativecontainer-V5)

