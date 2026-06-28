# Scroll容器嵌套多种组件事件处理案例

### 介绍

本示例适用于Scroll容器嵌套多组件事件处理场景：当需要一个父容器Scroll内嵌套web、List，当父子的滚动手势冲突时，此时希望父容器的滚动优先级最高，即实现子组件的偏移量都由父容器统一派发，实现滚动任一子组件流畅滚动到父容器顶/底的效果。   
例如本案例的新闻浏览界面，父组件Scroll嵌套了新闻内容与评论区（Web实现新闻内容，List实现评论区），
通过禁用web和list组件滚动手势，再由父组件Scroll统一计算派发偏移量，达到一种web的滚动和list组件滚动能无缝衔接，像同一个滚动组件滚动效果。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/container_nested_slide.gif" width="200">

**使用说明**
1. 点击Scroll容器嵌套多种组件事件处理案例。
2. 页面向下滚动直到页面底部，无卡顿现象。
3. 从页面底部向上滚动直到页面顶部，无卡顿现象。

### 实现思路
概述：使用Scroll嵌套Web和List组件实现。Scroll作为父组件响应滚动手势，Web和List组件禁用滚动手势，滚动偏移量由父组件Scroll给Web和List组件派发。  
即通过在Scroll.onScrollFrameBegin()每帧开始滚动时触发，将Scroll返回的实际滚动量的offset，通过scrollBy(0, offset)方法，将Scroll的偏移量派发给Web、List。  
**滚动偏移量派发逻辑**：  
一、 手指向上划动(页面下滑)：
1) 如果Web没有滚动到底部，Scroll将滚动偏移量派发给Web，Scroll组件自身不滚动。
2) 如果Web滚动到底部，Scroll没有滚动到底部，则Scroll自身滚动，不给Web和List派发滚动偏移量。
3) 如果Scroll滚动到底部，则滚动偏移量派发给List，Scroll自身不滚动。

二、 手指向下划动(页面上滑)：
1) 如果List没有滚动到顶部，则Scroll将滚动偏移量派发给List，Scroll自身不滚动。
2) 如果List滚动到顶部，Scroll没有滚动到顶部，则Scroll自身滚动，不给Web和List派发滚动偏移量。
3) 如果Scroll滚动到顶部，则滚动偏移量派发给Web，Scroll自身不滚动。  

具体步骤：
1. 禁用Web与List的滚动手势，[源码参考](src/main/ets/view/NewsDetailPage.ets)
```typescript
Scroll(){
  Web({ src: $rawfile("news.html"), controller: this.webviewController })
     // Web网页加载完成时，禁用Web手势生成的滚动。
     .onPageEnd(e => {
        // TODO：知识点：设置禁用Web手势生成的滚动
        this.webviewController.setScrollable(false, webview.ScrollType.EVENT);
        this.getWebHeight();
     })
     // 禁用Web的pan手势，即鼠标滚轮和触摸板的双指滑动。
     .onGestureRecognizerJudgeBegin((event: BaseGestureEvent, current: GestureRecognizer,
        others: Array<GestureRecognizer>) => {
        if (current.isBuiltIn() && current.getType() == GestureControl.GestureType.PAN_GESTURE) {
           // TODO：知识点：使用onGestureRecognizerJudgeBegin方法，禁用web自带的pan手势触发即鼠标滚轮和触摸板的双指滑动。
           return GestureJudgeResult.REJECT; // 禁用Web组件上的鼠标滚轮和触摸板的双指滑动
        }
        return GestureJudgeResult.CONTINUE;
     })
  
  List() { // 评论区
    // ...
  }
  .enableScrollInteraction(false) // TODO：知识点：禁用List组件的手势
}
```
2. 检测web组件是否滚动到边界: 通过webviewController.getPageHeight()获取web组件内容高度，当web组件滚动偏移量+web组件内容高度≥web组件自身高度时，即web组件滚动到边界，[源码参考](src/main/ets/view/NewsDetailPage.ets)
```typescript
getWebScrollTop() { // 检测web组件是否滚动到边界，isWebAtEnd的值为ture到Web底部，false还未到底部。
  try {
    // 获取Web组件的滚动偏移量
    this.webviewController.runJavaScriptExt('document.documentElement.scrollTop || document.body.scrollTop',
      (error, result) => {
        if (error || !result) {
          return;
        }
        let type = result.getType();
        if (type === webview.JsMessageType.NUMBER) {
          this.scrollTop = result.getNumber();
          let pageHeight = this.webviewController.getPageHeight(); // 获取web组件内容高度
          this.isWebAtEnd = false; // 未到Web底部
          if (this.scrollTop + this.webHeight >= pageHeight) { // 当web组件滚动偏移量 + web组件高度 ≥ web组件内容高度（web组件高度固定，内容可以很长）
            this.isWebAtEnd = true; // 到Web底部了
          }
        }
      });
  } catch (error) {
     logger.error('error' + error);
  }
}

getWebHeight() { // 获取web组件高度
  try {
    this.webviewController?.runJavaScriptExt('window.innerHeight', (error, result) => { 
      if (error || !result) {
        return;
      }
      if (result.getType() === webview.JsMessageType.NUMBER) {
        this.webHeight = result.getNumber(); // 获取web组件高度
      }
    })
  } catch (error) {
     logger.error('error' + error);
  }
}
```
3. 检测Scroll是否滚动到边界：  
Scroll滚动到底： 
```typescript
this.scroller.isAtEnd();
```
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;  Scroll滚动到顶：

