# 图片选择和下载保存案例

### 介绍

本示例介绍图片相关场景的使用：包含访问手机相册图片、选择预览图片并显示选择的图片到当前页面，下载并保存网络图片到手机相册或到指定用户目录，从web页面保存图片到相册三个场景。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/photo_pick_and_save.gif)

**使用说明**

1. 从主页通用场景集里选择**图片选择和下载保存**进入首页。
2. 分三个场景
- 点击“下载保存图片”文字，“下载网络图片到手机相册”场景示例。点击“下载”按钮，将图片保存到图库。点击“下载到指定路径”按钮，将图片保存到用户选择的指定路径，
- 点击“选择图片”文字进入”访问手机相册图片预览并选择”场景示例。点击下部“+”选择图片并显示到页面中。
- 长按web图片，弹出”是否保存图片“弹窗，点击”保存“后，弹出权限获取弹窗，给予权限后即可保存图片到相册。
### 实现思路

#### 场景1：访问手机相册图片预览并选择
通过photoViewPicker.select()拉起图库界面，用户可以预览并选择一个或多个文件，即可实现拉起手机相册并进行图片的预览与选择。

1. 创建文件类型为图片的，并最大预览数量为2的图库实例。

```
async getFileAssetsFromType(){
  const photoSelectOptions = new picker.PhotoSelectOptions(); // 创建图库对象实例
  photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE; // 选择媒体文件类型为Image
  photoSelectOptions.maxSelectNumber = 2; // 选择媒体文件的最大数目
 }
```
2. 通过photoViewPicker.select()接口,通过传入参数PhotoSaveOptions图库对象，获取返回的用户选择的图片信息。
```
  async getFileAssetsFromType(){  
    photoViewPicker.select(photoSelectOptions)
      .then((photoSelectResult) => { 
        this.uris = photoSelectResult.photoUris; // select返回的uri权限是只读权限，需要将uri写入全局变量@State中即可根据结果集中的uri进行读取文件数据操作。
      })
      .catch((err: BusinessError) => {
       console.info('Invoke photoViewPicker.select failed, code is ${err.code},message is ${err.message}');
      })
  }
```

#### 场景2：下载并保存网络图片
1. 通过http中request方法获取在线图片数据。

```ts
http.createHttp()
  .request('https://gitee.com/openharmony/applications_app_samples/raw/master/code/Solutions/Shopping/OrangeShopping/feature/navigationHome/src/main/resources/base/media/product002.png',
    (error: BusinessError, data: http.HttpResponse) => {
      if (error) {
        promptAction.showToast({
          message: $r("app.string.photopickandsave_image_request_fail"),
          duration: 2000
        })
        return
      }
      this.transcodePixelMap(data);
      if (data.result instanceof ArrayBuffer) {
        this.imageBuffer = data.result as ArrayBuffer;
      }
    })
```

2. 使用createPixelMap方法将获取到的图片数据转换成pixelmap展示到页面中

```ts
// 将ArrayBuffer类型的图片装换为PixelMap类型
transcodePixelMap(data: http.HttpResponse) {
  let code: http.ResponseCode | number = data.responseCode;
  if (ResponseCode.ResponseCode.OK === code) {
    let imageData: ArrayBuffer = data.result as ArrayBuffer;
    let imageSource: image.ImageSource = image.createImageSource(imageData);

    class tmp {
      height: number = 100;
      width: number = 100;
    };

    let options: Record<string, number | boolean | tmp> = {
      'alphaType': 0, // 透明度
      'editable': false, // 是否可编辑
      'pixelFormat': 3, // 像素格式
      'scaleMode': 1, // 缩略值
      'size': { height: 100, width: 100 }
    }; // 创建图片大小

    imageSource.createPixelMap(options).then((pixelMap: PixelMap) => {
      this.image = pixelMap;
      this.isShow = true
    });
  }
}
```

3. 将图片保存到图库或者用户选择的路径

   - 使用getPhotoAccessHelper、createAsset、fs.open、fs.write等接口将数据存到本地图库中
   ```ts
     async saveImage(buffer: ArrayBuffer | string): Promise<void> {
       let context = getContext(this) as common.UIAbilityContext;
       let helper = photoAccessHelper.getPhotoAccessHelper(context);
       let uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
       let file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
       await fs.write(file.fd, buffer);
       await fs.close(file.fd);
     }
   ```

   - 使用photoViewPicker.save、fs.open、fs.write等接口将数据存到用户选择路径的数据库中
   ```ts
     async pickerSave(buffer: ArrayBuffer | string): Promise<void> {
       const photoSaveOptions = new picker.PhotoSaveOptions(); // 创建文件管理器保存选项实例
       photoSaveOptions.newFileNames = ['PhotoViewPicker ' + new Date().getTime() + 'jpg'] // 保存文件名（可选）
       const photoViewPicker = new picker.PhotoViewPicker;
       photoViewPicker.save(photoSaveOptions)
         .then(async (photoSvaeResult) => {
           console.info('PhotoViewPicker.save successfully,photoSvaeResult uri:' + JSON.stringify(photoSvaeResult));
           let uri = photoSvaeResult[0];
           let file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
           await fs.write(file.fd, buffer);
           await fs.close(file.fd);
           promptAction.showToast({
             message: $r("app.string.photopickandsave_save_picture"),
             duration: 2000
           })
         })
     }
   ```

