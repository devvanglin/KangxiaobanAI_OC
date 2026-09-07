# Hermes Agent 架构解析

> 分析对象：`D:\Coding\KangxiaobanAI_OC\hermes-agent`（Nous Research 开源，v0.21.0，HEAD `485aaf69`，2026-09-03）
> 依据：仓库源码 + `AGENTS.md`（根 / `agent/` / `skills/`）+ `website/docs/developer-guide/` 官方开发者文档
> 用途：为康小伴 AI 的「MCP 管理 / Skills 管理」模块与自研 Agent 能力提供架构参考

---

## 1. 定位

Hermes 是一个**个人 AI 代理运行时**：同一套 agent 核心跑在 CLI、TUI、Electron 桌面、消息网关（约 20 个平台）、ACP（VS Code/Zed）五种入口上。它的差异点是**闭环学习**——从经验里长出技能、技能在使用中自我改进、跨会话记忆与检索。

两个贯穿全局的设计不变量（任何改动都拿这两条来审）：

1. **每会话 prompt 缓存不可破。** 长会话每轮复用缓存前缀；任何中途改系统提示、换工具集、重载记忆，都会作废前缀并成倍放大成本。唯一例外是上下文压缩。
2. **核心是窄腰，能力在边缘。** 每个模型工具都要随每次 API 调用发出去，因此新增能力的优先级是：扩展现有代码 → CLI 命令 + 技能 → service-gated 工具 → 插件 → MCP 服务器 → 核心工具（最后手段）。

---

## 2. 分层总览

```text
入口层   CLI(hermes) · TUI(Ink) · Desktop(Electron) · Gateway(20 平台) · ACP · Batch
            │
核心层   AIAgent (run_agent.py facade + mixins)
         ├─ Prompt Builder     系统提示分层装配（byte-stable）
         ├─ Provider Resolution 40 家 provider + 3 种 API 模式 + fallback
         ├─ Turn Loop          conversation_loop.py + turn_*.py 阶段化
         ├─ Compression        双层阈值 + 四阶段算法
         └─ Tool Dispatch      model_tools.py + tools/registry.py
            │
能力层   Tools(70+, 28 toolsets) · Skills(60 内置 + 137 可选) · MCP(65 目录) · Plugins
            │
底座     终端后端 6 种 · 浏览器后端 5 种 · Web 后端 4 种 · SQLite+FTS5 会话库 · Cron
```

---

## 3. Agent 核心的组合方式

`run_agent.py` 是**门面（facade）**，`AIAgent` 由多个 mixin 拼装而成：

| 组成 | 位置 | 职责 |
|---|---|---|
| 构造装配 | `agent/agent_init.py::init_agent` | 约 60 个入参（凭证、路由、回调、会话、预算、凭证池…） |
| 循环主体 | `agent/conversation_loop.py::run_conversation` | 同步循环，带中断检查、预算跟踪、一次宽限调用 |
| 轮次阶段 | `agent/turn_*.py`（20+ 个文件） | 一个阶段一个文件：preflight / iteration_prep / request_assembly / api_call / api_error / response_intake / empty_response / tool_round / overflow / truncation / context_compaction / recovery / retry_state / stop_gates / liveness / usage / final_response / finalizer / summary |
| 会话租约 | `agent/turn_facade_lease.py` | `AIAgent.run_conversation` 先取租约再转发 |

**接口两个**：`chat(message) -> str`（简易）与 `run_conversation(...) -> dict`（返回 `final_response` + `messages` + 用量）。

设计意图：改「溢出处理」只碰 `turn_overflow.py` 一个约 600 行的文件，不碰主循环。找阶段用 `grep -rn "def X" agent/turn_*.py`。

---

## 4. Turn 生命周期

```text
run_conversation()
 1. 没有 task_id 就生成
 2. 追加 user 消息到历史
 3. 构建或复用已缓存的系统提示（prompt_builder）
 4. 检查是否需要 preflight 压缩（> 50% 上下文）
 5. 按 API 模式把历史转成请求消息
 6. 注入临时提示层（预算告警、上下文压力）
 7. Anthropic 上打缓存标记
 8. 可中断的 API 调用（_interruptible_api_call）
 9. 解析响应：
     有 tool_calls → 执行工具 → 追加结果 → 回到第 5 步
     纯文本       → 持久化会话 → 按需 flush 记忆 → 返回
```

