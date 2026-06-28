# Navigation实现折叠屏适配案例

### 介绍

本示例展示了如何利用`Navigation`组件的`mode`属性来适配折叠屏设备，主要实现步骤是通过监听主窗口的尺寸变化和路由栈的动态变化来动态改变`Navigation`组件的`mode`属性，为用户带来更加优化和个性化的交互体验。

### 效果图预览

![](../product/entry/src/main/resources/base/media/foldable_device_adaptation.gif)

### 使用说明

1. 将程序运行在折叠屏手机上观看适配效果。

### 实现思路

1. 在`EntryAbility`中设置窗口尺寸变化监听并使用`AppStorage`存储。
<br>源码参考:[EntryAbility.ets](../product/entry/src/main/ets/entryability/EntryAbility.ets)
    ```ts
    onWindowStageCreate(windowStage: window.WindowStage): void {
      // 获取默认窗口
      this.mWindow = windowStage.getMainWindowSync();
      // 订阅窗口尺寸变化
      this.mWindow.on('windowSizeChange', (size: window.Size) => {
        AppStorage.setOrCreate('windowSize', size);
      });
    }
    ```

2. 自定义应用状态会发生改变的三种模式：设备折叠态发生改变或屏幕旋转、应用从首页进入子路由以及应用从子路由返回首页，并对模式改变进行监听便于进一步处理。
<br>源码参考:[EntryView.ets](../product/entry/src/main/ets/pages/EntryView.ets)
    ```ts
    // 设置导航栏显示改变模式枚举值
    export enum NavMode {
      DefaultMode, // 默认模式
      FoldMode, // 折叠模式
      ChildPageMode, // 进入子页面模式
      HomePageMode // 返回首页模式
    }

    // 定义初始模式为NavMode.DefaultMode，并设置监听函数onModeChange
    @State @Watch('onModeChange') navMode: NavMode = NavMode.DefaultMode;
    
    // 监听模式改变
    onModeChange() {
      // 获取路由栈最后一个路由的名称
      let lastRouteName = DynamicsRouter.appRouterStack.slice(-1)[0].name;
      switch (this.navMode) {
        // 当设备折叠态发生改变或屏幕旋转时响应以下逻辑
        case NavMode.FoldMode:
          // 全屏案例在折叠态变化时不需要切换NavigationMode
          if (FULL_SCREEN_ROUTE.includes(lastRouteName)) {
            this.navigationMode = NavigationMode.Stack;
            break;
          }
          if (this.windowSize.width > DEFAULT_WINDOW_SIZE.width) {
            if (this.pageStack.size() > 0) {
              // 宽屏条件下且展示了子路由，NavigationMode为Split
              this.navigationMode = NavigationMode.Split;
              this.swiperDisplayCount = 1;
            } else {
              // 宽屏条件下且未展示子路由，NavigationMode为Stack
              this.navigationMode = NavigationMode.Stack;
             this.swiperDisplayCount = 2;
            }
          } else {
            this.navigationMode = NavigationMode.Stack;
            this.swiperDisplayCount = 1;
          }
          break;
        // 当应用进入子路由时响应以下逻辑
        case NavMode.ChildPageMode:
          // 进入全屏案例需切换为Stack
          if (FULL_SCREEN_ROUTE.includes(this.enterRouteName)) {
            this.navigationMode = NavigationMode.Stack;
            break;
          }
          // 根据屏幕宽度决定NavigationMode
          if (this.windowSize.width > DEFAULT_WINDOW_SIZE.width) {
            this.navigationMode = NavigationMode.Split;
          } else {
            this.navigationMode = NavigationMode.Stack;
          }
          this.swiperDisplayCount = 1;
          break;
        // 当应用返回首页时响应以下逻辑
        case NavMode.HomePageMode:
          if (this.windowSize.width > DEFAULT_WINDOW_SIZE.width) {
            this.navigationMode = NavigationMode.Stack;
            this.swiperDisplayCount = 2;
          } else {
            this.navigationMode = NavigationMode.Stack;
            this.swiperDisplayCount = 1;
            this.isFullScreen = false;
          }
          this.pageStack.disableAnimation(false);
          break;
        default:
          break;
      }
      // 重置NavMode
      if(this.navMode !== NavMode.DefaultMode) {
        this.navMode = NavMode.DefaultMode;
      }
    }
    ```

