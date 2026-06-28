# 属性字符串实现部分文本高亮和超链接样式

### 介绍

本示例介绍使用[属性字符串](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-universal-styled-string-V13)灵活设置文本样式，实现多行文本中部分文本高亮和超链接的过程。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/styled_string.gif)

**使用说明**

1. 点击超链接，根据链接类型出现相应提示弹窗。
2. 长按消息卡片出现提示弹窗。

### 实现思路

StyledStringComponent组件通过自定义Span对象区分不同类型的文本，遍历自定义Span对象数组并检查字符长度，为其中每个Span创建属性字符串对象，然后根据不同的Span类型为属性字符串对象添加相应的样式和手势，创建完成的属性字符串对象依次入栈并按顺序拼接到新的属性字符串上，通过TextController控制器将拼接完成的属性字符串绑定到Text组件上展示出来。

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

3. 遍历自定义Span对象数组并检查字符长度。源码参考[StyledStringComponent.ets](./src/main/ets/components/StyledStringComponent.ets)。

```ts
processCustomSpans(spans: MyCustomSpan[]): MutableStyledString[] {
  let charCount = 0; // 遍历拼接customMessage.spans，记录已拼接的字符串长度
  const styledStrings: MutableStyledString[] = []; // 已生成的属性字符串数组
  customMessage.spans.forEach((span, index) => {
    // 如果当前累积字符数已经达到最大允许长度，则停止处理后续文本片段
    if (charCount >= MAX_STRING_LENGTH) {
      return;
    }
    // 判断添加当前文本片段后是否超过最大允许长度
    // TODO：知识点：遍历消息片段并检查字符长度，为每个片段创建MutableStyledString对象，添加对应样式和手势
    if (charCount + span.content.length >= MAX_STRING_LENGTH) {
      this.handleExceedingSize(span, charCount, styledStrings);
    } else {
      this.processWithinSize(span, charCount, styledStrings);
    }
    charCount += span.content.length;
  })
  return styledStrings;
}
```