主循环骨架：

```python
while (api_call_count < max_iterations and budget.remaining > 0) or budget_grace_call:
    if interrupt_requested: break
    response = client.chat.completions.create(model=model, messages=messages, tools=tool_schemas)
    if response.tool_calls:
        for tc in response.tool_calls:
            messages.append(tool_result_message(handle_function_call(tc.name, tc.args, task_id)))
        api_call_count += 1
    else:
        return response.content
```

**可中断调用**：HTTP 请求跑在后台线程，主线程同时等「响应就绪 / 中断事件 / 超时」三件事。被中断时丢弃响应，绝不把半截内容写进历史。

---

## 5. 三种 API 模式

| 模式 | 适用 | 客户端 |
|---|---|---|
| `chat_completions` | OpenAI 兼容端点（OpenRouter、自建…） | `openai.OpenAI` |
| `codex_responses` | OpenAI Codex / Responses API | `openai.OpenAI` + Responses 格式 |
| `anthropic_messages` | 原生 Anthropic Messages API | `anthropic.Anthropic` + adapter |

解析顺序：显式 `api_mode` 入参 → provider 推断 → base URL 启发式 → 默认 `chat_completions`。三种模式在 API 调用前后都收敛到同一套内部 OpenAI 风格消息字典 `{"role","content","tool_calls"}`，推理内容存 `assistant_msg["reasoning"]`。

---

## 6. 消息流不变量（改动必查）

- **系统提示在会话生命周期内字节稳定。** 唯一允许的上下文改写是压缩。必须中途注入的内容走 **user 消息或 tool result**，绝不进系统提示——技能斜杠命令注入为 user 消息；子目录 `AGENTS.md` 提示追加到 tool result（超过 32,000 字符截头去尾并告警）。
- **严格角色交替。** 不允许连续两条同角色消息，不允许循环中插入合成 user 消息（Cron 投递因此单独开会话）。工具结果例外：可连续多条 `tool`。
- **上下文文件只在启动时从 CWD 加载**，有字符上限；绝不把安装目录里的 `AGENTS.md` 当项目上下文，也拒绝工作目录外的路径（防止 `~/.claude/CLAUDE.md` 混入）。
- `_last_resolved_tool_names` 是 `model_tools.py` 里的**进程级全局**；子代理执行期间由 `delegate_tool._run_single_child()` 保存/恢复，读取方可能看到暂时过期的值。

---

## 7. 系统提示的分层装配

三层有序结构，最终拼接为 **stable → context → volatile**：

| 层 | 内容 | 归属 |
|---|---|---|
| 1 | 身份（`SOUL.md` 或内置兜底） | stable |
| 2 | 工具/模型行为指引（含 GPT/Codex 的强制用工具条款） | stable |
| 3 | Honcho 静态块（启用时） | stable |
| 4 | 可选 system message（配置或 API 传入） | context |
| 5 | `MEMORY.md` 冻结快照 | volatile |
| 6 | `USER.md` 用户画像冻结快照 | volatile |
| 7 | 技能索引（`## Skills (mandatory)` + `<available_skills>`） | stable |
| 8 | 项目上下文文件（`.hermes.md` / `AGENTS.md` / `CLAUDE.md` / `.cursorrules`） | context |
| 9 | 时间戳 + 会话 ID | volatile |
| 10 | 平台提示（CLI 不开 Markdown、Telegram 短消息…） | stable |

要点：技能在 **stable** 层，记忆与画像在 **volatile** 层，但**两者都在缓存的系统提示内**，不是中途叠加的临时层。子代理委派时若设 `skip_context_files`，则不加载 `SOUL.md`，改用硬编码的 `DEFAULT_AGENT_IDENTITY`。

平台提示可由 `config.yaml` 的 `platform_hints` 按平台 append/replace，配置固定则输出字节稳定，因此不破坏缓存。

---

## 8. 压缩与缓存

### 双层阈值

| 层 | 触发 | 位置 |
|---|---|---|
| 网关会话卫生 | 上下文 > 85%，轮次间执行 | gateway |
| Agent ContextCompressor | 上下文 > 50%（可按模型覆盖） | agent，`compression_facade.py` |

