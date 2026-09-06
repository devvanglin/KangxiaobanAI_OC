package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// AIAdminHandler serves admin AI connection proxies: Dify knowledge-base
// inventory and OpenAI-compatible (vLLM) model inventory. Provider keys stay
// server-side; the admin client only sees the fetched lists.
type AIAdminHandler struct {
	svc *service.AIService
}

func NewAIAdminHandler(svc *service.AIService) *AIAdminHandler {
	return &AIAdminHandler{svc: svc}
}

// ListRAGDatasets GET /api/v1/admin/ai/rag/datasets
func (h *AIAdminHandler) ListRAGDatasets(c *gin.Context) {
	datasets, err := h.svc.ListRAGDatasets(c.Request.Context())
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请先在「编辑模型索引」中填写", "知识库连接失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, datasets)
}

// ListProviderModels GET /api/v1/admin/ai/llm/models?role=caregiver|doctor
func (h *AIAdminHandler) ListProviderModels(c *gin.Context) {
	models, err := h.svc.ListProviderModels(c.Request.Context(), c.Query("role"))
	if err != nil {
		h.failProxy(c, err, "该角色未配置模型服务连接，请先在「编辑模型索引」中填写 vLLM 地址", "模型服务连接失败，请检查地址与密钥")
		return
	}
	OK(c, models)
}

func (h *AIAdminHandler) failProxy(c *gin.Context, err error, notConfiguredMsg, unavailableMsg string) {
	switch {
	case errors.Is(err, service.ErrRAGNotConfigured), errors.Is(err, service.ErrModelSourceNotConfigured):
		Fail(c, http.StatusBadRequest, 400, notConfiguredMsg)
	case errors.Is(err, service.ErrRAGUnavailable), errors.Is(err, service.ErrModelSourceUnavailable):
		Fail(c, http.StatusBadGateway, 502, unavailableMsg)
	default:
		Fail(c, http.StatusInternalServerError, 500, "AI 管理代理请求失败")
	}
}
