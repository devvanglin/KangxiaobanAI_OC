# Web组件开发性能提升指导测试工程——提前初始化内核

## 原理介绍

当应用首次打开时，默认不会初始化浏览器内核，只有当创建WebView实例的时候，才会开始初始化浏览器内核。

为了能提前初始化WebView实例，@ohos.web.webview提供了initializeWebEngine方法。该方法实现在Web组件初始化之前，通过接口加载Web引擎的动态库文件，从而提前进行Web组件动态库的加载和Web内核主进程的初始化，最终以提高启动性能，减少白屏时间。

## 优化步骤

### 初始化Web内核

```typescript
// EntryAbility.ets
import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    webview.WebviewController.initializeWebEngine();
  }
}
```

### 加载Web组件

```typescript
// Index.ets
import { webview } from '@kit.ArkWeb';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({ src: 'https://www.example.com/example.html', controller: this.controller })
        .fileAccess(true)
        .onPageBegin(() => {
          // 性能打点
          hiTraceMeter.startTrace('getMessageData', 0);
        })
        .onPageEnd(() => {
          // 性能打点
          hiTraceMeter.finishTrace('getMessageData', 0);
        })
    }
  }
}
```

## 总结

| **页面加载方式** | **耗时(局限不同设备和场景，数据仅供参考)**  | **说明** |
| ------ | ------- | ------------------------------------- |
| 直接加载Web页面  | 1264ms | 在加载Web组件时才初始化Web内核，增加启动时间 |
| 提前初始化Web内核  | 1153ms | 加载页面时减少了Web内核初始化步骤，提高启动性能 |