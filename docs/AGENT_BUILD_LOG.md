# Agent 建设记忆日志(AGENT BUILD LOG)

> 用途:跨上下文重置的任务记忆。每次里程碑后更新本文件并提交推送。
> 规则:所有密码/密钥只存在于被 git 忽略的 `.codex/private/*.json`,严禁写进本文件或任何被追踪的文件。
> 创建:2026-09-09,分支 `shenyi_dev`。

## 0. 使命(用户原话要点)

1. 完全理解现有 agent 架构,上网/GitHub 调研完善方案。
2. 每个工作台的 AI 用不同提示词(已有 ai_model_configs 按角色分配,需保持)。
3. 完善 **Skills** 与 **MCP**(管理端"大模型"页里 MCP 管理/Skills 管理现在是占位)。
4. **上下文管理**要有(历史压缩/预算)。
5. 适配好 **Dify 的 RAG 检索**(网关已有 best-effort 注入,要适配好)。
6. AI 对话区分两个模式:**【对话】= 正常聊天但也是 agent;【工作】= 能查老人信息等数据工具**。
7. UI 要有**思考过程**(agent 步骤/推理展示)。
8. 模型:已接 Qwen(部署在 DGX Spark 主机,通过 vLLM?)。
9. **首要目标:先完成一个能正常思考、调用工具的完整 agent。**
10. 流程:随时提交 git + 推送远端(留后路);本记忆文件持续更新;不懂就去 GitHub/网上找。

## 1. 环境(凭据见 .codex/private/fleet-ssh.json,git 已忽略)

| 主机 | 用户 | 用途 |
|---|---|---|
| 10.10.1.1 / 10.10.1.2 | nvidia | 两台 DGX Spark,部署模型(vLLM + Qwen?) |
| 10.10.1.12 | api | 后端/API 部署(docker compose @ /opt/kangxiaoban/kangxiaoban-service,端口 80→容器 8080) |
| 10.10.1.14 | mq | MQTT 网关(雷达设备) |

- 应用 REST 基址:`http://10.10.1.12/api/v1`;前端 ApiConfig.ets。
- 内置账号:admin/123456(管理员)、xiaoli(护工)、xiaomo(医师)。
- 部署惯例:交叉编译 linux 二进制 → 放部署目录 → `docker compose build && up -d`;备份带时间戳。

## 2. 参考架构(本地)

- `docs/hermes-agent-architecture.md`:hermes-agent(Nous,Python)分析。四契约要 Go 重实现:
  1. SKILL.md frontmatter(name, description<=60, version, platforms, metadata.tags, prerequisites)
  2. MCP 生命周期(discovery→health→OAuth→lifecycle→transport)
  3. 提示词分层 stable→context→volatile(缓存安全;对话内只压缩不注入 system)
  4. 压缩阈值+七段摘要模板(gateway 85%/agent 50%;prune→boundary→summary→reassemble)
  - 核心窄腰原则:新能力=工具/技能/MCP,不加核心面。
- AGENTS.md §9(AI 边界:advisory、usage 日志、租户隔离)、§15.14、§16。
- Go MCP SDK:`github.com/modelcontextprotocol/go-sdk`(待调研确认)。

## 3. 现状理解(探索后填写)

### 后端(kangxiaoban-service)
- `internal/service/ai_service.go`(约1358行):provider 分发(本地确定性回答 / OpenAI 兼容 chatHTTP),
  会话/消息持久化,usage 记录,Dify RAG 注入(ragContextForChat),RAG 数据集管理+代理,
  模型 list/probe/test,租户级 AIConnection(密钥 AES-GCM),角色级 AIModelConfig,提示词 CRUD。
- 模型:`internal/model/ai.go`:AIPromptSuggestion, AIModelConfig(角色), AIConnection(统一端点+Dify),
  AIConversation, AIMessage, AIUsageLog。
- 路由:`/ai/*`(chat/models/suggestions/conversations),`/admin/ai/*`。
- 现状:非流式、无工具调用、无 agent 循环、无上下文压缩。

