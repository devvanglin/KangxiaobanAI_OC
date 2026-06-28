# 人脸识别验证案例

### 介绍

本示例介绍使用[VisionKit(视觉服务)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/vision-arkts-V5)实现活体检测，使用[CryptoArchitectureKit(加解密算法框架服务)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-cryptoframework-V5)实现加解密。该案例多用于实名认证、身份证上传等场景。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/live_detection_encryption.gif" width="200">

**使用说明**

1. 首页签中登录按钮，拉起半模态弹窗。
2. 半模态弹窗中点击同意协议认证按钮，开始人脸检测，检测完回到首页弹窗提示检测结果

### 实现思路

1. 使用interactiveLiveness.startLivenessDetection方法，拉起活体检测页面。源码参考[StartFacialFecognition.ets](./src/main/ets/components/StartFacialFecognition.ets)
```ts
public static privateStartDetection(routerOptions: interactiveLiveness.InteractiveLivenessConfig,
  permissionArr: Array<Permissions>) {
  let context = getContext();
  // 向用户申请权限，此处为相机权限
  abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissionArr).then((res) => {
    for (let i = 0; i < res.permissions.length; i++) {
      if (res.permissions[i] === 'ohos.permission.CAMERA' && res.authResults[i] === 0) {
        // 拉起活体检测
        interactiveLiveness.startLivenessDetection(routerOptions).then((DetectState: boolean) => {
        })
      }
    }
  })
}
  ```
2. 使用interactiveLiveness.getInteractiveLivenessResult方法，获取活体检测结果。源码参考[StartFacialRecognition.ets](./src/main/ets/components/StartFacialFecognition.ets)
```ts
public static getDetectionResultInfo() {
  // getInteractiveLivenessResult接口调用完会释放资源
  let resultInfo = interactiveLiveness.getInteractiveLivenessResult();
  const promise: Promise<interactiveLiveness.InteractiveLivenessResult> = new Promise((resolve, reject) => {
    resultInfo.then(async (data) => {
      if (data.mPixelMap !== undefined) {
        promptAction.showToast({
          message: $r('app.string.start_decrypt_success_text'),
          duration: promptActionDuration
        });
        resolve(data);
      } else {
        promptAction.showToast({
          message: $r('app.string.start_decrypt_error_text'),
          duration: promptActionDuration
        });
      }
    }).catch((err: BusinessError) => {
      if (err.code !== 1008302000) {
        promptAction.showToast({
          message: err.message + '，请重试',
          duration: promptActionDuration
        });
      }
      reject(err);
    })
  })
  return promise;
}
  ```
3. 使用util工具类对图片base64和pixelmap互相转换。源码参考[Encode.ets](./src/main/ets/components/Encode.ets)、[liveDetectionAndEncryptionPage.ets](./src/main/ets/pages/LiveDetectionAndEncryptionPage.ets)
```ts
export function arrayBufferToBase64(buffer: ArrayBuffer) {
  const base64Helper = new util.Base64Helper();
  let data = base64Helper.encodeSync(new Uint8Array(buffer.slice(0, buffer.byteLength)));
  let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  return textDecoder.decodeToString(data, { stream: false });
}
  ```
4.通过cipher对象实现对图片和文字的加解密操作。源码参考[Encode.ets](./src/main/ets/components/Encode.ets)
```ts
export async function encryptMessagePromise(plainText: string,
  cryptoMode: cryptoFramework.CryptoMode) {
  let base = new util.Base64Helper();
  // 通过指定算法名称，获取相应的Cipher实例。Cipher：提供加解密的算法操作功能。
  let cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7');
  // 通过指定算法名称的字符串，获取相应的对称密钥生成器实例
  let symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  let keyMaterialBlob = genKeyMaterialBlob();
  // 异步根据指定数据生成对称密钥，通过注册回调函数获取结果。
  let promiseSymKey = await symKeyGenerator.convertKey(keyMaterialBlob)
  // 初始化加解密的cipher对象
  await cipher.init(cryptoMode, promiseSymKey, null);
  // 加密或者解密的数据
  let text: cryptoFramework.DataBlob =
    cryptoMode === cryptoFramework.CryptoMode.ENCRYPT_MODE ? { data: stringToUint8Array(plainText) } :
      { data: base.decodeSync(plainText) }
  const promise = new Promise<Uint8Array>(async (resolve, reject) => {
    // 获取加密数据
    await cipher.doFinal(text).then((res) => {
      resolve(res.data);
    }).catch((err: BusinessError) => {
      reject(err);
    })
  })
  return promise;
}
  ```

### 高性能知识点

**不涉及**

### 工程结构&模块类型

   ```
   livedetectionandencryptiond                   // har类型(默认使用har类型，如果使用hsp类型请说明原因)
   |---components
   |   |---Encode.ets                            // 加解密&数据转换方法
   |   |---StartFacialFecognition.ets            // 活体检测方法类
   |---LiveDetectionAndEncryptionPage.ets        // 活体检测&加解密页面
   ```

### 模块依赖

**不涉及**(默认不依赖其他模块，如果依赖其他har或hsp模块请详细说明。)

### 参考资料

[cryptoFramework 加解密算法库框架](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-cryptoframework-V5)
[interactiveLiveness 人脸活体检测](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/vision-interactive-liveness-V5)
[util工具函数](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-util-V5)
