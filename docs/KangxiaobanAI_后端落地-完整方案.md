# KangxiaobanAI 后端落地完整方案（Go 版）

> 版本：v1.0 草案　日期：2026-08-27
> 适用：将「康小伴AI」从纯本地 mock 原型升级为**可真实运行的养老机构全模块系统**

---

## 0. 现状与目标

### 现状（已核实）
- `KangxiaobanAI` 是 HarmonyOS 原生高保真原型（API 24，ArkUI V2 + HDS），**无后端/无网络层/无真实权限**。
- 业务数据全部内联在超大组件里（`TabPageView` ≈3447 行、`WideDoctorAdmission` ≈1793 行等），AI 为本地 mock。
- 已具备 IoT 基础：`MTQQ/` 毫米波雷达（R60ABD1 睡眠 / R60AFD1 跌倒）→ EMQX（192.168.100.110）→ 台账 链路端到端验证通过。
- 已克隆 120+ 养老开源仓库，可佐证数据模型。

### 目标
1. 建成**可运行的 Go 后端 + MySQL 数据库 + 真实鉴权 + IoT 直连**。
2. 覆盖**完整机构业务**：入院/长者/床位/护理/体征/用药/排班交接/费用/餐饮/权限/机构协作/告警。
3. HarmonyOS 端以 `@ohos.net.http` + WebSocket 对接，替换 mock；AI 走可插拔网关。
4. 真实雷达数据经 EMQX 流入后端并驱动分级告警。

---

## 1. 总体架构

```
┌────────────────────────── 机构内网 / 认证后有网 ──────────────────────────┐
│                                                                          │
│  HarmonyOS 护工端 / 医师端 / 管理端 (KangxiaobanAI, API 24)               │
│     ├─ REST  → @ohos.net.http   (业务/长者/护理/费用/权限)                │
│     └─ 实时  → @ohos.net.webSocket (告警/任务/实时体征/护士站)             │
│                                                                          │
│  HarmonyOS 工作人员端（管理员/医师/护工）                                   │
│                                                                          │
└──────────────┬───────────────────────────────────┬──────────────────────┘
               │ HTTPS(网关)                        │ WSS
   ┌───────────▼───────────┐         ┌──────────────▼──────────────┐
   │  Go 后端（单体起步）     │         │ 丝滑订阅                    │
   │  Gin/Echo + GORM       │         │  paho.mqtt.golang (MQTT)   │
   │  JWT + RBAC(casbin)    │         └──────────────┬──────────────┘
   │  WebSocket/SSE hub     │                        │
   │  规则/告警引擎           │                        │
   └───┬───────────┬────────┘                        │
       │           │                                 │
  ┌────▼───┐  ┌────▼─────┐                 ┌─────────▼─────────┐
  │ MySQL 8│  │  Redis   │                 │ EMQX (MQTT Broker)│
  │(核心库) │  │token/缓存 │                 │  192.168.100.110   │
  └────────┘  └──────────┘                 └──────┬──────────┬─┘
                                                  │          │
                                       R60ABD1 睡眠雷达   R60AFD1 跌倒雷达
```

- **后端**：Go（Gin 或 Echo）+ GORM + MySQL 8 + Redis + `paho.mqtt.golang` + casbin。
- **IoT 字节流**：后端作为 MQTT 客户端订阅 `EMQX` 上雷达 Topic，字段归一化后写库并触发告警。
- **部署**：**本机开发调试 → 新服务器(待到货) 部署**；EMQX 暂留在 192.168.100.110，后端跨机订阅，后续可整体搬迁/并入。

> 验证边界（沿用 AGENTS.md 口径）：MVP 后按 `Implemented / Build-verified / Device-verified / Service-verified / Planned` 五级如实标注，不把 mock 描述为真服务。

---

## 2. 技术栈选型（Go）

