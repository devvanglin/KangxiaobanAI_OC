# 文本选择菜单案例

### 介绍

本案例拓展富文本组件文字选择菜单选项，通过富文本组件editMenuOptions属性添加自定义选择菜单，在编辑文字时选择更多选项打开额外菜单栏。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/select_text_menu.gif" width="300" >

**使用说明**

1. 进入主页后输入文字，长按选择文字后自动打开编辑菜单。
2. 点击更多打开自定义拓展菜单。

### 实现思路

1. 子组件[RichEditorComponent](./src/main/ets/component/RichEditorComponent.ets)使用富文本组件RichEditor实现文本编辑功能。
    ```typescript
    RichEditor({ controller: this.controller })
      // TODO: 知识点：富文本组件使用editMenuOptions方法配置选中菜单
      // onCreateMenu对象实现按钮新增
      // onMenuItemClick对象配置各按钮对应的方法
      .editMenuOptions({
         onCreateMenu: this.onCreatMenu, onMenuItemClick: this.onMenuItemClick
      })// 在富文本组件渲染完成后修改文字大小等基础属性
    ```
2. 使用editMenuOptions方法扩展文本选择菜单，并分别传入菜单选项onCreateMenu和点击按钮触发方法onMenuItemClick。源码参考：[RichEditorComponent](./src/main/ets/component/RichEditorComponent.ets)。
    ```typescript
    initMenuOptions() {
      this.onCreatMenu = (textMenuItems: Array<TextMenuItem>) => {
        if (this.menuItemsContent) {
          // 循环遍历新增选项数组，传入RichEditor组件中
          this.menuItemsContent.forEach((value) => {
            textMenuItems.push(value);
          })
        }
        return textMenuItems;
      }
      this.onMenuItemClick = (textMenuItems: TextMenuItem, textRange: TextRange) => {
        // 传递当前选中的文本信息
        this.selectText = this.controller.getSpans({ start: textRange.start, end: textRange.end });
        // 传递当前选中的选项
        this.selectMenu = textMenuItems.content.toString();
        return true;
      }
      return false;
    }
    aboutToAppear(): void {
      this.initMenuOptions();
    }
    ```
3. 父组件[SelectTextMenu](./src/main/ets/view/SelectTextMenu.ets)传入选项对象，传入需要新增的菜单选项，并在点击选项后获取到当前选项和当前选中的文本信息。
    ```typescript
    @Watch('selectMenuChange') @State selectMenu: string = ''; // 当前选中的按钮选项
    @State selectText: Array<RichEditorTextSpanResult | RichEditorImageSpanResult> = []; // 当前选中的文本内容
    // 将按钮对象TextMenuItem传入子组件
    menuItemsContent: Array<TextMenuItem> = [
      {
        content: $r('app.string.select_text_menu_search_menu'),
        id: TextMenuItemId.of('search'),
        icon: $r("app.media.select_menu_search")
      },
      {
        content: $r('app.string.select_text_menu_translate_menu'),
        id: TextMenuItemId.of('translate'),
        icon: $r("app.media.select_menu_translate")
      },
      {
        content: $r('app.string.select_text_menu_share_menu'),
        id: TextMenuItemId.of('share'),
        icon: $r("app.media.select_menu_share")
      },
    ];
    
    // 监听到选中按钮发生改变时触发相应方法 
    selectMenuChange() {
      promptAction.showToast({
        message: $r('app.string.select_text_menu_tips')
      });
    }
    ```

### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
selecttextmenu                                    // har类型
|---component 
|   |---RichEditorComponent.ets                   // 富文本组件  
|---model
|   |---SelectMenuOption.ets                      // 富文本定义类
|---view
|   |---SelectTextMenu.ets                        // 视图层-文本编辑页面
   ```

### 模块依赖

- 本实例依赖依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

- [RichEditor](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-richeditor-V5)
- [editMenuOptions](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-richeditor-V5#editmenuoptions12)