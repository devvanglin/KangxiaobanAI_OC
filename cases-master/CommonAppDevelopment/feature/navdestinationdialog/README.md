# NavDestination弹窗

### 介绍

本案例介绍了使用NavDestination组件的Dialog模式实现与前一个页面的联动的评论弹窗。

### 效果预览图
![](../../product/entry/src/main/resources/base/media/navdestination_dialog.gif)

**使用说明**

点击案例中的商品介绍页面底部商店信息栏中的评论图标，即可拉起评论区弹窗，同时商品介绍页面自适应缩小。
此时在商品介绍页区域（或者未滑动浏览的评论区）可以通过手势向下滑动，缩小评论区高度的同时，增加商品介绍页面的高度，实现联动效果。

### 实现思路

1. 创建商品介绍页面。

通过Navigation组件作为路由导航根容器，同时也作为本案例的商品介绍页的容器。
> 具体商品介绍组件内容省略，详见代码[MainPage.ets](./src/main/ets/mainpage/MainPage.ets)。

```typescript
build() {
  Column() {
    this.goodsItem()
  }
  .width($r('app.string.navdialog_full_size'))
}

@Builder
goodsItem() {
  Column() {
    // 商品图片
    ...
    // 底部栏
    this.shopBar(() => {
      // 触发弹窗的回调函数
      animateTo({ duration: Consts.COMMENT_DIALOG_TRANS_DURATION, curve: Curve.Ease }, () => {
        this.ndDialogHeight = this.ndPageHeight * Consts.COMMENT_DIALOG_SCALE;
      })

      DynamicsRouter.push(RouterInfo.NAVDESTINATION_COMMENT_DIALOG)
      logger.info(TAG, `open dialog`);
    })
  }
  .width($r('app.string.navdialog_full_size'))
}
        
// 商店信息栏的自定义组件实现        
@Builder
shopBar(callback: () => void) {
  Row({ space: Consts.SHOP_BAR_SPACE }) {
    ...
    
    // 评论按钮
    Image($r("app.media.nd_comment"))
      .width(Consts.SHOP_BAR_ICON_SIZE)
      .height(Consts.SHOP_BAR_ICON_SIZE)
      .onClick(callback)

    ...
  }
  ...
}
```

2. 创建评论区组件。

使用NavDestination组件作为评论区子页面的根容器，设置mode属性为NavDestinationMode.DIALOG。
此模式默认透明，进出页面栈不影响下层NavDestination的生命周期，不支持系统转场动画，所以可以实现评论区和商品页面同时展现，同时需要自己定义转场动画。

> 除了弹窗的转场动画，同时还需要设置商品页面缩小的动画，以实现衔接（此内容在上一步中已经实现），并保持转场动画时长略大于主页缩小动画，避免出现衔接空白。
> 
> 如果显示评论区时不想显示底部商店信息栏，可以设置弹窗高度直接覆盖，可以简化实现代码。
```typescript
Column() {
  // 评论弹窗上部的蒙版，用于附加手势和确定评论弹窗高度
  Column()
  .width($r('app.string.navdialog_full_size'))
  .height(this.windowHeight - this.dialogHeight - Consts.SHOP_BAR_HEIGHT)
  .backgroundColor(Color.Transparent)

  Column() {
    Comment({
      isGesture: this.isGesture,
      listScrollAble: this.listScrollAble,
      close: () => {
        this.closeDialog();
      }
    })
  }
  .height(this.dialogHeight + Consts.SHOP_BAR_HEIGHT) // 提高弹窗的高度，用以覆盖底部商店栏
  .backgroundColor(Color.White)
  .transition(
    TransitionEffect
      .move(TransitionEdge.BOTTOM)
      .animation({ duration: Consts.COMMENT_DIALOG_TRANS_DURATION, curve: Curve.Ease }))
}
.height($r('app.string.navdialog_full_size'))
```

3. 设置手势实现动态联动效果。