#### 场景3：从web页面保存图片到相册

1. 通过onContextMenuShow长按web图片获取图片链接。

   ```ts
   Web({ src: $rawfile('index.html'), controller: this.controller })
     .onContextMenuShow((event) => {
       // 判断是否是图片
       if (event && event.param.existsImageContents()) {
         // 获取图片链接
         this.imageUrl = event.param.getSourceUrl();
         logger.info(TAG, 'save image url success')
         this.showMenu = true;
       }
       return true;
     })
   ```

2. 通过request.downloadFile将图片下载到沙箱路径。

   ```ts
   downloadImage() {
     // 获取沙箱路径
     let filesDir = this.context.filesDir;
   
     try {
       // 将web页面的图片下载到沙箱路径
       request.downloadFile(this.context, {
         url: this.imageUrl,
         filePath: `${filesDir}/savePictureFromWeb.png`
       }).then((downloadTask: request.DownloadTask) => {
         downloadTask.on('complete', async () => {
           logger.info(TAG, 'download image succeed');
           // 下载成功后图片的沙箱路径
           const srcFileUris: string[] = [`${filesDir}/savePictureFromWeb.png`];
           await this.saveImage(srcFileUris);
         })
       }).catch((err: BusinessError) => {
         logger.error(TAG, `wq Invoke downloadTask failed, code is ${err.code}, message is ${err.message}`);
       });
     }catch (error){
       logger.error(TAG, `download image failed, code is: ${error.code}, message is: ${error.message}`);
     }
   }
   ```
   
3. 通过phAccessHelper.showAssetsCreationDialog获取保存图片到相册的权限，将图片保存到相册。

   ```ts
   async saveImage(srcFileUris: Array<string>) {
     let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
     try {
       let photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [
         {
           title: 'test',
           fileNameExtension: 'png',
           photoType: photoAccessHelper.PhotoType.IMAGE,
           subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
         }
       ];
       // 拉起授予权限的弹窗，获取将图片保存到相册的权限
       let desFileUris: Array<string> = await phAccessHelper.showAssetsCreationDialog(srcFileUris, photoCreationConfigs);
       logger.info(TAG, 'showAssetsCreationDialog success, data is:' + desFileUris);
       // 转换为uri
       let uri: string = fileUri.getUriFromPath(srcFileUris[0]);
       // 打开沙箱路径下图片
       const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_WRITE);
       // 读取沙箱路径下图片为buffer
       const photoSize: number = fs.statSync(file.fd).size;
       let arrayBuffer: ArrayBuffer = new ArrayBuffer(photoSize);
       let readLength: number = fs.readSync(file.fd, arrayBuffer);
       let imageBuffer: ArrayBuffer = buffer.from(arrayBuffer, 0, readLength).buffer;
       try {
         // 打开相册下路径
         let fileInAlbum = await fs.openSync(desFileUris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
         // 写入相册
         await fs.write(fileInAlbum.fd, imageBuffer);
         // 关闭文件
         await fs.close(file.fd);
         await fs.close(fileInAlbum.fd);
         logger.info(TAG, 'save image succeed');
         // 图片保存成功后，删掉沙箱路径下图片
         fs.unlinkSync(srcFileUris[0]);
         promptAction.showToast({
           message: $r('app.string.photo_pick_and_save_success_message'),
           duration: ANIMATION_DURATION
         });
         // 关闭bindPopup
         this.showMenu = false;
       } catch (error) {
         logger.error(TAG, `save image failed, code is: ${error.code}, message is: ${error.message}`);
       }
     } catch (err) {
       logger.error(TAG, `showAssetsCreationDialog failed, errCode is: ${err.code}, message is: ${err.message}`);
     }
   }
   ```

### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
   picturemanage                                   // har类型
   |---src/main/ets/components
   |   |---SelectPictures.ets                      // 场景一：访问手机相册图片预览并选择 
   |   |---SaveNetWorkPictures.ets                 // 场景二：下载网络图片并保存到手机相册或用户选择的文件夹
   |   |---SavePictureFromWeb.ets                  // 场景三：保存web图片到相册
   |   |---PictureManage.ets                       // 视图层-主页面，三个场景入口
   |---src/main/ets/utils
   |   |---Logger.ets                              // 日志打印模块
   ```

### 模块依赖
依赖[har包-common库中UX标准](../../common/utils/src/main/resources/base/element)


### 参考资料

[photoViewPicker参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-file-picker-0000001774121766)

[Web](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-basic-components-web-V13#oncontextmenushow9)

[photoAccessHelper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/js-apis-photoaccesshelper-V13)