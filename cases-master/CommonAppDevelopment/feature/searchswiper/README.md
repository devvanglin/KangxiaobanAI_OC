# 搜索框热搜词自动滚动

### 介绍

本示例介绍使用TextInput组件与Swiper组件实现搜索框内热搜词自动切换。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/search_swiper.gif" width="200">

**使用说明**

页面顶部搜索框内热搜词条自动切换，编辑搜索框时自动隐藏。

### 实现思路

1. 使用TextInput实现搜索框
   ```javascript
   TextInput({ text: this.textData, controller: this.controller })
   .onChange((data) => {
      this.textData = data;
   })
   ```
2. 使用Swiper实现热搜词条切换,其中使用ForEach组件循环热搜内容
    ```javascript
    Swiper() {
     // 循环搜索关键字数据
      ForEach(FIND_SEARCH_TEXT_DATA, (item: SearchTextModel) => {
        Text(item.searchText)
        ... 
       }, (item: SearchTextModel) => item.id.toString())
    }
    ```
3. 通过判断搜索框编辑态来控制Swiper组件滚动的开始和暂停
   ```javascript
   .onEditChange((isEditing) => {
     if (!isEditing) {
       this.isAutoPlay = true
     } else {
       this.isAutoPlay = false
     }
   })
   ```
4. 通过判断搜索框是否有内容控制Swiper组件显示隐藏
   ```javascript
   Swiper() {
     ...
   }
   .visibility(this.textData ? Visibility.Hidden : Visibility.Visible)
   ```
5. 使用Stack组件堆叠搜索框与热搜词
   ```javascript
   Stack() {
     Swiper()
     TextInput()
   }
   ```
### 工程结构&模块类型
   ```
   searchswiper                                  // har类型
   |---SearchSwiper.ets                          // 视图层-场景列表页面
   ```

### 模块依赖

[routermodule(动态路由)](../../common/routermodule)

### 参考资料

**不涉及**