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

## 3. 现状理解(P1 探索完成 2026-09-09 凌晨)

### 关键事实(已实测)
- **当前 /ai/chat 是坏的(503)**:角色配置(caregiver+doctor)的 model=`kxb-local` 在网关上不存在。
- LLM 端点 = `http://10.10.1.12:3030/` = **new-api 网关**(docker 容器 new-api, 3030→3000)。
- new-api 模型清单仅 3 个:`Qwen3-VL-4B-Instruct`(对话)、`Qwen3-Reranker-0.6B`、`Qwen3-VL-Embedding-2B`。
- **模型上游当前离线**:直接打 /v1/chat/completions 返回 `upstream error: do request failed`;
  DGX(10.10.1.1/.2)从 .12 和本机都 ping 不通、22/8000/8080/3030/30000 全关 → **模型主机没开机/不可达**。
  => agent 必须双协议(原生 tools + hermes 文本协议兜底),模型回来即用;本地 provider 继续可用。
- RAG = Dify @ `http://10.10.1.12:8080/v1`,dataset `b4b65a72-...`,rag_enabled=true(在 ai_connections)。
- 网关密钥:加密存 ai_connections(api_key_encrypted),KXB_AI_CONFIG_KEY 在服务器 .env,AES-GCM(sha256(key)) RawStd b64 nonce 前缀;已验证可解密(仅内存,未外泄)。
- `chatHTTP` 是单轮裸调用(system+user,**无历史、无工具**);历史仅存储展示。上下文管理=没有。
- RAG 现状:`ragContextForChat` 把 Dify 检索结果拼进 system prompt(http provider 才触发),rag_used=attempted。
- 角色合并:connection 出 provider/baseURL/key;角色配置出 system_prompt+model;Temperature 固定 0.3。
- handler:`ai_handler.go` L32 aiRoleScope(claims)(admin→? L184 映射);SendMessage L156(service.SendMessage)。
- 模型:AIMessage 无 trace/thinking 字段(要加);AIModelConfig 有 context_window/temperature(未用于调用)。

### 前端(P1 完成)
- `AiChatPage.ets` 与 `WideDoctorAiPage.ets` 几乎逐行复制(行号+1)。改动必须双写。
- **已有** `embeddedAssistantMode` 0/1 状态 + `embeddedModeSwitcher()`(L1328/1329)= 现成的模式切换,发送走
  `POST /ai/conversations/{id}/messages` body `{content}`(L869/870),响应 `AiConversationExchangeResponse`。
- 消息渲染:`messageList()` L2013/2014 → `aiMessageItem` L1148/1149;空态英雄区/启动词 rows。
- 管理端 `WideModelManagement.ets`:MCP/Skills 占位 = `wipModule()` L1223-1231,build() L1439-1442 分发;
  提示词库 CRUD(L1040-1146)是模仿范式;对话框模式 = build() 尾部 Stack overlay。
- 可复用折叠模式:`WideRagDocumentsPage` expandedDocId(单开);`ResidentDetailPage` expandedMask。
- Dto:`AiConversationMessage` 无 thinking/trace 字段,要扩展;`AiConversationSendRequest {content}` 要加 mode。

## 4. 设计(目标形态)

- **Go agent 包** `internal/agent/`:
  - `Agent.Run(req)`:循环 [构建消息 → 调 LLM(tools) → 若 tool_calls:执行→追加→继续;若纯文本:结束],上限 8 轮。
  - **双协议工具调用**:优先原生 OpenAI `tools`;若模型把调用写进 content(hermes 风格 `<tool_call>{json}</tool_call>`),解析之。
    原因:模型主机离线无法实测 vLLM parser 是否开启;Qwen3 系列原生支持 hermes 文本协议。
  - `ToolRegistry`:原生工具(机构数据,租户+RBAC)+ MCP 工具桥接 + Dify 检索工具;OpenAI tools schema 导出。
  - `ContextManager`:系统提示(stable)+技能片段+历史预算裁剪+滚动摘要(写入 AIConversation.Summary)。
  - `Step` trace:thought/tool_call/tool_result/rag/reasoning/answer → 存 AIMessage.Trace(JSON)随消息返回;reasoning_content 透传。
- **模式**:SendMessage 增加 `mode`:chat(仅知识库工具,正常聊天)/work(全套数据工具)。POST /ai/chat 旧契约默认 chat。
- **原生工具(只读)**:get_elders / get_elder_detail / get_elder_health / get_today_tasks / get_alerts / get_today_schedule / search_knowledge_base;
  每个工具声明所需权限(elder:read 等),registry 按登录者 permissions 过滤,全部走租户上下文。
- **Skills**:表 `ai_skills`(code/name/description<=60/version/instructions/role_scope/enabled/sort_order/builtin),
  管理端 CRUD;agent 把启用技能注入 system prompt 的 volatile 段(hermes SKILL.md 契约的 Go 版)。
- **MCP**:表 `ai_mcp_servers`(name/transport=streamable_http|sse/endpoint/api_key_encrypted/enabled/status/last_probe_at),
  Go 客户端 JSON-RPC(initialize/tools/list/tools/call),管理端 CRUD+探测;工具以 mcp_前缀桥接进注册表,失败降级为 trace 步骤。
