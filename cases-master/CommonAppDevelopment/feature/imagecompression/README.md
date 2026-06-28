# 图片压缩方案

### 介绍

图片压缩在应用开发中是一个非常常见的需求，比如在处理用户上传图片时，需要上传指定大小以内的图片。目前图片压缩支持jpeg、webp、png格式。本例将介绍如何通过packing和scale实现图片压缩（如自动压缩到目标大小以内，手动调整图片质量和尺寸进行压缩等），以及把图片压缩成不同格式后保存到图库。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/image_compression.gif) 

**使用说明**

1. 进入页面，点击添加图片，从拉起的图库中选择一张图片，点击完成。在应用页面<code>压缩前</code>一栏会显示图片的大小以及格式。

2. <code>压缩模式</code>选择自动模式，输入图片压缩目标大小，可以自定义调整<code>scale每次缩小倍数</code>（相关参数说明点击右侧？帮助图标查看）。<code>压缩偏好</code>选择<code>优先压缩质量</code>，可以自定义调整<code>packing最小二分单位</code>（相关参数说明点击右侧？帮助图标查看）。可以选择图片压缩的输出格式。点击<code>压缩</code>按钮开始压缩，压缩完成后提示<code>压缩完成</code>，并在<code>压缩后</code>一栏显示压缩后预估的图片大小（<code>压缩后</code>所展示的图片大小，是该图片在内存中作为ArrayBuffer数据的压缩后大小，这一数值并不直接等同于该图片在最终保存到相册时的实际文件大小），以及压缩后的图片格式。点击<code>保存到图库</code>按钮，保存完成后提示<code>已保存到相册</code>。打开图库相册可查看保存的图片，相册中图片格式和<code>压缩后</code>一栏显示的格式一致，图片大小和<code>压缩后</code>一栏显示的图片大小相近。

3. <code>压缩模式</code>选择自动模式，输入图片压缩目标大小，可以自定义调整<code>scale每次缩小倍数</code>。<code>压缩偏好</code>选择<code>优先压缩尺寸</code>，可以自定义调整<code>最低图片质量</code>（相关参数说明点击右侧？帮助图标查看）。可以选择图片压缩的输出格式。点击<code>压缩</code>按钮开始压缩，压缩完成后提示<code>压缩完成</code>，并在<code>压缩后</code>一栏显示压缩后预估的图片大小，以及压缩后的图片格式。点击<code>保存到图库</code>按钮，保存后提示<code>已保存到相册</code>。打开图库相册可查看保存的图片，相册中图片格式和<code>压缩后</code>一栏显示的格式一致，图片大小和<code>压缩后</code>一栏显示的图片大小相近。

4. <code>压缩模式</code>选择手动模式，可以自定义调整图片质量和图片尺寸（相关参数说明点击右侧？帮助图标查看）。可以选择图片压缩的输出格式。点击压缩按钮开始压缩，压缩完成后提示<code>压缩完成</code>，并在<code>压缩后</code>一栏显示压缩后预估的图片大小，以及压缩后的图片格式。点击<code>保存到图库</code>按钮，保存后提示<code>已保存到相册</code>。打开图库相册可查看保存的图片，相册中图片格式和<code>压缩后</code>一栏显示的格式一致，图片大小和<code>压缩后</code>一栏显示的图片大小相近。

5. 点击应用页面上功能项右侧对应的？帮助图标可查看对应功能项的相关说明。

6. 手动模式的压缩是指手动调整图片质量和尺寸进行图片压缩。自动模式的压缩是指通过设置图片压缩目标大小，根据设置的相关压缩参数（如scale每次缩小倍数，packing最小二分单位，最低图片质量），将图片自动压缩至最接近但不超过该压缩目标的大小。但是如果参数配置不合理（如scale每次缩小倍数设置较大，但压缩目标大小又设置很小），可能会出现最终压缩出来的图片达不到设定的压缩目标大小。

7. 自动模式的压缩分为优先压缩图片质量和优先压缩图片尺寸。优先压缩图片质量是指优先通过调整图片质量进行压缩。但是如果图片质量压缩到最低仍然超过目标大小，则会再采用scale进行二次压缩。对于通过调整图片质量就能满足目标大小要求的图片，如果想要找到尽可能接近目标大小的最佳压缩大小，可以调低<code>packing最小二分单位</code>，但相应的压缩性能也会更差一些。优先压缩图片尺寸是指优先通过调整图片尺寸进行压缩。如果对图片质量要求不高但是需要压缩后的图片尺寸尽可能大一些也可以调低<code>最低图片质量</code>。

