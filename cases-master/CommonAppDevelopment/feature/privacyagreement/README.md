# 用户隐私协议案例

### 介绍

本示例介绍使用web组件加载用户协议、隐私协议等场景。该场景多用于应用类协议展示。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/privacy_agreement.gif" width="200">

**使用说明**

1. 点击主页右上角三条横线按钮打开侧边sidebar。
2. 点击sidebar中一个按钮跳转到案例页面加载对应点击的协议内容。

### 实现思路

1. 通过resourceManager获取资源的value并使用appStorage暂存。源码参考[EntryView.ets](../../product/entry/src/main/ets/pages/EntryView.ets)
```ts
  Button($r('app.string.privacy_agreement'))
    .width('100%')
    .backgroundColor(Color.White)
    .fontColor(Color.Black)
    .onClick(() => {
      animateTo({
        duration: 300
      }, () => {
        this.sideBarIsShow = false;
      })
      let context = getContext() as common.UIAbilityContext
      context.resourceManager.getStringValue($r('app.string.privacy_agreement')).then((data) => {
        AppStorage.setOrCreate('agreementTitle', data)
        FoldableRouter.pushUri('privacyagreement/PrivacyAgreementComponent', '');
      })
    })
  ```
2.通过appStorage暂存的值匹配需要加载的协议地址，通过web组件加载对应html页面。源码参考[WaterFlowDataSource.ets](./src/main/ets/components/PrivacyAgreement.ets)
```ts
@Component
export struct PrivacyAgreement {
  @State webUri: string = '';
  webController: WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    let titleName: string | undefined = AppStorage.get('agreementTitle');
    for (let i = 0; i < agreementDataArr.length; i++) {
      if (agreementDataArr[i].name === titleName) {
        this.webUri = agreementDataArr[i].uri;
      }
    }
  }

  build() {
    Column() {
      Web({ src: agreementDataArr[0].uri, controller: this.webController })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
  ```

### 高性能知识点

**不涉及**

### 工程结构&模块类型

   ```
   privacyagreement                                // har类型(默认使用har类型，如果使用hsp类型请说明原因)
   |---components
   |   |---PrivacyAgreement.ets                    // 视图层-协议加载页面
   ```

### 模块依赖

**不涉及**

### 参考资料

[ArkWeb](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/web-component-overview-V5?ha_source=sousuo&ha_sourceId=89000251)
