package router

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/handler"
	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// New 组装路由。
func New(cfg *config.Config, hub *ws.Hub, iotSvc *iot.IotService,
	userRepo *repository.UserRepository,
	authSvc *service.AuthService, elderSvc *service.ElderService,
	resourceSvc *service.ResourceService, taskSvc *service.TaskService,
	healthSvc *service.HealthService, scheduleSvc *service.ScheduleService,
	financeSvc *service.FinanceService, medicationSvc *service.MedicationService,
	auditSvc *service.AuditService, auditRepo *repository.AuditRepository,
	supplySvc *service.SupplyService,
) *gin.Engine {
	r := gin.Default()
	r.Use(middleware.CORS())

	r.GET("/api/v1/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	authHandler := handler.NewAuthHandler(authSvc)
	dashboardHandler := handler.NewDashboardHandler()
	elderHandler := handler.NewElderHandler(elderSvc)
	resourceHandler := handler.NewResourceHandler(resourceSvc)
	taskHandler := handler.NewTaskHandler(taskSvc, hub)
	healthHandler := handler.NewHealthHandler(healthSvc, hub)
	wsHandler := handler.NewWSHandler(hub, cfg.JWT.Secret)
	iotHandler := handler.NewIotHandler(iotSvc)
	m4Handler := handler.NewM4Handler(scheduleSvc, financeSvc, medicationSvc, auditSvc)
	supplyHandler := handler.NewSupplyHandler(supplySvc)

	// 访问校验封装
	perm := func(code string) gin.HandlerFunc { return middleware.RequirePermission(userRepo, code) }

	// 公开：登录
	r.POST("/api/v1/auth/login", authHandler.Login)
	// WebSocket 实时推送：token 经 query 或 Authorization 头，由 WSHandler 自行校验
	r.GET("/api/v1/ws", wsHandler.Serve)

	// 需认证
	authed := r.Group("/api/v1")
	authed.Use(middleware.JWTAuth(cfg.JWT.Secret))
	authed.Use(middleware.Audit(auditRepo))
	{
		authed.GET("/auth/me", authHandler.Me)

		// 工作台
		authed.GET("/dashboard/summary", perm("dash:read"), dashboardHandler.Summary)

		// 长者档案（读）
		elders := authed.Group("/elders", perm("elder:read"))
		elders.GET("", elderHandler.List)
		elders.GET("/:id", elderHandler.Get)
		elders.GET("/:id/health-records", healthHandler.ListByElder)

		// 长者档案（写）
		authed.POST("/elders", perm("elder:write"), elderHandler.Create)
		authed.PUT("/elders/:id", perm("elder:write"), elderHandler.Update)
		authed.DELETE("/elders/:id", perm("elder:write"), elderHandler.Delete)

		// 资源：房间/床位（浏览权限用 elder:read）
		authed.GET("/rooms", perm("elder:read"), resourceHandler.ListRooms)
		authed.GET("/beds", perm("elder:read"), resourceHandler.ListBeds)

		// 护理任务
		authed.GET("/tasks", perm("task:read"), taskHandler.List)
		authed.POST("/tasks", perm("task:write"), taskHandler.Create)
		authed.PATCH("/tasks/:id/status", perm("task:write"), taskHandler.SetStatus)

		// 体征录入（查看在 /elders/:id/health-records）
		authed.POST("/health-records", perm("health:write"), healthHandler.Create)

		// 物联网：设备/告警读写
		authed.GET("/iot/devices", perm("alert:read"), iotHandler.ListDevices)
		authed.GET("/alerts", perm("alert:read"), iotHandler.ListAlerts)
		authed.PATCH("/alerts/:id/handle", perm("admin:all"), iotHandler.HandleAlert)
		authed.POST("/iot/ingest", perm("admin:all"), iotHandler.Ingest)

		// 演示/测试：向所有客户端广播事件（admin）
		authed.POST("/demo/push", perm("admin:all"), wsHandler.DemoPush)

		// ---- M4 排班/交接班 ----
		authed.GET("/schedules", perm("task:read"), m4Handler.ListSchedules)
		authed.POST("/schedules", perm("task:write"), m4Handler.CreateSchedule)
		authed.GET("/handovers", perm("task:read"), m4Handler.ListHandovers)
		authed.POST("/handovers", perm("task:write"), m4Handler.CreateHandover)

		// ---- M4 费用 ----
		authed.GET("/bills", perm("elder:read"), m4Handler.ListBills)
		authed.POST("/bills/generate", perm("admin:all"), m4Handler.GenerateBills)
		authed.POST("/bills/pay", perm("admin:all"), m4Handler.Pay)
		authed.GET("/elders/:id/balance", perm("elder:read"), m4Handler.Balance)
		authed.GET("/elders/:id/flows", perm("elder:read"), m4Handler.ListFlows)

		// ---- M4 用药 ----
		authed.GET("/medications", perm("elder:read"), m4Handler.ListMedications)
		authed.POST("/medications", perm("task:write"), m4Handler.CreateMedication)
		authed.PATCH("/medications/:id/status", perm("task:write"), m4Handler.MarkMedicationStatus)

		// ---- M4 审计 ----
		authed.GET("/audits", perm("admin:all"), m4Handler.ListAudits)

		// ---- M5 药物库存 ----
		authed.GET("/stocks", perm("elder:read"), supplyHandler.ListStock)
		authed.POST("/stocks", perm("task:write"), supplyHandler.CreateStock)
		authed.PATCH("/stocks/:id", perm("admin:all"), supplyHandler.AdjustStock)

		// ---- M5 餐饮订餐 ----
		authed.GET("/dining", perm("elder:read"), supplyHandler.ListDining)
		authed.POST("/dining", perm("task:write"), supplyHandler.CreateDining)
	}

	return r
}