```typescript
this.scroller.currentOffset().yOffset <= 0;
```
4. 通过Scroll对子组件的偏移量派发，使用Scroll.onScrollFrameBegin()中返回的offset滑动量判断页面上划/下划，进而通过this.webviewController.scrollBy(0, offset)派发给web偏移量，
   通过this.listScroller.scrollBy(0, offset)派发给List偏移量，从而实现web的滚动和list组件滚动能无缝衔接，像同一个滚动组件滚动效果，[源码参考](src/main/ets/view/Scroller.ets)
```typescript
Scroll(){
  // ...
}
// TODO：知识点：通过调用Scroll.onScrollFrameBegin()，在每帧开始滚动时触发时将Scroll返回的实际滚动量的offset，通过scrollBy(0, offset)方法，将Scroll的偏移量派发给Web、List。
.onScrollFrameBegin((offset: number, state: ScrollState) => {
  this.getWebScrollTop(); // 检测web组件是否滚动到边界
  if (offset > 0) { // 当页面下滑
    if (!this.isWebAtEnd) { // 还没触到web底部
      this.webviewController.scrollBy(0, offset) // 通过调用Web的WebController.scrollBy接口，滚动偏移派发给web（水平方向滚动距离为0，竖直方向滚动距离为offset）
      return { offsetRemain: 0 } // 将Scroll剩余滚动偏移量返回0，scroll就不会滚动，也不会停止惯性滚动动画
    } else if (this.scroller.isAtEnd()) { // 检测scroll组件滚动到了下边界
      this.listScroller.scrollBy(0, offset) // 通过调用List滚动控制器的scrollBy接口，滚动偏移派发给List
      return { offsetRemain: 0 }
    }
  } else if (offset < 0) { // 当页面上滑
    if (this.listScroller.currentOffset().yOffset > 0) { // 检测List还没到上边界
      this.listScroller.scrollBy(0, offset) // 通过调用List滚动控制器的scrollBy接口，滚动偏移派发给List
      return { offsetRemain: 0 } // 将Scroll剩余滚动偏移量返回0，scroll就不会滚动，也不会停止惯性滚动动画
    } else if (this.scroller.currentOffset().yOffset <= 0) { // 检测scroll组件滚动到了上边界
      this.webviewController.scrollBy(0, offset) // 通过调用Web的WebController.scrollBy接口，滚动偏移派发给web
      return { offsetRemain: 0 }
    }
  }
  return { offsetRemain: offset } // 否则，scroll自身滚动
})
```

### 高性能知识点

* 动态加载数据场景可以使用[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-rendering-control-lazyforeach-V5)遍历数据。

* 本例使用扁平化布局优化嵌套层级，建议采用相对布局RelativeContainer进行扁平化布局，有效减少容器的嵌套层级，减少组件的创建时间。

### 工程结构&模块类型

```
containernestedslide                            // har类型
|---src/main/ets/view
|   |---CommentInputDialog.ets                  // 视图层-输入评论弹窗组件
|   |---CommentPage.ets                         // 视图层-评论组件
|   |---NewsDetailPage.ets                      // 视图层-主页
|   |---Scroller.ets                            // 视图层-父容器偏移量派发组件
|---model
|   |---TextFlowModel.ets                       // 模型层-评论数据类 
|---mock
|   |---DetailData.ets                          // 模拟数据模块
```

### 模块依赖

[routermodule(动态路由)](../../common/routermodule)

### 参考资料

[Scroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-scroll-V5)  
[手势拦截增强](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-gesture-blocking-enhancement-V5#ongesturerecognizerjudgebegin)  
[@ohos.web.webview (Webview)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-webview-V5#scrolltype12)  
