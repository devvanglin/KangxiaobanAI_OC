# AI图片文字智能识别

### 介绍

本示例使用[CoreVisionKit](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/core-vision-text-recognition-api-V5)智能识别图片中的文字，并使用[NaturalLanguageKit](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/natural-language-api-V5)自然语言处理工具集将识别的文字智能转换为姓名、手机、地址等信息。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/address_recognize.gif)

**使用说明**

1. 点击【新增地址】后，再点击【图片识别】，选择拍照或者从相册选择照片。
2. 选择照片后，拖动裁剪框，截取带有地址信息的图片区域。
3. 点击【完成】，自动调用recognizeText方法，识别图片中的文本。
4. 点击【识别】，调用textProcessing进行文字智能转换并填充到联系人信息中。


### 实现思路

1. 点击图片识别，绑定一个bindSheet，弹出菜单半模态。
```typescript
  Button() {
    Row({ space: CommonConstants.SPACE_GAP_2 }) {
      Image($r('app.media.ic_public_camera'))
        .width($r('app.integer.icon_size_md'))
        .aspectRatio(1)
      Text($r('app.string.recognize_image_button'))
        .fontSize($r('app.integer.font_size_12'))
        .fontColor(Color.Black)
    }
    .padding({ left: $r('app.integer.padding_6'), right: $r('app.integer.padding_6') })
    .height($r('app.integer.recognize_button_height'))
  }
  .type(ButtonType.Normal)
  .backgroundColor($r('app.color.secondary'))
  .borderColor($r('app.color.recognize_background'))
  .onClick(() => {
    this.showMenu = true;
  })
  .borderWidth(CommonConstants.MIN_BORDER_WIDTH)
  .borderRadius($r('app.integer.border_radius_sm'))
  .bindSheet($$this.showMenu, this.builderMenus(), {
    height: $r('app.integer.bind_sheet_height'),
    backgroundColor: Color.White,
    showClose: false
  })
  
@Builder
builderMenus() {
  Column() {
    Text($r('app.string.take_photo_button'))
      .margin($r('app.integer.length_ten'))
      .fontSize($r('app.integer.font_size_16'))
      .onClick(() => {
        this.showMenu = false;
        this.takePhoto();
      })

    Divider().height(CommonConstants.DIVIDER_HEIGHT).color($r('app.color.divider_color'));

    Text($r('app.string.picker_button'))
      .margin($r('app.integer.length_ten'))
      .fontSize($r('app.integer.font_size_16'))
      .onClick(() => {
        this.showMenu = false;
        this.imagePicker();
      })

    Divider().height(CommonConstants.DIVIDER_HEIGHT).color($r('app.color.divider_color'));

    Text($r('app.string.cancel_button'))
      .margin($r('app.integer.length_ten'))
      .fontSize($r('app.integer.font_size_16'))
      .onClick(() => {
        this.showMenu = false;
      })

    Divider().height(CommonConstants.DIVIDER_HEIGHT).color($r('app.color.divider_color'));
  }
  .width($r('app.string.width_percent_full'))
    .height($r('app.integer.menu_height'))
}

```
2. 点击【从相册选择】打开图库，选择一张带有地址信息的照片，选择完照片打开照片裁剪弹窗界面。也可以选择拍照获取带地址的图片。
```typescript

/**
 * 选择图库照片
 */
imagePicker(): void {
   //选择选项
   const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
   // 过滤选择媒体文件类型为IMAGE
   photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
   // 选择媒体文件的最大数目
   photoSelectOptions.maxSelectNumber = 1;
   const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
   photoViewPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
     let uris = photoSelectResult.photoUris;
     if (uris.length > 0) {
       //打开照片裁剪弹窗
       this.openSnapshotEditDialog(uris[0]);
     }
  }).catch((err: BusinessError) => {
    console.error(`Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
  })
}

/**
 * 打开图片裁剪弹窗
 * @param uri
 */
