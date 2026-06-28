---
name: hitracemeter-trace
description: "HiTraceMeter performance trace instrumentation tools for ArkTS dynamic syntax. Use when users want to insert, manage, or remove @ohos.hiTraceMeter trace points (@kit.PerformanceAnalysisKit) in HarmonyOS ArkTS code for performance debugging. Scenarios include: wrapping code blocks with startSyncTrace/finishSyncTrace, inserting startAsyncTrace/finishAsyncTrace for async operations, inserting traceByValue for integer tracking, batch removing all trace instrumentation, and validating trace start/finish pairing and level consistency."
---

# HiTraceMeter Trace 打点工具

用于在 ArkTS 动态语法代码中快速插桩和清理 HiTraceMeter 性能打点。

## API 速查

```typescript
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';

const L = hiTraceMeter.HiTraceOutputLevel.COMMERCIAL;
// 等级常量：COMMERCIAL | INFO | PROFESSIONAL | VERBOSE

// 同步打点 — 包裹顺序执行的代码块
hiTraceMeter.startSyncTrace(L, 'traceName', 'key=value');
// ... 要追踪的代码 ...
hiTraceMeter.finishSyncTrace(L);

// 异步打点 — 异步操作
hiTraceMeter.startAsyncTrace(L, 'asyncName', taskId, 'category', 'key=value');
// ... 异步操作 ...
hiTraceMeter.finishAsyncTrace(L, 'asyncName', taskId);

// 整数值跟踪
hiTraceMeter.traceByValue(L, 'counterName', value);
```

**输出级别说明：**
- `COMMERCIAL`（默认）— 商业发布版本也输出的 trace
- `INFO` — 一般调试信息
- `PROFESSIONAL` — 专业调试
- `VERBOSE` — 最详细的跟踪

**约束：**
- start/finish 必须成对使用，否则 trace 文件在 SmartPerf 等工具中显示异常
- 异步多个并行任务用不同的 taskId 区分，串行可复用
- 参数字段总长度建议不超过 420 字符，超过 512 会被截断
- 参数中避免使用 `|` 字符（trace 格式分隔符）

## Trace 点选择原则

当使用者给出代码片段、文件或接口入口时，由你（AI）自主判断在何处插桩。以下原则指导选点决策。

### 核心判断逻辑

```
拿到代码 → 识别用户关注入口 → 沿调用链展开关键路径
                                        ↓
                         在各阶段边界处选点 → 判断同步/异步
                                        ↓
                              traceByValue 补充状态变化
```

### 一、必须打点的高优先位置

| 类别 | 具体位置 | 用同步还是异步 | 备注 |
|------|----------|----------------|------|
| **用户交互入口** | `onClick`、`onTouch`、`onScroll` 等事件回调 | 同步 | 包裹回调内的全部逻辑 |
| **组件生命周期** | `aboutToAppear`、`onPageShow`、`onBackPress` | 同步 | 页面首次渲染性能 |
| **动画执行** | `animateTo` 回调、自定义动画函数 | 同步 | 区分"动画触发"和"动画执行" |
| **异步/网络请求** | HTTP 请求前后、Promise.then/catch、定时器回调 | **异步** | network 请求前后分别 start/finish |
| **复杂计算** | 循环、排序、数据转换、JSON 序列化/反序列化 | 同步 | 包裹整个计算块 |
| **状态变量变化** | 关键的 @State/@Link 变量赋值处 | `traceByValue` | 跟踪变化趋势 |
| **文件/数据库 IO** | 读写操作前后 | 异步（回调类的用同步） | 按实际回调形式选择 |

### 二、不打的低价值位置

| 不打的 | 理由 |
|--------|------|
| `build()` 整体 | 框架按需驱动调用，人工打点引入噪声 |
| 声明式 UI 绑定 `.translate()`、`.width()` 等 | 无执行时长意义 |
| 系统 API 调用内部（如 `promptAction.showToast`） | 无法干预，打了无意义 |
| 简单的 getter/setter / 常量声明 | 耗时可忽略 |
| import / 模块加载 | 不在性能调优范围内 |
| 单行日志打印（`hilog.info` 等） | 粒度太细，打点开销可能反超代码本身 |

### 三、粒度控制

**一条经验法则：每个文件 3-5 对 start/finish 为宜。** 超过此数量：
- 在 SmartPerf 中 trace 线过于密集，难以阅读
- 打点本身也有性能开销（上下文切换 + 内核写缓冲区）

**何时可以例外（适当增加）：**
- 用户明确要求"详细分析"或"每一帧都要看到"
- 关键路径包含多个明显可分的阶段（如上文 animateTo 内外分离）

