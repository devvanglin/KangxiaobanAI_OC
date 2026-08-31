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
