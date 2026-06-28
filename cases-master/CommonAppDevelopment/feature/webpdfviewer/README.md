# Web组件预览PDF及OFFICE文件实现案例

### 介绍

本案例通过Web组件实现**预览PDF文件**和**Office文件**，代码为Tabs组件包含4个页签，分别为预览**本地PDF**，**远程PDF**，**远程Excel**和**远程PPT**。每个子组件内部构建一个Web组件，预览PPT仅限顶部黑色区域可拖动，待优化。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/web_pdf_office_viewer.gif)

**使用说明**

1. 进入页面默认预览本地PDF文件，点击其他Tabs页签切换预览其他文件。

### 实现思路

#### 预览PDF实现思路

1. 本地PDF加载:通过resource协议（需在工程resources/rawfile 目录下添加PDF文件,通过RESOURCE_URL获取的PDF文件）来实现本地PDF文件资源的装载与呈现，在无需网络连接的情况下，也能顺利加载并预览用户本地PDF资源。
```javascript
Web({ src: RESOURCE_URL, controller: this.controller })
  .onProgressChange((event) => {
    if (event) {
      this.localProgressValue = event.newProgress
        if (this.localProgressValue >= TOTAL_VALUE) {
          this.isHiddenLocalProgress = false;
        }
     }
 })
 .domStorageAccess(true) // 设置是否开启文档对象模型存储接口（DOM Storage API）权限，默认未开启。
```
2. 网络PDF加载:通过设置网络链接属性，能够对接互联网上的PDF文件资源。提供有效的远程PDF文件URL（REMOTE_URL），实现云端PDF资源的加载与预览。
```javascript
Web({ src: REMOTE_URL, controller: this.controller })
  .onProgressChange((event) => {
    if (event) {
      this.remoteProgressValue = event.newProgress
        if (this.remoteProgressValue >= TOTAL_VALUE) {
          this.isHiddenRemoteProgress = false;
        }
     }
 })
 .domStorageAccess(true) // 设置是否开启文档对象模型存储接口（DOM Storage API）权限，默认未开启。
```
3. 网络PDF加载可以在[EntryAbility.ets](../../product/entry/src/main/ets/entryability/EntryAbility.ets)使用预连接[prepareForPageLoad](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/js-apis-webview-0000001813416660-V4#ZH-CN_TOPIC_0000001813416660__prepareforpageload10)，在[WebPDFViewer.ets](src/main/ets/view/WebPDFViewer.ets)中预加载[prefetchPage](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/js-apis-webview-0000001813416660-V4#ZH-CN_TOPIC_0000001813416660__prefetchpage10)接口来优化网络PDF加载的性能。
```javascript

// 通过WebviewController可以控制Web组件各种行为。一个WebviewController对象只能控制一个Web组件，且必须在Web组件和WebviewController绑定后，才能调用WebviewController上的方法（静态方法除外）。
webview.WebviewController.initializeWebEngine();
// 启动预连接，连接地址为即将打开的网址。
webview.WebviewController.prepareForPageLoad(REMOTE_URL, true, 1);

// 在远程PDF将要加载的页面之前调用，提前下载页面所需的资源，但不会执行网页JavaScript代码或呈现网页，以加快加载速度。
.onPageEnd(() => { 
  // 开启在线PDF预加载
  this.controller.prefetchPage(REMOTE_URL);
})
```
**注：** 其中domStorageAccess 方法用于控制Web中对文档对象模型存储（DOM Storage API）的启用状态，若将其设置为 false，可能会影响到PDF文件在Web中的预览功能，因此需要将其设为 true 以确保PDF文件能够正常预览。

#### 预览EXCEL实现思路
1. 网络excel加载，在body里内嵌一个iframe标签，将excel文件的下载地址填在对应file_url位置即可实现预览。

```html
<body>
<iframe
        src="http://view.officeapps.live.com/op/view.aspx?src=file_url"
        width="100%"
        height="800px"
        frameborder="0"
></iframe>
</body>
```

#### 预览PPT实现思路
1. 网络ppt加载，在body里内嵌一个iframe标签，将ppt文件的下载地址填在对应file_url位置即可实现预览。

```html
<body>
<iframe
        src="http://view.officeapps.live.com/op/view.aspx?src=file_url"
        width="100%"
        height="800px"
        frameborder="0"
></iframe>
</body>
```

### 高性能知识点

本示例使用了[prepareForPageLoad](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/js-apis-webview-0000001813416660-V4#ZH-CN_TOPIC_0000001813416660__prepareforpageload10)预连接url，在加载url之前调用此API，对url只进行dns解析，socket建链操作，并不获取主资源子资源。还用到了[prefetchPage](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V4/js-apis-webview-0000001813416660-V4#ZH-CN_TOPIC_0000001813416660__prefetchpage10)在预测到将要加载的页面之前调用，提前下载页面所需的资源，包括主资源子资源，但不会执行网页JavaScript代码或呈现网页，以加快加载速度。
通过使用自定义TabBar与Swiper配合[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)实现页面懒加载和释放

### 工程结构&模块类型

```
webpdfviewer                                     // har类型
|---view
|   |---WebPDFViewer.ets                         // 加载主页 
|   |---RemotePPTViewer.ets                      // 远程渲染ppt组件 
|   |---RemoteExcelViewer.ets                    // 远程渲染excel组件 
|---rawfile
|   |---sample.pdf                               // PDF文件资源
|   |---sample.pptx                              // PPT文件资源
|   |---sample.excel                             // Excel文件资源
|   |---web_excel.html                           // 实现预览网络excel效果的html文件
|   |---web_ppt.html                             // 实现预览网络ppt效果的html文件
```

### 模块依赖

本实例依赖common模块来实现[资源](../../common/utils/src/main/resources/base/element)的调用以及路由模块来[注册路由](../routermodule/src/main/ets/router/DynamicsRouter.ets)。

### 参考资料

[Web](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-web-0000001860247877)

[Tabs](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-tabs-0000001815927636)

[Progress](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-progress-0000001862687613)



