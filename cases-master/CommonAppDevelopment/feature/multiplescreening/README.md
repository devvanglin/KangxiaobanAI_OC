# 多重筛选案例

### 介绍

本示例主要介绍多重筛选场景，利用数组方法过滤满足条件的数据，利用LazyForEach实现列表信息的渲染以及刷新。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/multiple_screening.gif" width="300" >

**使用说明**

1. 等待列表数据全部加载完成后，点击筛选类型，展开筛选数据。
2. 选中想要筛选的数据，点击确认，列表刷新。
3. 再次点开筛选类型，保留上次筛选的内容，点击重置筛选内容复原，列表数据恢复为未筛选前的数据。

### 实现思路

本例涉及的关键特性和实现方案如下：

1. 使用Grid实现筛选条件布局，源码参考[FilterComponent.ets](./src/main/ets/components/FilterComponent.ets)。

```typescript
Grid() {
  ForEach(this.item.options, (options: string, idx: number) => {
    GridItem() {
      Text(options)
        .textAlign(TextAlign.Center)
        .fontSize(16)
        .height(40)
        .width('100%')
    }
      ...
  })
}
.columnsTemplate('1fr 1fr 1fr')
  .rowsGap(16)
  .columnsGap(16)
  .margin({
    left: 16,
    right: 6,
    top: 8,
    bottom: 8
  })
  .layoutDirection(GridDirection.Row)
  .constraintSize({
    minHeight: '15%',
    maxHeight: '15%'// grid会撑满maxHeight，先限定死高度
  })
```

2. 使用数组方法对筛选数据进行过滤，得到筛选数据，源码参考[FilterComponent.ets](./src/main/ets/components/FilterComponent.ets)。

```typescript
GridItem() {
  Text(options)
    .textAlign(TextAlign.Center)
    .fontSize(16)
    .height(40)
    .width('100%')
}
.onClick(() => {
  if (this.item.selectItem.includes(idx)) {
    let index = this.item.selectItem.indexOf(idx);
    let listIdx = this.changData.indexOf(options);
    // 删除已存在的筛选数据的index值
    this.item.selectItem.splice(index, 1);
    // 过滤出来没有重复数据的筛选值
    this.changData = this.changData.filter(i => i !== options);
    this.selectArr = this.item.selectItem;
    // 删除已选择的数据的行数index数组
    this.arrayListData.splice(listIdx, 1);
  } else {
    // 添加筛选数据的index值
    this.item.selectItem.push(idx);
    // 添加选中的数据
    this.changData.push(options);
    this.selectArr = this.item.selectItem;
    // 添加选择的数据的行数index数组
    this.arrayListData.push(this.listIndex);
  }
})
```

3. 得到筛选的数据后根据点击的筛选数据行数，使用has进行if判断看是否满足多重筛选的条件，源码参考[FilterComponent.ets](./src/main/ets/components/FilterComponent.ets)。

```typescript
Button('确认')
  .height(40)
  .width(150)
  .backgroundColor(Color.White)
  .fontColor('#333')
  .onClick(() => {
    this.isShow = false;
    let arrayListData = new Set(this.arrayListData)
    if (arrayListData.has(0) && !arrayListData.has(1)) {
      // 仅选择停放时间
      this.siteList.timeMultiFilter(this.changData);
    } else if (!arrayListData.has(0) && arrayListData.has(1)) {
      // 仅选择套餐类型
      this.siteList.typeMultiFilter(this.changData);
    } else if (!arrayListData.has(0) && !arrayListData.has(1) && arrayListData.has(2)) {
      // 仅选择充电
      this.siteList.getInitalList();
    } else if (this.changData.length === 0) {
      // 未对数据进行选择
      this.siteList.getInitalList();
    } else {
      // 多重筛选
      this.siteList.multiFilter(this.changData);
    }
    if (this.siteList.totalCount() === 0) {
      this.siteList.getInitalList();
      promptAction.showToast({ message: "未找到相关数据" });
    }
  })
```

4. 使用filter过滤出来符合条件的数据，筛选出来的数组构建一个新的Set，使用Set中的has判断列表中相关数据是否存在，源码参考[SiteListDataSource.ets](./src/main/ets/model/SiteListDataSource.ets)。

```typescript
public multiFilter(changData: Array<string>) {
  let siteListString: string | undefined = AppStorage.get('siteList')
  if (siteListString) {
    let siteListObject: SiteListDataSource | undefined = JSON.parse(siteListString)
    if (siteListObject === undefined) {
      return
    }
    this.initialSiteList = siteListObject.dataList
    this.dataList = []
    this.dataList = this.initialSiteList
    // 筛选数据
    let changDataSet = new Set(changData)
    let dataList: SiteItem[] = this.dataList.filter(item => {
      item.siteBale = item.siteBale.filter(item => {
        if ((item.time && item.type) && (changDataSet.has(item.time)) && (changDataSet.has(item.type))) {
          return item
        }
        return
      })
      return item.siteBale
    })
    dataList = dataList.filter(item => item.siteBale.length !== 0);
    this.dataList = [];
    this.dataList = dataList;
    this.notifyDataReload();
  }
}
```

5. 使用深拷贝保留原数据，源码参考[SiteListDataSource.ets](./src/main/ets/model/SiteListDataSource.ets)。

```typescript
/**
 * 返回原数组
 */
public getInitalList() {
  let siteListString: string | undefined = AppStorage.get('siteList');
  if (siteListString) {
    let siteListObject: SiteListDataSource | undefined = JSON.parse(siteListString);
    if (siteListObject === undefined) {
      return;
    }
    this.initialSiteList = siteListObject.dataList;
    this.dataList = [];
    this.dataList = this.initialSiteList;
    this.notifyDataReload();
  }
}
```

### 工程结构&模块类型

   ```
multiplescreening                            // har类型
|---components
|   |---CustomComponent.ets                 // 组件层-首页底部tabs
|   |---CustonTitle.ets                     // 组件层-首页顶部标题
|   |---FilterComponent.ets                 // 组件层-筛选组件
|   |---InfoCard.ets                        // 组件层-列表组件
|---model 
|   |---SiteItemModel.ets                   // 模型层-场地信息
|   |---SiteItemModel.ets                   // 模型层-筛选以及懒加载数据处理
|   |---TabBarModel.ets                     // 模型层-tabs数据信息
|---view
|   |---Index.ets                           // 视图层-多重筛选主页面
   ```

### 模块依赖

[routermodule(动态路由)](../../common/routermodule/README_AUTO_GENERATE.md)

### 参考资料

- [LazyForEach](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-rendering-control-lazyforeach-V5)
- [Grid](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-container-grid-V13)