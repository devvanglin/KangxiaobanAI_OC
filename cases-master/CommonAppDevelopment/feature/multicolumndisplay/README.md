# 多段混合数据展示案例

### 介绍

本示例介绍了如何使用[WaterFlow](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-container-waterflow-V13)组件展示多列不同数据，通过设置sections属性来配置不同数据的列间距、行间距等信息。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/multi_column_display.gif" width="300" >

**使用说明**

1. 向下滑动，不同的数据可以规律展示。

### 实现思路

本示例通过设置WaterFlow组件的sections属性，来配置不同列/不同数据的相关信息，使得多段不同列数混合布局的数据能够正常展示。
1. 初始化不同列输的分组信息。[源码参考](./src/main/ets/components/MultiColumnDisplayPage.ets)

   ```ts
   // 瀑布流是一列的时候，分组配置信息
   private oneColumnSection: SectionOptions = {
     // 分组中FlowItem数量
     itemsCount: 1,
     // 列数
     crossCount: 1,
     // 分组的列间距
     columnsGap: 5,
     // 分组的行间距
     rowsGap: 0,
     // 分组的margin
     margin: this.sectionMargin,
     // FlowItem的高度
     onGetItemMainSizeByIndex: (index: number) => {
       // 如果是最后一个item，高度赋值200
       if (index === this.dataCount - 1) {
         return 200;
       }
       return 160;
     }
   };
   // 瀑布流是两列的时候，分组配置信息
   private twoColumnSection: SectionOptions = {
     itemsCount: 8,
     crossCount: 2,
     columnsGap: 8,
     rowsGap: 0,
     onGetItemMainSizeByIndex: (index: number) => {
       // 瀑布流数据中最大的index是9的倍数，通过index除9的余数可以确定哪些item的高度较矮
       const newIndex = index % 9;
       // index除9的余数在以下数组中的的，高度较矮
       const longIndexArr = [1, 4, 5, 8];
       return longIndexArr.includes(newIndex) ? 155 : 256;
     }
   }
   ```

2. 按照不同列数数据的出现顺序将分组信息存放到数组中。[源码参考](./src/main/ets/components/MultiColumnDisplayPage.ets)

   ```ts
   aboutToAppear() {
     let sectionOptions: SectionOptions[] = [];
     // 通过商品数据类型初始化瀑布流分组信息
     for (let index = 0; index < waterFlowData.length; index++) {
       const productInfo: ProductInfo = waterFlowData[index];
       if (productInfo.type === this.imageFlowItemReuseId) {
         // 仅展示图片时瀑布流是一列
         sectionOptions.push(this.oneColumnSection);
       } else if(productInfo.type === this.bottomFlowItem){
         // 瀑布流最后一个元素是一列
         sectionOptions.push(this.oneColumnSection);
       } else if (productInfo.type === this.reusableFlowItemReuseId) {
         // 图片文字混合时瀑布流是两列
         sectionOptions.push(this.twoColumnSection);
         index += (this.twoColumnSection.itemsCount - 1);
       }
     }
     this.sections.splice(0, 0, sectionOptions);
   }
   ```

3. 使用WaterFlow组件构造页面，根据id构建不同的组件。[源码参考](./src/main/ets/components/MultiColumnDisplayPage.ets)

   ```ts
   WaterFlow({ scroller: this.scroller, sections: this.sections }) {
     LazyForEach(this.dataSource, (item: ProductInfo) => {
       FlowItem() {
         // 通过type字段区分需要展示的ux
         if (item.type === this.reusableFlowItemReuseId) {
           ReusableFlowItem({ listData: item })
             .reuseId(this.reusableFlowItemReuseId)
         } else if (item.type === this.imageFlowItemReuseId) {
           ReusableImageItem({ listData: item })
             .reuseId(this.imageFlowItemReuseId)
         } else {
           this.bottomItemInWaterFlow(item);
         }
       }
       .width($r('app.string.water_flow_item_width'))
     }, (item: ProductInfo) => JSON.stringify(item))
   }
   ```

### 高性能知识点

1. 本示例构造子组件时，使用[@Reusable](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/arkts-reusable-V13)标识组件，使其具有可复用的能力，减少性能消耗。

### 工程结构&模块类型

```
multicolumndisplay                                // har类型
|---/src/main/ets/components                        
|   |---MultiColumnDisplayPage.ets                // 多列不同数据展示案例首页
|   |---WaterFlowDataSource.ets                   // LazyForEach控制器
|---/src/main/ets/data                        
|   |---ProductData.ets                           // mock数据
|   |---ProductDataFormat.ets                     // 瀑布流数据结构
```

### 模块依赖

   [routermodule(动态路由)](../../common/routermodule/README_AUTO_GENERATE.md)

### 参考资料

[WaterFlow](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-container-waterflow-V13)

[组件复用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/arkts-reusable-V13)