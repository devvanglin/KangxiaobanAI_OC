package router

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/handler"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
)

// New 组装路由。
func New(cfg *config.Config, userRepo *repository.UserRepository,
	authSvc *service.AuthService, elderSvc *service.ElderService,
	resourceSvc *service.ResourceService, taskSvc *service.TaskService,
	healthSvc *service.HealthService,
) *gin.Engine {
	r := gin.Default()

	r.GET("/api/v1/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	authHandler := handler.NewAuthHandler(authSvc)
	dashboardHandler := handler.NewDashboardHandler()
	elderHandler := handler.NewElderHandler(elderSvc)
	resourceHandler := handler.NewResourceHandler(resourceSvc)
	taskHandler := handler.NewTaskHandler(taskSvc)
	healthHandler := handler.NewHealthHandler(healthSvc)

	// 访问校验封装
	perm := func(code string) gin.HandlerFunc { return middleware.RequirePermission(userRepo, code) }

	// 公开：登录
	r.POST("/api/v1/auth/login", authHandler.Login)

	// 需认证
	authed := r.Group("/api/v1")
	authed.Use(middleware.JWTAuth(cfg.JWT.Secret))
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
	}

	return r
}