| 层 | 选型 | 说明 |
|---|---|---|
| 语言 | Go 1.22+ | 用户指定 |
| Web 框架 | **Gin**（推荐）或 **Echo** | 生态最成熟 |
| ORM | **GORM** | 结构体建表/迁移，贴近已克隆 zzyl 实体思路 |
| 数据库 | **MySQL 8** | 事务、统一字符集 utf8mb4 |
| 缓存/Token | **Redis 7** | token 黑名单、热点、实时阀值 |
| 鉴权 | **JWT + casbin** | RBAC 细粒度（角色/菜单/接口权限）+ 审计日志 |
| 实时推送 | gorilla/websocket（或 SSE） | 告警/任务/体征订阅 |
| MQTT 客户端 | `paho.mqtt.golang` | 直连 EMQX 订阅雷达 |
| 配置 | 环境变量 + `viper`（可选） | 分离开发/生产配置 |
| 日志 | `slog`/`zerolog` | 不落敏感体征/令牌 |
| 任务调度 | `gocron` / `robfig/cron` | 自动生成月账单、排班、用药提醒 |
| API 文档 | Swagger（swaggo） | 与 HarmonyOS 端 DTO 对齐 |

**项目骨架**（单体，模块化包，为后续拆微服务留边界）：
```
kangxiaoban-service/
├── cmd/server/main.go
├── internal/
│   ├── config/        # 配置加载
│   ├── model/         # GORM 实体（≈ 领域表）
│   ├── repository/    # 数据访问（接口+实现）
│   ├── service/       # 业务逻辑 / UseCase
│   ├── handler/       # HTTP 控制器
│   ├── middleware/    # JWT / 请求日志 / 审计
│   ├── auth/          # 登录/Token/RBAC
│   ├── iot/           # MQTT 订阅 + 字段归一化 + 规则引擎
│   ├── ws/            # WebSocket hub
│   └── pkg/           # 通用工具
├── migrations/        # SQL DDL / 种子数据
└── go.mod
```
不照搬任何克隆仓库，只借鉴其表结构与业务语义，按 Go 惯用法重建。

---

## 3. 数据库设计（核心交付）

综合 `itxinfei__zzyl`（机构语义最全）、`hngcadmin__nursing_home`（DDL+触发器最规范）、`geekit__ruchu-care`（RBAC 底座）三份，**补齐排班/交接班/用药/设备/告警**后形成完整模型。库名 `kangxiaoban`。

### 3.1 组织与权限（RBAC）
```
sys_user(员工账号)  sys_role(角色: 管理员/医师/护工)
sys_user_role  sys_menu  sys_role_menu  sys_dept(部门/科室)
audit_log(审计: user/action/module/target/ip/time)
```

### 3.2 资源（楼栋→楼层→房间→床位）
```
building 1─n floor 1─n room 1─n bed
room(building, floor, room_no, type[普通/照护/特护], status[空闲/已住/维修])
bed(bed_no, room_id, status[free/occupied/maintenance], elder_id)
```

### 3.3 长者与入离院
```
elder(id, name, id_card, gender, birth, phone, care_level, status[登记/入住/退住], bed_id,
        emergency_contact(JSON), image, remark)   -- 高频冗余 bed/care_level，避免频繁 JOIN
elder_contact(elder_id, name, relation, phone)       -- 长者联系人资料
contract(elder_id, member_id, start/end, fee_terms, signed_url)
check_in(申请→评估→审批→配置→签约 状态机, config 含 nursing_level/bed/costs)
check_out(退住 状态机 + 结算)
admission_assess(能力评估条目, 照护等级建议, 规则来源)
```

### 3.4 护理与任务（zzyl 抽象 + 排班/交接班补全）
```
nursing_level(name, fee, desc)
care_plan_template(template → 项目多对多, 执行时间/周期/频次)
care_plan_execution(elder_id, date, plan, status[todo/done/missed/abnormal], photo_url, remark)
nursing_task(elder_id, project_id, nurse_id, bed_no, status[待执行/已执行/已关闭], 打卡拍照)
schedule(staff_id, date, shift_type[早/晚/夜], room_responsible)   -- 补齐
shift_handover(from,to,date,summary,issues)                          -- 补齐
```

### 3.5 健康体征 / 用药
```
health_record(elder_id, temp, bps/bpd, hr, spo2, sugar, source[manual/iot], record_time)
                                          -- 需求量大, 按时分表/分区
medication_record(elder_id, prescription_id, medicine, dosage, plan_time, taken_time, status)
medicine_stock(name, spec, batch, qty, expire, storage)   -- 近效期/缺药
```