- **RAG 适配**:work 模式下检索成为 `search_knowledge_base` 工具(模型自主决定何时检索);chat 模式保留现有自动注入;失败不阻塞。
- **前端**:两个 AI 页(双写):`embeddedAssistantMode` 0=对话/1=工作 → 发送带 mode;助手消息下加"思考过程"折叠区
  (steps 列表,单开模式 expandedMsgId);管理端 MCP/Skills 模块真实 CRUD(模仿提示词库 master-detail)。
- **usage 日志**:继续每次一条;加 tool_calls 字段可选。

## 5. 阶段清单(持续更新)

- [x] P0 底线提交 + 记忆文件
- [x] P1 现状探索:当前对话链路是坏的(kxb-local 模型不存在);DGX 关机时上游全断
- [x] P2 调研:vLLM 无 tool parser 时 400;Qwen3 hermes 文本协议实测可用
- [x] P3 agent 包 68567ec1;P4-P5 网关接线 83a5187b;P6-P7 skills+MCP 61f676d0
- [x] P8-P9 前端(模式/思考过程/管理端 CRUD)已构建成功 46c927fd
- [x] P10 部署完成;角色模型名已改 Qwen3-VL-4B-Instruct、context_window=4096(admin API)
- [x] P11 HAP 安装设备并启动

## 8. 最终状态(2026-09-09 凌晨完成)

线上已验证的真实行为(admin 与 xiaoli 两个账号实测):
- work 模式:模型真实调用 get_elders/get_today_tasks,回答为真实数据(4位长者名单、8条待办),trace 步骤持久化并随消息返回
- chat 模式:正常聊天,无数据工具
- 工具失败时模型如实告知(不编造);追问可基于上下文推理
- 四个内置技能已种子化;管理端 /admin/ai/skills、/admin/ai/mcp/servers CRUD 可用

### 途中修复的两个关键 bug(都有回归测试)
1. llm.go:请求体先组装、后 prepend system 消息 —— append 重新切片导致 map 里留旧切片头,
   **所有请求都没带 system 提示/技能/工具 schema**,模型因此直接编造(llm_test.go 回归)
2. get_today_tasks 的 LEFT JOIN 与租户回调的裸 tenant_id 条件冲突(歧义列),已去掉 join

### 会话持久化 + 上下文完善(2026-09-09 追加, a5f6f86f/c227858e 之后)
- 历史栏每次展开自动刷新(30s 节流),重启不再显示过期空列表
- 按用户记住最近会话(PreferenceManager),重进应用自动恢复上次对话
- 切换会话保留 reasoning/trace/model(此前 cloneMessage 会丢,思考过程切换后消失)
- agent 历史回放窗口 24→40 条;线上实测跨轮记忆 OK(“最开始查到的长者总数”→ 正确答 4,无需重新调工具)
- 前端“康小伴·快速”写死标签 → 显示服务端真实模型名;思考过程展开显示“真实模型:…(在线调用)”

### RAG 修复 + 思考协议(2026-09-09 追加)
- 原生思考不可用:Qwen3-VL-4B-Instruct 模板无思考分支,直连 vLLM 传 enable_thinking 被静默忽略
  (实测)。采用提示词 <think> 协议:回答前先思考,解析进 reasoning 步骤;think 里的 tool_call
  也会被提取执行(模型常把调用写进 think,有回归测试)
- ragRetrieve 漏了 normalizeAPIBase,配置地址自带 /v1 导致 /v1/v1 永远 404,RAG 自上线即静默失效;
  修复后线上验证:模型调 search_knowledge_base → Dify 真实检索(200, 3 条)→ 诚实回答
- 注意:当前 Dify 知识库存的是心理量表/认知障碍类学术文献,没有机构制度文档;要答制度流程需上传对应文档
- 前端思考/工具过程改为内联平铺展示(Kimi 式),去掉折叠;“真实模型”标注行按用户要求移除

### 已知边界/后续建议
- 当前线上唯一对话模型 = Qwen3-VL-4B-Instruct(new-api → DGX-2:8000,max-model-len 4096,
  未开 --enable-auto-tool-choice → 走 hermes 文本协议;模型更换后无需改代码)
- 上下文预算按 4096 窗口裁剪 + 滚动摘要;大对话历史压缩阈值可再调
- MCP 桥接已实现但线上还没有注册任何 MCP 服务(管理端探测按钮可用)
- kxb-deploy-linux-amd64 曾被误提交,已在 303dba6e 移出跟踪(历史中仍在,无密钥风险)

## 6. 提交记录(本次任务)

- `cf552cf2` 之前的基线(rbac 工作台)已在远端。
- 本次任务提交:见 git log,每个里程碑一个。

## 7. 注意事项

- 前端 ArkTS 严格模式:对象字面量必须带接口类型;Repeat/ForEach key 要含内容。
- 后端种子 FirstOrCreate:结构体条件字段全进 WHERE(已踩坑,见 cf552cf2)。
- 管理端页面为 1280vp 居中列 + 滑动胶囊导航(照 WideModelManagement 现有风格)。
- 部署后必须验证 /healthz + 登录 + 业务端点;数据卷 ./data 别动。
- 密钥严禁入库;fleet-ssh.json 已被忽略。
