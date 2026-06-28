# 视频横竖屏切换及进度条热区拖动案例

### 介绍

本示例介绍了[@ohos.multimedia.media](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-media-V5)组件和[@ohos.window](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-window-V5)接口以及使用[触摸热区](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-touch-target-V5)实现视频横竖屏切换及进度条热区拖动的功能。
该场景多用于横竖屏视频等媒体播放。

### 效果图预览

<img src="./src/main/resources/base/media/video_screen_direction_switching.gif" width="300">

**使用说明**：

* 点击全屏观看按钮，切换横屏窗口。
* 点击左上角返回按钮，恢复竖屏窗口。
* 在进度条上方位置横向拖动可带动进度条移动。

## 实现步骤

1. 初始化[@ohos.multimedia.media](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-media-V5)的AVPlayer。
  ```ts
  async Init(): Promise<void> {
    await this.release();
    const context = getContext(this);
    // 获取fdSrc用于注册AVPlayer
    context.resourceManager.getRawFd(this.fileName).then(async (value: resourceManager.RawFileDescriptor) => {
      this.avPlayer = await media.createAVPlayer();
      this.isCreate = true;
      this.setSourceInfo(); // 视频信息上报函数
      this.setStateChangeCallback(); // 状态机上报回调函数
      this.avPlayer.fdSrc = {
        fd: value.fd,
        offset: value.offset,
        length: value.length
      };
    });
  }
  ```
2. 当AVPlayer初始化完毕进入initialized状态时，将XComponent和AVPlayer通过surfaceId绑定，这样可以在XComponent组件内实现视频播放功能。比起Video组件，AVPlayer可以更方便自定义全屏动画效果。
  ```ts
  // TODO 知识点：XComponent和AVPlayer通过surfaceId绑定
  setSurfaceID(): void {
    logger.info('play video: surfaceID is:' + this.surfaceID);
    this.avPlayer.surfaceId = this.surfaceID;
  }
  ```