### 3.6 费用（zzyl 三表模式）
```
bill(bill_no, elder_id, bill_month, bed_fee, nursing_fee, meal_fee, medical_fee, other_fee,
     payable, prepaid, deposit, status[未付/部分/已付], deadline)
balance(elder_id, prepaid_balance, deposit, arrears, status)
fund_flow(elder_id, direction, related_bill_no, reason, amount, time)   -- 每笔流水
prepaid_recharge_record(充值记录)
```

### 3.7 餐饮
```
meal_package / dish / dining_order(elder_id, meal_time, items, qty, unit_price, total)
diet_preference(elder_id, taboo, dietary_plan[糖尿病餐等])
```

### 3.8 IoT 设备与告警（对接 MTQQ 真实链路）
```
iot_device(device_id(唯一), product[breath_radar/fall_radar/mat/bp/spo2/band/sos],
           building/floor/room/bed, elder_id, online, last_seen, protocol[MQTT])
signal_record(device_id, elder_id, type, value, ts)          -- 原始/归一化体征与事件
alert_rule(type, level, threshold, window_sec)                -- 离床久/呼吸低/跌倒/SOS
alert(elder_id, device_id, type, level[emergency/important/info],
      content, status[new/handling/handled/closed], handled_by, create/close_time)
```

**建表策略**：`migrations/*.sql` 提供可运行 DDL（继承 nursing_home 的规范 + 触发器思路），再交给 GORM `AutoMigrate` 增量演进。

---

## 4. 模块清单（完整机构全模块，对应前端页）

| # | 模块 | 后端要点 | 前端（KangxiaobanAI）对应 |
|---|---|---|---|
| 1 | 认证与 RBAC | JWT + casbin + 审计 | 登录(任意非空→真实校验)、角色路由 |
| 2 | 长者档案 | CRUD + 搜索 + 联系人资料 | 长者列表/画像/详情 |
| 3 | 房间床位 | 层级资源 + 状态可视化 |（可在后台/新增面板）|
| 4 | 入院/退院 | 状态机 + 评估 + 签约 | WideDoctorAdmission 四步接入真实提交 |
| 5 | 护理计划/任务 | 模板→执行 + 打卡 | 任务闭环、值班主页 |
| 6 | 排班/交接班 | schedule + shift_handover | 交接班页面（补齐）|
| 7 | 体征/健康 | 记录 + 曲线 + 异常 | 长者健康页、HealthExpandPage |
| 8 | 用药 | 记录 + 库存 + 提醒 | 用药列表/提醒 |
| 9 | 费用账单 | bill/balance/fund_flow |（后台/财务）|
| 10 | 餐饮 | 订餐 + 忌口 |（后台/新增）|
| 11 | 消息/通知 | 站内信 + 推送 | 侧滑消息（未读数）|
| 12 | 系统管理 | 用户/角色/菜单/审计 | 管理端占位 → 落地 |
| 13 | IoT/告警 | 订阅雷达+规则引擎+分级处置 | 告警列表、实时体征 |
| 14 | AI 助手 | 网关(可插拔)+审计+人工确认 | AiChatPage 接真实 model API |

> 外部联系人客户端不属于当前交付范围；当前仅提供机构工作人员之间的协作消息和通知。

---

## 5. API 契约与 HarmonyOS 端接入

### 5.1 REST（业务，`@ohos.net.http`）
- `POST /api/v1/auth/login` → `{ accessToken, refreshToken, role, user }`
- 之后 `Authorization: Bearer <token>`
- 资源接口按模块分：`/elders`、`/beds`、`/tasks`、`/health-records`、`/alerts`、`/bills`、`/weekschedule`(排班) 等，统一 `{code,msg,data}` 封装 + 分页。

### 5.2 WebSocket（实时，`@ohos.net.webSocket`）
- `ws://host/api/v1/ws?token=...`
- 事件：`alert.new`（分级告警）、`task.due`（任务到期）、`vital.point`（实时体征点）、`shift.handover`（交接通知）。
- 后端用全局 WS hub 按 elder/role/room 订阅广播；护士站大屏复用同一订阅。

