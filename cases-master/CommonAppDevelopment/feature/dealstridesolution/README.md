# 解决相机预览花屏案例

### 介绍

本示例用于开发者在[使用相机服务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/camera-kit-V5)时，如果仅用于预览流展示，通常使用[XComponent](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-xcomponent-V5)组件实现，如果需要获取每帧图像做二次处理（例如获取每帧图像完成二维码识别或人脸识别场景），可以通过[ImageReceiver](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-image-V5#imagereceiver9)中imageArrival事件监听预览流每帧数据，解析图像内容。在解析图像内容时，如果未考虑stride，直接通过使用width*height读取图像内容去解析图像，会导致相机预览异常，从而出现相机预览花屏的现象。当预览流图像stride与width不一致时，需要对stride进行无效像素的去除处理。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/deal_stride_solution.gif" width="300" >

**使用说明**

1. 本案例仅支持真机验证，因在案例集合中导致权限弹窗reason只支持一种string。
2. 点击进入案例，授权给相机。
3. 三个方案滑动页面不会出现花屏。
4. 点击相机右上角方案说明，可出现相关方案的具体描述。

### 实现思路

本例涉及的关键特性和实现方案如下：

#### 方案一

1. 应用通过image.ImageReceiver注册imageArrival图像回调方法，获取每帧图像数据实例image.Image，应用通过定义一个width为1920*height为1080分辨率的预览流直接创建pixelMap，此时获取到的stride的值为1920。源码参考[CameraServiceCrop.ets](./src/main/ets/model/CameraServiceCrop.ets)。

```typescript
onImageArrival(receiver: image.ImageReceiver): void {
  receiver.on('imageArrival', () => {
  receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
  if (err || nextImage === undefined) {
  logger.error(TAG, `requestPermissionsFromUser call Failed! error: ${err.code}`);
  return;
}
if (nextImage) {
  nextImage.getComponent(image.ComponentType.JPEG, async (_err, component: image.Component) => {
    let width = 1920; // width为应用创建预览流分辨率对应的宽
    let height = 1080; // height为应用创建预览流分辨率对应的高
    let stride = component.rowStride; // 通过component.rowStride获取stride
    logger.info(TAG, `receiver getComponent width:${width} height:${height} stride:${stride}`);
    // stride和width相等，按宽读取buffer不影响结果
    if (stride === width) {
      let pixelMap = await image.createPixelMap(component.byteBuffer, {
        size: { height: height, width: width },
        srcPixelFormat: image.PixelMapFormat.NV21,
      })
      AppStorage.setOrCreate('stridePixel', pixelMap);
    } else {
      ...
    }
    nextImage.release();
  })
}
});
})
}
```

2. 在初始相机模块时，调用onImageArrival()，将未处理的width和height作为size，创建PixelMap，通过在Image中传入被@StorageLink修饰的变量stridePixel进行数据刷新，图片送显。源码参考[ImageViewCrop.ets](./src/main/ets/components/ImageViewCrop.ets)。

```typescript
Column() {
  Stack() {
    if (this.isShowStridePixel) {
      Image(this.stridePixel)
        .rotate({
          z: 0.5,
          angle: this.previewRotate
        })
        .zIndex(0)
    }
  }
  .width(px2vp(this.imageWidth))
  .height(px2vp(this.imageHeight))
}
.onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRation: number) => {
  // 切换组件时清除不可见的页面信息，重新进入组件时重新进入相机
  if (isVisible) {
    CameraServiceCrop.initCamera(this.cameraDeviceIndex);
  } else {
    CameraServiceCrop.releaseCamera();
  }
})
```

3. 当stride和width相等时，按宽读取buffer不影响结果。
当stride和width不等时，如果应用想使用byteBuffer预览流数据创建pixelMap直接显示，可以根据stride*height字节的大小先创建pixelMap，然后调用PixelMap的cropSync方法裁剪掉多余的像素，从而正确处理stride，解决预览流花屏问题。源码参考[CameraServiceCrop.ets](./src/main/ets/model/CameraServiceCrop.ets)。

```typescript
onImageArrival(receiver: image.ImageReceiver): void {
  receiver.on('imageArrival', () => {
  receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
  if (err || nextImage === undefined) {
  logger.error(TAG, `requestPermissionsFromUser call Failed! error: ${err.code}`);
  return;
}
if (nextImage) {
  nextImage.getComponent(image.ComponentType.JPEG, async (_err, component: image.Component) => {
    let width = 1920; // width为应用创建预览流分辨率对应的宽
    let height = 1080; // height为应用创建预览流分辨率对应的高
    let stride = component.rowStride; // 通过component.rowStride获取stride
    logger.info(TAG, `receiver getComponent width:${width} height:${height} stride:${stride}`);
    // stride和width相等，按宽读取buffer不影响结果
    if (stride === width) {
      ...
    } else {
      let pixelMap = await image.createPixelMap(component.byteBuffer, {
        // 1.创建PixelMap时width传stride。
        size: { height: height, width: stride },
        srcPixelFormat: 8,
      })
      // 2.然后调用PixelMap的cropSync方法裁剪掉多余的像素。
      pixelMap.cropSync({
        size: { width: width, height: height },
        x: 0,
        y: 0
      }) // 根据输入的尺寸裁剪图片,从(0,0)开始，裁剪width*height字节的区域。
      let pixelBefore: PixelMap | undefined = AppStorage.get('stridePixel');
      await pixelBefore?.release();
      AppStorage.setOrCreate('stridePixel', pixelMap);
    }
    nextImage.release();
  })
}
});
})
}
```

#### 方案二

1. 方案二的创建pixelMap、图片送显和方案一的1、2步骤一样，此处不再赘述。

   当stride和width相等时，按宽读取buffer不影响结果。
   当stride和width不等时，将相机返回的预览流数据即component.byteBuffer的数据去除stride，拷贝得到新的dstArr数据进行数据处理，将处理后的dstArr数组buffer，通过width和height直接创建pixelMap, 并存储到全局变量stridePixel中，传给Image送显，解决预览流花屏问题。源码参考[CameraServiceUint.ets](./src/main/ets/model/CameraServiceUint.ets)。

```typescript
onImageArrival(receiver: image.ImageReceiver): void {
  receiver.on('imageArrival', () => {
  receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
  if (err || nextImage === undefined) {
  logger.error(TAG, `requestPermissionsFromUser call Failed! error: ${err.code}`);
  return;
}
if (nextImage) {
  nextImage.getComponent(image.ComponentType.JPEG,
    async (err, component: image.Component) => {
      let width = 1920; // width为应用创建预览流分辨率对应的宽
      let height = 1080; // height为应用创建预览流分辨率对应的高
      let stride = component.rowStride; // 通过component.rowStride获取stride
      logger.info(TAG, `receiver getComponent width:${width} height:${height} stride:${stride}`);
      // 当图片的width等于相机预览流返回的行跨距stride，此时无需处理stride，通过width和height直接创建pixelMap,并存储到全局变量stridePixel中，传给Image送显。
      if (stride === width) {
       ...
      } else {
        // 当图片的width不等于相机预览流返回的行跨距stride，此时将相机返回的预览流数据component.byteBuffer去除掉stride，拷贝得到新的dstArr数据，数据处理后传给其他不支持stride的接口处理。
        const dstBufferSize = width * height * 1.5; // 创建一个width * height * 1.5的dstBufferSize空间，此处为NV21数据格式。
        const dstArr = new Uint8Array(dstBufferSize); // 存放去掉stride后的buffer。
        // 读取每行数据，相机支持的profile宽高均为偶数，不涉及取整问题。
        for (let j = 0; j < height * 1.5; j++) { // 循环dstArr的每一行数据。
          // 拷贝component.byteBuffer的每行数据前width个字节到dstArr中(去除无效像素，刚好每行得到一个width*height的八字节数组空间)。
          const srcBuf = new Uint8Array(component.byteBuffer, j * stride,
            width); // 将component.byteBuffer返回的buffer，每行遍历，从首位开始，每行截取出width字节。
          dstArr.set(srcBuf, j * width); // 将width*height大小的数据存储到dstArr中。
        }
        let pixelMap = await image.createPixelMap(dstArr.buffer, {
          // 将处理后的dstArr数组buffer，通过width和height直接创建pixelMap,并存储到全局变量stridePixel中，传给Image送显。
          size: { height: height, width: width },
          srcPixelFormat: image.PixelMapFormat.NV21,
        })
        AppStorage.setOrCreate('stridePixel', pixelMap);
      }
      nextImage.release();
    })
}
});
})
}
```

#### 方案三

1. 使用XComponent渲染预览对象输出的图像，源码参考[XComponentView.ets](./src/main/ets/component/XComponentView.ets)。

```typescript
Stack() {
  XComponent({
    type: XComponentType.SURFACE,
    controller: this.xComponentCtl
  })
    .onLoad(async () => {
      logger.info('onLoad is called');
      this.xComponentSurfaceId = this.xComponentCtl.getXComponentSurfaceId(); // 获取组件surfaceId
      // 初始化相机，组件实时渲染每帧预览流数据
      CameraService.initCamera(this.cameraDeviceIndex, this.xComponentSurfaceId);
    })
    .zIndex(0)

  PublishView({ imageWidth: this.imageWidth, imageHeight: this.imageHeight })
    .zIndex(1)

}
.onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRation: number) => {
  if (isVisible) {
    CameraService.initCamera(this.cameraDeviceIndex, this.xComponentSurfaceId);
  } else {
    CameraService.releaseCamera();
  }
})
```

2. 在初始相机模块时，使用getXComponentSurfaceId获取XComponent对应Surface的ID，调用createPreviewOutput创建预览输出对象，图片送显，源码参考[CameraService.ets](./src/main/ets/model/CameraService.ets)。

```typescript
async initCamera(cameraDeviceIndex: number, xComponentSurfaceId: string): Promise<void> {
  logger.debug(TAG, `initCamera cameraDeviceIndex: ${cameraDeviceIndex}`);
  try {
    await this.releaseCamera();
    // 获取相机管理器实例
    this.cameraManager = this.getCameraManagerFn();
    if (this.cameraManager === undefined) {
      logger.error(TAG, 'cameraManager is undefined');
      return;
    }
    this.cameras = this.getSupportedCamerasFn(this.cameraManager);
    this.curCameraDevice = this.cameras[cameraDeviceIndex];
    if (this.curCameraDevice === undefined) {
      logger.error(TAG, 'Failed to create the camera input.');
      return;
    }
    // 创建cameraInput输出对象
    this.cameraInput = this.createCameraInputFn(this.cameraManager, this.curCameraDevice);
    if (this.cameraInput === undefined) {
      logger.error(TAG, 'Failed to create the camera input.');
      return;
    }
    // 打开相机
    let isOpenSuccess = await this.cameraInputOpenFn(this.cameraInput);
    if (!isOpenSuccess) {
      logger.error(TAG, 'Failed to open the camera.');
      return;
    }
  
    // 选择具有不同的stride和width
    let previewProfile: camera.Profile = {
      format: camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP,
      size: {
        width: Constants.X_COMPONENT_SURFACE_WIDTH,
        height: Constants.X_COMPONENT_SURFACE_HEIGHT
      }
    };
    let size: image.Size = {
      width: Constants.X_COMPONENT_SURFACE_WIDTH,
      height: Constants.X_COMPONENT_SURFACE_HEIGHT
    }
    this.receiver = image.createImageReceiver(size, image.ImageFormat.JPEG, 8);
    this.previewOutput = this.createPreviewOutputFn(this.cameraManager, previewProfile, xComponentSurfaceId);
    if (this.previewOutput === undefined) {
      logger.error(TAG, 'Failed to create the preview stream.');
      return;
    }
    // 会话流
    await this.sessionFlowFn(this.cameraManager, this.cameraInput, this.previewOutput);
  } catch (error) {
    logger.error(TAG, `initCamera fail: ${JSON.stringify(error)}`);
  }
}
```

#### 注意

本示例未设置成全屏状态，开发者可通过设置宽或高为100%，再根据当前设备的像素比设置aspectRatio(宽/高)，例如Mate60可设置为aspectRatio(9/16)。

```typescript
Stack() {
  if (this.isShowStridePixel) {
    Image(this.stridePixel)
      .rotate({
        z: 0.5,
        angle: this.previewRotate
      })
      .zIndex(0)
  }
}
.width('100%')
.aspectRatio(9/16)
```

### 工程结构&模块类型

   ```
dealstridesolution                           // har类型
|---components
|   |---ImageViewCrop.ets                    // 组件层-使用cropSync方法裁剪掉多余的像素处理图像组件
|   |---ImageViewUint.ets                    // 组件层-使用新建的width和height直接创建pixelMap处理图像组件
|   |---MainPage.ets                         // 组件层-tab主页面
|   |---XComponentView.ets                   // 组件层-使用createPreviewOutput创建预览输出对象直接输出图像组件
|---model 
|   |---CameraService.ets                    // 模型层-使用createPreviewOutput创建预览输出对象直接输出图像
|   |---CameraServiceCrop.ets                // 模型层-使用cropSync方法裁剪掉多余的像素处理图像
|   |---CameraServiceUint.ets                // 模型层-使用新建的width和height直接创建pixelMap处理图像
|---common 
|   |---Constants.ets                        // 公共层-相关方案解释信息
|   |---Logger.ets                           // 公共层-日志
   ```

### 模块依赖

[routermodule(动态路由)](../../common/routermodule/README_AUTO_GENERATE.md)

### 参考资料

- [相机预览花屏解决方案](https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-deal-stride-solution-V5)
- [双路预览(ArkTS)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/camera-dual-channel-preview-V5)