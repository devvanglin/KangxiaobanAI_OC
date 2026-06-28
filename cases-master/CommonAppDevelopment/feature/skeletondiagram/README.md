# 骨架屏实现案例

### 介绍

本示例介绍通过**骨架屏**提升加载时用户体验的方法。骨架屏用于在页面数据加载完成前，先给用户展示出页面的大致结构（通常以灰色或其他浅色系的占位图形式呈现），待接口数据加载完成后，再渲染出实际页面内容并替换掉骨架屏。 通过网络接口返回的状态改变 loadingCollectedStatus 值，动态切换页面内容：初始显示骨架屏（LoadingView）；成功且有数据则显示列表页（ListView）；数据为空显示无数据页（NoneContentView）；加载失败则显示失败页（LoadingFailedView）。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/skeleton_diagram.gif)

**使用说明**

1. 进入页面开始加载，加载完成后显示整个界面。

### 实现思路

1. 为了实现骨架屏的加载效果，首先自行构造一个网络JSON数据供请求使用（此处不详述具体过程）。在aboutToAppear生命周期方法中加载网络数据，并根据返回结果改变状态变量loadingCollectedStatus的值。
```typescript
aboutToAppear() {
  this.loadList();
}

// 加载网络数据
loadList() {
  // 正在加载状态
  this.loadingCollectedStatus = LoadingStatus.LOADING;
  let httpRequest = http.createHttp();
  // 设置发起请求可选参数
  let options: http.HttpRequestOptions = {
    expectDataType: http.HttpDataType.OBJECT, // 可选，指定返回数据的类型
  };
  httpRequest.request(REQUEST_URL, options,
    (err: Error, data: http.HttpResponse) => {
      if (!err) {
        if (data.responseCode === CommonConstants.SUCCESS) {
          // 数据加载成功
          this.loadingCollectedStatus = LoadingStatus.SUCCESS;
          // 加载数据的处理
          this.dataSource.pushArrayData(data.result['data'] as Array<Model>)
        } else {
          // 数据加载失败
          this.loadingCollectedStatus = LoadingStatus.FAILED;
        }
      } else {
        // 数据加载失败
        this.loadingCollectedStatus = LoadingStatus.FAILED;
      }
    });
}
```
2. 根据LoadingStatus的值渲染不同的页面内容：当LoadingStatus为LOADING时，显示骨架屏（LoadingView）；若LoadingStatus为SUCCESS且dataSource.totalCount大于零，则显示列表页（ListView）；若数据为空，则显示无数据页面（NoneContentView）；若LoadingStatus为FAILED，则显示加载失败页面（LoadingFailedView）。
```typescript
build() {
  Column() {
    if (this.loadingCollectedStatus === LoadingStatus.LOADING) {
      // 加载骨架屏
      LoadingView()
    } else if (this.loadingCollectedStatus === LoadingStatus.FAILED) {
      // 网络请求失败
      LoadingFailedView(() => {
        this.loadList();
      })
    } else if (this.dataSource.totalCount() === 0) {
      // 获取数据为空
      NoneContentView($r("app.media.ic_browse_no"), $r("app.string.ske_to_view"))
    } else {
      // 加载列表
      ListView({ listData: this.dataSource })
    }
  }
  .backgroundColor($r("app.color.ske_list_back_ground_color"))
  .height(CommonConstants.FULL_PERCENT)
  .width(CommonConstants.FULL_PERCENT)
}
```
3. 实现与真实列表布局一致的骨架屏效果，采用如下步骤：首先，使用Row控件并设置灰色背景还原ListItem上所有的控件位置和大小，通过ForEach循环创建列表项，以此形成骨架屏的基本结构；接着，为骨架屏列表添加animateTo显示动画，这样在加载过程中，骨架屏就会呈现出闪烁的效果，从而提升用户体验。
```typescript
// 骨架屏的闪烁动画
startAnimation(): void {
  animateTo(CommonConstants.SKELETON_ANIMATION, () => {
    // 动态修改骨架屏的透明度
    this.listOpacity = CommonConstants.HALF_OPACITY;
  });
}

build() {
  Row() {
    List({ space: CommonConstants.SPACE_12 }) {
      ForEach(SkeletonData, (item: SkeletonType) => {
        ListItem() {
          // 骨架屏布局
          ArticleLoadingSkeleton(item.isMine)
        }
      })
    }
    .layoutWeight(CommonConstants.LAYOUT_WEIGHT)
      .scrollBar(BarState.Off)
      .padding({
        left: $r("app.float.ske_md_padding_margin"),
        right: $r("app.float.ske_md_padding_margin")
      })
  }
  .alignItems(VerticalAlign.Top)
    .height(CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .opacity(this.listOpacity)
      // 组件挂载显示后触发此回调，调用动画接口给组件添加动画。
    .onAppear(() => {
      this.startAnimation();
    })
}

```

### 高性能知识点

本示例使用了[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)进行数据懒加载，LazyForEach懒加载可以通过设置cachedCount属性来指定缓存数量，同时搭配[组件复用](https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-component-reuse-V5)能力以达到性能最优效果。

### 工程结构&模块类型

```
skeletondiagram                                    // har类型
|---common
|   |---CommonConstants.ets                        // 常量定义 
|   |---CommonConstants.ets                        // 枚举定义
|---model
|   |---LazyDataSource.ets                         // 数据类懒加载
|   |---Model.ets                                  // 列表数据模型 
|---view
|   |---ArticleLoadingSkeleton.ets                 // 骨架屏组件 
|   |---ListView.ets                               // 列表展示页面 
|   |---LoadingFailed.ets                          // 网络加载失败展示页面
|   |---LoadingView.ets                            // 骨架屏加载页面
|   |---NoneContentView.ets                        // 空数据展示页面
|   |---ObservedArray.ets                          // 被观察数据对象包装
|   |---SkeletonDiagram.ets                        // 主页面
```

### 模块依赖

本实例依赖common模块来实现[日志](../../common/utils/src/main/ets/log/Logger.ets)的打印以及路由模块来[注册路由](../routermodule/src/main/ets/router/DynamicsRouter.ets)。

### 参考资料

[HMOS世界](https://gitee.com/harmonyos_samples/hmosworld)

[RelativeContainer](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-relativecontainer-V5)

[显式动画 (animateTo)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-explicit-animation-V5)

[@ohos.net.http (数据请求)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-http-V5)
