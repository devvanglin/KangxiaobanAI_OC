# 人脸指纹解锁案例

### 介绍

本示例介绍了使用[@ohos.userIAM.userAuth](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-useriam-userauth-V5)用户认证服务实现人脸或指纹识别的功能。
该场景多用于需要人脸或指纹识别的安全场景。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/face_and_finger_print_unlocking.PNG" width="200">

**使用说明**：

* 点击指纹登录，弹出指纹登录场景框。
* 点击面容登录，弹出面容登录场景框。

### 实现步骤

实现H5页面调用自定义输入法，有两个关键点，一是需要将arkTS方法注册到h5页面中；二是要实现弹出键盘的组件。

1. 发起人脸和指纹识别的方法首先需要先申请权限ohos.permission.ACCESS_BIOMETRIC。同时指定认证类型（UserAuthType）和认证等级（AuthTrustLevel），调用getAvailableStatus接口查询当前的设备是否支持相应的认证能力。
```ts
  userAuth.getAvailableStatus(type === CommonConstants.FINGER ? userAuth.UserAuthType.FINGERPRINT : userAuth.UserAuthType.FACE,
        userAuth.AuthTrustLevel.ATL1);
```
2. 指定用户认证相关参数AuthParam（包括挑战值、认证类型UserAuthType列表和认证等级AuthTrustLevel）、配置认证控件界面WidgetParam，调用getUserAuthInstance获取认证对象。
```ts
  // 设置认证参数
  let reuseUnlockResult: userAuth.ReuseUnlockResult = {
    reuseMode: userAuth.ReuseMode.AUTH_TYPE_RELEVANT,
    reuseDuration: userAuth.MAX_ALLOWABLE_REUSE_DURATION,
  }
  const rand = cryptoFramework.createRandom();
  const len: number = CommonConstants.LEN;
  const randData: Uint8Array = rand?.generateRandomSync(len)?.data;
  const _this = this;
  this.authParam = {
    challenge: randData,
    authType: [type === CommonConstants.FINGER ? userAuth.UserAuthType.FINGERPRINT : userAuth.UserAuthType.FACE],
    authTrustLevel: userAuth.AuthTrustLevel.ATL1,
    reuseUnlockResult: reuseUnlockResult,
  };
  // 获取认证对象
  const userAuthInstance = userAuth.getUserAuthInstance(this.authParam, this.widgetParam);
```
3. 调用UserAuthInstance.on接口订阅认证结果。
```ts
  // 订阅认证结果
  userAuthInstance.on('result', {
    onResult(result) {
      console.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
      if (result.result !== userAuth.UserAuthResultCode.SUCCESS) {
        if (type === CommonConstants.FINGER) {
          _this.fingerSwitch = !_this.fingerSwitch;
        } else {
          _this.faceSwitch = !_this.faceSwitch;
        }
      }
      // 可在认证结束或其他业务需要场景，取消订阅认证结果
      userAuthInstance.off('result');
    }
  });
```
4. 调用UserAuthInstance.start接口发起认证，通过IAuthCallback回调返回认证结果UserAuthResult。
```ts
  userAuthInstance.start();
```

### 高性能知识点

**不涉及**

### 工程结构&模块类型

   ```
   faceandfingerprintunlocking                // har
   |---common
   |   |---CommonContants.ets.ets             // 常量文件
   |---view
   |   |---MainPage.ets                       // 案例页面
   ```

### 模块依赖

**不涉及**

### 参考资料

[@ohos.userIAM.userAuth](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-useriam-userauth-V5)

[用户身份认证开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/user-authentication-dev-V5)
