# 3D立方体旋转轮播实现案例

### 介绍

本示例展示了如何通过使用[Swiper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-swiper-V5)组件的[customContentTransition](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-swiper-V5#customcontenttransition12)属性和[rotate](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-transformation-V5#rotate)属性实现3D立方体旋转轮播效果，增强用户交互体验。每次用户滑动轮播项时，都会展示生动的3D立方体旋转过渡效果。组件支持通过控制器对象动态更新轮播数据，包括添加、删除、替换等操作。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/cube_rotate_animation.gif)

### 使用说明

1. 页面加载完成后，热门卡片中轮播图自动播放，切换时带有3D立方体旋转过渡效果。
2. 可以左右滑动轮播项，滑动时会展示3D立方体旋转过渡效果。

### 实现思路

CubeRotateAnimationSwiper是一个能够在用户滑动时展示3D立方体旋转过渡效果的自定义轮播组件。它使用Swiper组件作为基础容器，通过customContentTransition属性自定义页面切换动画，实现3D立方体旋转效果。同时提供了控制器对象用于动态更新轮播数据。源码参考[CubeRotateAnimationSwiper.ets](./src/main/ets/components/CubeRotateAnimationSwiper.ets)。

1. 组件使用Swiper组件作为基础容器，结合LazyForEach实现轮播项的渲染。
    ```ts
    build() {
      Swiper(this.swiperController) {
        LazyForEach(this.items, (item: ESObject, index: number) => {
          Stack() {
            this.swiperItemSlotParam(item)
          }
          .rotate({
            x: 0,
            y: 1,
            z: 0,
            angle: this.angleList[index],
            centerX: this.centerXList[index],
            centerY: '50%',
            centerZ: 0,
            perspective: 0
          })
        })
      }
      .customContentTransition({
        timeout: 1000,
        transition: (proxy: SwiperContentTransitionProxy) => {
          // ...
        }
      })
    }
    ```

2. 通过customContentTransition属性自定义页面切换动画，在页面切换时逐帧触发回调，在回调中设置rotate属性值，修改轮播项的旋转角度和旋转中心轴，实现自定义3D立方体旋转切换动画。
    ```ts
    customContentTransition({
      // 页面移除视窗时超时1000ms下渲染树
      timeout: 1000,
      transition: (proxy: SwiperContentTransitionProxy) => {
        let angle = 0; // 旋转角度
        // position为index页面相对于selectedIndex对应页面的起始位置的移动比例，向左移动减小，向右移动增加。
        if (proxy.position < 0 && proxy.position > -1) {
          // 当前页向左滑出或上一页向右滑入
          angle = proxy.position * 90;
          // 设置index页面的旋转中心轴为右侧边缘
          this.centerXList[proxy.index] = '100%';
        } else if (proxy.position > 0 && proxy.position < 1) {
          // 当前页向右滑出或下一页向左滑入
          angle = proxy.position * 90;
          // 设置index页面的旋转中心轴为左侧边缘
          this.centerXList[proxy.index] = '0%';
        } else {
          // position小于-1时表示向左完全滑出区域，大于1时表示向右完全滑出区域，重置角度
          angle = 0;
        }
        // 修改index页的旋转角
        this.angleList[proxy.index] = angle;
      }
    })
    ```

3. 组件提供了控制器对象用于动态更新数据，支持添加、删除、替换等操作。
    ```ts
    // 组件控制器对象
    cubeSwiperController?: CubeSwiperController;

    aboutToAppear(): void {
      // ...
      if (this.cubeSwiperController) {
        this.cubeSwiperController.addData = this.addData;
        this.cubeSwiperController.deleteData = this.deleteData;
        this.cubeSwiperController.pushData = this.pushData;
        this.cubeSwiperController.setData = this.setData;
      }
    }
    ```

CubeRotateAnimationSamplePage基于CubeRotateAnimationSwiper组件，构建了一个完整的应用首页场景，展示了组件在实际应用中的使用效果。源码参考[CubeRotateAnimationSamplePage.ets](./src/main/ets/views/CubeRotateAnimationSamplePage.ets)。

1. 引入功能组件CubeRotateAnimationSwiper，并初始化相关参数，其中items为轮播数据源，swiperItemSlotParam为自定义轮播项内容。
    ```ts
    CubeRotateAnimationSwiper({
      items: item,
      swiperItemSlotParam: (item: MySwiperItem) => {
        this.mySwiperItem(item)
      }
    })
    ```

2. 通过swiperItemSlotParam自定义轮播项内容，例如标题、副标题和背景图片。
    ```ts
    @Builder
    mySwiperItem(item: MySwiperItem) {
      Stack({ alignContent: Alignment.TopStart }) {
        Rect()
          .width($r('app.string.cube_animation_full_size'))
          .height($r('app.string.cube_animation_full_size'))
          .fill($r('app.color.cube_animation_mask'))
          .fillOpacity($r('app.float.cube_animation_mask_opacity'))
  
        Column() {
          Text(item.title)
            // ...
          Text(item.subTitle)
            // ...
        }
      }
      .backgroundImage(item.image)
      .backgroundImageSize(ImageSize.Cover)
    }
    ```

### 高性能知识点

1、轮播项数据通过[LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-rendering-control-lazyforeach-V5)进行动态加载，以提升性能。
2、Swiper组件的[customContentTransition](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-swiper-V5#customcontenttransition12)属性在页面切换时逐帧触发回调，属于高频回到函数，注意在里面不要调用冗余操作和耗时操作。

### 工程结构&模块类型

   ```
   cuberotateanimation                               // har类型
   |---/src/main/ets/components                       
   |   |---CubeRotateAnimationSwiper.ets             // 封装的3D立方体旋转轮播功能组件
   |---/src/main/ets/model                        
   |   |---BasicDataSource.ets                       // 数据模型层-LazyForEach数据模型
   |   |---DataModel.ets                             // 数据模型层-场景页面的类型定义
   |---/src/main/ets/mock                        
   |   |---MockData.ets                              // mock数据
   |---/src/main/ets/views                        
   |   |---CubeRotateAnimationSamplePage.ets         // 视图层-3D立方体旋转轮播场景主页面
   ```

### 参考资料

[Swiper](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-swiper-V5)

[customContentTransition](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-container-swiper-V5#customcontenttransition12)

[rotate](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-transformation-V5#rotate) 