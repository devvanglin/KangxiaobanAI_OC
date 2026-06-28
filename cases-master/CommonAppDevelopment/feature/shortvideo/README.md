# 短视频切换

### 介绍

短视频切换在应用开发中是一种常见场景，上下滑动可以切换视频，十分方便。本模块基于Swiper组件和Video组件实现短视频切换功能。评论区弹窗请参考[评论组件案例实现](./README_COMMENT.md)。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/short_video.gif" width="400">

**使用说明**

1. 上下滑动可以切换视频。
2. 点击屏幕暂停视频，再次点击继续播放。

### 下载安装

1.模块oh-package.json5文件中引入依赖。
```typescript
"dependencies": {
  "@ohos-cases/shortvideo": "har包地址"
}
```

2.ets文件import自定义视图实现列表视图。

```typescript
import { VideoSwiper, VideoBuilder } from '@ohos-cases/shortvideo';
```

### 快速使用

本章节主要介绍了如何快速使用VideoSwiper组件以及VideoBuilder来实现短视频切换功能。

1. 构建遮罩层视图。遮罩层内容包括视频信息以及博主头像等内容，开发者可以自定义。
```typescript
@Builder
export function VideoComponent(videoData: VideoData) {
  VideoMask({
    videoData: videoData
  })
}
```
2. 初始化数据。数据项类型为VideoBuilder，参数分别为短视频数据以及对应的遮罩层视图框架。

```typescript
 aboutToAppear() {
   for (let i = 0; i < VIDEO_DATA.length; i++) {
     // 模拟评论数据,真实场景需要请求后台获取评论数据
     for (let j = 0; j < 100; j++) {
       VIDEO_DATA[i].commentDataSource.pushData({
         id: j + "",
         avatar: VIDEO_DATA[i].head,
         name: "精灵球收七龙珠" + j,
         commentContent: "我没有看到后续，但总有人会看到" + j,
         timeAgo: j + "小时前",
         address: "广州",
         likeCount: j + ""
       });
     }
     this.data.pushData(new VideoBuilder(VIDEO_DATA[i], wrapBuilder(VideoComponent)));
   }
 }
```
3. 构建短视频视图。
```typescript

VideoSwiper({
  data: this.data,
  playButtonView: this.playButtonView,
  defaultIndex: this.defaultIndex
})

```

### 属性(接口)说明

VideoData属性，开发者可以自定义VideoData参数属性。

|    属性     |      类型       |   释义    | 默认值 |
|:---------:|:-------------:|:-------:|:---:|
|   video   | VideoCompData | 视频组件数据  |  -  |
| videoMask | VideoMaskData | 视频遮罩层信息 |  -  |

VideoCompData属性

|    属性    |     类型      |   释义    | 默认值 |
|:--------:|:-----------:|:-------:|:---:|
| videoUrl | ResourceStr | 视频资源地址  |  -  |
| duration |   number    |  视频时长   |  -  |
| duration |   number    | 视频遮罩层信息 |  -  |


VideoMaskData属性

|        属性         |        类型         |   释义   | 默认值 |
|:-----------------:|:-----------------:|:------:|:---:|
|       name        |      string       |  博主名称  |  -  |
|    description    |      number       |  视频描述  |  -  |
|       time        |     PlayMode      |  视频日期  |  -  |
|       head        |    ResourceStr    |  头像路径  |  -  |
|     likeCount     |      string       |  点赞数量  |  -  |
|   commentCount    |      string       |  评论数量  |  -  |
|   favoriteCount   |      string       |  收藏数量  |  -  |
|    shareCount     |      string       |  分享次数  |  -  |
|      hotspot      |      string       |   热点   |  -  |
| commentDataSource | CommentDataSource |  评论数据  |  -  |

VideoBuilder属性

|       属性       |             类型              |   释义   | 默认值 |
|:--------------:|:---------------------------:|:------:|:---:|
|      data      |          VideoData          | 视图内容数据 |  -  |
| contentBuilder | WrappedBuilder<[VideoData]> | 视图框架UI |  -  |

VideoSwiper视图属性

|       属性       |    类型    |                释义                 | 默认值 |
|:--------------:|:--------:|:---------------------------------:|:---:|
|      data      | VideoNew |               短视频数据               |  -  |
| playButtonView | ()=>void |              播放按钮视图               |  -  |

### 实现思路

1. 使用Swiper创建一个竖直的可上下滑动的框架。源码参考[VideoSwiper.ets](./src/main/ets/utils/VideoSwiper.ets)。

   ```typescript
   LazyForEach(this.data, (item: VideoBuilder, index: number) => {
     Stack({ alignContent: Alignment.Top }) {
       VideoSection({
         videoData: item,
         changeVideo: this.changeVideo,
         firstFlag: this.firstFlag,
         playBoo: this.playBoo,
         videoItemIndex: index,
         currentVideoIndex: this.currentVideoIndex,
        })
        item.contentBuilder.builder(item.data);
        if (!this.playBoo && !this.changeVideo) {
          Column() {
            this.playButtonView()
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width($r('app.string.shortvideo_hundred_percent'))
          .height($r('app.string.shortvideo_hundred_percent'))
          .onClick(() => {
            this.playBoo = true;
          })
        }
      }
    },(item: VideoBuilder) => JSON.stringify(item))
   ```

2. 在Swiper组件中使用Video组件承载视频。源码参考[VideoSection.ets](./src/main/ets/utils/VideoSection.ets)。

   ```typescript
   Video({
      // 使用Video组件实现播放视频并控制其播放状态
      src: this.videoData.data.video,
      controller: this.controller,
      previewUri: this.videoData.data.previewUri
   })
   ```

### 高性能知识点

本示例使用了[LazyForEach](https://developer.harmonyos.com/cn/docs/documentation/doc-guides-V3/arkts-rendering-control-lazyforeach-0000001524417213-V3)进行数据懒加载，LazyForEach懒加载可以通过设置cachedCount属性来指定缓存数量，同时搭配[组件复用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/best-practices-long-list-0000001728333749#section36781044162218)能力以达到性能最优效果。


### 工程结构&模块类型

   ```
   shortvideo                             // har类型
   |---model
   |   |---BasicDataSource.ets            // 模型层-懒加载数据源
   |   |---DataModel.ets                  // 数据模型层-视频数据
   |---utils
   |   |---Logger.ets                     // 日志
   |   |---VideoSection.ets               // 视频播放组件
   |   |---VideoSwiper.ets                // 短视频切换视图
   |---view
   |   |---CommentView.ets                // 视图层-评论组件
   |   |---ShortVideo.ets                 // 视图层-主页
   |   |---Side.ets                       // 视图层-视频右侧页面操作栏与左侧信息栏
   |   |---VideoMask.ets                  // 视图层-视频遮罩层
   ```

### 模块依赖

1. 本示例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印、[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料
[Swiper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-swiper-0000001774121298)

[Video](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-media-components-video-0000001821000921)

[LazyForEach详细用法](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)