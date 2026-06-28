# 图片编辑实现马赛克效果

### 介绍

本示例将原图手指划过的区域分割成若干个大小一致的小方格，然后获取每个小方格中的像素点的平均色彩数值，使用获取到的平均色彩数值替换该方格中所有的像素点。最后使用createPixelMapSync接口将新的像素点数据写入图片，即可实现原始图片的局部马赛克处理。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/image_mosaic.gif) 

**使用说明**

1. 进入页面，手指划过图片的某一个区域即可将该区域马赛克处理。点击底部的“恢复原图”按钮，将恢复为原图。

### 实现思路
1. 获取原始图片信息，将原始图片设置为可编辑状态。
   ```typescript
   /**
   * 获取图片内容
   */
   @Concurrent
   async function getImageContent(imgPath: string, context: Context): Promise<Uint8Array | undefined> {
     // 获取resourceManager资源管理
     const resourceMgr: resourceManager.ResourceManager = context.resourceManager;
     // 获取rawfile中的图片资源
     const fileData: Uint8Array = await resourceMgr.getRawFileContent(imgPath);
     return fileData;
   }
   ```

   ```typescript
   /**
   * 获取原始图片信息
   */
   async getSrcImageInfo(): Promise<void> {
    // TODO: 性能知识点：使用new taskpool.Task()创建任务项，传入获取图片内容函数和所需参数
    const task: taskpool.Task = new taskpool.Task(getImageContent, MosaicConstants.RAWFILE_PICPATH, getContext(this));
    try {
      const fileData: Uint8Array = await taskpool.execute(task) as Uint8Array;
      // 获取图片的ArrayBuffer
      const buffer = fileData.buffer.slice(fileData.byteOffset, fileData.byteLength + fileData.byteOffset);
      // 获取原图imageSource
      this.imageSource = image.createImageSource(buffer);
      // TODO 知识点： 将图片设置为可编辑
      const decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      }
      // 创建PixelMap
      this.pixelMapSrc = await this.imageSource.createPixelMap(decodingOptions);
    } catch (err) {
      console.error("getSrcImageInfo: execute fail, err:" + (err as BusinessError).toString());
    }
   }
   ```
2. 保存图片的原始尺寸及在屏幕的显示区域。

   ```typescript
    // 读取图片信息
    const imageInfo: image.ImageInfo = await this.pixelMapSrc!.getImageInfo();
    // 获取图片的宽度和高度
    this.imageWidth = imageInfo.size.width;
    this.imageHeight = imageInfo.size.height;
    // 获取屏幕尺寸
    const displayData: display.Display = display.getDefaultDisplaySync();
    // 计算图片的显示尺寸
    this.displayWidth = px2vp(displayData.width);
    this.displayHeight = this.displayWidth * this.imageHeight / this.imageWidth;
   ```
   
3. 获取手指按下和移动时的坐标，手指移动时执行马赛克任务。

   ```typescript
   PanGesture()
     .onActionStart((event: GestureEvent) => {
       const finger: FingerInfo = event.fingerList[0];
       if (finger == undefined) {
         return;
       }
       this.startX = finger.localX;
       this.startY = finger.localY;
       })
     .onActionUpdate((event: GestureEvent) => {
       const finger: FingerInfo = event.fingerList[0];
         if (finger == undefined) {
           return;
         }
         this.endX = finger.localX;
         this.endY = finger.localY;
         // 执行马赛克任务
         await this.doMosaicTask(this.startX, this.startY, this.endX, this.endY);
         this.startX = this.endX;
         this.startY = this.endY;
        })
   ```

