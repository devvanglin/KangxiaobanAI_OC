---
name: hitrace-collect
description: "采集和导出 HarmonyOS 设备上的 hitrace 性能 trace。用户需要采集 trace 时使用。场景包括：(1) 定时采集抓取指定时间窗口的 trace (2) 快照模式按需从缓冲区导出 trace (3) 录制模式长时间持续采集 trace 落盘 (4) 查询/设置 trace 级别阈值。触发词：采集 trace、抓 trace、hitrace、trace 收集。使用前确保已通过 hdc 连接设备。"
---

# Hitrace 使用指南

## 概述

`hitrace` 是 HarmonyOS 的命令行 trace 采集工具，通过内核 ftrace 机制采集系统和应用的性能打点。本 skill 提供完整的 hitrace 使用流程指引。

**底层原理：** hitrace 通过 `/sys/kernel/tracing/`（或 `/sys/kernel/debug/tracing/`）接口控制内核 ftrace 子系统，在用户态通过 `tracing_mark_write` 写入 trace 事件，在设备上生成 `.ftrace`（文本）或 `.sys`（二进制）文件。

**前置条件：**
- 已通过 `hdc` 连接设备（`hdc shell` 可用）
- 默认需 shell 权限（部分调试场景可能需要 root）
- 输出路径规则：
  - 文本格式（`--text`）：仅支持 `-o /data/local/tmp/...`
  - 二进制格式（`--raw`）：默认保存到 `/data/log/hitrace/`，不支持 `-o` 指定路径

---

## ⚡ 标准工作流（Agent 必读）

**当开发者说「我要抓 trace」「采集 trace」「帮我抓个 xxx 的 trace」时，按以下流程执行：**

> ⚠️ **重要：** 不要启动交互式 shell（`bash hitrace-menu.sh`），因为 Agent 会话没有终端供开发者交互。
> Agent 必须在对话中直接呈现菜单，让开发者通过回复选择。

### 第一步：获取场景数据

```bash
bash ~/.agents/skills/hitrace-collect/hitrace-menu.sh --json
```

得到 28 个带 `index` / `category` / `name` / `tags` / `bufferKB` / `durationS` / `description` / `command` 的 JSON。

### 第二步：呈现分类菜单（一级）

按 `category` 分组，在对话中展示：

```
请选择 trace 场景分类：
  1  📱 应用性能 — 冷启动/页面/触控/动画/内存/IPC/综合/FFRT
  2  🖥️ 系统性能 — CPU/中断/磁盘/电源/内核/内存总线
  3  🌐 网络与通信 — 网络/蓝牙/分布式
  4  🎬 多媒体 — 音频/视频/图形渲染
  5  🔧 系统服务 — 通知/传感器/输入/安全/文件
  6  📸 快照模式 — 按需 dump
  7  📼 录制模式 — 长时间采集
```

### 第三步：展示场景子菜单（二级）

开发者选分类后，展示该分类下所有场景（含 index、描述、关键参数）：

```
📱 应用性能场景：
  1. 应用冷启动 | app ace ability ark graphic | 50MB/10s
  2. 页面跳转/导航 | app ace ability window | 50MB/10s
  ...
```

### 第四步：执行 trace（含设备操作提示）

开发者回复序号后，从 JSON 提取对应场景。根据场景类型分两种情况执行：

#### A. 需要开发者操作设备的场景（冷启动/页面/触控/动画等）

这些场景依赖开发者在 trace 窗口内主动操作设备。

**⚠️ 关键原则：trace 启动和操作提示必须在同一轮对话中发出！**

执行流程：

```
1. Agent 在同一轮回复中做三件事：
   a) 后台启动 hitrace（background=true 或短 yieldMs）
   b) 立即发送设备操作提示 🔔
   c) 告知等待时间
2. 等待 trace 完成（poll）
3. 拉取文件
```

**设备操作提示映射表：**

