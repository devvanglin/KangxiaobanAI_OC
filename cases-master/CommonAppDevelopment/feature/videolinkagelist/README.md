# 视频卡片和列表区域的联动滚动

### 介绍

本示例使用Scroll和List组件嵌套，通过List组件的滚动控制器和nestedScroll属性实现了视频卡片和列表区域的联动滚动场景。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/video_linkage_list.gif)

**使用说明**

1. 向上滑动列表，页面向上滚动到末尾后隐藏视频，继续向上滑动，卡片吸顶，列表开始滚动，列表滚动到底触发回弹效果。
2. 向下滑动列表，列表先滚动到头部后，页面向下滚动，视频显示，继续向下滑动到页面头部，页面上方触发回弹效果。
3. 点击视频卡片中的播放按钮切换视频播放状态。
4. 视频卡片点击上一条、下一条时，通过List的滚动控制器控制列表滚动到指定位置，视频卡片不发生滚动。
5. 点击列表项，列表发生滚动，视频卡片不滚动。

### 实现思路

1. 初始化新闻列表数据 NEWS_LIST_DATA，通过状态变量currentPlayNews和currentIndex跟踪当前播放的新闻。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  // 当前播放的新闻
  @State currentPlayNews: NewsItem = new NewsItem('', '');
  // 当前播放的新闻在列表中的下标
  @State currentIndex: number = 0;
  
  aboutToAppear() {
    // 新闻列表数据初始化
    NEWS_LIST_DATA.forEach((news: NewsItem) => {
      this.newsList.pushData(news);
    })
    this.currentPlayNews = this.newsList.getData(this.currentIndex);
    ...
  }
```

2. 为了解决新闻列表与外层Scroll容器嵌套时的滚动冲突问题，给新闻列表List设置 nestedScroll 属性，指定列表向末尾端和起始端滚动时与外层Scroll的嵌套滚动方式。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  List({ scroller: this.scroller }) {
    ...
  }
  .nestedScroll({
    scrollForward: NestedScrollMode.PARENT_FIRST, // 可滚动组件往末尾端滚动时的嵌套滚动选项,父组件先滚动，父组件滚动到边缘以后自身滚动。
    scrollBackward: NestedScrollMode.SELF_FIRST // 可滚动组件往起始端滚动时的嵌套滚动选项,自身先滚动，自身滚动到边缘以后父组件滚动。
  })
```

3. 为了实现视频卡片的吸顶效果， Scroll 容器的内容高度使用 calc 计算属性设置为 Scroll 容器高度和视频高度的和，使 Scroll 滚动到尾部边缘时，视频隐藏，视频卡片吸顶。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)
   
```ts
  Scroll(this.scroller) {
    Column() {
      NewsVideoView({
        currentPlayNews: this.currentPlayNews,
        currentIndex: this.currentIndex,
        newsList: this.newsList,
        isHideVideo: this.isHideVideo,
        scrollHeight: this.scrollHeight,
        newsListHeight: this.newsListHeight,
      })
        .margin({ top: this.videoMarginTop, bottom: $r('app.integer.video_linkage_list_video_card_margin_bottom') })
      NewsListView({
        currentPlayNews: this.currentPlayNews,
        currentIndex: this.currentIndex,
        newsList: this.newsList,
        isHideVideo: this.isHideVideo,
        newsListHeight: this.newsListHeight
      })
    }
    .height(`calc(${Constants.VIDEO_HEIGHT}vp + 100%)`)
  }
```

4. 新闻列表组件设置 layoutWeight 为1，使列表自动占满 Scroll 内容的剩余空间，当视频卡片吸顶时新闻列表可以完全显示，并且当新闻标题改变导致卡片高度发生变化时，新闻列表组件高度也相应变化。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  List({ scroller: this.scroller }) {
    ...
  }
  .layoutWeight(Constants.LAYOUT_WEIGHT)