3. 定义兼容折叠屏的路由跳转和退出逻辑，根据不同的屏幕宽度进行合适的路由操作。
<br>源码参考:[FoldableRouter.ets](../common/routermodule/src/main/ets/foldableRouter/FoldableRouter.ets) [DynamicsRouter.ets](../common/routermodule/src/main/ets/router/DynamicsRouter.ets)
    ```ts
    /**
    * 兼容折叠屏下的路由跳转
    */
    export class FoldableRouter {
      /**
      * 兼容折叠屏下的路由跳转
      * @param uri 路由名称
      * @param param 路由参数
      */
      public static pushUri(uri: string, param: ESObject) {
        // 记录当前进入路由名称
        AppStorage.setOrCreate('enterRouteName', uri);
        // 定义事件3
        let innerEvent: emitter.InnerEvent = {
          eventId: 3
        };
        let eventData: emitter.EventData = {
          data: {
            navMode: NavMode.ChildPageMode
          }
        };
        // 触发EntryView下navMode改变
        emitter.emit(innerEvent, eventData);
        // 获取当前窗口宽度
        let displayInfo = display.getDefaultDisplaySync();
        let windowSize = AppStorage.get<window.Size>('windowSize') !== undefined ? AppStorage.get<window.Size>('windowSize') : {
          width: displayInfo.width,
          height: displayInfo.height
        } as window.Size;
        // 宽屏条件下跳转
        if (windowSize!.width > DEFAULT_WINDOW_SIZE.width) {
          DynamicsRouter.clear();
          if (DynamicsRouter.timer) {
            clearTimeout(DynamicsRouter.timer);
          }
          // Navigation的mode属性修改会有一段响应时间，需延时跳转
          DynamicsRouter.timer = setTimeout(() => {
            DynamicsRouter.pushUri(uri, param);
          }, DELAY_TIME);
        } else {
          DynamicsRouter.pushUri(uri, param);
        }
      }
    }
   
    // 通过获取页面栈并pop
    public static popAppRouter(): void {
      // pop前记录的来源页为当前栈顶
      const referrerModel: AppRouterInfo = DynamicsRouter.appRouterStack[DynamicsRouter.appRouterStack.length - 1];
      DynamicsRouter.referrer[0] = referrerModel.pageModule;
      DynamicsRouter.referrer[1] = referrerModel.name;
      logger.info(`From DynamicsRouter.routerStack pop preview module name is + ${DynamicsRouter.referrer[0]}, path is ${DynamicsRouter.referrer[1]}`);
      if (DynamicsRouter.appRouterStack.length > 1) {
        DynamicsRouter.appRouterStack.pop();
      } else {
        logger.info("DynamicsRouter.routerStack is only Home.");
      }
      // 定义事件3
      let innerEvent: emitter.InnerEvent = {
        eventId: 3
      };
      let eventData: emitter.EventData = {
        data: {
          navMode: 3
        }
      };
      // 查找到对应的路由栈进行pop
      if(!DynamicsRouter.fullScreenRoutes.includes(DynamicsRouter.referrer[1]) && DynamicsRouter.getNavPathStack().size() === 1) {
        // 非全屏子路由宽屏条件下回到首页，Navigation的mode属性修改默认动画会与过场动画冲突，需关闭过场动画
        if (display.getDefaultDisplaySync().width > DEFAULT_WINDOW_SIZE.width) {
          DynamicsRouter.getNavPathStack().disableAnimation(true);
        }
        DynamicsRouter.timer = setTimeout(() => {
          // 触发EntryView下navMode改变
          emitter.emit(innerEvent, eventData);
        }, DELAY_TIME);
        DynamicsRouter.getNavPathStack().pop();
      }else if(DynamicsRouter.fullScreenRoutes.includes(DynamicsRouter.referrer[1])) {
        // 全屏子路由返回逻辑
        DynamicsRouter.getNavPathStack().pop();
        // 触发EntryView下navMode改变
        emitter.emit(innerEvent, eventData);
      }else {
        DynamicsRouter.getNavPathStack().pop();
      }
    }
    ```

### 高性能知识点

不涉及

### 模块依赖

本实例依赖[common模块](../common)获取定义的常量、折叠屏下跳转方法等、依赖[动态路由模块](../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的返回。

### FAQ

#### 1. 首页swiper的宽度为什么要根据显示的item数量动态计算而不是直接使用100%？
如果直接使用100%首页Navigation切换mode属性时swiper会有缩放闪烁问题，根据显示的item数量动态计算swiper的宽度swiper不会闪烁且item宽度合理。
<br>源码参考:[HomePageSwiper.ets](../product/entry/src/main/ets/view/HomePageSwiper.ets)
   ```ts
      Swiper() {
        ForEach(this.swiperData, (dataItem: SceneModuleInfo) => {
          Image(dataItem.imageSrc)
            .width(this.isFoldable ? px2vp(this.windowSize.width / 2) : $r('app.integer.swiper_width'))
            ...
        })
      }
      .id("MainSwiper")
      .autoPlay(true)
      .displayCount(this.swiperDisplayCount)
      .margin({ top: $r('app.integer.swiper_margin_top'), bottom: $r('app.integer.swiper_margin_bottom') })
      .width(this.swiperDisplayCount === 2 ? px2vp(this.windowSize.width) : $r('app.integer.swiper_width'))
   ```

#### 2. 折叠屏展开条件下从首页进行路由跳转为什么要使用延时？
这是因为Navigation修改完mode属性后有一段反应时长，不能够马上路由跳转，否则子路由页面会从屏幕最左侧滑动进入，理想效果是Navigation先分栏子路由页面再从屏幕中间滑动进入。
<br>源码参考:[FoldableRouter.ets](../common/routermodule/src/main/ets/foldableRouter/FoldableRouter.ets)
   ```ts
      // 宽屏条件下跳转
      if (windowSize!.width > DEFAULT_WINDOW_SIZE.width) {
        DynamicsRouter.clear();
        if (DynamicsRouter.timer) {
          clearTimeout(DynamicsRouter.timer);
        }
        // Navigation的mode属性修改会有一段响应时间，需延时跳转
        DynamicsRouter.timer = setTimeout(() => {
          DynamicsRouter.pushUri(uri, param);
        }, DELAY_TIME);
      } else {
        DynamicsRouter.pushUri(uri, param);
      }
   ```

#### 3. windowSize的初始值为什么要使用`display.getDefaultDisplaySync()`获取的值而不是从AppStorage中取值？
AppStorage中的windowSize要屏幕发生改变才会赋值，所以初始值需要使用display接口获取。
<br>源码参考:[EntryView.ets](../product/entry/src/main/ets/pages/EntryView.ets)
   ```ts
      @StorageProp('windowSize') @Watch('onWindowSizeChange') windowSize: window.Size = {
        width: display.getDefaultDisplaySync().width,
        height: display.getDefaultDisplaySync().height
      };
   ```

### 参考资料

[Navigation](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-navigation-V5)

[windowClass.on('onWindowSizeChange')](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-window-V5#onwindowsizechange7)

[display.getDefaultDisplaySync](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-display-V5#displaygetdefaultdisplaysync9)