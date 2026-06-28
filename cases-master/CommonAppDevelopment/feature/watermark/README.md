# 水印案例

### 介绍

在很多的场景中，如保存图片以及容器封面都能够见到水印，本案例通过Canvas组件以及OffscreenCanvas实现了页面添加水印以及保存图片时添加水印的功能。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/water_mark.gif" width="300"/>

**使用说明**：

1. 进入页面，页面背景显示水印效果。
2. 长按轮播图片，弹出半模态弹窗，点击保存按钮，图片保存在图库中，查看图片，图片显示水印。
3. 长按轮播视频，弹出半模态弹窗，点击保存按钮，视频保存在图库中，查看视频，视频显示移动旋转水印。

### 下载安装

1. 模块oh-package.json5文件中引入依赖。
```typescript
"dependencies": {
  "watermark": "har包地址"
}
```

2. ets文件import自定义视图实现列表视图。

```typescript
import { WaterMarkModel, createWaterMarkView } from 'watermark';
```
### 快速使用

本章节主要介绍了如何快速对组件和图片进行水印的添加。

1. 组件添加水印。构建水印视图（WaterMarkView），使用overlay把水印视图作为组件的浮层形成水印的效果。

```typescript
@Builder
contentView() {
  Stack() {
    Column() {
      ···
    }
    .height(CommonConstants.COMPONENT_VIEW_FULL)
    .overlay(createWaterMarkView(this.textModify))
}
```

2. 图片添加水印。引入WaterMarkModel类，调用addImageWaterMark函数，传递原图pixelMap、原图信息以及文本属性参数。

```typescript
const IMAGE_TEXT_PARAM: TextModify = new TextModify(CommonConstants.TEXT_CONTENT2, CommonConstants.FONT_SIZE1,
         CommonConstants.FONT_COLOR2, CommonConstants.TEXT_ALIGN,
         CommonConstants.TEXT_BASE_LINE, data.size.width - 20, data.size.height - 20);
this.pixelMap = await waterMarkModel.addImageWaterMark(pixelMap, data.size, IMAGE_TEXT_PARAM);
```

### 属性(接口)说明

TextModify文本属性

|      属性      |         类型         |             释义              | 默认值 |
|:------------:|:------------------:|:---------------------------:|:---:|
|     text     |       string       |             内容              |  -  |
|   fontSize   |       string       |            字体大小             |  -  |
|  fontColor   |       string       |            字体颜色             |  -  |
|  textAlign   |  CanvasTextAlign   |        文本绘制中的文本对齐方式         |  -  |
| textBaseline | CanvasTextBaseline |       设置文本沿水平方向的对齐方式        |  -  |
|   offsetX    |       number       | 需要绘制的文本的左下角x坐标（图片添加水印方式中引用） |  -  |
|   offsetY    |       number       | 需要绘制的文本的左下角y坐标（图片添加水印方式中引用） |  -  |

createWaterMarkView视图参数属性

|        属性         |     类型     |  释义  | 默认值 |
|:-----------------:|:----------:|:----:|:---:|
|    textModify     | TextModify | 文本属性 |  -  |

addImageWaterMark函数参数属性

|     属性     |       类型       |     释义     | 默认值 |
|:----------:|:--------------:|:----------:|:---:|
|  pixelMap  | image.PixelMap | 图片pixelMap |  -  |
|    data    |      Size      |    图片尺寸    |  -  |
| textModify |   TextModify   |    文本属性    |  -  |

### 实现思路

本示例使用两种方法添加水印
方法一：Canvas组件绘制水印，然后将水印组件通过overlay属性将水印作为浮层放置在页面中
方法二：获取初始图片的pixelMap对象， 通过OffscreenCanvas绘制水印，并生成一个新的pixelMap对象进行保存。
方法三：获取视频和水印图片存到沙箱，使用mp4parser三方库MP4Parser.ffmpegCmd API调用为视频添加动态水印