提供方可证实的溢出会触发失败冷却。阈值令牌 = `threshold × 主模型上下文长度`，与摘要模型窗口无关。

### 四阶段算法

1. **剪旧工具结果**（不调 LLM）：受保护尾部之外、超过 200 字符的旧工具输出替换为 `[Old tool output cleared to save context space]`。
2. **定边界**：头部 `protect_first_n`；中间待摘要；尾部按**令牌预算**从后往前走（不足时退回 `protect_last_n`，默认 20）。边界对齐到不拆散 `tool_call/tool_result` 组。
3. **生成结构化摘要**：用 auxiliary 模型，模板固定为 Goal / Constraints & Preferences / Progress(Done·In Progress·Blocked) / Key Decisions / Relevant Files / Next Steps / Critical Context。摘要预算 = `content_tokens × 0.20`，下限 2,000，上限 `min(ctx×0.05, 12,000)`。
   ⚠️ 摘要模型上下文窗口必须 ≥ 主模型，否则生成失败会**静默丢掉中段**——这是压缩质量劣化的头号原因。
4. **重组消息**：头消息 + 摘要消息（角色选择避开连续同角色）+ 尾部原样；`_sanitize_tool_pairs()` 清理孤儿调用/结果。

**迭代重压缩**：后续压缩把上一版摘要交给模型**增量更新**，而不是从头总结，信息跨多次压缩延续。

**Anthropic 缓存策略** `system_and_3`：系统提示 + 前 3 条消息打缓存标记，支持 5 分钟 / 1 小时 TTL；缓存写入与命中都计入指标。

---

## 9. 工具层

- **注册式发现**：`tools/registry.py`（零依赖）→ 各 `tools/*.py` 在 import 时注册 → `model_tools.py` 负责发现与 schema 收集 → `handle_function_call()` 分发。依赖链单向，不会成环。
- **工具集（toolsets.py）**：`TOOLSETS` 字典 + `_HERMES_CORE_TOOLS`；28 个工具集、70+ 工具。能力门控靠工具集，而非环境变量。
- **执行**：单工具走主线程；多工具走 `ThreadPoolExecutor` 并发，但结果按**原始调用顺序**回填；交互式工具（如 `clarify`）强制串行。
- **单工具流程**：解析 handler → `pre_tool_call` 钩子 → 危险命令审批（`tools/approval.py`，走 `approval_callback` 等人）→ 执行 → `post_tool_call` 钩子 → 追加 `{"role":"tool"}`。
- **Agent 级工具拦截**：`todo` / `memory` / `session_search` / `delegate_task` 在到达 registry 之前被 `agent/tool_executor.py` 拦下（`INLINE_TOOL_EXECUTORS` 表驱动，禁止 `if name == ...` 链），直接改 agent 状态并返回合成结果。
- **后端**：终端 6 种（local / docker / ssh / modal / daytona / singularity）、浏览器 5 种、Web 4 种、MCP 动态、文件与视觉等。
- **MCP**：`tools/mcp_tool*.py` 共 22 个文件，覆盖发现、OAuth、健康检查、生命周期、采样、传输、服务端；另有 65 个可选 MCP 服务器目录。

---

## 10. 子代理、预算与容错

| 机制 | 行为 |
|---|---|
| `IterationBudget` | 默认 500 轮（`agent.max_turns`）；子代理独立预算，`delegation.max_iterations` 默认 50；用尽后停止并返回工作总结；有一轮宽限调用 |
| Fallback 模型 | 主模型 429/5xx/401/403 时按 `fallback_providers` 顺序切换；401/403 先尝试刷新凭证再切换 |
| Auxiliary 兜底 | 视觉、压缩、网页抽取各自有独立的 auxiliary fallback 链（`auxiliary.*` 配置） |
| 回调面 | `tool_progress` / `thinking` / `reasoning` / `clarify` / `step` / `stream_delta` / `tool_gen` / `status`，供 CLI、Gateway、ACP 做实时呈现 |

---

## 11. 记忆与学习闭环