```

5. 通过状态变量isHideVideo修改视频的高度实现显隐，Scroll滚动到末尾时隐藏视频，视频已隐藏情况下, Scroll向下滚动时显示视频。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  // 是否隐藏视频区域
  @State @Watch('onIsHideVideoChange') isHideVideo: boolean = false;
  
  Scroll(this.scroller) {
    ...
  }
  // TODO: 性能知识点：onScroll属于频繁回调接口，应该避免在内部进行冗余和耗时操作，例如避免打印日志
  .onScroll((xOffset: number, yOffset: number) => {
    // 视频已隐藏情况下, Scroll向下滚动时显示视频
    if (yOffset < 0 && this.isHideVideo) {
      this.isHideVideo = false;
    }
  })
  .onReachEnd(() => {
    // Scroll滚动到末尾时隐藏视频
    this.isHideVideo = true;
  })
  
  Stack({ alignContent: Alignment.Bottom }) {
    ...
  }
  .width($r('app.string.video_linkage_list_full_size'))
   // 修改视频的高度实现显隐控制
  .height(this.isHideVideo ? 0 : Constants.VIDEO_HEIGHT)
  

```
6. 在状态变量isHideVideo的监听回调中，根据视频的显隐状态修改视频卡片的上边距保持Scroll内容高度不变，避免滚动混乱。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  // TODO：知识点：根据视频显隐状态修改边距，使用边距代替video占位，使Scroll容器内容高度不变，可以向下滚动显示视频，并且避免滚动混乱
  onIsHideVideoChange() {
    if (!this.isHideVideo) {
      // 视频显示，视频卡片上边距减去视频高度
      this.videoMarginTop -= Constants.VIDEO_HEIGHT;
    } else {
      // 视频隐藏，视频卡片上边距加上视频高度
      this.videoMarginTop += Constants.VIDEO_HEIGHT;
    }
  }
```

7. 在视频卡片中上一条、下一条按钮的点击回调中修改currentIndex和currentPlayNews。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  // 上一条
  Image($r('app.media.video_linkage_list_play_previous'))
    .height($r('app.integer.video_linkage_list_control_previous_next_height'))
    .onClick(() => {
      // 如果不是第一条，切换至上一条
      if (this.currentIndex > 0) {
        this.currentIndex--;
        this.currentPlayNews = this.newsList.getData(this.currentIndex);
      } else {
        promptAction.showToast({
          message: $r('app.string.video_linkage_list_first_data_toast')
        });
      }
    })
  ...
  // 下一条
  Image($r('app.media.video_linkage_list_play_next'))
    .height($r('app.integer.video_linkage_list_control_previous_next_height'))
    .onClick(() => {
      // 如果不是最后一条，切换至下一条
      if (this.currentIndex < this.newsList.totalCount() - 1) {
        this.currentIndex++;
        this.currentPlayNews = this.newsList.getData(this.currentIndex);
      } else {
        promptAction.showToast({
          message: $r('app.string.video_linkage_list_last_data_toast')
        });
      }
    })
```

8. 在新闻列表组件中监听状态变量currentIndex，根据选中项的索引值计算列表的滚动偏移。源码参考[VideoLinkageList.ets](./src/main/ets/pages/VideoLinkageList.ets)

```ts
  // TODO：知识点：监听currentIndex的变化，视频播放卡片切换新闻和点击列表项切换新闻时修改currentIndex,根据下标计算列表的滚动偏移
  onCurrentIndexChange() {
    // 选中的列表项下标大于3时，列表向上滚动，滚动到与列表显示区域内上方间隔3个列表项或列表尾部时停止。
    if (this.currentIndex > Constants.NEWS_LIST_SCROLL_TO_INDEX) {
      this.scroller.scrollTo({
        yOffset: Constants.NEWS_LIST_ITEM_HEIGHT * (this.currentIndex - Constants.NEWS_LIST_SCROLL_TO_INDEX),
        xOffset: 0
      });
    } else {
      // 选中的列表项下标小于等于3时，列表滚动至头部
      this.scroller.scrollTo({ yOffset: 0, xOffset: 0 });
    }
  }
```

### 高性能知识点

1. 本示例使用了LazyForEach进行数据懒加载，List布局时会根据可视区域按需创建ListItem组件，并在ListItem滑出可视区域外时销毁以降低内存占用。参考文章[正确使用LazyForEach优化](https://docs.openharmony.cn/pages/v4.0/zh-cn/application-dev/performance/lazyforeach_optimization.md/)

### 工程结构&模块类型

   ```
   videolinkagelist                              // har类型
   |---/src/main/ets/model                        
   |   |---NewsListDataSource.ets                // 数据模型层-列表数据模型 
   |   |---NewsItemModel.ets                     // 数据模型层-列表项数据模型
   |---/src/main/ets/pages                        
   |   |---VideoLinkageList.ets                  // 视图层-主页面
   |---/src/main/ets/mock                        
   |   |---NewsListData.ets                      // 新闻列表mock数据
   |---/src/main/ets/common                        
   |   |---Constants.ets                         // 常量数据
   ```

### 模块依赖

1. 本实例依赖[common模块](../../common/utils/src/main/resources)中的资源文件。
2. 本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[List](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-list-0000001862607449)

[Scroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-scroll-0000001815927632)