| 场景 | 操作提示 |
|------|---------|
| 应用冷启动 | ⚡ **请在设备上打开目标应用！**（从后台杀掉后冷启） |
| 页面跳转/导航 | ⚡ **请在设备上进行页面跳转操作！** |
| 触控响应 | ⚡ **请在设备上滑动/点击目标页面！** |
| 动画与渲染 | ⚡ **请在设备上触发动画/转场效果！** |
| IPC/Binder通信 | ⚡ **请在设备上触发跨进程调用！** |
| 内存分析 | ⚡ **请在设备上执行内存密集操作！** |
| FFRT任务调度 | ⚡ **请在设备上触发并发任务！** |
| 音频播放/录制 | ⚡ **请在设备上播放/录制音频！** |
| 视频/相机 | ⚡ **请在设备上打开相机或播放视频！** |
| 图形渲染管线 | ⚡ **请在设备上进行页面滑动或动画！** |
| 快照模式 | ⚡ **请复现问题，完成后通知我导出！** |
| 其余系统场景 | （无需操作设备，静默采集） |

**Agent 执行示例（冷启动）：**

```bash
# ❌ 错误做法：先 start trace，等 exec 返回后下一轮才发提示
#    → 开发者看到提示时 10s 窗口已过了大半

# ✅ 正确做法：同一轮对话中，background 启动 trace + 立刻发提示
# 1. 后台执行
hdc shell "hitrace -t 10 -b 51200 app ace ability ark graphic -o /data/local/tmp/cold.ftrace" &
# 2. 同一轮回复立即告诉开发者
#    → 「⚡ 现在请在设备上打开目标应用！⏳ 10 秒窗口」
# 3. 等待完成后 poll + recv

#### B. 纯系统场景（CPU/中断/磁盘/电源/内核等）

这些场景采集系统后台数据，无需开发者操作：

```
1. 直接执行 hitrace 命令
2. 等待完成
3. 拉取文件到 ~/Documents/
```

### 一步直达（开发者明确说了场景名）

如果开发者直接说出场景名（如"抓个冷启动 trace"），直接从 JSON 中匹配 `name` 字段，跳过菜单直接执行。

**仍需按第四步规则发送设备操作提示**（如冷启动→「⚡ 请在设备上打开目标应用！」）。

---

## 命令参考（完整参数列表）

以下为设备端 `hitrace -h` 输出的完整参数表：

| 参数 | 别名 | 参数值说明 | 默认值 | 适用模式 |
|------|------|-----------|--------|---------|
| `-b N` | `--buffer_size N` | 缓冲区大小，单位 KB，最小 512 | 18432 (18MB) | 定时 / 快照 |
| `-t N` | `--time N` | 采集时长，单位秒 | 5s | 定时 |
| `-l` | `--list_categories` | 列出设备支持的 tag 列表 | — | 辅助 |
| `-o filename` | `--output filename` | 输出文件路径（文本模式仅 `/data/local/tmp/`） | stdout | 定时 / 快照 |
| `-z` | — | 输出时自动压缩（gzip） | 不压缩 | 定时 |
| `--text` | — | 指定输出为文本格式（默认） | 文本 | 定时 / 快照 |
| `--raw` | — | 指定输出为二进制格式（`.sys`，供 SmartPerf） | 文本 | 定时 / 快照 |
| `--trace_begin` | — | 开始采集（快照模式或录制模式） | — | 快照 / 录制 |
| `--trace_dump` | — | 导出缓冲区内容（不停止采集） | stdout | 快照 |
| `--trace_finish` | — | 停止采集并导出 | stdout | 快照 / 录制 |
| `--trace_finish_nodump` | — | 停止采集，不导出 | — | 快照 / 录制 |
| `--record` | — | 与 `--trace_begin` / `--trace_finish` 配合启用录制模式 | 关闭 | 录制 |
| `--overwrite` | — | 缓冲区满时丢弃**最新**数据（否则丢弃最旧数据） | 丢弃最旧 | 定时 / 快照 / 录制 |
| `--trace_clock clock` | — | 时间戳时钟源：`boot` / `global` / `mono` / `uptime` / `perf` | boot | 定时 |
| `--start_bgsrv` | — | 启动 trace_service 快照守护 | — | 快照(bgsrv) |
| `--dump_bgsrv` | — | 触发 trace_service 导出快照 | `/data/log/hitrace/` | 快照(bgsrv) |
| `--stop_bgsrv` | — | 停止 trace_service 快照守护 | — | 快照(bgsrv) |
| `--file_size N` | — | 单个文件大小上限，单位 KB | 102400 (100MB) | 录制（raw） |
| `--trace_level level` | — | 设置 trace 级别阈值（持久化参数） | 见下方 | 配置 |
| `--get_level` | — | 查询当前 trace 级别阈值 | — | 配置 |
| Tag 列表 | — | 末尾空格分隔的 tag 名，如 `app sched freq` | 见默认 tag | 所有模式 |

### trace_level 级别与过滤规则

| 命令行参数 | 实际值 | 含义 | 采集范围 |
|-----------|--------|------|---------|
| `D` / `Debug` | Debug | 采集所有级别 | I + C + M |
| `I` / `Info` | Info | 采集 Info 及以上 **（设备默认）** | C + M |
| `C` / `Critical` | Critical | 只采集 Critical 及以上 | M |
| `M` / `Commercial` | Commercial | 只采集 Commercial (nolog 版本) | M |

**⚠️ 重要：** `--trace_level` 设置后写入系统持久化参数 `persist.hitrace.level.threshold`，重启不失效。调完后记得恢复默认值。

**当前设备级别查询：**
```bash
hitrace --get_level
# 输出示例: 2026/06/17 09:59:34 the current trace level threshold is Info
```

### --overwrite 缓冲区满策略

| 选项 | 行为 | 翻译 | 适用场景 |
|------|------|------|---------|
| 不使用 `--overwrite`（默认） | 缓冲区满时丢弃**最早**数据，保留最新数据 | 保留最新 | ⭐ 日常使用，关注最近事件 |
| 使用 `--overwrite` | 缓冲区满时丢弃**最新**数据，保留最早数据 | 保留最早 | 捕获偶发异常，希望保留缓冲区中最早的关键事件 |

> **一个直觉理解：** 默认行为就像 CCTV 循环录像——旧画面被覆盖，你看到的总是最新的。`--overwrite` 则像一个冰冻的存档，满了就不再录新的。

### --trace_clock 时间戳时钟源

| 时钟源 | 说明 | 特点 |
|--------|------|------|
| `boot`（默认） | 系统启动以来的时间，含休眠 | 与其他工具对齐，适合跨进程分析 |
| `global` | 全局单调时钟 | 多 CPU 间精确同步 |
| `mono` | 单调递增时钟，不含休眠 | 精度高，同步 `realtime_ts` |
| `uptime` | 系统运行时间 | 不含休眠，直观易懂 |
| `perf` | perf 事件时钟（TSC） | 最高精度，但可能采样不均匀 |

`mono` 模式会额外输出 `trace_event_clock_sync` 事件，包含 `realtime_ts`（Unix 毫秒时间戳），可用于将 trace 时间对齐到真实时间。

---

## 采集模式详解

hitrace 提供三大采集模式，按场景选择：

| 模式 | 适用场景 | 采集时长 | 输出格式 | 特点 |
|------|----------|---------|---------|------|
| **定时采集** | 定位已知问题、短期调优 | 固定时间（秒级） | `.ftrace` 文本 / `.sys` 二进制 | 最常用，简单直接 |
| **快照模式** | 问题偶发、按需触发 | 不限制 | `.ftrace` 文本 / `.sys` 二进制 | 缓冲区持续写入，按需导出 |
| **录制模式** | 长时间跑测、无人值守 | 长时间（分钟/小时级） | `.sys` 二进制（多文件） | 文件自动分片滚动 |

---

### 一、定时采集（Timed Mode） — 最常用

#### 命令结构

```bash
hitrace -t <时长秒> -b <缓冲区KB> [--overwrite] [-z] [--text|--raw] [--trace_clock <clock>] -o <路径> <tag1 tag2 ...>
```

#### 基础用法

**文本格式（默认）：**
```bash
# 10秒，200MB缓冲区，采集 app 和 ace tag
hitrace -t 10 -b 204800 app ace -o /data/local/tmp/test.ftrace
```

**二进制格式（SmartPerf 可视化）：**
```bash
# 10秒，200MB缓冲区，二进制输出 → 自动保存到 /data/log/hitrace/
hitrace -t 10 -b 204800 app --raw
# 输出示例: /data/log/hitrace/record_trace_20260617095957@978313-363971658.sys
```

**带压缩输出：**
```bash
hitrace -z -b 102400 -t 10 sched freq app -o /data/local/tmp/test.ftrace.gz
```

**指定时钟源：**
```bash
# 使用单调时钟 + 同步 realtime_ts
hitrace -t 10 -b 204800 --trace_clock mono app -o /data/local/tmp/test.ftrace
```

#### 典型场景命令模板

| 场景 | 推荐 tag 组合 | 缓冲区 | 时长 | 说明 |
|------|-------------|--------|------|------|
| 应用冷启动 | `app ace ability ark graphic` | 51200 | 10s | 覆盖应用生命周期 + UI 帧率 |
| 页面滑动流畅性 | `app ace graphic window sched` | 102400 | 10s | 帧率 + 调度 + 渲染 |
| 触控响应 | `app ace graphic multimodalinput sched` | 102400 | 10s | 触控事件 + UI + 渲染 |
| 应用初始化/跳转 | `app ace ability window` | 51200 | 10s | 能力管理 + 窗口 + UI |
| CPU/调度分析 | `sched freq idle load` | 51200 | 10s | 纯内核调度 |
| 帧率渲染（RS 层） | `graphic ace app` | 204800 | 10s | RS 渲染管线 |
| 网络请求 | `app net` | 51200 | 10s | 网络模块打点 |
| 内存分析 | `memory memreclaim pagecache` | 102400 | 10s | 内存 + 回收 |
| IPC/Binder 通信 | `binder zbinder app` | 51200 | 10s | binder 延迟分析 |
| 综合性能分析 | `app ace graphic window sched freq disk` | 204800 | 10s | 最全面的日常场景 |
| 分布式场景 | `dsoftbus dsched dscreen daudio` | 102400 | 15s | 分布式协同 |
| 媒体播放/录制 | `zaudio zmedia zcamera zimage` | 102400 | 15s | 多媒体链路 |
| 动画调试 | `ace animation graphic window` | 51200 | 10s | 动画帧密集期 |

---

### 二、快照模式（Snapshot Mode）

trace 数据持续写入内核缓冲区，按需随时导出。缓冲区满时依据 `--overwrite` 策略决定丢弃策略。

#### 模式 A：使用 `--trace_begin/--trace_dump/--trace_finish`

```bash
# 1️⃣ 开启采集（持续写入缓冲区，不设结束时间）
hitrace --trace_begin -b 204800 app ace graphic

