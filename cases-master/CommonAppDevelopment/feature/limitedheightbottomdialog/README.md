# 限制高度底部弹窗

### 介绍

本示例介绍了如何实现一个限制高度的底部弹窗，以购物应用的“我的”页面来呈现。当给一个底部弹窗的可滚动区域设置最大高度后，如果弹窗内部视图的高度超过了这个最大高度，弹窗可滚动区域的高度就是这个最大高度，视图内容不会展示完全，需要滚动查看；如果弹窗内部视图的高度没有超过这个最大高度，弹窗可滚动区域高度就是视图的高度，视图内容展示完全。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/limited_height_bottom_dialog.gif" width="320">

**使用说明**：
* 点击“常用设置”查看已达到限制高度的底部弹窗，视图内容不会展示完全，需要滚动查看。
* 点击“安全设置”查看未达到限制高度的底部弹窗，视图内容展示完全。

### 实现步骤

1. 创建一个限制高度的底部弹窗，这个弹窗内部视图和可滚动区域的最大高度可以通过外部传入。如下代码所示，wrapBuilder用于创建自定义的视图，Scroll组件使用constraintSize方法设置了最大高度，如果自定义视图的高度没有超过最大高度，Scroll组件的高度就是自定义视图的高度。如果自定义视图的高度超过最大高度，Scroll组件的高度就会是最大高度。
    
    ```ts
    maxScrollHeight: Length = '90%';     // 最大可滚动区域高度
    wrapBuilder?: WrappedBuilder<[]>;    // 自定义视图创建方式
   ```
    ```ts
    Scroll() {
      Column() {
        if (this.wrapBuilder) {
          // 创建自定义视图
          this.wrapBuilder.builder()
        }
      }.width($r('app.string.limited_height_bottom_dialog_full_width'))
    }.width($r('app.string.limited_height_bottom_dialog_full_width'))
    // TODO：知识点：使用constraintSize方法可以设置约束尺寸，组件布局时，进行尺寸范围限制。这里设置Scroll组件的高度限制。
    .constraintSize({maxHeight: this.maxScrollHeight})
    .id('scroll')   
   ```
2. 创建常用设置底部弹窗的视图和安全设置底部弹窗的视图，下面是创建常用设置底部弹窗视图的代码。
    
    ```ts
    /**
     * 创建常用设置底部弹窗视图
     */
     @Builder
     function createCommonSettingView() {
       CommonSettingView()
     }
    ```
3. 创建常用设置底部弹窗的CustomDialogController和创建安全设置底部弹窗的CustomDialogController，传入需要的参数，下面是创建常用设置底部弹窗的CustomDialogController的代码。

   ```ts
    // 常用设置底部弹窗的CustomDialogController
    commonSettingDialogController: CustomDialogController = new CustomDialogController({
      builder: LimitedHeightBottomDialog({
        title: $r('app.string.limited_height_bottom_dialog_common_setting'),
        maxScrollHeight: DIALOG_MAX_SCROLL_HEIGHT,
        wrapBuilder: wrapBuilder(createCommonSettingView),
        showFlag: this.commonSettingDialogShowFlag
      }),
      alignment: DialogAlignment.Bottom,
      width: $r('app.string.limited_height_bottom_dialog_full_width'),
      customStyle: true,         // customStyle需要设置为true，否则底部弹窗出现的动效会有问题
      autoCancel: true,
      onWillDismiss: () => {     // 修改点击弹窗外部区域和返回操作时弹窗消失的方式，这里的处理会有一个动效。不加这个处理方式的话，弹窗会以默认的方式消失
        this.commonSettingDialogShowFlag = Visibility.Hidden;
        setTimeout(() => {
        this.commonSettingDialogController.close();
        }, CLOSE_DIALOG_DELAY)
      }
    }); 
   ```
4. 调用常用设置底部弹窗的CustomDialogController或安全设置底部弹窗的CustomDialogController的open方法，让弹窗展示出来，下面出现常用设置底部弹窗的代码。
    
    ```ts
    // 弹出常用设置底部弹窗
    this.commonSettingDialogController.open();
    ```
### 高性能知识点
不涉及

### 工程结构&模块类型

   ```
   limitedheightbottomdialog                           // har
   |---dialog
   |   |---CommonSettingView.ets                       // 常用设置弹窗视图
   |   |---LimitedHeightBottomDialog.ets               // 限制高度底部弹窗
   |   |---SecuritySettingView.ets                     // 安全设置弹窗视图
   |---model
   |   |---ActionItem                                  // 操作项信息
   |---view
   |   |---ActionSectionView.ets                       // 操作组合组件
   |   |---LimitedHeightBottomDialogComponent.ets      // 限制高度底部弹窗案例页面
   ```

### 是否支持模拟器
是
### 模块依赖
依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。
### 参考资料
[自定义弹窗 (CustomDialog)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-methods-custom-dialog-box-V5)



