# 康小伴 KangxiaobanAI

多端智慧养老产品套件 monorepo：HarmonyOS NEXT 机构养老工作台（护工 / 医师 / 管理员）、Go 机构服务端、
老人陪伴端，以及语音评估 Agent 运行时。开发分支：`shenyi_dev`。

## 仓库结构

```text
.
├── AppScope/ products/ hvigor/    # 康小伴 HarmonyOS 客户端（仓库根即客户端工程）
│   └── products/entry/src/main/ets  # 生产源码
├── server/                        # Go 机构服务端（REST + WebSocket/MQTT，SQLite/MySQL，RBAC + 租户隔离）
├── elderly/                       # 老人陪伴端 HarmonyOS 客户端（直连 AsLive 聊天端点）
├── assessment-agent/              # AsLive ASR/VAD/TTS/LLM 运行时仓库副本
└── docs/                          # 架构分析、HarmonyOS 指南库、hermes-agent 架构参考
```

## 康小伴客户端（仓库根）

HarmonyOS NEXT 原生应用，ArkUI V2 状态管理 + HDS 设计系统。

- 包名 `com.gxoc.kxbai`，模块 `kanxiaoban`（entry），设备 `phone / tablet / 2in1`
- SDK：兼容 `6.1.0(23)`，target `26.0.0`（以根目录 `build-profile.json5` 为准）
- 角色：护工工作台（手机四 Tab / 宽屏命令条）、医师临床工作台、管理员管理总台（总览 / 角色 / 用户 / 区域 / 订阅 / 大模型 / 设备）
- 登录走机构后端 JWT，角色由服务端 workspace 决定；业务数据全部来自租户级 API，无本地假数据

### 构建

用 DevEco Studio 打开仓库根目录，或命令行：

```bash
# 需先设置 DEVECO_SDK_HOME 指向本机 DevEco SDK，签名使用本地 signingConfigs
hvigorw --mode module -p product=default -p module=kanxiaoban@default assembleHap
# 产物：products/entry/build/default/outputs/default/kanxiaoban-default-signed.hap
```

`elderly/` 是独立工程，构建互不代表，需单独打开构建。

## server（Go 机构服务端）

Go + Gin + GORM。开发默认 SQLite（`server/.env.example` 配置 `KXB_DB_DRIVER=sqlite`），生产可切 MySQL。
提供认证、租户/RBAC、长者与床位、任务与排班、健康与告警、计费、消息、AI 网关、
入住评估（附录 A/B/C + 语音评估代理）与运维监控等接口，WebSocket/MQTT 负责实时通道。

```bash
cd server
cp .env.example .env   # 按需修改端口、数据库、AI/存储等配置
go run ./cmd/server    # 工具：./cmd/ai-env-migrate
```

接口契约与入住单等业务细节见 `server/README.md`。AI 网关、Dify RAG、MinIO 等外部连接
全部由服务端环境变量持有（`KXB_AI_*`、`KXB_DIFY_*`），客户端不可见、不可改。

## elderly（老人陪伴端）

面向老人的陪伴聊天客户端：Grok Ball 表情舞台 + 全双工语音对话，直连 AsLive 公开聊天端点；
与受保护的 `/assessment-ws` 评估通道相互独立。

## assessment-agent（语音评估运行时）

AsLive 传输运行时（ASR/VAD/TTS/LLM）的仓库副本。生产实例不直连客户端：
康小伴客户端经 Go 服务端鉴权代理访问 `/assessment-ws`，服务端创建租户/用户/摄入三重作用域的会话
并快照题库。本地运行参考 `assessment-agent/README.md`。

## 环境与凭据安全

- 凭据类文件（`.codex/private/`、`server/.env`、`server/*.db`、签名材料）已全部 git-ignore，严禁提交
- 客户端不持有任何端点密钥；AI 与存储连接只存在于服务端环境
- 架构约定、已知风险与变更流程见 [AGENTS.md](AGENTS.md)

## 文档索引

| 文档 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 工程宪法：已验证事实、架构边界、编码与验证基线 |
| [server/README.md](server/README.md) | 后端接口契约与部署说明 |
| [docs/hermes-agent-architecture.md](docs/hermes-agent-architecture.md) | Agent 架构参考（提示词缓存 / MCP / Skills 契约） |
| [docs/huawei-harmonyos-guides-complete-2026-08-10/](docs/huawei-harmonyos-guides-complete-2026-08-10/) | 本地 HarmonyOS 指南库（日期快照） |

## License

[Apache-2.0](LICENSE)
