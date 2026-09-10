package handler

import (
	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/system"
)

// SystemHandler exposes host metrics for the protected administrator console.
type SystemHandler struct{}

func NewSystemHandler() *SystemHandler { return &SystemHandler{} }

// Monitor GET /api/v1/system/monitor returns current server and process metrics.
func (h *SystemHandler) Monitor(c *gin.Context) {
	OK(c, system.Collect())
}