openSnapshotEditDialog(uri: string): void {
  DialogUtil.showCustomDialog({
    dialogId: this.dialogId,
      builder: wrapBuilder(imageEditDialogBuilder),
      dialogType: DialogTypeEnum.BOTTOM,
      dialogBuilderParam: {
        onConfirm: (isCloseDialog?: boolean, data?: ESObject) => {
          if (isCloseDialog) {
            DialogUtil.closeCustomDialogById(this.dialogId);
            this.loadingId = loading($r('app.string.recognize_text'));
            this.recognizeImageToText(data);
          } else {
            promptAction.showToast({
              message: data,
              duration: CommonConstants.TOAST_DURATION
            });
          }
         },
         data: new ImageEditParam(uri, this.bottomHeight)
      },
      isSlideToClose: false,
      isModalClosedByOverlayClick: false
  });
}

```
3. 加载选择的图片，使用Canvas绘制蒙层、裁剪框等。
```typescript
Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
  Image(this.pixelMap)
    .width($r('app.string.width_percent_full'))
    .height($r('app.string.width_percent_full'))
    .objectFit(ImageFit.Contain)
  // 蒙层
  Canvas(this.canvasContext3)
    .position({
      x: this.initPosition.x,
      y: this.initPosition.y
    })
    .width(px2vp(this.imageInfo?.size.width))
    .height(px2vp(this.imageInfo?.size.height))
   // 裁剪框
  Canvas(this.canvasContext2)
    .position({
      x: this.clipRect.x,
      y: this.clipRect.y
    })
    .width(this.clipRect.width)
    .height(this.clipRect.height)
    .onReady(() => {
      this.drawClipImage()
    })
    .onTouch(event => {
      if (event.type === TouchType.Down) {
        this.isMove(event.target.area, event.touches[0]);
        this.touchPosition = {
          x: event.touches[0].screenX,
          y: event.touches[0].screenY
        }
      } else if (event.type === TouchType.Move) {
        let moveX = event.changedTouches[0].screenX - this.touchPosition.x;
        let moveY = event.changedTouches[0].screenY - this.touchPosition.y;
        this.touchPosition = {
          x: event.changedTouches[0].screenX,
          y: event.changedTouches[0].screenY
        }
        this.moveClipCanvas(moveX, moveY);
      }
    })
}
.width($r('app.string.width_percent_full'))
.height($r('app.string.size_percent_ninety'))
.backgroundColor($r('sys.color.black'))

```
4. 点击完成。调用pixelMap.crop完成图片裁剪，将裁剪后的pixelMap返回到主页面进行识别。

```typescript
/**
 * 裁剪图片
 */
async clipImage() {
  let x = this.clipRect.x - this.initPosition.x;
  let y = this.clipRect.y - this.initPosition.y;
  this.pixelMap?.crop({
    x: vp2px(x),
    y: vp2px(y),
    size: { height: vp2px(this.clipRect.height), width: vp2px(this.clipRect.width) }
  }).then(() => {
    this.param.onConfirm!(true, this.pixelMap);
  }).catch(() => {
    this.param.onConfirm!(false, $r('app.string.crop_area_fail_text'));
  })
}

/**
 * 识别图片转文字
 * @param pixelMap
 */
