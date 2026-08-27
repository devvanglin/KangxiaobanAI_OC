package handler

import (
	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
)

// DashboardHandler 工作台摘要（M0 仅演示 RBAC 保护，后续里程碑接真实统计）。
type DashboardHandler struct{}

func NewDashboardHandler() *DashboardHandler {
	return &DashboardHandler{}
}

// Summary GET /api/v1/dashboard/summary —— 需要 dash:read 权限。
func (h *DashboardHandler) Summary(c *gin.Context) {
	cl, _ := middleware.ClaimsFrom(c)
	OK(c, gin.H{
		"roles": cl.Roles,
		"todo":  0,
		"risk":  0,
		"kpi": gin.H{
			"note": "M0 骨架演示：统计数据将由 M1 长者/任务模块接入",
		},
	})
}