主页和弹窗页面的尺寸需要联动修改，通过@LocalStorageLink装饰器配置的状态变量，即可实现二者高度的联动，同时设置手势属性实现实时跟手联动效果。
```typescript
Column() {
  Comment({
    isGesture: this.isGesture,
    listScrollAble: this.listScrollAble,
    close: () => {
      this.closeDialog();
    }
  })
}
.width($r('app.string.navdialog_full_size'))
.height(this.dialogHeight + Consts.SHOP_BAR_HEIGHT) // 提高弹窗的高度，用以覆盖底部商店栏
  ...
.parallelGesture(PanGesture({ direction: PanDirection.Vertical })
  .onActionUpdate((event) => {
    if (!this.isGesture || this.dialogHeight <= 0) {
      return;
    }
    // 计算当前弹窗的高度
    const curDialogHeight = this.initDialogHeight - event.offsetY;
    if (curDialogHeight < 0) {
      this.dialogHeight = 0;
    } else if (curDialogHeight <= this.initDialogHeight) {
      this.dialogHeight = curDialogHeight;
    }
  })
  .onActionEnd(() => {
    if (!this.isGesture && this.dialogHeight === this.initDialogHeight) {
      return;
    }
    if (this.dialogHeight < Consts.COMMENT_DIALOG_MIN_HEIGHT) {
      this.closeDialog();
    } else {
      this.recoveryDialog();
    }
    // 手势结束后，重新允许列表滚动
    this.listScrollAble = true;
  }), GestureMask.Normal)
```
通过onActionUpdate实时修改弹窗的高度，在抬手时通过onActionEnd回调实现关闭弹窗或者恢复弹窗以及相应的动画效果。

此处有一个注意点是同步评论区List组件的滑动手势和前面手动设置的自定义滑动手势。首先需要监听评论区的滑动位置，只有用户不在浏览状态（也就是List偏移不为0）
时才可以触发自定义手势。其次绑定自定义手势使用parallelGesture，使系统的List滑动手势和自定义绑定的手势都能够触发，避免滑动冒泡事件被阻塞。

```typescript
// commets list
List({ space: Consts.COMMENT_SPACE, scroller: this.scroller }) {
    // TODO: 高性能知识点: LazyForEach按需加载，提高加载性能。
    LazyForEach(this.data, (item: number, index: number) => {
      ListItem() {
        CommentItem({ index: index + 1 }) // index from 1
      }
    }, (item: number) => item.toString())
}
// TODO: 高性能知识点: 使用了cachedCount设置预加载的评论，提高快速滑动时的性能。
.cachedCount(Consts.COMMENTS_LIST_CACHE)
.edgeEffect(EdgeEffect.Spring)
.onScroll(() => {
    const offsetY = this.scroller.currentOffset().yOffset;
    if (offsetY <= 0) {
      this.isGesture = true;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } else {
      this.isGesture = false;
    }
})
.layoutWeight(1) // 自适应布局
```

### 高性能知识点

1. 本案例在滚动容器List中使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V1/arkts-rendering-control-lazyforeach-0000001580345086-V1#ZH-CN_TOPIC_0000001666708148__idatasource%E7%B1%BB%E5%9E%8B%E8%AF%B4%E6%98%8E)，框架会根据滚动容器可视区域按需创建组件，当组件滑出可视区域外时，框架会进行组件销毁回收以降低内存占用。为了更好的列表滚动体验，减少列表滑动时出现白块，使用了List组件的cachedCount参数用于设置列表项缓存数，只在懒加载LazyForEach中生效。
2. 本案例使用了系统高频回调[onScroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V1/ts-container-scroll-0000001630146357-V1#ZH-CN_TOPIC_0000001714626361__事件)与[onActionUpdate](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-gestures-pangesture-0000001815767760#ZH-CN_TOPIC_0000001815767760__事件)，为提高性能应注意避免在其中使用冗余和耗时的操作。

### 工程结构&模块类型

```text
navdestinationdialog           // HAR类型
    ├─common
    |   ├─Constants.ets        // 项目中的常量
    |   └─Utils.ets            // 通用的工具函数
    ├─mainpage
    |   └─MainPage.ets         // 入口主页 
    ├─model
    |   └─NavgationModel.ets   // 数据模型 
    └─viewmodel
        ├─CommentDialog.ets    // 评论弹窗视图
        └─Comment.ets          // 评论列表视图
```

### 模块依赖

- [**路由模块**](../routermodule)
- [**utils**](../../common/utils)

### 参考资料

- [**PanGesture**](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-gestures-pangesture-0000001815767760)
- [**LazyForEach**](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-0000001820879609)
- [**NavDestination**](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navdestination-0000001815767788)
- [**Navigation**](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navigation-0000001815927580)