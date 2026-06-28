# 折叠面板案例

### 介绍

本示例通过定义层级实现多层折叠面板，并在首页性能文章tab实际使用跳转到对应文章的web页面。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/collapse_menu_case.gif" width="150">

**使用说明**

定义好菜单各层级的数据源，可以由父级传入也可以固定，本案例为固定数据源。

根据当前层级节点是否存在children判断是否可展开，以此实现折叠效果。

1. 打开《我的开发案例》进入到首页，进入性能文章标签页面。
2. 点击多层级列表，展开子列表。
3. 点击相关子列表跳转到对应文章的web页面。

### 下载安装

1.模块oh-package.json5文件中引入依赖。

```typescript
"dependencies": {
  "@ohos-cases/collapsemenu": "har包地址"
}
```

2.ets文件import自定义视图实现折叠面板视图。

```typescript
import { CollapseMenuSection, TreeNode } from '@ohos-cases/collapsemenu';
```

### 快速使用

本章主要介绍了如何快速使用CollapseMenu组件和TreeNode类属性实现折叠面板视图。

1.定义面板数据类TreeNode，开发者可以自行扩展数据属性。

```typescript
@Observed
class TreeNode {
  expand: boolean = false;
  type: number | string | ESObject = 0
  title: string = ''
  url?: string = ''
  children?: TreeNode[] = [];
}

```

2.初始化数据。

```typescript
@State articleNodes: ArticleNode[] = [];

aboutToAppear() {
  this.articleNodes = [...ARTICLE_DATA];
}

```

3.构建折叠面板列表视图。

```typescript

CollapseMenuSection({
  articleNodes: this.articleNodes,
  articleItemBuilder: this.articleItemBuilder,
  articleHeaderBuilder: this.articleHeaderBuilder
})

```

### 属性(接口)说明

TreeNode属性-面板数据类

|    属性    |           类型           |  释义   | 默认值 |
|:--------:|:----------------------:|:-----:|:---:|
|  expand  |        boolean         | 控制折叠  |  -  |
|   type   | number/string/ESObject |  数据类  |  -  |
|  title   |         string         | 数据标题  |  -  |
|   url    |         string         | 文章地址  |  -  |
| children |       TreeNode[]       | 子数据列表 |  -  |

CollapseMenuSection-折叠面板视图

|          属性          |                       类型                        |   释义    | 默认值 |
|:--------------------:|:-----------------------------------------------:|:-------:|:---:|
|     articleNodes     |                     number                      | 视频组件数据  |  -  |
|  articleItemBuilder  |          (articleNode: TreeNode)=>void          | 视频遮罩层信息 |  -  |
| articleHeaderBuilder | (articleNode: TreeNode, isExpand:boolean)=>void | 列表头部视图  |  -  |


### 实现思路

折叠面板的列表项传入固定数据源。

- 根据当前层级节点是否存在children判断是否可展开，再根据isExpand判断当前是否展开，从而控制右侧箭头的显隐及切换。

```typescript
 Image(articleNode.expand ? $r('app.media.ic_down_arrow') : $r('app.media.ic_right_arrow'))
  .width(articleNode.expand  ? $r('app.integer.collapse_menu_arrow_unfold_width') :
  $r('app.integer.collapse_menu_arrow_width'))
  .height(articleNode.expand  ? $r('app.integer.collapse_menu_arrow_width') :
  $r('app.integer.collapse_menu_arrow_unfold_width'))
  .margin({ right: articleNode.expand  ? 0 : $r('app.integer.collapse_menu_arrow_fold_margin_right') })
```

- 用户点击普通列表，跳转到对应的文章网页，点击折叠列表项时，控制子列表的折叠和展开。

```typescript
 Column() {
   Column() {
     if (this.articleNode.type === Constants.COLLAPSE_MENU) {
       Column() {
         this.articleHeaderBuilder({
           expand: this.articleNode.expand,
           type: this.articleNode.type,
           title: this.articleNode.title,
           url: this.articleNode.url,
           children: this.articleNode.children,
         })
       }
       .onClick(() => {
         this.articleNode.expand = !this.articleNode.expand;
         this.articleSource.notifyDataChange(this.articleGroupIndex);
       })
     } else {
       this.articleItemBuilder(this.articleNode);
     }
   }.padding({
     left: 12 * this.count
   })
   .width('100%')

   Divider()
     .height(1)
     .opacity(COLLAPSE_MENU_DIVIDER_OPACITY)
     .color($r('app.color.font_color_dark'))
}

```

### 高性能知识点

不涉及。

### 工程结构&模块类型

   ```
   collapsemenu                                     // har类型
   |---src/main/ets/model
   |   |---ArticleNode.ets                          // 模型层-数据类型
   |   |---MockData.ets                             // 模型层-模拟数据
   |---src/main/ets/utils
   |   |---CollapseMenuSection.ets                  // 视图层-折叠面板组件
   |---src/main/ets/view
   |   |---ArticleWebComponent.ets                  // 视图层-网页 
   |   |---CollapseMenu.ets                         // 视图层-主页 
   ```
### 模块依赖

本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)

### 参考资料

[List](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-list-V5)

[ListGroup](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-listitemgroup-V5)

