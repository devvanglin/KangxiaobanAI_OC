package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/auth"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// AIHandler 照护 AI 对话。
type AIHandler struct {
	svc *service.AIService
}

func NewAIHandler(svc *service.AIService) *AIHandler {
	return &AIHandler{svc: svc}
}

// ListSuggestions GET /api/v1/ai/suggestions
func (h *AIHandler) ListSuggestions(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	ctx := service.WithAIRoleScope(c.Request.Context(), aiRoleScope(claims))
	items, err := h.svc.ListPromptSuggestions(ctx)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询 AI 快捷提示失败")
		return
	}
	OK(c, gin.H{"list": items})
}

type aiReq struct {
	Question string `json:"question" binding:"required"`
}

type aiConversationReq struct {
	Title string `json:"title"`
}

type aiMessageReq struct {
	Content string `json:"content" binding:"required"`
}

// Chat POST /api/v1/ai/chat
func (h *AIHandler) Chat(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	var req aiReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误: question 必填")
		return
	}
	ctx := service.WithAIRoleScope(c.Request.Context(), aiRoleScope(claims))
	answer, model, err := h.svc.ChatAndPersistDefault(ctx, claims.UserID, req.Question)
	if err != nil {
		handleAIConversationError(c, err, "AI 暂不可用")
		return
	}
	OK(c, gin.H{"answer": answer, "model": model, "note": "AI 回答仅供参考，不构成临床诊断"})
}

// ListConversations GET /api/v1/ai/conversations
func (h *AIHandler) ListConversations(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	items, err := h.svc.ListConversations(c.Request.Context(), claims.UserID)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询 AI 会话失败")
		return
	}
	OK(c, gin.H{"list": items})
}

// CreateConversation POST /api/v1/ai/conversations
func (h *AIHandler) CreateConversation(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	var req aiConversationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	conversation, err := h.svc.CreateConversation(c.Request.Context(), claims.UserID, req.Title)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建 AI 会话失败")
		return
	}
	OK(c, conversation)
}

// DeleteConversation DELETE /api/v1/ai/conversations/:id
func (h *AIHandler) DeleteConversation(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	id, valid := parseAIConversationID(c)
	if !valid {
		return
	}
	if err := h.svc.DeleteConversation(c.Request.Context(), claims.UserID, id); err != nil {
		handleAIConversationError(c, err, "删除 AI 会话失败")
		return
	}
	OK(c, gin.H{"id": id, "deleted": true})
}

// ListMessages GET /api/v1/ai/conversations/:id/messages
func (h *AIHandler) ListMessages(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	id, valid := parseAIConversationID(c)
	if !valid {
		return
	}
	items, err := h.svc.ListMessages(c.Request.Context(), claims.UserID, id)
	if err != nil {
		handleAIConversationError(c, err, "查询 AI 消息失败")
		return
	}
	OK(c, gin.H{"list": items})
}

// SendMessage POST /api/v1/ai/conversations/:id/messages
func (h *AIHandler) SendMessage(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	id, valid := parseAIConversationID(c)
	if !valid {
		return
	}
	var req aiMessageReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Content) == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: content 必填")
		return
	}
	ctx := service.WithAIRoleScope(c.Request.Context(), aiRoleScope(claims))
	exchange, err := h.svc.SendMessage(ctx, claims.UserID, id, req.Content)
	if err != nil {
		handleAIConversationError(c, err, "发送 AI 消息失败")
		return
	}
	OK(c, gin.H{
		"conversation": exchange.Conversation, "user_message": exchange.UserMessage,
		"assistant_message": exchange.AssistantMessage, "answer": exchange.Answer,
		"model": exchange.Model, "note": "AI 回答仅供参考，不构成临床诊断",
	})
}

func aiRoleScope(claims *auth.Claims) string {
	for _, role := range claims.Roles {
		if role == "doctor" {
			return "doctor"
		}
	}
	return "caregiver"
}

func parseAIConversationID(c *gin.Context) (uint, bool) {
	raw, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || raw == 0 {
		Fail(c, http.StatusBadRequest, 400, "会话 id 参数错误")
		return 0, false
	}
	return uint(raw), true
}

func handleAIConversationError(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrAIConversationNotFound):
		Fail(c, http.StatusNotFound, 404, "AI 会话不存在")
	case errors.Is(err, service.ErrAIValidation):
		Fail(c, http.StatusBadRequest, 400, "参数错误")
	case errors.Is(err, service.ErrAIProviderUnavailable):
		Fail(c, http.StatusServiceUnavailable, 503, "AI 服务暂不可用")
	default:
		Fail(c, http.StatusInternalServerError, 500, fallback)
	}
}
