# 基于一多能力实现响应式布局

## 介绍

本示例展示了如何使用HarmonyOS提供一多响应式能力，在多设备（直板机、双折叠、三折叠、平板、PC/2in1）上实现常见的响应式布局。

## 效果展示

手机运行效果图：

![](screenshots/device/mate60pro.png)

双折叠运行效果图：

![](screenshots/device/matex5.png)

三折叠运行效果图：

![](screenshots/device/matext.png)

平板运行效果图：

![](screenshots/device/matepadpro.png)

PC/2in1运行效果图：

![](screenshots/device/matebookx.png)

## 使用说明

应用可以点击首页不同的列表项，展示在多设备上的响应式布局页面效果，包括：列表布局、瀑布流布局、轮播布局、宫格布局、侧边栏、二分栏、三分栏、挪移布局、底部/侧边导航和缩进布局。
在二分栏和三分栏布局中，分别展示了聊天、日历和邮箱应用场景，帮助开发者使用分栏布局。

## 工程目录

```
├──entry/src/main/ets/
│  ├──constants                          
│  │  ├──CommonConstants.ets             // 通用常量类
│  │  ├──ConversationConstants.ets       // 会话相关常量类
│  │  └──ProductDetailConstants.ets      // 商品详情常量类
│  ├──entryability
│  │  └──EntryAbility.ets
│  ├──entrybackupability
│  │  └──EntryBackupAbility.ets
│  ├──pages
│  │  ├──DoubleColumnConversation.ets    // 单双栏聊天页 
│  │  ├──DoubleColumnLayout.ets          // 单双栏页
│  │  ├──GridLayout.ets                  // 网格页
│  │  ├──IndentedLayout.ets              // 缩进布局页
│  │  ├──Index.ets                       // 主页
│  │  ├──ListLayout.ets                  // 列表布局页
│  │  ├──MoveLayout.ets                  // 挪移布局页
│  │  ├──SidebarLayout.ets               // 侧边栏页
│  │  ├──SwiperLayout.ets                // 轮播布局页
│  │  ├──TabsLayout.ets                  // 底部/侧边导航页
│  │  ├──TripleColumnCalendar.ets        // 三分栏日历页
│  │  ├──TripleColumnLayout.ets          // 三分栏页
│  │  ├──TripleColumnMail.ets            // 三分栏邮箱页
│  │  └──WaterFlowLayout.ets             // 瀑布流布局页
│  ├──utils
│  │  ├──WidthBreakpointType.ets         // 一多断点工具类
│  │  └──WindowUtil.ets                  // 窗口工具类
│  └──views
│     ├──DoubleConversationView          // 双栏聊天视图目录 
│     │  ├──model                        
│     │  │  └──ConversationData.ets      // 聊天数据类
│     │  ├──productView                  
│     │  │  ├──CommonView.ets            // 商品通用视图
│     │  │  ├──ProductConfig.ets         // 商品配置视图
│     │  │  ├──ProductDiscount.ets       // 商品打折视图
│     │  │  ├──ProductPrice.ets          // 商品价格视图
│     │  │  └──ProductUtilView.ets       // 购物车与购买组件
│     │  ├──ConversationDetail.ets       // 聊天详情页
│     │  ├──ConversationDetailNone.ets   // 默认聊天页
│     │  ├──ConversationList.ets         // 聊天列表页
│     │  ├──ConversationNavBarView.ets   // 聊天导航栏
│     │  ├──DoubleConversationView.ets   // 双栏聊天首页
│     │  ├──MessageBubble.ets            // 聊天气泡视图
│     │  └──ProductPage.ets              // 商品详情页
│     ├──TabsView                        // 底部/侧边导航视图目录
│     │  ├──model                    
│     │  │  └──TabData.ets               // 页签数据类
│     │  ├──TabSideBarView.ets           // 侧边栏
│     │  ├──TabsView.ets                 // 底部/侧边导航首页
│     │  ├──TopTabView.ets               // 顶部页签
│     │  └──VideoInfoView.ets            // 内容区域页
│     ├──TripleCalendarView              // 三分栏日历视图目录
│     │  ├──model                        
│     │  │  ├──CalendarItem.ets          // 日历数据类型
│     │  │  └──TripData.ets              // 日程数据类型
│     │  ├──CalendarSideBarView.ets      // 日历侧边栏
│     │  ├──CalendarView.ets             // 日历内容页
│     │  ├──TripleCalendarView.ets       // 三分栏日历首页
│     │  └──TripShedule.ets              // 日历日程页
│     ├──TripleMailView                  // 三分栏邮箱视图目录
│     │  ├──model                        
│     │  │  └──MailData.ets              // 邮箱数据类型
│     │  ├──MailContent.ets              // 邮件内容页
│     │  ├──MailNavView.ets              // 邮箱导航页
│     │  ├──MailSideBarView.ets          // 邮箱侧边栏
│     │  └──TripleMailView.ets           // 三分栏邮箱首页
│     ├──DoubleColumnView.ets            // 单双栏视图
│     ├──GridView.ets                    // 网格视图
│     ├──IndentedView.ets                // 缩进布局视图
│     ├──ListView.ets                    // 列表布局视图
│     ├──MoveView.ets                    // 挪移布局视图
│     ├──NavigationBarView.ets           // 分栏布局导航栏视图
│     ├──NavigationContentView.ets       // 分栏布局内容区视图
│     ├──SidebarView.ets                 // 侧边栏视图
│     ├──SwiperView.ets                  // 轮播布局视图
│     ├──TripleColumnView.ets            // 三分栏视图
│     └──WaterFlowView.ets               // 瀑布流布局视图
└──entry/src/main/resource               // 应用静态资源目录
```

## 实现思路

1. 使用List组件+断点实现列表布局。
2. 使用WaterFlow组件+断点实现瀑布流布局。
3. 使用Swiper组件+断点实现轮播布局。
4. 使用Grid组件+断点实现网格布局。
5. 使用SideBarContainer组件+断点实现侧边栏。
6. 使用Navigation组件+断点实现单/双栏。
7. 使用SideBarContainer组件+Navigation组件+断点实现三分栏。
8. 使用Tabs组件+断点实现底部/侧边导航。 
9. 使用GridRow/GridCol组件+断点+栅格实现挪移布局。 
10. 使用GridRow/GridCol组件+断点+栅格实现缩进布局。

## 相关权限

不涉及。

## 依赖

不涉及。

## 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：直板机、双折叠、三折叠、平板、PC/2in1。
2. HarmonyOS系统：HarmonyOS 6.0.0 Release及以上。
3. DevEco Studio版本：DevEco Studio 6.0.0 Release及以上。
4. HarmonyOS SDK版本：HarmonyOS 6.0.0 Release SDK及以上。