# 2️⃣ 😰 问题重现后，导出当前缓冲区内容（不停止采集）
hitrace --trace_dump -o /data/local/tmp/snapshot1.ftrace

# 3️⃣ 💡 如果相关问题再次出现，再次导出
hitrace --trace_dump -o /data/local/tmp/snapshot2.ftrace

# 4️⃣ 🛑 停止采集并导出最终数据
hitrace --trace_finish -o /data/local/tmp/final.ftrace

# 或者直接停止，不导出（不会丢失之前导出的数据）
hitrace --trace_finish_nodump
```

#### 模式 B：使用 `--start_bgsrv/--dump_bgsrv/--stop_bgsrv`

后台服务模式，使用**内置默认 tag 列表**，持续写入二进制格式。

```bash
# 运行时状态名: SNAPSHOT_START / SNAPSHOT_DUMP / SNAPSHOT_STOP

# 1️⃣ 启动 trace_service（无 tag 参数 → 使用默认 tag 列表）
hitrace --start_bgsrv

# 2️⃣ 导出快照（多次导出 → 生成多个 .sys 文件）
hitrace --dump_bgsrv
# 输出: /data/log/hitrace/trace_20260617100026@978342-3619.sys

# 3️⃣ 停止服务
hitrace --stop_bgsrv
```

**⚠️ bgsrv 模式要点：**
- **不支持自定义 tag** — 使用系统的默认 tag 列表（见下文）
- **不支持 `-o` 指定路径** — 所有输出到 `/data/log/hitrace/`
- **每次 dump 累积** — 多次 dump 生成多个带时间戳的 `.sys` 文件
- **格式固定为二进制** — 只能通过 SmartPerf 分析

**bgsrv 模式默认 tag 列表：**
```
net, dsched, graphic, multimodalinput, dinput, ark, ace, window,
zaudio, daudio, zmedia, dcamera, zcamera, dhfwk, app, gresource,
ability, power, samgr, ffrt, nweb, hdf, virse, workq, ipa, sched,
freq, disk, sync, binder, mmc, membus, load
```
（共 34 个 tag，覆盖大部分常用场景）

---

### 三、录制模式（Recording Mode）

长时间持续采集，缓冲区满时自动写入新文件。**只支持二进制格式。**

```bash
# 启动录制（--record 与 --trace_begin 结合）
hitrace --trace_begin --record -b 204800 --file_size 102400 app graphic

