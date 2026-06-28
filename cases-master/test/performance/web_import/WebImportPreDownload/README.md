# Web组件开发性能提升指导测试工程——预下载

## 原理介绍

开发者可以在onPageEnd阶段进行预加载，当真正去加载下一个页面的时候，如果预加载已经成功，则相当于直接从缓存中加载页面资源，速度更快。一般来说能够准确预测到用户下一步要访问的页面的时候，可以进行预加载将要访问的页面，比如小说下一页， 浏览器在地址栏输入过程中识别到用户将要访问的页面等。

@ohos.web.webview提供prefetchPage方法实现在预测到将要加载的页面之前调用，提前下载页面所需的资源，包括主资源子资源，但不会执行网页JavaScript代码或呈现网页，以加快加载速度。

## 优化步骤

### 在闲时预下载即将打开的Web页面

```typescript
// src/main/ets/pages/WebBrowser.ets
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column({space: 10}) {
      Web({ src: 'https://www.example.com', controller: this.controller })
        .onPageEnd((event) => {
          // 在确定即将跳转的页面时开启预加载
          this.controller.prefetchPage('https://www.example.com/nextpage');
        })
        .width(300)
        .height(300)
      
    }
    .width('100%')
  }
}
```

### 加载已完成预下载的Web页面

```typescript
Button('下一页')
  .onClick(() => {
    // 跳转下一页
    this.controller.loadUrl('https://www.example.com/nextpage');
  })
  .width(300)
  .height(30)
```