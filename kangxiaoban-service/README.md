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

## 演示登录账号

首次启动会创建以下测试账号（生产环境请立即改密或删除）：

```text
管理员：admin / Admin@123456
演示管理员：admin_demo / 123456
护工：caregiver_demo / 123456
医师：doctor_demo / 123456
家属：family_demo / Family@123456
```

## 验证

```bash
go test ./...
go vet ./...
```