recognizeImageToText(pixelMap: image.PixelMap) {
  if (!pixelMap) {
    promptAction.showToast({
      message: $r('app.string.recognize_image_fail_text'),
      duration: CommonConstants.TOAST_DURATION
    });
    //清除loading
    clearLoading(this.loadingId);
    return;
  }
  // 调用文本识别接口
  let visionInfo: textRecognition.VisionInfo = {
    pixelMap: pixelMap
  };
  let textConfiguration: textRecognition.TextRecognitionConfiguration = {
    isDirectionDetectionSupported: false
  };
  setTimeout(() => {
    textRecognition.recognizeText(visionInfo, textConfiguration,
      (error: BusinessError, data: textRecognition.TextRecognitionResult) => {
        // 识别成功，获取对应的结果
        if (error.code == 0) {
          // 将结果更新到Text中显示
          this.recognizeText = data.value;
        }
    });
    //清除loading
    clearLoading(this.loadingId);
  }, CommonConstants.TOAST_DURATION);
}
```
5. 点击【识别】，调用AI接口智能将文本内容转换为姓名、电话、地址等信息，填充到联系人信息。
主要方法为textProcessing.getEntity，参数为需要识别的文本text以及需要识别的实体配置项entityConfig。
本案例主要识别地址信息，所以实体数组设置为[EntityType.NAME, EntityType.PHONE_NO, EntityType.LOCATION]，分别表示需要识别文本中的姓名、电话、地址信息。
得到识别的实体数组entities，根据每个实体对象中的type类型，判断是否是正确的结果。如果识别文本text中没有没有可识别的姓名、电话、地址等信息，则entities数组为空。

```typescript
/**
 * 识别文本
 */
recognizeAddress(): void {
  if (!this.recognizeText) {
    promptAction.showToast({
      message: $r('app.string.address_recognize_toast'),
      duration: CommonConstants.TOAST_DURATION,
      textColor: Color.Red
    });
    return;
  }
  this.loadingId = loading($r('app.string.recognize_text'));
  this.doEntityRecognition();
}

/**
 * 智能识别
 */
doEntityRecognition(): void {
  textProcessing.getEntity(this.recognizeText, {
    entityTypes: [EntityType.NAME, EntityType.PHONE_NO, EntityType.LOCATION]
  }).then(result => {
    this.formatEntityResult(result);
  }).catch((err: BusinessError) => {
    console.error(`getEntity errorCode: ${err.code} errorMessage: ${err.message}`);
    //清除loading
    clearLoading(this.loadingId);
  })
}

/**
 * 格式化识别结果
 * @param entities
 */
formatEntityResult(entities: textProcessing.Entity[]): void {
  if (!entities || !entities.length) {
    promptAction.showToast({
      message: $r('app.string.recognize_fail_text'),
      duration: CommonConstants.TOAST_DURATION
    });
    // 清除loading
    clearLoading(this.loadingId);
    return;
  }
  for (let i = 0; i < entities.length; i++) {
    let entity = entities[i];
    if (entity.type === EntityType.NAME) {
      // 姓名
      this.name = entity.text;
    } else if (entity.type === EntityType.PHONE_NO) {
      // 电话
      this.phone = entity.text;
    } else if (entity.type === EntityType.LOCATION) {
      // 地址
      this.address = entity.text;
    }
  }
  //清除loading
  clearLoading(this.loadingId);
}
```

### 工程结构&模块类型

```
addressrecognize                             // har类型
|---src
|   |---main
|   |     |---ets
|   |     |  |---common                        
|   |        |    |---CommonConstants.ets    // 常量定义 
|   |     |  |---components                        
|   |        |    |---Loading.ets            // 全局loading组件 
|   |     |  |---models           
|   |        |    |---Address.ets            // 地址相关实体类  
|   |        |    |---Bean.ets               // 简单实体类 
|   |        |    |---ImageEditParam.ets     // 图片裁剪参数类 
|   |     |  |---view                          
|   |        |    |---AddressRecognize.ets   // 主页面
|   |        |    |---ImageEdit.ets          // 图片裁剪界面
|   |     |  |---utils                        
|   |        |    |---WindowUtil.ets         // 工具方法类 
```

### 模块依赖

路由模块[注册路由](../routermodule/src/main/ets/router/DynamicsRouter.ets)。

### 参考资料

[Cavas绘制](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-canvasrenderingcontext2d-V5)

[自然语言理解](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/natural-language-api-V5)

[文字识别](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/core-vision-text-recognition-api-V5)

