package router

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/handler"
	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// New 组装路由。
func New(db *gorm.DB, cfg *config.Config, hub *ws.Hub, iotSvc *iot.IotService,
	userRepo *repository.UserRepository,
	authSvc *service.AuthService, elderSvc *service.ElderService,
	resourceSvc *service.ResourceService, taskSvc *service.TaskService,
	healthSvc *service.HealthService, scheduleSvc *service.ScheduleService,
	financeSvc *service.FinanceService, medicationSvc *service.MedicationService,
	auditSvc *service.AuditService, auditRepo *repository.AuditRepository,
	supplySvc *service.SupplyService, familySvc *service.FamilyService,
	careSvc *service.CareService,
	admissionSvc *service.AdmissionService,
	notificationSvc *service.NotificationService,
	messageSvc *service.MessageService,
	aiSvc *service.AIService,
) *gin.Engine {
	// WebSocket authentication currently supports a query token for native clients. Skip access logging
	// for that path so reverse-proxy or application logs never persist the JWT-bearing query string.
	r := gin.New()
	r.Use(gin.LoggerWithConfig(gin.LoggerConfig{SkipPaths: []string{"/api/v1/ws"}}))
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())

	r.GET("/api/v1/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	authHandler := handler.NewAuthHandler(authSvc)
	dashboardHandler := handler.NewDashboardHandler(db)
	elderHandler := handler.NewElderHandler(elderSvc, familySvc)
	resourceHandler := handler.NewResourceHandler(resourceSvc, familySvc)
	taskHandler := handler.NewTaskHandler(taskSvc, hub, familySvc)
	healthHandler := handler.NewHealthHandler(healthSvc, hub, familySvc)
	wsHandler := handler.NewWSHandler(hub, cfg.JWT.Secret)
	iotHandler := handler.NewIotHandler(iotSvc, familySvc)
	m4Handler := handler.NewM4Handler(scheduleSvc, financeSvc, medicationSvc, auditSvc, familySvc)
	supplyHandler := handler.NewSupplyHandler(supplySvc, familySvc)
	familyHandler := handler.NewFamilyManageHandler(familySvc)
	aiHandler := handler.NewAIHandler(aiSvc)
	careHandler := handler.NewCareHandler(careSvc, familySvc)
	admissionHandler := handler.NewAdmissionHandler(admissionSvc)
	notificationHandler := handler.NewNotificationHandler(notificationSvc)
	messageHandler := handler.NewMessageHandler(messageSvc, familySvc, hub, userRepo)
	systemHandler := handler.NewSystemHandler()

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
		authed.GET("/dashboard/cockpit", perm("dash:read"), dashboardHandler.Cockpit)
		authed.GET("/dashboard/policy", perm("dash:read"), dashboardHandler.Policy)
		// 服务器监控：仅管理员可查看主机和进程资源，避免向普通业务角色暴露部署信息。
		authed.GET("/system/monitor", perm("admin:all"), systemHandler.Monitor)

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

		// 护理闭环：评估 -> 计划 -> 执行 -> 复核
		authed.GET("/assessments", perm("health:read"), careHandler.ListAssessments)
		authed.POST("/assessments", perm("health:write"), careHandler.CreateAssessment)
		authed.GET("/care-plans", perm("task:read"), careHandler.ListPlans)
		authed.POST("/care-plans", perm("task:write"), careHandler.CreatePlan)
		authed.POST("/care-plans/:id/items", perm("task:write"), careHandler.AddPlanItem)
		authed.GET("/care-executions", perm("task:read"), careHandler.ListExecutions)
		authed.POST("/care-executions", perm("task:write"), careHandler.CreateExecution)
		authed.PATCH("/care-executions/:id/review", perm("care:review"), careHandler.ReviewExecution)

		// 入住评估：A 基础信息、B 26项能力评估、C 服务端评分与入院建档。
		authed.GET("/admission-assessments/templates/current", perm("admission:read"), admissionHandler.CurrentTemplate)
		authed.GET("/admission-assessments/screening-templates", perm("admission:read"), admissionHandler.ScreeningTemplates)
		authed.GET("/admission-assessments", perm("admission:read"), admissionHandler.List)
		authed.POST("/admission-assessments", perm("admission:write"), admissionHandler.Create)
		authed.GET("/admission-assessments/:id", perm("admission:read"), admissionHandler.Get)
		authed.PUT("/admission-assessments/:id", perm("admission:write"), admissionHandler.Update)
		authed.POST("/admission-assessments/:id/preview", perm("admission:write"), admissionHandler.Preview)
		authed.POST("/admission-assessments/:id/submit", perm("admission:write"), admissionHandler.Submit)
		authed.GET("/admission-assessments/:id/screenings", perm("admission:read"), admissionHandler.ListScreenings)
		authed.PUT("/admission-assessments/:id/screenings/:template_code", perm("admission:write"), admissionHandler.SaveScreening)
		authed.GET("/notifications", notificationHandler.List)
		authed.PATCH("/notifications/:id/read", notificationHandler.MarkRead)
		authed.GET("/messages", messageHandler.List)
		authed.POST("/messages", messageHandler.Send)
		authed.PATCH("/messages/:id/read", messageHandler.MarkRead)
		authed.GET("/message-contacts", messageHandler.Contacts)

		// 物联网：设备/告警读写
		authed.GET("/iot/devices", perm("alert:read"), iotHandler.ListDevices)
		authed.GET("/alerts", perm("alert:read"), iotHandler.ListAlerts)
		authed.GET("/alerts/:id/actions", perm("alert:read"), iotHandler.ListAlertActions)
		authed.POST("/alerts/:id/actions", perm("task:write"), iotHandler.CreateAlertAction)
		authed.PATCH("/alerts/:id/handle", perm("admin:all"), iotHandler.HandleAlert)
		authed.POST("/iot/ingest", perm("admin:all"), iotHandler.Ingest)

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

		// ---- 家属账号管理（管理员）----
		authed.POST("/families", perm("admin:all"), familyHandler.CreateMember)
		authed.GET("/families", perm("admin:all"), familyHandler.ListBindings)
		authed.DELETE("/families", perm("admin:all"), familyHandler.Unbind)

		// ---- 照护 AI（登录即可问）----
		authed.POST("/ai/chat", aiHandler.Chat)
		authed.GET("/ai/suggestions", aiHandler.ListSuggestions)
		authed.GET("/ai/conversations", aiHandler.ListConversations)
		authed.POST("/ai/conversations", aiHandler.CreateConversation)
		authed.DELETE("/ai/conversations/:id", aiHandler.DeleteConversation)
		authed.GET("/ai/conversations/:id/messages", aiHandler.ListMessages)
		authed.POST("/ai/conversations/:id/messages", aiHandler.SendMessage)
	}

	return r
}
