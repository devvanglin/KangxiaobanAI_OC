# Text实现部分文本高亮和超链接样式

### 介绍

本示例通过自定义Span类型，在Text组件中使用ForEach遍历，根据不同的Span类型生成不同样式和功能的Span组件，实现部分文本高亮和超链接。此外还可以通过属性字符串灵活设置文本样式实现同样效果，详情可见[属性字符串实现部分文本高亮和超链接样式](./STYLEDSTRING.md)。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/styled_text.gif)

**使用说明**

1. 点击超链接，根据链接类型出现相应提示弹窗。
2. 长按消息卡片出现提示弹窗。

### 实现思路

TextAndSpanComponent 组件通过自定义Span对象区分不同类型的文本，在Text组件中遍历自定义Span对象数组并检查字符长度，根据自定义Span对象的类型生成不同样式和功能的Span组件。

1. 定义 MyCustomSpanType 枚举类型，此处定义了 Normal、Hashtag、Mention、VideoLink 和 DetailLink 五种类型。源码参考[TextModel.ets](./src/main/ets/model/TextModel.ets)。

```ts
export enum MyCustomSpanType {
  Normal, // 普通文本，不含任何特殊格式或标记
  Hashtag, // 话题标签
  Mention, // @提及
  VideoLink, // 视频链接
  DetailLink // 正文详情
}
```

2. 创建 MyCustomSpan 数据类，用于表示不同类型的 Span 对象。源码参考[TextModel.ets](./src/main/ets/model/TextModel.ets)。

```ts
export class MyCustomSpan {
  id: number | string; // 文本id
  type: MyCustomSpanType; // 文本类型
  content: string; // 文本内容
  url?: string; // 跳转的链接地址

  constructor(id: number | string, type: MyCustomSpanType = MyCustomSpanType.Normal, content: string, url?: string) {
    this.id = id;
    this.type = type;
    this.content = content;
    if (url) {
      this.url = url;
    }
  }
}
```

3. 使用 Text 组件结合 ForEach 方法遍历 spans 中的 MyCustomSpan 对象，根据不同的 Span 类型生成不同样式和功能的 Span 组件。源码参考[TextAndSpanComponent.ets](./src/main/ets/components/TextAndSpanComponent.ets)。

```ts
Text() {
  ForEach(this.spans, (item: MyCustomSpan) => {
    if (item.type === MyCustomSpanType.Normal) {
      Span(item.content)
    } else if (item.type === MyCustomSpanType.Hashtag || item.type === MyCustomSpanType.Mention || item.type === MyCustomSpanType.DetailLink) {
      this.textLinkSpanBuilder(item)
    } else {
      this.videoLinkSpanBuilder(item)
    }
  }, (item: MyCustomSpan, index: number) => `${index}_${JSON.stringify(item)}`)
}
.width($r('app.string.styled_text_layout_full_size'))
.fontSize(this.defaultFontSize)
.fontColor(this.defaultFontColor)
```

4. 对于 Normal 类型的 Span，直接使用 Span 组件展示文本内容，样式跟随父组件Text。源码参考[TextAndSpanComponent.ets](./src/main/ets/components/TextAndSpanComponent.ets)。

```ts
Span(item.content)
```
5. 对于 Hashtag、Mention 和 DetailLink 类型的 Span，在Builder函数 textLinkSpanBuilder 中添加带有超链接功能的 Span 组件，在 Span 组件的点击事件中调用父组件传入的点击回调函数，父组件可以根据点击的 Span 类型做相应处理。源码参考[TextAndSpanComponent.ets](./src/main/ets/components/TextAndSpanComponent.ets)。

```ts
@Builder
textLinkSpanBuilder(item: MyCustomSpan) {
  Span(item.content)
    .fontColor(this.linkColor)
    .fontSize(this.linkFontSize)
    .textBackgroundStyle({
      color: this.clickSpanId === item.id ? $r('app.color.styled_text_link_clicked_background_color') :
      Color.Transparent
    })
    .onClick(() => {
      setTimeout(() => {
        this.clickSpanId = '';
      }, this.backgroundChangeDelay)
      this.clickSpanId = item.id;
      if(this.linkClickCallback){
        this.linkClickCallback(item);
      }
    })
}
```

