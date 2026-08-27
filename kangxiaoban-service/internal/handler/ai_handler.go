package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// AIHandler 照护 AI 对话。
type AIHandler struct {
	svc *service.AIService
}

func NewAIHandler(svc *service.AIService) *AIHandler {
	return &AIHandler{svc: svc}
}

type aiReq struct {
	Question string `json:"question" binding:"required"`
}

// Chat POST /api/v1/ai/chat
func (h *AIHandler) Chat(c *gin.Context) {
	var req aiReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误: question 必填")
		return
	}
	answer, model, err := h.svc.Chat(c.Request.Context(), req.Question)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "AI 暂不可用")
		return
	}
	OK(c, gin.H{"answer": answer, "model": model, "note": "AI 回答仅供参考，不构成临床诊断"})
}