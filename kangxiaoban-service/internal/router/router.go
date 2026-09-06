package router

import (
	"context"
	"net/http"
	"time"

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
	supplySvc *service.SupplyService,
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
	// Cancel context-aware REST work when the database is locked or an upstream
	// dependency stops responding. WebSocket is excluded because it intentionally
	// remains open.
	r.Use(middleware.RequestTimeout(30 * time.Second))

	r.GET("/api/v1/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	// Readiness is intentionally unauthenticated so deployment probes and the
	// native client can distinguish a live process from a usable database.
	r.GET("/api/v1/health/ready", func(c *gin.Context) {
		sqlDB, err := db.DB()
		if err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "not_ready", "database": "unavailable"})
			return
		}
		pingCtx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()
		if err := sqlDB.PingContext(pingCtx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "not_ready", "database": "unavailable"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ready", "database": "ok"})
	})

	authHandler := handler.NewAuthHandler(authSvc)
	dashboardHandler := handler.NewDashboardHandler(db)
	elderHandler := handler.NewElderHandler(elderSvc)
	resourceHandler := handler.NewResourceHandler(resourceSvc)
	taskHandler := handler.NewTaskHandler(taskSvc, hub)
	healthHandler := handler.NewHealthHandler(healthSvc, hub)
	wsHandler := handler.NewWSHandler(hub, cfg.JWT.Secret)
	streamMgr := iot.NewStreamManager(cfg.Stream, cfg.JWT.Secret)
	iotHandler := handler.NewIotHandler(iotSvc, streamMgr)
	m4Handler := handler.NewM4Handler(scheduleSvc, financeSvc, medicationSvc, auditSvc)
	supplyHandler := handler.NewSupplyHandler(supplySvc)
	aiHandler := handler.NewAIHandler(aiSvc)
	aiConfigHandler := handler.NewAIConfigHandler(db, &cfg.AI)
	aiUsageHandler := handler.NewAIUsageHandler(aiSvc)
	aiAdminHandler := handler.NewAIAdminHandler(aiSvc)
	careHandler := handler.NewCareHandler(careSvc)
	photoSvc := service.NewAdmissionPhotoService(db, cfg.Server.UploadDir)
	admissionHandler := handler.NewAdmissionHandler(admissionSvc, photoSvc)
	notificationHandler := handler.NewNotificationHandler(notificationSvc)
	messageHandler := handler.NewMessageHandler(messageSvc, hub, userRepo)
	systemHandler := handler.NewSystemHandler()
	roleHandler := handler.NewRoleHandler(db)
	userHandler := handler.NewUserHandler(db)
	areaHandler := handler.NewAreaHandler(db)
	carePackageHandler := handler.NewCarePackageHandler(db)

	// 访问校验封装
	perm := func(code string) gin.HandlerFunc { return middleware.RequirePermission(userRepo, code) }

	// 公开：登录
	r.POST("/api/v1/auth/login", authHandler.Login)
	// 公共展示屏：仅返回脱敏聚合数据，无需登录。
	r.GET("/api/v1/public/dashboard", dashboardHandler.PublicSummary)
	// WebSocket 实时推送：token 经 query 或 Authorization 头，由 WSHandler 自行校验
	r.GET("/api/v1/ws", wsHandler.Serve)
	// 摄像头 HLS 预览分片：播放器不带 Authorization 头，改用签名令牌（放在路径里，随相对分片请求自动携带）
	r.GET("/api/v1/iot/preview/:id/:token/:file", iotHandler.ServeStream)

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
		authed.GET("/roles", perm("admin:all"), roleHandler.List)
		authed.GET("/permissions", perm("admin:all"), roleHandler.ListPermissions)
		authed.POST("/roles", perm("admin:all"), roleHandler.Create)
		authed.PUT("/roles/:id", perm("admin:all"), roleHandler.Update)
		authed.DELETE("/roles/:id", perm("admin:all"), roleHandler.Delete)
		authed.PATCH("/roles/:id/status", perm("admin:all"), roleHandler.SetStatus)
		authed.GET("/users", perm("admin:all"), userHandler.List)
		authed.POST("/users", perm("admin:all"), userHandler.Create)
		authed.PUT("/users/:id/roles", perm("admin:all"), userHandler.UpdateRoles)
		authed.PATCH("/users/:id/status", perm("admin:all"), userHandler.SetStatus)
		authed.GET("/admin/ai/configs", perm("admin:all"), aiConfigHandler.List)
		authed.POST("/admin/ai/configs", perm("admin:all"), aiConfigHandler.Create)
		authed.PUT("/admin/ai/configs/:id", perm("admin:all"), aiConfigHandler.Update)
		authed.DELETE("/admin/ai/configs/:id", perm("admin:all"), aiConfigHandler.Delete)
		authed.GET("/admin/ai/usage/summary", perm("admin:all"), aiUsageHandler.Summary)
		authed.GET("/admin/ai/usage/models", perm("admin:all"), aiUsageHandler.Models)
		authed.GET("/admin/ai/connection", perm("admin:all"), aiAdminHandler.Connection)
		authed.PUT("/admin/ai/connection", perm("admin:all"), aiAdminHandler.UpdateConnection)
		authed.GET("/admin/ai/rag/datasets", perm("admin:all"), aiAdminHandler.ListRAGDatasets)
		authed.GET("/admin/ai/llm/models", perm("admin:all"), aiAdminHandler.ListProviderModels)

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
		authed.POST("/beds", perm("admin:all"), resourceHandler.CreateBed)
		authed.DELETE("/beds/:id", perm("admin:all"), resourceHandler.DeleteBed)
		areas := authed.Group("/areas", perm("elder:read"))
		areas.GET("", areaHandler.List)
		areas.GET("/tree", areaHandler.List)
		areas.POST("", perm("admin:all"), areaHandler.Create)
		areas.PUT("/:id", perm("admin:all"), areaHandler.Update)
		areas.DELETE("/:id", perm("admin:all"), areaHandler.Delete)
		packages := authed.Group("/care-package-templates", perm("task:read"))
		packages.GET("", carePackageHandler.ListTemplates)
		packages.POST("", perm("admin:all"), carePackageHandler.CreateTemplate)
		packages.PUT("/:id", perm("admin:all"), carePackageHandler.UpdateTemplate)
		packages.POST("/:id/items", perm("admin:all"), carePackageHandler.AddTemplateItem)
		packages.DELETE("/:id/items/:itemId", perm("admin:all"), carePackageHandler.DeleteTemplateItem)
		elderPackages := authed.Group("/elders/:id/care-package-subscriptions", perm("task:read"))
		elderPackages.GET("", carePackageHandler.ListSubscriptions)
		elderPackages.POST("", perm("plan:manage"), carePackageHandler.CreateSubscription)

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
		// 简化办理入住：独立于完整 A/B/C 能力评估，不伪造评估分数。
		authed.GET("/admission-intakes", perm("admission:read"), admissionHandler.ListIntakes)
		authed.POST("/admission-intakes/photos", perm("admission:write"), admissionHandler.UploadIntakePhoto)
		authed.DELETE("/admission-intakes/photos", perm("admission:write"), admissionHandler.DeletePendingIntakePhoto)
		authed.POST("/admission-intakes", perm("admission:write"), admissionHandler.CreateIntake)
		authed.GET("/admission-intakes/:id", perm("admission:read"), admissionHandler.GetIntake)
		authed.GET("/admission-intakes/:id/photos", perm("admission:read"), admissionHandler.ListIntakePhotos)
		authed.GET("/admission-intake-photos/:id/content", perm("admission:read"), admissionHandler.IntakePhotoContent)
		authed.GET("/notifications", notificationHandler.List)
		authed.PATCH("/notifications/:id/read", notificationHandler.MarkRead)
		authed.GET("/messages", messageHandler.List)
		authed.POST("/messages", messageHandler.Send)
		authed.PATCH("/messages/:id/read", messageHandler.MarkRead)
		authed.GET("/message-contacts", messageHandler.Contacts)

		// 物联网：设备/告警读写
		authed.GET("/iot/devices", perm("alert:read"), iotHandler.ListDevices)
		authed.POST("/iot/devices", perm("admin:all"), iotHandler.CreateDevice)
		authed.PATCH("/iot/devices/:id", perm("admin:all"), iotHandler.UpdateDevice)
		authed.GET("/iot/devices/:id/signals", perm("alert:read"), iotHandler.ListSignals)
		authed.GET("/iot/devices/:id/preview", perm("admin:all"), iotHandler.Preview)
		authed.POST("/iot/devices/:id/probe", perm("admin:all"), iotHandler.Probe)
		authed.DELETE("/iot/devices/:id", perm("admin:all"), iotHandler.DeleteDevice)
		authed.GET("/alerts", perm("alert:read"), iotHandler.ListAlerts)
		authed.GET("/alerts/:id/actions", perm("alert:read"), iotHandler.ListAlertActions)
		authed.POST("/alerts/:id/actions", perm("alert:handle"), iotHandler.CreateAlertAction)
		authed.PATCH("/alerts/:id/handle", perm("alert:handle"), iotHandler.HandleAlert)
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

		// ---- 照护 AI（登录即可问）----
		authed.POST("/ai/chat", aiHandler.Chat)
		authed.GET("/ai/models", aiHandler.ListModels)
		authed.GET("/ai/suggestions", aiHandler.ListSuggestions)
		authed.GET("/ai/conversations", aiHandler.ListConversations)
		authed.POST("/ai/conversations", aiHandler.CreateConversation)
		authed.DELETE("/ai/conversations/:id", aiHandler.DeleteConversation)
		authed.GET("/ai/conversations/:id/messages", aiHandler.ListMessages)
		authed.POST("/ai/conversations/:id/messages", aiHandler.SendMessage)
	}

	return r
}