### 实现思路

1. 拉起图库选择要压缩的图片。使用photoAccessHelper.PhotoViewPicker创建图库选择器实例photoViewPicker，调用photoViewPicker.select()接口拉起图库界面进行图片选择。图片选择成功后，返回photoSelectResult结果集。从photoSelectResult.photoUris中获取返回图库选择后的媒体文件的uri数组，从而获取图片大小，并在页面上显示选择的图片。

```typescript
async selectPhotoFromAlbum() {
  // 创建图库选项实例
  const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  // 设置选择的媒体文件类型为Image
  photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  // 设置选择媒体文件的最大数目
  photoSelectOptions.maxSelectNumber = 1;
  // 创建图库选择器实例
  const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
  // 调用photoViewPicker.select()接口拉起图库界面进行图片选择，图片选择成功后，返回photoSelectResult结果集。
  photoViewPicker.select(photoSelectOptions).then((photoSelectResult) => {
    // select返回的uri权限是只读权限，需要将uri写入全局变量@State中即可进行读取文件数据操作。
    this.uris = photoSelectResult.photoUris;
    this.photoCount = this.uris.length;
    if (this.photoCount > 0) {
      const ALBUM_PATH: string = photoSelectResult.photoUris[0];
      // 找到最后一个点（.）的索引位置
      let lastDotIndex = ALBUM_PATH.lastIndexOf('.');
      // 使用slice方法从最后一个点之后的位置开始截取字符串到末尾
      this.beforeCompressFmt =
        ALBUM_PATH.slice(lastDotIndex + 1) === 'jpg' ? 'jpeg' : ALBUM_PATH.slice(lastDotIndex + 1);
      this.afterCompressFmt = this.beforeCompressFmt;
      // 读取选择图片的buffer
      const file = fs.openSync(ALBUM_PATH, fs.OpenMode.READ_ONLY);
      // 获取选择图片的字节长度
      this.beforeCompressByteLength = fs.statSync(file.fd).size;
      fs.closeSync(file);
    }
  }).catch((err: BusinessError) => {
    hilog.error(0x0000, TAG, `PhotoViewPicker.select failed :, error code: ${err.code}, message: ${err.message}.`);
  })
}
```

2. 手动模式压缩图片。先获取从图库选择的图片uris，然后将图片数据读取到buffer。通过createImageSource(buffer)创建图片源实例，设置解码参数DecodingOptions，传入createPixelMap创建PixelMap图片对象originalPixelMap。使用scale进行图片尺寸压缩，使用packing进行图片质量压缩。

```typescript
manualCompression() {
  const ALBUM_PATH: string = this.uris[0];
  const file = fs.openSync(ALBUM_PATH, fs.OpenMode.READ_ONLY);
  let buffer = new ArrayBuffer(fs.statSync(file.fd).size);
  fs.readSync(file.fd, buffer);
  fs.closeSync(file);
  const decodingOptions: image.DecodingOptions = { editable: true };
  const imageSource: image.ImageSource = image.createImageSource(buffer);
  imageSource.createPixelMap(decodingOptions).then(async (originalPixelMap: image.PixelMap) => {
    // 使用scale对图片进行缩放。入参分别为图片宽高的缩放倍数
    await originalPixelMap.scale(this.imageScaleVal / 100, this.imageScaleVal / 100);
    // savePixelMap用于把压缩后的图片保存到图库时使用。由于保存图片时调用的packToFile内部会做类似packing的处理，所以这里只保存scale缩放尺寸后的PixelMap。
    this.savePixelMap = originalPixelMap;
    // packing压缩图片
    let compressedImageData: ArrayBuffer =
      await this.packing(originalPixelMap, this.imageQualityVal, this.afterCompressFmt);
    // 压缩后的ArrayBuffer数据转PixelMap
    let imageSource = image.createImageSource(compressedImageData);
    let opts: image.DecodingOptions = { editable: true };
    // showPixelMap用于显示压缩后的图片
    this.showPixelMap = await imageSource.createPixelMap(opts);
    // showCompressFormat用于显示压缩后的图片格式
    this.showCompressFormat = this.afterCompressFmt;
    // 显示估算packing压缩后的图片大小。该图片在内存中作为ArrayBuffer数据的压缩后大小，这一数值并不直接等同于该图片在最终保存到相册时的实际文件大小。
    this.afterCompressionSize = (compressedImageData.byteLength / BYTE_CONVERSION).toFixed(1);
    promptAction.showToast({ message: $r('app.string.image_compression_compress_completed') });
  }).catch((err: BusinessError) => {
    hilog.error(0x0000, TAG, `Failed to create PixelMap, error code: ${err.code}, message: ${err.message}.`);
  });
}
```