4. 在马赛克任务中处理坐标转换问题后执行马赛克处理函数applyMosaic。

  ```typescript
  async doMosaicTask(offMinX: number, offMinY: number, offMaxX: number, offMaxY: number): Promise<void> {
    // TODO 知识点：将手势移动的起始坐标转换为原始图片中的坐标
    offMinX = Math.round(offMinX * this.imageWidth / this.displayWidth);
    offMinY = Math.round(offMinY * this.imageHeight / this.displayHeight);
    offMaxX = Math.round(offMaxX * this.imageWidth / this.displayWidth);
    offMaxY = Math.round(offMaxY * this.imageHeight / this.displayHeight);
    // 处理起始坐标大于终点坐标的情况
    if (offMinX > offMaxX) {
      const temp = offMinX;
      offMinX = offMaxX;
      offMaxX = temp;
    }
    if (offMinY > offMaxY) {
      const temp = offMinY;
      offMinY = offMaxY;
      offMaxY = temp;
    }
    // 获取像素数据的字节数
    const bufferData = new ArrayBuffer(this.pixelMapSrc!.getPixelBytesNumber());
    await this.pixelMapSrc!.readPixelsToBuffer(bufferData);
    // 将像素数据转换为 Uint8Array 便于像素处理
    let dataArray = new Uint8Array(bufferData);
    // TODO: 性能知识点：使用new taskpool.Task()创建任务项，传入任务执行函数和所需参数
    const task: taskpool.Task =
      new taskpool.Task(applyMosaic, dataArray, this.imageWidth, this.imageHeight, MosaicConstants.BLOCK_SIZE,
        offMinX, offMinY, offMaxX, offMaxY);
    try {
      taskpool.execute(task, taskpool.Priority.HIGH).then(async (res: Object) => {
        this.pixelMapSrc = image.createPixelMapSync((res as Uint8Array).buffer, this.opts);
        this.isMosaic = true;
      })
    } catch (err) {
      console.error("doMosaicTask: execute fail, " + (err as BusinessError).toString());
    }
  }
  ```

5. 实现图像局部马赛克处理函数

   ```typescript
   async applyMosaic(dataArray: Uint8Array, imageWidth: number, imageHeight: number, blockSize: number,
       offMinX: number, offMinY: number, offMaxX: number, offMaxY: number): Promise<Uint8Array | undefined> {
    try {
    // 计算横排和纵排的块数
    let xBlocks = Math.floor((Math.abs(offMaxX - offMinX)) / blockSize);
    let yBlocks = Math.floor((Math.abs(offMaxY - offMinY)) / blockSize);
    logger.info(MosaicConstants.TAG, 'xBlocks: ' + xBlocks.toString() + ' ,yBlocks:' + yBlocks.toString());
    // 不足一块的，按一块计算
    if (xBlocks < 1) {
      xBlocks = 1;
      offMaxX = offMinX + blockSize;
    }
    if (yBlocks < 1) {
      yBlocks = 1;
      offMaxY = offMinY + blockSize;
    }

    // 遍历每个块
    for (let y = 0; y < yBlocks; y++) {
      for (let x = 0; x < xBlocks; x++) {
        const startX = x * blockSize + offMinX;
        const startY = y * blockSize + offMinY;

        // 计算块内的平均颜色
        let totalR = 0;
        let totalG = 0;
        let totalB = 0;
        let pixelCount = 0;
        for (let iy = startY; iy < startY + blockSize && iy < imageHeight && iy < offMaxY; iy++) {
          for (let ix = startX; ix < startX + blockSize && ix < imageWidth && ix < offMaxX; ix++) {
            // TODO 知识点：像素点数据包括RGB通道的分量值及图片透明度
            const index = (iy * imageWidth + ix) * 4; // 4 像素点数据包括RGB通道的分量值及图片透明度
            totalR += dataArray[index];
            totalG += dataArray[index + 1];
            totalB += dataArray[index + 2];
            pixelCount++;
          }
        }
        const averageR = Math.floor(totalR / pixelCount);
        const averageG = Math.floor(totalG / pixelCount);
        const averageB = Math.floor(totalB / pixelCount);
        // TODO 知识点： 将块内平均颜色应用到块内的每个像素
        for (let iy = startY; iy < startY + blockSize && iy < imageHeight && iy < offMaxY; iy++) {
          for (let ix = startX; ix < startX + blockSize && ix < imageWidth && ix < offMaxX; ix++) {
            const index = (iy * imageWidth + ix) * 4; // 4 像素点数据包括RGB通道的分量值及图片透明度
            dataArray[index] = averageR;
            dataArray[index + 1] = averageG;
            dataArray[index + 2] = averageB;
          }
        }
      }
    }
    return dataArray;
    } catch (error) {
      logger.error(MosaicConstants.TAG, 'applyMosaic fail,err:' + error);
      return undefined;
    }
   }
   ```

### 高性能知识点

本示例使用了[taskpool](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/taskpool-introduction-0000001820879741)执行耗时操作以达到性能优化。

### 工程结构&模块类型
   ```
   imagemosaic                               // har类型  
   |---view  
   |   |---ImageMosaicView.ets               // 视图层-图片马赛克场景  
   |---constants  
   |   |---MosaicConstants.ets               // 常量  
   ```
   
### 模块依赖

本示例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印、[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

1. [位图操作](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-pixelmap-operation-0000001774280186)
2. [taskpool](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/taskpool-introduction-0000001820879741)  