### 四、同步 vs 异步的决策标准

```
事件的执行流程是顺序的还是分段触发的？
  ├─ 顺序执行（函数调用链）→ 同步 trace
  └─ 分段触发（setTimeout/Promise/Worker/回调等）
       └─ 异步 trace，注意 taskId 区分并行实例
```

**特别注意：** 不要因为函数内有异步操作，就把整个外层也改用异步 trace。外层仍然用同步 trace 包裹，异步操作用独立的异步 trace 包裹。

### 五、命名规范

**格式：** `{组件/文件缩写}{动词}{名词}`，全部驼峰

| 位置 | 示例 | 说明 |
|------|------|------|
| 交互事件 | `addressExchangeClick` | 组件名 + 动作 |
| 网络请求 | `fetchUserData` | API 名 |
| 动画回调 | `exchangeIconRotateAnimate` | 功能 + 阶段 |
| 生命周期 | `pageAboutToAppear` | 生命周期名 |
| 异步操作 | `loadImage` | 以操作命名 |
| 值跟踪 | `listItemCount` | 变量名 |

**避免：** 简单用 `trace1`、`trace2` 这样无意义的命名。

### 六、上下文感知

- **循环/列表中的多次调用：** 只对第一次调用或总时间打点，避免 trace 数据爆炸。如需每项分别打点，建议用不同的 traceName 区分。
- **跨文件同名：** 如果 A.ets 和 B.ets 中有同名 trace（如 `onClick`），建议加上文件前缀：`pageAOnClick`、`pageBOnClick`，便于 SmartPerf 按 name 过滤分析。
- **嵌套打点：** 允许嵌套（如外层 onClick 和内层 animateTo 各一对），但不宜超过 2 层，否则 trace 图上的"开始"和"结束"线会难以跟踪。

## 使用流程

### 1. 插入同步打点

用户请求"帮这段代码加上 trace"时：

1. 确认 import 已存在（没有则添加）
2. 在代码块前加 `startSyncTrace(level, name, customArgs?)`
3. 在代码块后加 `finishSyncTrace(level)`
4. 默认用 `COMMERCIAL` 级别，traceName 保持简短、描述性强、文件内唯一
5. `customArgs` 格式：`"key1=value1,key2=value2"`（可选）

### 2. 插入异步打点

用户请求"给这个异步操作加 trace"时：

1. 确认 import 已存在
2. 异步操作前加 `startAsyncTrace(level, name, taskId, category, customArgs?)`
3. 异步完成后加 `finishAsyncTrace(level, name, taskId)`
4. 注意 taskId 的串行/并行规则
5. `customCategory` 用于聚类同类异步打点，不需要可传空字符串 `''`

### 3. 插入整数值跟踪

追踪变量变化：

1. 在变量变化处插入 `traceByValue(level, name, count)`
2. name 建议用有意义的变量名
3. 可在 SmartPerf 泳道图中观测变化趋势

### 4. 批量清理所有打点

调试完成后，用脚本一键清理：

```bash
# 单文件
python3 scripts/remove_traces.py Page.ets

# 整个项目（递归）
python3 scripts/remove_traces.py --dir entry/src/main/ets

# 预览（不实际修改）
python3 scripts/remove_traces.py --dir entry/src/main/ets --dry-run -v
```

清理内容包括：
- 所有 `hiTraceMeter.startSyncTrace/finishSyncTrace/startAsyncTrace/finishAsyncTrace/traceByValue` 调用
- `if (hiTraceMeter.isTraceEnabled()) { ... }` 块
- 自动删除 `import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'`（如果不再使用）
- 自动清理多余空行

### 5. 验证打点配对

检查 start/finish 是否成对、参数是否一致：

```bash
# 单文件
python3 scripts/validate_traces.py Page.ets

# 整个项目
python3 scripts/validate_traces.py --dir entry/src/main/ets
```

检查内容：
- ✅ 同步打点 start/finish 配对
- ✅ 异步打点 (name, taskId) 配对
- ✅ start/finish 的 level 一致性
- ❌ 多余/缺失的 finish
- ❌ 未闭合的 start

## 设计原则

- 所有打点默认使用 `COMMERCIAL` 级别，除非用户指定其他级别
- trace name 用驼峰命名
- 统一用 `const L = hiTraceMeter.HiTraceOutputLevel.COMMERCIAL;` 缩写变量，不要到处写全名
- 清理脚本建议在提交代码前运行，确保不把调试打点带上正式版本
