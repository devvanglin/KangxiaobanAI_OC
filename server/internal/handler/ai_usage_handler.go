package handler

import (
	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// AIUsageHandler serves read-only AI gateway usage aggregates for admin pages.
type AIUsageHandler struct {
	svc *service.AIService
}

func NewAIUsageHandler(svc *service.AIService) *AIUsageHandler {
	return &AIUsageHandler{svc: svc}
}

// Summary 返回当前租户的 AI 用量统计，用于大模型管理页指标卡片。
func (h *AIUsageHandler) Summary(c *gin.Context) {
	summary, err := h.svc.UsageSummary(c.Request.Context())
	if err != nil {
		Fail(c, 500, 500, "AI 用量统计加载失败")
		return
	}
	OK(c, summary)
}

// Models GET /api/v1/admin/ai/usage/models 返回今日逐模型用量，用于模型卡片。
func (h *AIUsageHandler) Models(c *gin.Context) {
	stats, err := h.svc.UsageByModel(c.Request.Context())
	if err != nil {
		Fail(c, 500, 500, "模型用量统计加载失败")
		return
	}
	OK(c, stats)
}