4. 为其中每个Span创建属性字符串对象，然后根据不同的Span类型为属性字符串对象添加相应的样式和手势，如果字符长度超过限制需要在末尾添加“...全文”，创建好的属性字符串放入数组styledStrings保存。源码参考[StyledStringComponent.ets](./src/main/ets/components/StyledStringComponent.ets)。

   - 字符数超过指定字符长度时，末尾添加“...全文”，创建对应样式的属性字符串
    ```ts
    handleExceedingSize(span: MyCustomSpan, charCount: number, styledStrings: MutableStyledString[]) {
      const ELLIPSIS: string = '...';
      const FULL_TEXT: string = '全文';
      // 检查文本片段的类型，决定如何处理超出部分
      if (span.type === MyCustomSpanType.Normal) {
        // 如果是普通文本，则截断并拼接 ...全文
        styledStrings.push(new MutableStyledString(`${span.content.substring(0,
          MAX_STRING_LENGTH - charCount)}${ELLIPSIS}${FULL_TEXT}`, [
          {
            start: MAX_STRING_LENGTH - charCount + ELLIPSIS.length,
            length: FULL_TEXT.length,
            styledKey: StyledStringKey.FONT,
            styledValue: this.textAttribute
          },
          {
            start: MAX_STRING_LENGTH - charCount + ELLIPSIS.length,
            length: FULL_TEXT.length,
            styledKey: StyledStringKey.GESTURE,
            styledValue: this.generateClickStyle(span)
          }]));
      } else {
        // 对于链接类型，不截断直接拼接 ...全文，如果视频链接图标的pixelMap已存在，在对应类型的链接前添加图片类型的属性字符串
        if (span.type === MyCustomSpanType.VideoLink && this.imagePixelMap !== undefined) {
          styledStrings.push(new MutableStyledString(new ImageAttachment({
            value: this.imagePixelMap,
            size: {
              width: $r('app.integer.styled_text_video_link_icon_size'),
              height: $r('app.integer.styled_text_video_link_icon_size')
            },
            verticalAlign: ImageSpanAlignment.CENTER,
            objectFit: ImageFit.Contain
          })));
        }
        styledStrings.push(new MutableStyledString(`${span.content}${ELLIPSIS}${FULL_TEXT}`, [
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.FONT,
            styledValue: this.textAttribute
          },
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.GESTURE,
            styledValue: this.generateClickStyle(span)
          },
          {
            start: span.content.length + ELLIPSIS.length,
            length: FULL_TEXT.length,
            styledKey: StyledStringKey.FONT,
            styledValue: this.textAttribute
          },
          {
            start: span.content.length + ELLIPSIS.length,
            length: FULL_TEXT.length,
            styledKey: StyledStringKey.GESTURE,
            styledValue: this.generateClickStyle(span)
          }]));
      }
    }
    ```
   - 字符数未超过指定字符长度时，创建对应样式的属性字符串。
    ```ts
    processWithinSize(span: MyCustomSpan, charCount: number, styledStrings: MutableStyledString[]) {
      if (span.type === MyCustomSpanType.Hashtag || span.type === MyCustomSpanType.Mention ||
        span.type === MyCustomSpanType.DetailLink) {
        styledStrings.push(new MutableStyledString(span.content, [
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.GESTURE,
            styledValue: this.generateClickStyle(span)
          },
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.FONT,
            styledValue: this.textAttribute
          }
        ]));
      } else if (span.type === MyCustomSpanType.VideoLink) {
        // 如果视频链接图标的pixelMap已存在，在对应类型的链接前添加图片类型的属性字符串
        if (this.imagePixelMap !== undefined) {
          styledStrings.push(new MutableStyledString(new ImageAttachment({
            value: this.imagePixelMap,
            size: {
              width: $r('app.integer.styled_text_video_link_icon_size'),
              height: $r('app.integer.styled_text_video_link_icon_size')
            },
            verticalAlign: ImageSpanAlignment.CENTER,
            objectFit: ImageFit.Contain
          })))
        }
        styledStrings.push(new MutableStyledString(span.content, [
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.GESTURE,
            styledValue: this.generateClickStyle(span)
          },
          {
            start: 0,
            length: span.content.length,
            styledKey: StyledStringKey.FONT,
            styledValue: this.textAttribute
          }
        ]));
      } else {
        styledStrings.push(new MutableStyledString(span.content, []));
      }
    }
    ```
   - 在超链接的点击手势事件中调用父组件的点击回调，父组件可以根据点击的span类型做相应处理。
   ```ts
   linkClickCallback?: (span: MyCustomSpan) => void; // 超链接点击回调
   
   generateClickStyle(span: MyCustomSpan): GestureStyle {
     return new GestureStyle({
       onClick: () => {
         if(this.linkClickCallback){
           this.linkClickCallback(span);
         }
       }
     })
   }
   ```

5. 将数组styledStrings中的属性字符串按顺序拼接到属性字符串paragraphStyledString上。源码参考[StyledStringComponent.ets](./src/main/ets/components/StyledStringComponent.ets)。
```ts
// 将每个文本片段生成的属性字符串追加到属性字符串paragraphStyledString中
this.styledStrings.forEach((mutableStyledString: MutableStyledString, index: number) => {
  this.paragraphStyledString.appendStyledString(mutableStyledString);
})
```

6. Text组件挂载完成后通过绑定的TextController控制器controller将拼接完成的属性字符串绑定到Text组件上展示出来。源码参考[StyledStringComponent.ets](./src/main/ets/components/StyledStringComponent.ets)。

```ts
Text(undefined, { controller: this.controller })
  .width($r('app.string.styled_text_layout_full_size'))
  .fontSize($r('app.string.styled_text_font_size_default'))
  .margin({ top: $r('app.string.styled_text_card_margin_start') })
  .onAppear(() => {
    // TODO：知识点：在Text组件挂载完成后绑定处理后的属性字符串
    this.controller.setStyledString(this.paragraphStyledString);
  })
```

StyledTextMainPageComponent实现了一个消息列表场景，当选择tab页签为StyledString时，消息组件MessageItem基于StyledStringComponent组件实现多行文本中部分文本高亮和超链接效果。源码参考[StyledText.ets](./src/main/ets/pages/StyledText.ets)。

1. 引入功能组件StyledStringComponent，并初始化相关参数，其中spans为MyCustomSpan对象数组，imagePixelMap为视频链接图标的pixelMap对象，linkClickCallback为链接点击回调。

```ts
StyledStringComponent({
  spans: this.messageItem.spans,
  imagePixelMap: this.imagePixelMap,
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

本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-rendering-control-lazyforeach-V5)进行数据懒加载。

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

[Text组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-text-V5)

[属性字符串](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-styled-string-V5)