| 组件 | 位置 | 说明 |
|---|---|---|
| 记忆文件 | `MEMORY.md` / `USER.md` | 每轮结束 flush；以冻结快照进系统提示 volatile 层 |
| 记忆 Provider ABC | `agent/memory_provider.py` + `memory_manager.py` | 插件化后端：`mem0` / `honcho` / `supermemory` / `hindsight` / `holographic` / `byterover` / `retaindb` / `openviking` |
| 上下文引擎 ABC | `agent/context_engine.py` | 可插拔上下文管理，默认实现是 `context_compressor.py` |
| 会话检索 | `session_search` 工具 + SessionDB FTS5 | FTS5 + LLM 摘要，跨会话回溯 |
| 技能策展 | `agent/curator.py` + `curator_backup.py` | 复杂任务后自动创建技能，使用中改进 |
| 用户建模 | Honcho | 辩证式用户画像 |

Cron 会话默认 `skip_memory=True`——记忆 provider 不跑在定时任务里，这是有意为之。

---

## 12. 会话存储

`hermes_state.py` 是 SQLite SessionDB 的 facade，配 21 个 `hermes_state_*.py` 兄弟文件（schema / WAL / FTS / 搜索 / 会话 / 标题 / 用量 / 压缩 / 修复 / 迁移 / Telegram / 读池 …）。消息落库、可 `/resume` 恢复；FTS5 支撑 `session_search`。

---

## 13. 关键源码索引

| 关注点 | 入口 |
|---|---|
| Agent 门面 | `run_agent.py`（1558 行），`agent/agent_init.py` |
| 主循环 | `agent/conversation_loop.py`，`agent/turn_*.py` |
| 提示装配 | `agent/prompt_builder.py`，`agent/system_prompt.py` |
| 压缩 | `agent/compression_facade.py`，`agent/context_compressor.py`，`agent/turn_context_compaction.py` |
| 缓存 | `agent/prompt_caching.py`，`agent/prompt_cache_boundary.py`，`agent/prompt_cache_scope.py` |
| 工具 | `model_tools.py`（906 行），`toolsets.py`（479 行），`tools/registry.py` |
| MCP | `tools/mcp_tool.py` + 21 个 `mcp_tool_*.py` |
| 记忆 | `agent/memory_provider.py`，`agent/memory_manager.py`，`plugins/memory/*` |
| 技能 | `skills/`（60），`optional-skills/`（137），`agent/curator.py` |
| 网关 | `gateway/run.py` + `gateway/platforms/` |
| 调度 | `cron/jobs.py`，`cron/scheduler*.py` |

---

## 14. 对康小伴 AI 的可落地借鉴

康小伴 `WideModelManagement` 的模块导航是「模型管理 / 提示词库 / **MCP 管理** / **Skills 管理** / RAG 知识库」，其中 MCP 与 Skills 目前是 `wipModule` 占位，Go 后端尚无对应实现。可按下表逐项落地：

| 康小伴模块 | 直接可用的 Hermes 设计 |
|---|---|
| Skills 管理 | SKILL.md + YAML frontmatter 契约（`name` / `description`≤60 字符 / `version` / `platforms` / `metadata.tags` / `prerequisites`）；内置 vs 可选两档目录，可选需显式启用；`## Prerequisites` / `## When to Use` 固定小节；有 authoring 校验测试 |
| MCP 管理 | 22 文件客户端形态：发现 → 健康检查 → OAuth → 生命周期 → 传输；65 个可选服务器目录做成「目录 + 一键启用」 |
| 提示词库 | 三层装配 stable / context / volatile：**技能索引进 stable，租户记忆与用户画像进 volatile，两者都进缓存系统提示**；中途注入只走 user 消息或 tool result |
| AI 网关 | 主模型 + auxiliary 侧模型（压缩/摘要/标题/向量）分离；fallback 链按任务独立配置；每次调用落 `ai_usage_logs`（康小伴已有） |
| 上下文成本 | 双层压缩阈值（85% 网关卫生 / 50% agent 压缩）+ 四阶段算法；摘要模板固定 7 段；迭代增量重压缩 |
| 权限与安全 | 危险操作审批回调；service-gated 工具 `check_fn`；能力归属会话而非进程环境 |

**风险提示**：Hermes 是 Python 运行时，康小伴后端是 Go + 鸿蒙 ArkTS 客户端，只能借鉴**契约与流程设计**，不能搬代码。真正要落的是：技能元数据契约、MCP 生命周期状态机、提示分层规则、压缩阈值与摘要模板这四套**规范**，用 Go 重写。
