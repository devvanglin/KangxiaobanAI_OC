# ArrayBuffer序列化和转移 示例

### 介绍
本示例是[ArrayBuffer序列化和转移](https://gitee.com/harmonyos-cases/cases/blob/master/docs/performance/thread_data_transfer.md)的示例代码。 主要展示利用子线程进行图片处理的场景（比如需要调整一张图片的亮度、饱和度、大小等），避免阻塞主线程，同时可以查看处理时间对子线程数量进行优化。

### 效果预览
 ![](./screenshots/thread_data_transfer.png)   

### 使用说明
1. 调整任务数和传参方式后，调整饱和度，对比运行时间。
2. 对比不同任务数的运行时间，可以找到最合理的任务数量。

### 工程目录
```
entry/src/main/ets
├── entryability
│   ├── EntryAbility.ets                // Ability的生命周期回调内容
├── entrybackupability
│   └── EntryBackupAbility.ets          // 应用数据备份恢复类
├── pages
│   ├── AdjustImageView.ets             // 视图层- 动态图像参数调整页面
│   ├── AdjustThreadView.ets            // 视图层-多线程参数配置界面
│   ├── ImageView.ets                   // 视图层-基础图像展示页面
│   ├── Index.ets                       // 视图层-主页面
│   └── ThreadDataTransferHomePage.ets  // 视图层-多线程数据传输演示主页
├── utils
│   ├── ImageUtil.ets                   // 图像处理工具类
│   ├── LoggerUtil.ets                  // 增强型日志工具
│   ├── PixelUtil.ets                   // 显示单位转换工具
│   └── ThreadUtil.ets                  // 线程管理工具类
└── entry/src/main/resources            // 应用静态资源目录
```

### 相关权限 

不涉及。 

### 依赖

不涉及。 

### 约束与限制   

不涉及。 