3. 自动模式（指定压缩目标大小）优先压缩图片尺寸。优先使用scale对图片进行尺寸缩放，采用while循环每次递减reduceScaleVal倍数（对应‘scale每次缩小倍数’）进行尺寸缩放，再用packing（其中图片质量参数quality根据‘最低图片质量’设置）获取压缩后的图片大小，最终查找压缩到最接近指定图片压缩目标的大小，并获取图片压缩数据用于后续图片保存。
```typescript
async scalePriorityCompress(sourcePixelMap: image.PixelMap, maxCompressedImageSize: number, quality: number) {
  // ...
  // scale压缩图片尺寸。采用while循环每次递减reduceScaleVal，最终查找到最接近指定图片压缩目标大小的缩放倍数的图片压缩数据。
  let imageScale = 1; // 定义图片宽高的缩放倍数，1表示原比例。
  const REDUCE_SCALE = this.reduceScaleVal;
  const AFTER_COMPRESS_FMT = this.afterCompressFmt;
  // 判断压缩后的图片大小是否大于指定图片的压缩目标大小，如果大于，继续降低缩放倍数压缩。
  while (compressedImageData.byteLength > maxCompressedImageSize * BYTE_CONVERSION) {
    if (imageScale > 0) {
      // 性能知识点: 由于scale会直接修改图片PixelMap数据，所以不适用二分查找scale缩放倍数。这里采用循环递减reduceScaleVal缩放图片，
      // 来查找确定最适合的缩放倍数。如果对图片压缩质量要求不高，建议调高每次递减的缩放倍数，减少循环，提升scale压缩性能。
      imageScale = imageScale - REDUCE_SCALE; // 每次缩放倍数
      // 使用scale对图片尺寸进行缩放
      await sourcePixelMap.scale(imageScale, imageScale);
      // packing压缩
      compressedImageData = await this.packing(sourcePixelMap, quality, AFTER_COMPRESS_FMT);
    } else {
      // imageScale缩放倍数小于等于0时，没有意义，结束压缩。
      break;
    }
  }
  // ...
}
```

4. 自动模式（指定压缩目标大小）优先压缩图片质量。先判断设置图片质量参数为0时，packing能压缩到的图片最小字节大小compressedImageData.byteLength是否满足指定的图片压缩大小。如果满足，则使用packing方式二分查找最接近指定图片压缩目标大小的quality来压缩图片。如果不满足，则图片质量按最低0进行设置，并调用scalePriorityCompress进行scale尺寸压缩。