# 长时间运行...

# 停止录制
hitrace --trace_finish --record
```
停止后输出所有生成的文件路径列表。

**参数说明：**
- `--file_size N`：单个文件大小上限，单位 KB，默认 102400KB（100MB）
- `-b N`：缓冲区大小，单位 KB
- `-o path`（API 24+）：输出目录，如 `-o /data/local/tmp`
- `--total_size N`（API 24+）：总文件大小上限，单位 KB，默认 2048×1024KB（2GB）

**注意事项：**
- 录制模式文件生成在 `/data/log/hitrace/`，命名格式：`record_trace_年月日时分秒@boottime.sys`
- API 24 以下不支持 `-o` 指定路径
- `--file_size` **仅在 raw 模式下有效**（录制模式本身就是 raw）

---

### 三种模式对比速查

| 方面 | 定时采集 | 快照模式 | 录制模式 |
|------|---------|---------|---------|
| 入口命令 | `hitrace -t N ...` | `hitrace --trace_begin ...` | `hitrace --trace_begin --record ...` |
| 关闭命令 | 自动结束 | `--trace_finish` | `--trace_finish --record` |
| 采集时长 | 固定秒数 | 手动控制 | 手动控制 |
| 缓冲区策略 | 固定窗口 | 循环缓冲 | auto 分片落盘 |
| 文本格式 | ✅ 默认 | ✅ `-o` 指定 | ❌ 只支持二进制 |
| 二进制格式 | ✅ `--raw` | ✅ `--dump_bgsrv` | ✅ 唯一格式 |
| 自定义 tag | ✅ | ✅（`--trace_begin` 模式，bgsrv 不支持） | ✅ |
| 单次 vs 多次 | 一次执行一文件 | 多次 dump 多次导出 | 自动分片多文件 |
| 适用场景 | 短时定位问题 | 问题偶发、等待重现 | 长期跑测、无人值守 |

---

## 产品说明

### 输出格式

| 格式 | 后缀 | 输出方式 | 查看方式 |
|------|------|---------|---------|
| **文本格式** | `.ftrace` | stdout 或 `-o /data/local/tmp/` | 文本编辑器直接查看 |
| **二进制格式** | `.sys` | 默认 `/data/log/hitrace/` | SmartPerf Host GUI 可视化分析 |

### 文件名规则

- **定时模式 + 文本**：`-o` 指定名称
- **定时模式 + 二进制**：`record_trace_年月日时分秒@boottime.sys`
- **快照模式（bgsrv）**：`trace_年月日时分秒@boottime.sys`
- **录制模式**：`record_trace_年月日时分秒@boottime.sys`

### 分析工具

- **SmartPerf Host**（推荐）：可视化 GUI 泳道图分析工具
  - 开源地址：[developtools_smartperf_host](https://gitcode.com/openharmony/developtools_smartperf_host)
  - 发布版下载：[GitCode Releases](https://gitcode.com/openharmony/developtools_smartperf_host/releases)
  - 支持功能：CPU 调度泳道、频点、线程时间片、内存、帧率、Binder 事务等
- **SmartPerf Device**：设备端悬浮窗 + 命令行实时监控

---

## 从设备拉取 trace 到本地

```bash
# 文本格式（/data/local/tmp/）
hdc file recv /data/local/tmp/test.ftrace ~/Desktop/

