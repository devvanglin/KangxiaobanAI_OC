# Hitrace Tag 描述

源自官方文档 `hitrace -l` 输出的 tag 列表。tag 分为**内核态**和**用户态**两类。

## 用户态 tag（应用开发者最常用）

| tag | 描述 | 备注 |
|-----|------|------|
| `app` | **应用模块** — 通过 HiTraceMeter 接口做的打点 | ⭐ 最常用 |
| `ace` | ArkUI 跨平台引擎开发框架 |
| `ark` | Ark 模块 |
| `ability` | 能力管理器服务 |
| `animation` | 动画模块 |
| `window` | 窗口管理器 |
| `graphic` | 图形模块 |
| `power` | 电源管理器 |
| `samgr` | 服务能力管理组 |
| `ffrt` | FFRT 任务 |
| `nweb` | NWeb 模块 |
| `net` | 网络模块 |
| `multimodalinput` | 多模态输入 |
| `notification` | 通知模块 |
| `sensors` | 传感器模块 |
| `usb` | USB 子系统 |
| `zaudio` | 音频模块 |
| `zmedia` | 媒体模块 |
| `zcamera` | 相机模块 |
| `zimage` | 图像模块 |
| `huks` | 通用密钥库 |
| `security` | 安全子系统 |
| `useriam` | 用户身份与访问管理 |
| `distributeddatamgr` | 分布式数据管理器 |
| `dsoftbus` | 分布式软总线 |
| `dhfwk` | 分布式硬件框架 |
| `dinput` | 分布式输入 |
| `dscreen` | 分布式屏幕 |
| `dcamera` | 分布式相机 |
| `daudio` | 分布式音频 |
| `dsched` | 分布式调度 |
| `devicemanager` | 设备管理器 |
| `deviceauth` | 设备认证 |
| `deviceprofile` | 设备配置文件 |
| `bluetooth` | 蓝牙通信 |
| `account` | 账户管理器 |
| `accesscontrol` | 访问控制模块 |
| `accessibility` | 无障碍软件服务管理器 |
| `commercial` | nolog 版本标签 |
| `commonlibrary` | 通用库 |
| `filemanagement` | 文件管理 |
| `cloud` | 云子系统 |
| `gresource` | 全局资源管理器 |
| `hdf` | 硬件驱动框架 |
| `hdcd` | hdcd 工具 |
| `interconn` | 互联子系统 |
| `mdfs` | 移动分布式文件系统 |
| `misc` | misc 模块 |
| `musl` | musl 模块 |
| `ohos` | 系统通用标签 |
| `push` | 推送子系统 |
| `rpc` | RPC 与 IPC 通信 |
| `virse` | 虚拟化服务 |
| `dlpcre` | 数据防泄露凭证服务 |
| `drm` | 数字版权管理 |

## 内核态 tag

| tag | 描述 | 备注 |
|-----|------|------|
| `sched` | CPU 调度 | 性能分析常用 |
| `schedlt` | 轻量级 CPU 调度 | API 23+ |
| `freq` | CPU 频率 | 性能分析常用 |
| `idle` | CPU 空闲信息 |
| `load` | CPU 负载 |
| `irq` | IRQ 事件 |
| `irqoff` | IRQ 禁用代码段追踪 |
| `preemptoff` | 抢占禁用代码段追踪 |
| `disk` | 磁盘 I/O |
| `binder` | binder 通信内核信息 |
| `sync` | DMA 同步 |
| `memory` | 内存信息 |
| `memreclaim` | 内核内存回收 |
| `membus` | 内存总线利用率 |
| `pagecache` | 页缓存 |
| `erofs` | 增强型只读文件系统 |
| `ipa` | 热功耗分配器 |
| `workq` | 内核 worker 队列 |
| `i2c` | I2C 总线事件 |
| `mmc` | 嵌入式多媒体卡命令 |
| `ufs` | 通用闪存存储命令 |
| `regulators` | 电压电流调节器 |
| `zbinder` | zbinder 事件 |

## 快照模式默认 tag

快照模式捕获二进制格式 trace 时，不指定 tag 则默认采集以下列表：

```
net, dsched, graphic, multimodalinput, dinput, ark, ace, window,
zaudio, daudio, zmedia, dcamera, zcamera, dhfwk, app, gresource,
ability, power, samgr, ffrt, nweb, hdf, virse, workq, ipa, sched,
freq, disk, sync, binder, mmc, membus, load
```

## 使用建议

- **只看自己的代码打点** → 只采集 `app`
- **看帧率和 UI 性能** → `app ace graphic window`
- **综合性能分析** → `app ace graphic window sched freq disk`
- **全面系统分析** → 快照模式默认 tag 列表或 `--trace_begin -b 409600 app ace graphic window sched freq disk idle binder`
