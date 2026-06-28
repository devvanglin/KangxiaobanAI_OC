# 时延类性能问题分析实践

## 概要

本示例为[时延类性能问题分析实践](../../../docs/performance/delay_related_performance.md)的示例代码，主要展示占位符加载、上拉加载、渐变动画导致完成时延不满足标准经典场景。


## 效果预览

![](../../../docs/performance/figures/delay_related_performance_21.gif)

![](../../../docs/performance/figures/delay_related_performance_22.gif)

![](../../../docs/performance/figures/delay_related_performance_23.gif)

### 使用说明

1、父页面点击"PullToRefreshNews"文本按钮，跳转子页面PullToRefreshNews。

2、跳转子页面PullToRefreshNews页面，在滚动到底部时，上拉加载更多的网络请求，对比查看时延类性能问题。

3、返回父页面点击"FriendMoment"文本按钮，跳转子页面FriendMoment。

4、跳转子页面FriendMomen页面，滑动页面触发上拉加载，在loading动画期间等待数据请求，数据请求完成后刷新列表，对比查看时延类性能问题。

5、返回父页面点击"BottomDrawerSlideCase"文本按钮，跳转子页面BottomDrawerSlideCase。

6、跳转子页面BottomDrawerSlideCase页面，在滑动列表过程中，对比查看时延类性能问题。

### 工程目录
```
├──entry/src/main/ets
│  ├──constants 
│  │  ├──NewsConstants                      // PullToRefreshNews页面常量
│  │  ├──MomentConstants                    // FriendMoment页面常量
│  │  ├──ListConstants                      // 列表相关常量
│  │  └──CommonConstants.ets                // 页面相关公共常量
│  ├──entryability
│  │  └──EntryAbility.ets                   // Ability的生命周期回调内容
│  ├──entrybackupability
│  │  └──EntryBackupAbility.ets             // 程序入口类
│  ├──viewModel    
│  │  └──BasicDataSource.ets                // 基本数据源                      
│  └──pages
│     ├──components             
│     │  ├──Component.ets                   // 相关组件
│     │  ├──OneMoment.ets                   // FriendMoment列表子组件       
│     │  └──ImageText.ets                   // 图片&文字组合组件
│     ├──Index.ets                          // 主页面
│     ├──BottomDrawerSlideCase.ets          // 渐变动画示例
│     ├──FriendMoment.ets                   // 上拉加载示例
│     └──PullToRefeshNews.ets               // 占位符加载示例
└──entry/src/main/resources                 // 应用静态资源目录
```

### 相关权限

不涉及。

### 依赖

不涉及。

### 约束与限制

1.本示例仅支持标准系统上运行，支持设备：华为手机。

2.HarmonyOS系统：HarmonyOS NEXT Release及以上。

3.DevEco Studio版本：DevEco Studio NEXT Release及以上。

4.HarmonyOS SDK版本：HarmonyOS NEXT Release SDK及以上。

### 相关资料

[时延类性能问题分析实践](../../../docs/performance/delay_related_performance.md)