### 5.3 Kant替换 mock 的策略
1. 在 KangxiaobanAI 增加 `network/` 层：`httpClient`（封装 `@ohos.net.http`）、`wsClient`、`ApiClient`、`DTO`。
2. 将 `AppStorageV2` 里 mock 数据源替换为 `FakeRepository` 接口实现：`LocalFakeRepository`（保留原型）↔ `RemoteRepository`（走后端），**UI 不感知切换**。
3. 登录先用 `/auth/login` 校验，保留 800ms 过渡动画。
4. 实时体征/告警用 WS 订阅，替代本地 timer 假数据。
5. AI 对话接网关：发起请求→流式返回→展示，回写审计。

---

## 6. IoT 真实雷达接入（直连）

沿用 `MTQQ/` 已跑通的链路，把 `mqtt_bridge_demo.py` 的角色收进 Go 后端：

1. **订阅**：后端以 MQTT 客户端连 `192.168.100.110:1883`，按台账订阅
   - `/Radar60SP/{device_id}/sys/property/post`（睡眠雷达：breathValue/heartRateValue/getIntoBed/...）
   - `/Radar60FL/{device_id}/sys/property/post`（跌倒雷达：fallStatus/fallPosition/...）
2. **归一化**：按 `iot_device` 台账（device↔床↔eldely）映射字段到 `signal_record`。
3. **规则引擎**：按 `alert_rule` 判断（离床超时、呼吸<10 或 >25、跌倒置位、SOS）→ 写 `alert` 表 → WS 广播分级告警。
4. **阈值来源**：参考 `nursing_home` 触发器阈值（缩压 90–140/舒压 60–90/心率 60–100/体量 36.0–37.3）与 MTQQ 实测参数（报告模式、心率/呼吸开关等）。
5. **可视**：护士站大屏 + 护工 App 实时体征曲线。

> 隐私：雷达进房间前告知；体征敏感字段加密、日志不含床号外敏感信息；按需对长隐私授权。

---

## 7. 部署规划（本机 → 新服务器）

```
阶段A（本机开发，现在）
  本机: Go 后端 + MySQL8(docker/本地) + Redis
  跨机订阅: EMQX @192.168.100.110 (雷达数据已真流入)
阶段B（新服务器到货后）
  docker-compose: backend + mysql + redis + (可选迁移 EMQX)
  同一内网，后端订阅 EMQX；HTTPS + 内网 CA 或自签
```

- 配置分离：`.env` 区分 dev/prod；JWT 密钥、DB 密码放环境变量/注入，**不入库不入仓库**。
- 用 `docker-compose up` 一键起；数据卷持久化 MySQL/Redis。
- 待新服务器到货后提供 `setup_docs + docker-compose` 即点即用。

---

## 8. 里程碑（建议节奏，非工期承诺）

| 阶段 | 交付 | 验证 |
|---|---|---|
| M0 骨架 | Go 工程 + 连接 MySQL/Redis + JWT 登录 + RBAC 底座 | 登录/角色路由 build-verified |
| M1 核心业务 | 长者/床位/入院/护理任务/体征 CRUD + 种子数据 | 接口自测 + Swagger |
| M2 实时 | WS 告警/任务 + 前端 RemoteRepository 替换 | 真机连后端 |
| M3 IoT | MQTT 订阅雷达 + 归一化 + 告警引擎 | 真雷达数据驱动告警 |
| M4 完整闭环 | 费用/排班/交接/用药/餐饮/审计/AI 网关 | 全模块端到端 |
| M5 部署 | 新服务器 docker 部署 + HTTPS | 内网真机全链跑通 |

> 每阶段都保持前端 UI 行为稳定（勿同时大改视觉 + 深迁移）。

---

## 9. 主要风险与待定

- **部署目标机未到**：M0-M4 全部本机可做；M5 依赖新服务器，到时再落地。
- **全模块范围大**：先保证 M0-M3（可跑可演示的闭环），再逐模块增补费用/餐饮等，避免一次性过大。
- **雷达真数据不稳定**：需台账正确 + 字段归一化覆盖；M3 前先保留 mock 兜底。
- **工作人员端边界**：当前仅交付管理员、医师和护工，其他角色与外部联系人客户端不在范围内。
- **安全/合规**：整体走等保 2.0 思路；敏感体征加密、审计、不泄露令牌。

---

*本文件为规划草案，落地细节（具体表 DDL、每个模块的 API、前端接入代码）在实施每个里程碑时产出并更新。*