**Canvas组件绘制水印**
1. 自定义一个WaterMarkView组件，在Canvas组件的onReady函数中执行内容的填入逻辑。context.fillStyle、context.font、context.textAlign以及textBaseline
   来实现绘制的填充色、文本绘制中的字体大小、文本绘制中的文本对齐方式以及文本绘制中的水平对齐方式。
   源码参考[WaterMarkView.ets](src/main/ets/utils/WaterMarkView.ets)。
```typescript
 Canvas(this.context)
   .width('100%')
   .height('100%')
   .hitTestBehavior(HitTestMode.Transparent)
   .onReady(() => {
     // TODO:知识点:通过canvas绘制水印
     this.context.fillStyle = '#10000000';
     this.context.font = '16vp';
     this.context.textAlign = 'center';
     this.context.textBaseline = 'middle';
     ...
   })
```
2.通过context.fillText来进行内容的绘制，而for循环根据context.width和context.height来实现内容铺满整个画布。源码参考[WaterMarkView.ets](src/main/ets/utils/WaterMarkView.ets)。
```typescript
 for (let i = 0; i < this.context.width / 120; i++) {
   this.context.translate(120, 0);
   let j = 0;
   for (; j < this.context.height / 120; j++) {
      this.context.rotate(-Math.PI / 180 * 30);
      this.context.fillText('水印水印', -60, -60);
      this.context.rotate(Math.PI / 180 * 30);
      this.context.translate(0, 120);
   }
   this.context.translate(0, -120 * j);
}
```
3.最后通过overlay属性将水印作为浮层放置在页面中。源码参考[MainView.ets](./src/main/ets/view/MainView.ets)
```typescript
@Builder
  contentView() {
    Stack() {
      Column() {
      }
      .height('100%')
      .overlay(createWaterMarkView(this.textModify))
    }
  }
```
**OffscreenCanvas绘制水印**
1. 首先根据imageSource.createPixelMap创建一个选定图片的图像像素类pixelMap。源码参考[MainView.ets](./src/main/ets/view/MainView.ets)
```typescript
addWaterMark() {
  CONTEXT.resourceManager.getMediaContent(this.imageSource.id, (error, value) => {
    if (error) {
      return;
    }
    let imageSource: image.ImageSource = image.createImageSource(value.buffer);
    imageSource.getImageInfo((err, data) => {
      if (err) {
        return;
      }
      let opts: image.DecodingOptions = {
        editable: true,
        desiredSize: {
          height: data.size.height,
          width: data.size.width
        }
      }
      imageSource.createPixelMap(opts, async (err, pixelMap) => {
       ...
      })
    })
  })
}
```
2.新增一个OffscreenCanvas对象并根据offScreenCanvas.getContext('2d')获取offscreen canvas绘图上下文信息offScreenContext，
根据此上下文信息可以使用drawImage进行图像绘制，offScreenContext.fillText绘制内容。源码参考[WaterMarkModel.ets](./src/main/ets/utils/WaterMarkModel.ets)
```typescript
 async addImageWaterMark(pixelMap: image.PixelMap, imageInfo: Size, textModify: TextModify) {
   // TODO:知识点:通过OffscreenCanvasRenderingContext2D绘制水印
   const offScreenCanvas = new OffscreenCanvas(imageInfo.width, imageInfo.height);
   const offScreenContext: OffscreenCanvasRenderingContext2D = offScreenCanvas.getContext('2d');
   offScreenContext.drawImage(pixelMap, 0, 0, offScreenCanvas.width, offScreenCanvas.height);
   offScreenContext.textAlign = textModify.textAlign;
   offScreenContext.textBaseline = textModify.textBaseline;
   offScreenContext.fillStyle = textModify.fontColor;
   // 设置字体大小
   offScreenContext.font = textModify.fontSize;
   // 添加文字阴影
   offScreenContext.shadowBlur = CommonConstants.TEXT_SHADOW_BLUE;
   offScreenContext.shadowColor = CommonConstants.TEXT_SHADOW_COLOR;
   // 绘制文本
   offScreenContext.fillText(textModify.text, textModify.offsetX,
      textModify.offsetY);
   let lastPixelMap: image.PixelMap =
      offScreenContext.getPixelMap(0, 0, offScreenCanvas.width, offScreenCanvas.height);
   return lastPixelMap;
}

```
3.通过offScreenContext.getPixelMap获取新的图像像素类pixelMap。源码参考[MainView.ets](./src/main/ets/view/MainView.ets)
```typescript
this.pixelMap = await waterMarkModel.addImageWaterMark(pixelMap, data.size, IMAGE_TEXT_PARAM);
```
4.phAccessHelper.createAsset方法生成一个图片存储地址，然后通过imagePacker.packing将新的pixelMap图像像素类生成一个buffer数据，
最后通过fs.writeSync方法进行图片的保存。源码参考[MainView.ets](./src/main/ets/view/MainView.ets)
```typescript
const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(CONTEXT);
const uri = await phAccessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
if (this.pixelMap !== undefined) {
   // 保存图片到本地
   const imagePacker = image.createImagePacker();
   const imageBuffer = await imagePacker.packing(this.pixelMap, { format: 'image/png', quality: 100 });
   try {
      // 通过uri打开媒体库文件
      let file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      logger.info(`openFile success, fd: ${file.fd}`);
      // 写到媒体库文件中
      fs.writeSync(file.fd, imageBuffer);
      fs.closeSync(file.fd);
   } catch (err) {
      logger.info(`fs failed ${err.code},errMessage:message`);
   }
}
```
**mp4parser给视频添加动态组件**
1. 首先将视频和水印资源，存储到沙箱中并拿到路径
```typescript
let getLocalDirPath = getContext(this).cacheDir + "/";

    let videoBuffer: ArrayBuffer = this.uint8ArrayToBuffer(getContext(this).resourceManager.getMediaContentSync($r("app.media.water_mark_video_1")))
    let cacheVideoPath = getLocalDirPath + "testVideo.mp4"

    let waterMarkBuffer: ArrayBuffer = this.uint8ArrayToBuffer(getContext(this).resourceManager.getMediaContentSync($r("app.media.water_mark_chat")))
    let cacheWaterMarkPath = getLocalDirPath + "testWaterMark1.png"

    let cacheVideo = fs.openSync(cacheVideoPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.truncateSync(cacheVideo.fd)
    fs.writeSync(cacheVideo.fd, videoBuffer);
    fs.closeSync(cacheVideo.fd);

    let cacheWaterMark = fs.openSync(cacheWaterMarkPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.truncateSync(cacheWaterMark.fd)
    fs.writeSync(cacheWaterMark.fd, waterMarkBuffer);
    fs.closeSync(cacheWaterMark.fd);
```