### 前端(KangxiaobanAI)
- `pages/AiChatPage.ets`(护工,约2384行)、`pages/WideDoctorAiPage.ets`(医师,约2385行):会话列表/消息/反馈,
  无模式切换、无思考过程展示。
- 管理端 `component/wide/WideModelManagement.ets`(约1505行):模型管理/提示词库/MCP 管理(占位)/Skills 管理(占位)/RAG 知识库。

### 模型侧(DGX)
- 待探测:10.10.1.1/.2 上 vLLM/模型/端口/是否启用 tool parser。
- 应用当前 ai_connections 指向待查(admin API /admin/ai/connection)。

## 4. 设计(目标形态)

- **Go agent 包** `internal/agent/`:
  - `Agent.Run(req)`:循环 [构建消息 → 调 LLM(tools) → 若 tool_calls:执行→追加→继续;若纯文本:结束],上限 N 轮(如8)。
  - `ToolRegistry`:原生工具(机构数据,租户+RBAC)+ MCP 工具桥接;OpenAI tools schema 导出。
  - `ContextManager`:系统提示(stable)+ 技能片段 + 历史(预算内裁剪)+ 滚动摘要(超限触发 LLM 摘要,存会话)。
  - `Trace`:每步 {类型: thought/tool/tool_result/answer, 内容摘要, 工具名, 参数摘要, 耗时} → 随消息返回/存储。
  - reasoning_content 透传(vLLM+Qwen3 thinking 时可返回)。
- **模式**:/ai/chat 增加 `mode`:chat(无工具纯对话,仍走 agent 循环)/work(挂数据工具)。默认 chat。
- **原生工具(先只读)**:elders 列表/详情、健康记录、今日任务、告警、排班、消息未读——全部走 repository + 租户上下文 + 角色权限校验。
- **Skills**:表 `ai_skills`(frontmatter 契约字段 + 启用/绑定角色/内容),管理端 CRUD,agent 注入为提示词片段;预置2-3个示例。
- **MCP**:表 `ai_mcp_servers`(name/transport=streamable_http/endpoint/headers/enable),Go 客户端(list tools/call tool/health),
  管理端 CRUD + 探测;工具桥接进注册表。
- **RAG 适配**:保持 ragContextForChat,但改为 agent 循环前的显式步骤,并把检索结果作为 trace 步骤暴露;失败不阻塞。
- **前端**:两个 AI 页加 对话/工作 模式切换 + "思考过程"折叠区(trace 步骤列表);管理端 MCP/Skills 模块真实 CRUD。
- **使用日志**:usage_logs 继续记录(工具调用次数可并入)。

## 5. 阶段清单(持续更新)

- [x] P0 底线提交 + 记忆文件
- [x] P1 现状探索(后端 ai_service / 前端 AI 页 / DGX 模型探测)
- [x] P2 调研(vLLM+Qwen tool calling、MCP Go SDK)
- [x] P3 Go agent 包(循环/trace/上下文管理/工具注册表)
- [x] P4 原生数据工具(租户+权限)
- [x] P5 模式(chat/work)+ /ai/chat 接线 + trace 存储
- [x] P6 Skills(表/CRUD/注入/预置)
- [x] P7 MCP(表/CRUD/客户端/桥接)
- [x] P8 前端:模式切换 + 思考过程 UI(两个 AI 页)
- [x] P9 管理端 MCP/Skills 模块
- [x] P10 测试 + 构建 + 部署 + 线上验证
- [x] P11 前端构建 + 设备安装

## 6. 提交记录(本次任务)

- `cf552cf2` 之前的基线(rbac 工作台)已在远端。
- 本次任务提交:见 git log,每个里程碑一个。

## 7. 注意事项

- 前端 ArkTS 严格模式:对象字面量必须带接口类型;Repeat/ForEach key 要含内容。
- 后端种子 FirstOrCreate:结构体条件字段全进 WHERE(已踩坑,见 cf552cf2)。
- 管理端页面为 1280vp 居中列 + 滑动胶囊导航(照 WideModelManagement 现有风格)。
- 部署后必须验证 /healthz + 登录 + 业务端点;数据卷 ./data 别动。
- 密钥严禁入库;fleet-ssh.json 已被忽略。