```typescript
// 优先压缩图片质量
async qualityPriorityCompress(sourcePixelMap: image.PixelMap, maxCompressedImageSize: number) {
  let compressedImageData: ArrayBuffer =
    await this.packing(sourcePixelMap, IMAGE_QUALITY_ZERO, this.afterCompressFmt);
  // 先判断图片质量参数设置最低0能否满足目标大小。如果能满足目标大小，则直接使用packing二分图片质量。如果不满足，则质量参数固定为0，进行scale尺寸压缩
  if (compressedImageData.byteLength <= maxCompressedImageSize * BYTE_CONVERSION) {
    // 满足目标大小，直接使用packing二分
    await this.packingImage(sourcePixelMap, compressedImageData, maxCompressedImageSize * BYTE_CONVERSION);
  } else {
    // 不满足目标大小，质量参数设置为0，再进行scale尺寸压缩
    await this.scalePriorityCompress(sourcePixelMap, maxCompressedImageSize, IMAGE_QUALITY_ZERO);
  }
  // 更新显示压缩后的图片格式
  this.showCompressFormat = this.afterCompressFmt;
}

// packing二分方式循环压缩
async packingImage(sourcePixelMap: image.PixelMap, compressedImageData: ArrayBuffer, maxCompressedImageByte: number) {
  let imageQuality: number = 0;
  const DICHOTOMY_ACCURACY = this.minBisectUnit;
  // 图片质量参数范围为0-100，这里以minBisectUnit为最小二分单位创建用于packing二分图片质量参数的数组。
  const packingArray: number[] = [];
  // 性能知识点: 如果对图片压缩质量要求不高，建议调高minBisectUnit（对应‘packing最小二分单位’），减少循环，提升packing压缩性能。
  for (let i = 0; i <= 100; i += DICHOTOMY_ACCURACY) {
    packingArray.push(i);
  }
  let left = 0; // 定义二分搜索范围的左边界
  let right = packingArray.length - 1; // 定义二分搜索范围的右边界
  const AFTER_COMPRESS_FMT = this.afterCompressFmt;
  // 二分压缩图片
  while (left <= right) {
    const mid = Math.floor((left + right) / 2); // 定义二分搜索范围的中间位置
    imageQuality = packingArray[mid]; // 获取二分中间位置的图片质量值
    // 根据传入的图片质量参数进行packing压缩，返回压缩后的图片文件流数据。
    compressedImageData = await this.packing(sourcePixelMap, imageQuality, AFTER_COMPRESS_FMT);
    // 判断查找一个尽可能接近但不超过压缩目标的压缩大小
    if (compressedImageData.byteLength <= maxCompressedImageByte) {
      // 二分目标值在右半边，继续在更高的图片质量参数（即mid + 1）中搜索
      left = mid + 1;
      // 判断mid是否已经二分到最后，如果二分完了，退出
      if (mid === packingArray.length - 1) {
        break;
      }
      // 获取下一次二分的图片质量参数（mid+1）压缩的图片文件流数据
      compressedImageData = await this.packing(sourcePixelMap, packingArray[mid + 1], AFTER_COMPRESS_FMT);
      // 判断用下一次图片质量参数（mid+1）压缩的图片大小是否大于指定图片的压缩目标大小。如果大于，说明当前图片质量参数（mid）压缩出来的
      // 图片大小最接近指定图片的压缩目标大小。传入当前图片质量参数mid，得到最终目标图片压缩数据。
      if (compressedImageData.byteLength > maxCompressedImageByte) {
        compressedImageData = await this.packing(sourcePixelMap, packingArray[mid], AFTER_COMPRESS_FMT);
        break;
      }
    } else {
      // 目标值不在当前范围的右半部分，将搜索范围的右边界向左移动，以缩小搜索范围并继续在下一次迭代中查找左半部分。
      right = mid - 1;
    }
  }
  // ...
}
```

5. 压缩后的图片数据保存到相册。通过photoAccessHelper.getPhotoAccessHelper获取相册管理模块的实例，使用createAsset创建图片资源，然后使用createImagePacker创建ImagePacker实例。最后调用imagePacker.packToFile传入压缩后的PixelMap图片源，对应的图片格式和质量参数packOpts，编码后打包进图片文件，图片将自动保存到相册。需要说明packToFile内部会进行packing操作，所以传入packToFile的PixelMap对象只是scale尺寸缩放后的图片数据，最终需要压缩的图片质量通过packOpts进行设置。

```typescript
async saveImageToAlbum(): Promise<void> {
  // 获取相册管理模块的实例
  const HELPER = photoAccessHelper.getPhotoAccessHelper(this.context);
  // 指定待创建的文件类型、后缀和创建选项，创建图片资源
  const URI = await HELPER.createAsset(photoAccessHelper.PhotoType.IMAGE, this.afterCompressFmt);
  let file = await fs.open(URI, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  let imagePacker = image.createImagePacker();
  let packOpts: image.PackingOption = {
    format: 'image/' + this.afterCompressFmt,
    quality: this.isAutoMode ? this.autoModeQuality : this.imageQualityVal
  };
  // 指定打包参数，将PixelMap图片源编码后直接打包进文件
  imagePacker.packToFile(this.savePixelMap, file.fd, packOpts, async (err: BusinessError) => {
    if (err) {
      hilog.error(0x0000, TAG, `Failed to pack the image to file, error code: ${err.code}, message: ${err.message}.`);
    } else {
      promptAction.showToast({ message: $r('app.string.image_compression_save_image_msg') });
    }
    // TODO 知识点：使用packToFile方法，需要调用imagePacker.release主动释放imagePacker，打开图库时才能看到新存入的图片
    await fs.close(file.fd).finally(() => {
      imagePacker.release();
    })
  })
}
```

### 高性能知识点

本示例packing方式压缩图片时，使用二分查找最接近指定图片压缩目标大小的图片质量quality来压缩图片，提升查找性能。

### 工程结构&模块类型

   ```
   imagecompression                               // har类型
   |---view
   |   |---ImageCompression.ets                   // 视图层-图片压缩页面
   |   |---HelpDescription.ets                    // 视图层-自定义帮助组件
   ```

### 模块依赖

本示例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印、[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

1. [图片编码](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/image-encoding-V5)
2. [packing](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-image-V5#packing)
3. [scale](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-image-V5#scale9)
4. [相册管理模块](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-photoaccesshelper-V5#photoaccesshelpergetphotoaccesshelper)