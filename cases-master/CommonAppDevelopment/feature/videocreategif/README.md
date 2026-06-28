# 视频截取gif图

### 介绍

本示例介绍了如何截取视频的一段内容制作gif图片。该场景多出现在长视频类应用。使用FFmpeg命令对视频进行截取gif图。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/video_create_gif.gif" width="500">

**使用说明**：

* 点击“本地视频截取gif”或“在线视频截取gif”的视频，进入视频播放页面。
* 在视频播放页面中点击“gif”按钮，进入视频截取gif图页面。
* 可以拖动底部时间轴的选中框来选取需要截取的gif的片段，然后点击“下一步”按钮，进入gif图生成页面。
* 在gif图生成页面稍等片刻会生成gif图片，可以将gif图保存至相册。

### 实现步骤

1. 打开视频播放页面，根据视频是本地视频还是线上视频选择设置avPlayer的url。如果是线上视频，使用边缓存边播放的方式，需要记录缓存文件的本地路径。
    
    ```ts
    if (this.url.startsWith(getContext().filesDir)) {
      this.srcFilePath = this.url;
      let file = await fs.open(this.url);
      this.avPlayer.url = `fd://${file.fd}`;
    } else {
      let that = this;
    
      class MyCacheListener implements CacheListener {
        onCacheAvailable(cacheFilePath: string, url: string, percentsAvailable: number): void {
          AppStorage.setOrCreate('currentCachePercent', percentsAvailable);
          if (!that.srcFilePath) {
            // 记录缓存文件的本地路径
            that.srcFilePath = cacheFilePath;
          }
        }
      }
    
      GlobalProxyServer?.getInstance()?.getServer()?.registerCacheListener(new MyCacheListener(), this.url);
    
      let proxyUrl: string | undefined =
        await GlobalProxyServer?.getInstance()?.getServer()?.getProxyUrl(this.url);
      if (proxyUrl.startsWith(getContext().cacheDir)) {
        this.srcFilePath = proxyUrl;
        const file = fs.openSync(this.srcFilePath, fs.OpenMode.READ_ONLY);
        proxyUrl = `fd://${file.fd}`;
      }
      this.avPlayer.url = proxyUrl;
   }
   ```
2. 根据视频播放页面上"gif"按钮的时间点，按一定规则确定截取的时间范围，进入选取生成gif时间片段页面，通过MP4Parser获取每秒的视频帧图片，展示在时间轴上。
    
    ```ts
    MP4Parser.getFrameAtTimeRang(startTimeUs, endTimeUs, MP4Parser.OPTION_CLOSEST, frameCallBack);
    ```
3. 时间轴选择框框取范围处理，具体处理可以查看[RangeSeekBarView.ets](./src/main/ets/components/RangeSeekBarView.ets)文件，

    ```ts
    let touchXNew:number = this.clearUndefined(event?.offsetX);
    let deltaX:number = touchXNew - this.touchXOld;
    if (this.touchType == TouchType.TouchLeftThumb) {
      this.leftThumbUpdate(deltaX);
      this.onRangeValueChanged();
    } else if (this.touchType == TouchType.TouchRightThumb) {
      this.rightThumbUpdate(deltaX);
      this.onRangeValueChanged();
    } else if (this.touchType == TouchType.TouchMiddleThumb) {
      if ((deltaX < 0 && this.leftThumbRect[0] > 0)
            || (deltaX > 0 && this.rightThumbRect[2] < this.componentMaxWidth)) {
        this.leftThumbUpdate(deltaX);
        this.rightThumbUpdate(deltaX);
        this.onRangeValueChanged();
      }
    }

    this.touchXOld = this.clearUndefined(event?.offsetX);  
    ```
4. 点击"下一步"按钮，会出现gif生成页面，根据起始时间和截取长度通过MP4Parser的ffmpegCmd方法生成gif图片。
    
    ```ts
    MP4Parser.ffmpegCmd("ffmpeg -i " + srcFilePath + " -ss " + startTime + " -t " + duration + " " + dst, callBack);
    ```
### 高性能知识点
不涉及

### 工程结构&模块类型

   ```
   videocreategif                                     // har
   |---components
   |   |---CustomLoadingDialog.ets                    // 自定义等待弹窗
   |   |---GifCreateView.ets                          // gif生成页面
   |   |---RangeSeekBarView.ets                       // 时间轴选中框
   |   |---SelectGifTimeFrameView.ets                 // 选取生成gif时间片段页面
   |   |---VideoThumbListView.ets                     // 时间轴小图展示
   |---model                                         
   |   |---BannerInfo.ets                             // banner信息
   |   |---GlobalProxyServer.ets                      // 边缓存边播放服务器管理
   |   |---VideoInfo.ets                              // 视频信息
   |---util
   |   |---Logger.ets                                 // 日志打印工具  
   |   |---TimeTools.ets                              // 时长数据转换工具
   |---view
   |   |---VideoCreateGif.ets                         // 视频项展示页面
   |   |---VideoPlayPage.ets                          // 视频播放页面
   ```
### 模块依赖
依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

依赖[mp4parser](https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fmp4parser)来使用FFmpeg命令。

依赖[OhosVideoCache](https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fvideo-cache)来实现边缓存边播放。
### 参考资料

[video_trimmer](https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fvideotrimmer)源码

[@kit.MediaKit](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-media-V5)

[mp4parser](https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fmp4parser)

[OhosVideoCache](https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fvideo-cache)