# 二进制格式（/data/log/hitrace/）
hdc file recv /data/log/hitrace/trace_20260617100026@978342-3619.sys ~/Desktop/
```

---

## 产线/日常使用建议

### Tag 选择指南

- **只看自己的代码打点** → 只采集 `app`（HiTraceMeter API 打点）
- **看帧率和 UI 性能** → `app ace graphic window`
- **综合应用性能分析** → `app ace graphic window sched freq disk`
- **触控交互优化** → `app ace graphic multimodalinput sched`
- **启动耗时优化** → `app ace ability ark graphic window`
- **内存分析** → `memory memreclaim pagecache app`
- **IPC/binder 优化** → `binder zbinder app`
- **全面的系统级分析** → 使用快照模式 bgsrv（默认 34 个 tag）

### 缓冲区大小建议

| 场景 | 推荐 `-b` 值 | 说明 |
|------|-------------|------|
| 轻量级（仅 app tag） | 8192 (8MB) | 只关心自己代码打点 |
| 中等负载 | 51200 (50MB) | app + ace + graphic |
| 综合场景 | 102400 (100MB) | 常用 tag 组合 |
| 全面分析 | 204800 (200MB) | 大量内核 tag |
| 生产环境 | ≤ 102400 (100MB) | 占用设备内存，不设置过大 |

### 生产环境注意事项

1. **`--trace_level` 是持久化参数**（`persist.hitrace.level.threshold`），设置后需主动恢复默认值
2. **大缓冲区占用设备内存** — 生产环境控制在 102400KB 以内
3. **tag 选择越精简，数据量越小** — 按需采集，不要全量
4. **调试打点完成后**，请用 `hitracemeter-trace` skill 清理代码中的 HiTraceMeter 调用
5. **快照模式不使用 tag 参数** — bgsrv 强制使用默认 tag 列表

---

## 常见错误排查

| 错误现象 | 原因 | 解决方法 |
|---------|------|---------|
| 错误码 `1` | hiview 进程异常 | 重启手机后重试 |
| `not support category on this device` | tag 名拼写错误或设备不支持 | 先用 `hitrace -l` 查询支持列表 |
| 错误码 `1004` | 路径不存在 / 无权限 / 磁盘满 | 确保路径在 `/data/local/tmp/`，释放空间 >500MB |
| `illegal path` | 路径非 `/data/local/tmp/` 开头 | 文本格式只支持 `/data/local/tmp/` |
| `Permission denied` | 访问 `/data/log/hitrace/` 需更高权限 | 二进制格式自动写入该路径 |
| `output failed` | 输出文件已存在且无写入权限 | 先 `rm` 同名文件再采集 |
| 文本 trace 内容为空 | `trace_level` 过滤掉了低级别打点 | 检查 `--get_level`，改为 `--trace_level Debug` |
| bgsrv 停止失败 | 服务不在运行状态 | 忽略，或检查是否之前已停止 |

---

## 关联技能

- **[hitracemeter-trace](skill:../hitracemeter-trace)**：在 ArkTS 代码中插入 HiTraceMeter 打点（`startSyncTrace` / `finishSyncTrace` 等）
- **[hitrace-menu.sh](hitrace-menu.sh)**：交互式场景选择器 CLI 工具（多级菜单 + 一键执行）
- **参考资料**：[tag-descriptions.md](references/tag-descriptions.md)

---

## 交互式 CLI：hitrace-menu.sh

CLI 工具提供两种使用方式：

| 使用场景 | 方式 | 说明 |
|---------|------|------|
| 🖥️ **开发者直接终端** | `bash hitrace-menu.sh` | 交互式 TUI，多级菜单选择，一键执行 |
| 🤖 **Agent 会话中** | `bash hitrace-menu.sh --json` | 获取结构化场景数据，Agent 在对话中呈现菜单 |
| 📋 **查看所有场景** | `bash hitrace-menu.sh --list` | 纯文本列出 28 个场景及命令 |

CLI 工具路径：`~/.agents/skills/hitrace-collect/hitrace-menu.sh`

---

## 参考链接

- [Hitrace 官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hitrace)
- [HiTraceMeter 打点 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hitracemeter-intro)
- [SmartPerf Host 工具](https://gitcode.com/openharmony/developtools_smartperf_host)
- 本 skill 关联 skill：[hitracemeter-trace](skill:../hitracemeter-trace)
- 迭代记录：[CHANGELOG.md](CHANGELOG.md)
