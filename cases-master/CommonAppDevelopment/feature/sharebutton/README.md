# 分享二维码按钮案例

### 介绍

本示例介绍如何在应用中，通过url自动生成二维码，并通过Share Kit的接口拉起系统分享。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/share_button.gif" width="200">

**使用说明**
1. 点击任意案例。
2. 点击按钮"源码网页"。
3. 点击分享按钮，可以拉起系统的分享框。

### 实现思路

1. 通过url生成二维码。
    ```typescript
    // TODO: 知识点:通过调用systemShare的接口指定号码并跳转到发送短信页面
    async function createBarcode(content: string, size: number): Promise<image.PixelMap | null> {
      if (canIUse("SystemCapability.Multimedia.Scan.Core") && canIUse("SystemCapability.Multimedia.Scan.GenerateBarcode")) {
        try {
          // 以QR码为例，码图生成参数
          let options: generateBarcode.CreateOptions = {
            scanType: scanCore.ScanType.QR_CODE,
            height: size,
            width: size
          };
          let pixelMap: image.PixelMap = await generateBarcode.createBarcode(content, options);
          console.debug("生成码图成功");
          return pixelMap;
        } catch (error) {
          hilog.error(0x0001, '[generateBarcode]',
            `Failed to createBarcode by promise with options. Code: ${error.code}, message: ${error.message}`);
          return null;
        }
      } else {
        console.error("该设备暂不支持生成二维码");
        return null;
      }
    }
    ```
2. 将图片落盘成jpg格式图片，并包装成SharedData对象，作为分享的，供源数据分享使用
   ```typescript
   const file = fileIo.openSync(this.path,
     fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
   // 创建ImagePacker实例
   const imagePackerApi = image.createImagePacker();
   let picture = image.createPicture(this.generatedImage);
   // 设置打包参数
   let fullBuffer: ArrayBuffer = await imagePackerApi.packing(picture, {
     format: 'image/jpeg',
     quality: 98
   });
   let thumbnailBuffer: ArrayBuffer = await imagePackerApi.packing(picture, {
     format: 'image/jpeg',
     quality: 10
   });
   fileIo.writeSync(file.fd, fullBuffer);
   fileIo.close(file.fd);
   // 构造ShareData，需配置一条有效数据信息
   this.shareData = new systemShare.SharedData({
     utd: utd.UniformDataType.JPEG,
     uri: fileUri.getUriFromPath(this.path),
   });
   
   this.shareData.addRecord({
     utd: utd.UniformDataType.HYPERLINK,
     content: this.url, // 仅为示例 使用时请替换为自己的链接
     thumbnail: new Uint8Array(thumbnailBuffer),
   });
   ```
3. 通过controller拉起分享页面
   ```typescript
   this.sharedController?.show(this.ctx as common.UIAbilityContext, {
      anchor: "ShareButton",
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DETAIL
   }).then(() => {
      console.info('ShareController show success.');
   }).catch((error: BusinessError) => {
      console.error(`ShareController show error. code: ${error.code}, message: ${error.message}`);
   });
   ```
### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
   sharedbutton                                     // har类型
   |---src/main/ets/components/components
   |   |---ShareButton.ets                         // 分享按钮组件
   ```

### 模块依赖

[@ohos/routermodule(动态路由)](../../feature/routermodule)

### 参考资料

[Share Kit简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/share-introduction-V13)