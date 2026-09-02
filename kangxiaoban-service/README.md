# Kangxiaoban 后端

Go + Gin + GORM 的养老机构服务端。默认使用 SQLite，生产可切换 MySQL。

## 新增护理闭环接口

服务端已提供“评估 → 护理计划 → 执行 → 复核”基础合同：

```text
GET/POST /api/v1/assessments
GET/POST /api/v1/care-plans
POST     /api/v1/care-plans/:id/items
GET/POST /api/v1/care-executions
PATCH    /api/v1/care-executions/:id/review
```

告警处置时间线和应用内通知：

```text
GET/POST /api/v1/alerts/:id/actions
GET      /api/v1/notifications
PATCH    /api/v1/notifications/:id/read
```

短信、Push、微信等外部渠道仍需实现对应 Provider；当前通知记录和 WebSocket 广播是可运行的基础层。

## 办理入住（简化运营表单）

简化表单使用独立的入住单接口，不会把未完成的 26 项能力评估伪造成已提交：

```text
POST /api/v1/admission-intakes
GET  /api/v1/admission-intakes
GET  /api/v1/admission-intakes/:id
```

提交时必须提供 `resident_name`、`gender`、`birth_date`（YYYY-MM-DD）、`age`、`id_card`、
`admission_start_date`（YYYY-MM-DD）、`care_level` 和真实可用的 `bed_id`。费用、家属和结束日期为可选项；
`idempotency_key` 为必填项，用于安全重试和并发去重。成功后服务端在一个事务中创建/关联长者、占用床位、护理计划与任务，
按填写费用生成账单、按填写押金生成资金流水，并返回入住单及关联记录。床位冲突、重复身份证和跨租户访问会分别返回
409/403，不会留下半成品数据。

办理入住照片使用独立的私有上传接口。客户端先按 `portrait`、`id_front`、`id_back` 槽位上传，
服务端校验 JPG/PNG/WebP 文件头和 5 MiB 大小上限，再在入住事务中绑定照片；照片文件不通过静态目录公开：

```text
POST   /api/v1/admission-intakes/photos                 # multipart 字段 file；X-Upload-Key/X-Photo-Kind
DELETE /api/v1/admission-intakes/photos                 # 清理未绑定照片
GET    /api/v1/admission-intakes/:id/photos             # 入住单照片元数据
GET    /api/v1/admission-intake-photos/:id/content      # 认证后读取照片内容
```

上传目录由 `KXB_UPLOAD_DIR` 配置；Docker Compose 默认将其放在持久化的 `/data/uploads`，
生产环境应与数据库一同备份，并限制目录权限。

## 管理端服务器监控

管理员登录后可访问：

```text
GET /api/v1/system/monitor
```

接口返回当前后端进程所在主机的 CPU、内存、磁盘、操作系统、IP、Go 版本、启动时间、运行时长和
Goroutine 数。该接口受 `admin:all` 保护；CPU、主机内存和磁盘指标按运行平台采集，无法提供时会返回
`available=false`，不会伪造资源数值。

## 登录账号

首次启动会创建以下基础账号，密码可在生产环境按机构策略修改：

```text
管理员：admin / 123456
护工：caregiver / 123456
医师：doctor / 123456
家属：family / 123456
```

## 验证

```bash
go test ./...
go vet ./...
```
