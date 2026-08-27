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
func New(cfg *config.Config, userRepo *repository.UserRepository, authSvc *service.AuthService) *gin.Engine {
	r := gin.Default()

	r.GET("/api/v1/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	authHandler := handler.NewAuthHandler(authSvc)
	dashboardHandler := handler.NewDashboardHandler()

	// 公开：登录
	r.POST("/api/v1/auth/login", authHandler.Login)

	// 需认证
	authed := r.Group("/api/v1")
	authed.Use(middleware.JWTAuth(cfg.JWT.Secret))
	{
		authed.GET("/auth/me", authHandler.Me)
		authed.GET("/dashboard/summary",
			middleware.RequirePermission(userRepo, "dash:read"),
			dashboardHandler.Summary)
	}

	return r
}