3. 使用[AVPlayer](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-media-V5#avplayer9)中的width和height属性判断是横屏视频还是竖屏视频，方便判断是否需要展示**全屏观看**按钮。
```ts
  case 'prepared':
    logger.info('state prepared called');
    this.isPlaying = true; // 准备完成阶段 开始播放
    this.totalDuration = this.avPlayer.duration; // 获取视频时长
    this.aspect_ratio = this.avPlayer.width / this.avPlayer.height; // 获取视频宽高比
    if(this.avPlayer.width >= this.avPlayer.height) { // 判断是横屏视频还是竖屏视频
      this.verticalVideo = false;
    } else {
      this.verticalVideo = true;
    }
    this.getPlay();
    break;
```
4. 调用[@ohos.window](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-window-V5)的 getLastWindow 方法获取当前应用内最上层的子窗口，若无应用子窗口，则返回应用主窗口。
5. 利用获取到的窗口对象，调用 setWindowSystemBarEnable 方法设置窗口是否显示导航栏和状态栏。
6. 调用窗口对象的 setPreferredOrientation 方法设置窗口旋转方向以及是否应用重力感应。
7. 调用窗口对象的setWindowLayoutFullScreen方法实现沉浸式布局。
  ```ts
  changeOrientation() {
    // 获取UIAbility实例的上下文信息
    let context = getContext(this);
    // 调用该接口手动改变设备横竖屏状态（设置全屏模式，先强制横屏，再加上传感器模式）
    window.getLastWindow(context).then((lastWindow) => {
      if (this.isLandscape) {
        // 设置窗口的布局是否为沉浸式布局
        lastWindow.setWindowLayoutFullScreen(true, () => {
          // 设置窗口全屏模式时导航栏、状态栏的可见模式
          lastWindow.setWindowSystemBarEnable([]);
          // 设置窗口的显示方向属性，AUTO_ROTATION_LANDSCAPE表示传感器自动横向旋转模式
          lastWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
        });
      } else {
        // 设置窗口的显示方向属性，UNSPECIFIED表示未定义方向模式，由系统判定
        lastWindow.setPreferredOrientation(window.Orientation.UNSPECIFIED, () => {
          // 设置窗口全屏模式时导航栏、状态栏的可见模式
          lastWindow.setWindowSystemBarEnable(WINDOW_SYSTEM_BAR, () => {
            // 设置窗口的布局是否为沉浸式布局
            lastWindow.setWindowLayoutFullScreen(false, () => {
              setTimeout(() => {
                // 设置退出全屏动画
                animateTo({
                  duration: ANIMATE_DURATION,
                  onFinish: () => {
                    this.fileName = '';
                  }
                }, () => {
                  this.isFullScreen = !this.isFullScreen;
                });
              }, TIMEOUT_DURATION);
            });
          });
        });
      }
    });
  }
  ```
8. 对进度条整个组件设置[触摸热区](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-touch-target-V5)。
  ```ts
  Row() {
    // ...
    Slider({
      value: Math.round(this.currentTime / this.totalDuration * 100)
    })
      .onChange((value: number, mode: SliderChangeMode) => {
        if (this.isCreate) {
          this.currentTime = this.totalDuration * value / 100;
          this.avPlayer.seek(this.currentTime);
          if (mode === SliderChangeMode.Moving) {
            if (this.avPlayer.state === 'playing') {
              this.getPause();
            }
          } else if (mode === SliderChangeMode.End) {
            if (this.avPlayer.state === 'paused' && this.isPlaying) {
              this.getPlay();
            }
          }
        }
      })
    // ...
  }
  .hitTestBehavior(HitTestMode.Transparent) // 将组件的触摸测试类型设置为自身和子节点都响应触摸测试，不会阻塞兄弟节点的触摸测试，不会影响祖先节点的触摸测试。
  .responseRegion( // 设置多个触摸热区
    [
      {
        x: 0,
        y: 0,
        width: $r('app.string.video_screen_direction_switching_layout_100'),
        height: $r('app.string.video_screen_direction_switching_layout_100')
      },
      {
        x: 0,
        y: $r('app.string.video_screen_direction_switching_layout_negative_200'),
        width: $r('app.string.video_screen_direction_switching_layout_100'),
        height: $r('app.string.video_screen_direction_switching_layout_200')
      }
    ]
  )
  .gesture( // 设置拖动手势，将距离变量与进度条变量进行绑定计算
    PanGesture(new PanGestureOptions({
      direction: PanDirection.Left | PanDirection.Right
    }))
      .onActionStart(() => {
        this.flagValue = this.currentTime;
      })
      .onActionUpdate((event?: GestureEvent) => {
        if (event) {
          if (this.isCreate) {
            if (this.avPlayer.state === 'playing') {
              this.getPause();
            }
            this.currentTime =  (this.flagValue + this.totalDuration * (event.offsetX / 3) / 100) > this.totalDuration ? this.totalDuration : (this.flagValue + this.totalDuration * (event.offsetX / 3) / 100);
          }
        }
      })
      .onActionEnd(() => {
        if (this.isCreate) {
          this.avPlayer.seek(this.currentTime);
          if (this.avPlayer.state === 'paused' && this.isPlaying) {
            this.getPlay();
          }
        }
      })
  )
  ```

### 高性能知识点

1. 本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5) 进行数据懒加载优化,以降低内存占用和渲染开销。

### 工程结构&模块类型

   ```
   videoscreendirectionswitching                      // har
   |---component
   |   |---VideoComponent.ets                         // AVPlayer组件页面
   |---model                                         
   |   |---BasicDataSource.ets                        // 数据类型文件
   |---util
   |   |---TimeTools.ets                              // 时间轴组件页面
   |---view
   |   |---VideoScreenDirectionSwitching.ets          // 视频横竖屏切换容器页面
   ```

### 模块依赖

1. 本实例依赖common模块来获取[日志工具类logger](../../common/utils/src/main/ets/log/Logger.ets)。

### 参考资料

[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)

[@ohos.multimedia.media](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-media-V5)

[@ohos.window](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-window-V5)