6. 对于 VideoLink 类型的 Span，使用Builder函数 videoLinkSpanBuilder 添加图标和超链接功能，点击时调用父组件传入的点击回调函数，父组件可以根据点击的 Span 类型做相应处理。源码参考[TextAndSpanComponent.ets](./src/main/ets/components/TextAndSpanComponent.ets)。

```ts
@Builder
videoLinkSpanBuilder(item: MyCustomSpan) {
  ContainerSpan() {
    ImageSpan(this.videoLinkIcon)
      .height($r('app.integer.styled_text_video_link_icon_height'))
      .verticalAlign(ImageSpanAlignment.CENTER)
      .onClick(() => {
        setTimeout(() => {
          this.clickSpanId = '';
        }, this.backgroundChangeDelay)
        this.clickSpanId = item.id;
        if(this.linkClickCallback){
          this.linkClickCallback(item);
        }
      })
    Span(item.content)
      .fontColor(this.linkColor)
      .fontSize(this.linkFontSize)
      .onClick(() => {
        setTimeout(() => {
          this.clickSpanId = '';
        }, this.backgroundChangeDelay)
        this.clickSpanId = item.id;
        if(this.linkClickCallback){
          this.linkClickCallback(item);
        }
      })
  }
  .textBackgroundStyle({
    color: this.clickSpanId === item.id ? $r('app.color.styled_text_link_clicked_background_color') :
    Color.Transparent
  })
}
```

StyledTextMainPageComponent实现了一个消息列表场景，当选择tab页签为Text&Span时，消息组件MessageItem基于TextAndSpanComponent组件实现多行文本中部分文本高亮和超链接效果。源码参考[StyledText.ets](./src/main/ets/pages/StyledText.ets)。

1. 引入功能组件TextAndSpanComponent，并初始化相关参数，其中spans为MyCustomSpan对象数组，linkClickCallback为链接点击回调。

```ts
TextAndSpanComponent({
  spans: this.messageItem.spans,
  linkClickCallback: this.linkClickCallback
})
```

2. 通过设置点击回调linkClickCallback，可以根据点击的span类型，执行对应操作，例如跳转详情页或视频页。

```ts
// 超链接点击回调
private linkClickCallback: (span: MyCustomSpan) => void =
  (span: MyCustomSpan) => {
    // 根据文本超链接的类型做相应处理
    if (span.type === MyCustomSpanType.Hashtag) {
      promptAction.showToast({
        message: $r('app.string.styled_text_hashtag_toast_message')
      });
    } else if (span.type === MyCustomSpanType.Mention) {
      promptAction.showToast({
        message: $r('app.string.styled_text_user_page_toast_message')
      });
    } else if (span.type === MyCustomSpanType.VideoLink) {
      promptAction.showToast({
        message: $r('app.string.styled_text_video_function_message')
      });
    } else {
      promptAction.showToast({
        message: $r('app.string.styled_text_content_details_toast_message')
      });
    }
  };
```

### 高性能知识点

本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V4/arkts-rendering-control-lazyforeach-0000001820879609-V4?catalogVersion=V4)进行数据懒加载

### 工程结构&模块类型

   ```
   styledtext                                   // har类型
   |---/src/main/ets/components                        
   |   |---StyledStringComponent.ets            // 视图层-Text设置属性字符串的功能组件
   |   |---TextAndSpanComponent.ets             // 视图层-Text循环生成Span的功能组件
   |---/src/main/ets/mock                        
   |   |---MockData.ets                         // mock数据
   |---/src/main/ets/model                        
   |   |---DataSource.ets                       // 列表数据模型                        
   |   |---TextModel.ets                        // 数据类型定义
   |---/src/main/ets/pages                        
   |   |---StyledText.ets                       // 视图层-场景页面
   ```

### 模块依赖

1. 本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[Text组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-text-0000001815927600)

[Span组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-span-0000001862607421)

[ContainerSpan组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-containerspan-0000001862607393)