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

type aiEndpointProbeReq struct {
	BaseURL string   `json:"base_url"`
	APIKey  string   `json:"api_key"`
	Models  []string `json:"models"`
}

// ProbeModels POST /api/v1/admin/ai/llm/models 用表单值探测模型清单（保存前测试）。
func (h *AIAdminHandler) ProbeModels(c *gin.Context) {
	var req aiEndpointProbeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	models, err := h.svc.ProbeProviderModels(c.Request.Context(), req.BaseURL, req.APIKey)
	if err != nil {
		h.failProxy(c, err, "请填写模型服务 Base URL", "模型服务连接失败，请检查地址与密钥")
		return
	}
	OK(c, models)
}

// TestModels POST /api/v1/admin/ai/llm/test 对所选模型逐个发起最小对话补全测试。
func (h *AIAdminHandler) TestModels(c *gin.Context) {
	var req aiEndpointProbeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if len(req.Models) == 0 {
		Fail(c, http.StatusBadRequest, 400, "请先选择要测试的模型")
		return
	}
	results, err := h.svc.TestProviderModels(c.Request.Context(), req.BaseURL, req.APIKey, req.Models)
	if err != nil {
		h.failProxy(c, err, "请填写模型服务 Base URL", "模型服务连接失败，请检查地址与密钥")
		return
	}
	OK(c, results)
}

// ProbeRagDatasets POST /api/v1/admin/ai/rag/datasets 用表单值探测知识库清单（保存前测试）。
func (h *AIAdminHandler) ProbeRagDatasets(c *gin.Context) {
	var req aiEndpointProbeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	datasets, err := h.svc.ProbeRAGDatasets(c.Request.Context(), req.BaseURL, req.APIKey)
	if err != nil {
		h.failProxy(c, err, "请填写 Dify RAG URL", "知识库连接失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, datasets)
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

// failProxy 探测/测试类失败统一以 HTTP 200 + 业务码返回，让网关编辑弹窗
// 能把具体原因（未配置/连接失败）原样展示给管理员，而不是被网络层吞掉。
func (h *AIAdminHandler) failProxy(c *gin.Context, err error, notConfiguredMsg, unavailableMsg string) {
	switch {
	case errors.Is(err, service.ErrRAGNotConfigured), errors.Is(err, service.ErrModelSourceNotConfigured):
		respond(c, http.StatusOK, 400, notConfiguredMsg, nil)
	case errors.Is(err, service.ErrRAGUnavailable), errors.Is(err, service.ErrModelSourceUnavailable):
		respond(c, http.StatusOK, 502, unavailableMsg, nil)
	default:
		respond(c, http.StatusOK, 500, "AI 管理代理请求失败", nil)
	}
}
