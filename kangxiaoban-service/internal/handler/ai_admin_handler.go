package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// AIAdminHandler serves admin AI management surfaces: the unified tenant
// connection, the Dify knowledge-base inventory and the OpenAI-compatible
// (vLLM) model inventory. Provider keys stay server-side; the admin client
// only sees configured flags and the fetched lists.
type AIAdminHandler struct {
	svc *service.AIService
}

func NewAIAdminHandler(svc *service.AIService) *AIAdminHandler {
	return &AIAdminHandler{svc: svc}
}

func connectionView(row *model.AIConnection) gin.H {
	return gin.H{
		"provider":               row.Provider,
		"base_url":               row.BaseURL,
		"api_key_configured":     row.APIKeyEncrypted != "",
		"rag_enabled":            row.RAGEnabled,
		"rag_base_url":           row.RAGBaseURL,
		"rag_dataset_id":         row.RAGDatasetID,
		"rag_api_key_configured": row.RAGAPIKeyEncrypted != "",
		"enabled":                row.Enabled,
	}
}

// Connection GET /api/v1/admin/ai/connection
func (h *AIAdminHandler) Connection(c *gin.Context) {
	row, err := h.svc.Connection(c.Request.Context())
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "AI 连接加载失败")
		return
	}
	OK(c, connectionView(row))
}

type aiConnectionUpdateReq struct {
	Provider     string `json:"provider"`
	BaseURL      string `json:"base_url"`
	APIKey       string `json:"api_key"`
	RAGEnabled   bool   `json:"rag_enabled"`
	RAGBaseURL   string `json:"rag_base_url"`
	RAGDatasetID string `json:"rag_dataset_id"`
	RAGAPIKey    string `json:"rag_api_key"`
	Enabled      *bool  `json:"enabled"`
}

// UpdateConnection PUT /api/v1/admin/ai/connection
func (h *AIAdminHandler) UpdateConnection(c *gin.Context) {
	var req aiConnectionUpdateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	enabled := true
	if req.Enabled != nil {
		enabled = *req.Enabled
	}
	row, err := h.svc.UpdateConnection(c.Request.Context(), service.AIConnectionUpdate{
		Provider: req.Provider, BaseURL: req.BaseURL, APIKey: req.APIKey,
		RAGEnabled: req.RAGEnabled, RAGBaseURL: req.RAGBaseURL,
		RAGDatasetID: req.RAGDatasetID, RAGAPIKey: req.RAGAPIKey,
		Enabled: enabled,
	})
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "AI 连接保存失败")
		return
	}
	OK(c, connectionView(row))
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

// ListProviderModels GET /api/v1/admin/ai/llm/models
func (h *AIAdminHandler) ListProviderModels(c *gin.Context) {
	models, err := h.svc.ListProviderModels(c.Request.Context())
	if err != nil {
		h.failProxy(c, err, "未配置模型服务连接，请先在「编辑模型索引」中填写 vLLM 地址", "模型服务连接失败，请检查地址与密钥")
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
