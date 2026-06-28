# 多媒体发布

### 介绍

本示例主要介绍使用[@ohos.file.photoAccessHelper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-photoaccesshelper-V5#photoaccesshelpergetphotoaccesshelper)实现访问系统相册获取媒体资源的多媒体发布场景。 该场景多用于社交软件朋友圈、评论动态发布的场景。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/publish_multimedia_updates.gif" width="200">

**使用说明**：

1. 点击右上角添加标志，弹出分享菜单。
2. 分别点击文字、照片、视频发布按键，弹出发布内容的自定义弹窗。
3. 在系统相册中选择相应的媒体资源进行发布。

### 实现思路
1. 使用LazyForEach+cachedCount+@Reusable实现懒加载列表，并且缓存附近组件。源码参考[PublishMultimediaUpdates.ets](./src/main/ets/pages/PublishMultimediaUpdates.ets)和[OneMoment.ets](./src/main/ets/components/OneMoment.ets)。
   ```typescript
   
        List({ space: ListConstants.LIST_SPACE, scroller: this.listScroller }) {
          // TODO：高性能知识点：列表数据较多，不需要全部渲染上屏，采用LazyForEach。
          LazyForEach(this.commentList, (moment: FriendMoment) => {
            ListItem() {
              OneMoment({ moment: moment });
    
            }
          }, (moment: FriendMoment) => moment.id)
        }
        // TODO：高性能知识点：为保证滑动流畅，采用cachedCount缓存前后节点。
        .cachedCount(this.cachedCountNumber)
        .width($r('app.string.publish_multimedia_updates_layout_100'))
        .height($r('app.string.publish_multimedia_updates_layout_94'))
        .listDirection(Axis.Vertical)
        .divider({
          strokeWidth: $r('app.integer.publish_multimedia_updates_divider_width'),
          color: $r('app.color.publish_multimedia_updates_divider_color'),
          startMargin: $r('app.integer.publish_multimedia_updates_list_divider_margin'),
          endMargin: $r('app.integer.publish_multimedia_updates_list_divider_margin')
        })


   ```
2.  使用[@ohos.file.photoAccessHelper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-photoaccesshelper-V5#photoaccesshelpergetphotoaccesshelper)对图库资源进行选取访问。
   ```typescript
      async getPictureFromAlbum() {
        // 拉起相册，选择图片
        let PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
        // 选择图库内媒体资源种类
        PhotoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
        // 设置最大媒体文件选择数量
        PhotoSelectOptions.maxSelectNumber = this.maxSelectMedia;
        // 创建photoPicker
        let photoPicker = new photoAccessHelper.PhotoViewPicker();
        // 使用photoAccessHelper获取媒体资源信息
        let photoSelectResult: photoAccessHelper.PhotoSelectResult = await photoPicker.select(PhotoSelectOptions);
        // 获取对应资源文件uri地址
        this.selectedImages = photoSelectResult.photoUris[0];
    
      } 
   ```

### 高性能知识点

参考了[长列表加载性能优化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/best-practices-long-list-0000001728333749#section5720231172219)，使用了里面的LazyForEach+cacheCount+@Reusable实现长列表不卡顿滑动。

### 工程结构&模块类型

```
   listslidetohistory                  // har包
   |---constants                    
   |   |---ListConstants               // 列表常量
   |---model                        
   |   |---BasicDataSource             // 列表LazyForEach数据类 + 图文数据类
   |   |---mockdata                    // 模拟列表数据内容          
   |---components            
   |   |---ImageText                   // 图标+文字组件
   |   |---OneMoment                   // 列表内图文混排组件
   |---pages 
   |   |---CommentInputDialog          // 内容输入弹窗
   |   |---PublishMultimediaUpdates    // 多媒体发布主页面
```

### 模块依赖
[routermodule(动态路由)](../../common/routermodule)

### 参考资料

[LazyForEach详细用法](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)