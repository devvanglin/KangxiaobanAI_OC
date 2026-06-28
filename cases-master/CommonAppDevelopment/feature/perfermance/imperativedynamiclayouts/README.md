# 使用ArkUI的FrameNode扩展实现动态布局类框架

### 介绍

本示例是[使用ArkUI的FrameNode扩展实现动态布局类框架](../../../../docs/performance/imperative_dynamic_layouts.md)
的示例代码，主要讲解如何使用ArkUI的FrameNode扩展实现动态布局类框架。

### 效果图预览

![](../../../product/entry/src/main/resources/base/media/imperative_dynamic_layouts.gif)

**使用说明**

1. 点击刷新按钮，所有图片变化，且刷新按钮消失

### 实现思路

1. 定义DSL，DSL一般会使用JSON、XML等数据交换格式来描述UI，本案例使用JSON，详细代码请参考[foo.json](src/main/ets/jsonpage/foo.json)。

```json
{
  "type": "Column",
  "css": {
    "width": "100%"
  },
  "children": [
    {
      "type": "Row",
      "css": {
        "width": "100%",
        "padding": {
          "left": 15,
          "right": 15
        },
        "margin": {
          "top": 5,
          "bottom": 5
        },
        ...
      },
      ...
    },
    ...
  ]
}
```

2. 定义相应数据结构用于接收UI描述数据,详细代码参考[ImperativeView.ets](src/main/ets/view/ImperativeView.ets)。

```typescript
class VM {
  type?: string
  content?: string
  css?: ESObject
  children?: VM[]
  id?: string
}
```

3. 自定义DSL解析逻辑，且使用carouselNodes保存轮播图节点，方便后续操作节点更新，详细代码参考[ImperativeView.ets](src/main/ets/view/ImperativeView.ets)。
```typescript
let carouselNodes: typeNode.Image[] = [];

function FrameNodeFactory(vm: VM, context: UIContext): FrameNode | null {
  ...
  return null;
}

function setColumnNodeAttr(node: typeNode.Column, css: ESObject) {
  ...
}

function setRowNodeAttr(node: typeNode.Row, css: ESObject) {
  ...
}
```

4. 使用NodeContainer组件占位，将创建的组件加载到页面中，详细代码请参考[ImperativeView.ets](src/main/ets/view/ImperativeView.ets)。
```typescript
class ImperativeController extends NodeController {
  makeNode(uiContext: UIContext): FrameNode | null {
    return FrameNodeFactory(data, uiContext);
  }
}

@Entry
@Component
struct ImperativeView {
  controller: ImperativeController = new ImperativeController();
  build() {
    Column() {
      NodeContainer(this.controller)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(Color.Black)
  }
}
```

### 高性能知识点

使用ArkUI的FrameNode扩展，可以避免创建自定义组件对象和状态变量对象，也无需进行依赖收集，从而显著提升组件创建的速度,并且能更快的组件更新操作以及对组件树结构的直接控制。

### 工程结构&模块类型

   ```
   imperativedynamiclayouts                           // har类型
   |---jsonpage                                       // 存放描述UI的数据文件
   |---|---foo.json                                   // 描述UI的数据
   |---view                                           // 视图
   |---|---ImperativeView.ets                         // 视频首页
   ```

### 参考资料

[NodeContainer](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-nodecontainer.md#nodecontainer)

[NodeController](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-nodeController.md)