2.创建输出视频文件路径，每次执行需要重新截断再写入
```typescript
let outVideoPath: string = getLocalDirPath + "outVideo.mp4"
let outVideoFile = fs.openSync(outVideoPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
fs.truncateSync(outVideoFile.fd)
fs.close(outVideoFile.fd)
```
3.生成将动态旋转水印添加到视频的ffmpegCmd命令，并执行
```typescript
let ffmpegCmd = `ffmpeg -y -i ${cacheVideoPath} -loop 1 -i ${cacheWaterMarkPath} -filter_complex [1:v]rotate=a='t*PI':ow='rotw(PI/4)':oh='roth(PI/4)':fillcolor='none'[out],[0:v][out]overlay=x=100:y=100:shortest=1 ${outVideoPath}`
try {
  MP4Parser.ffmpegCmd(ffmpegCmd, callBack)
} catch (e) {
  console.log(JSON.stringify(e))
}
```

### 高性能知识点

**不涉及。**

### 工程结构&模块类型

```
videocache                                         // har类型
|---model
|   |---DataType.ets                               // 模型层-数据类型
|   |---MockData.ets                               // 模型层-模拟数据
|---view
|   |---MainView.ets                               // 视图层-主页面
|   |---WaterMarkView.ets                          // 视图层-水印
```

### 模块依赖

本实例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印、[资源](../../common/utils/src/main/resources/base/element)
的调用、[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[Canvas组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V2/ts-components-canvas-canvas-0000001427744852-V2)

[OffscreenCanvas对象](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V2/js-components-canvas-offscreencanvas-0000001477981277-V2)
