package handler

import (
	"errors"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/service"
)

// AIAdminHandler serves admin AI management surfaces: the read-only
// model-service/Dify connection status, the Dify knowledge-base inventory and
// the OpenAI-compatible (vLLM/NewAPI) model inventory. Endpoints and keys live
// only in server-side .env; the admin client sees configured flags and the
// fetched lists, never the values themselves.
type AIAdminHandler struct {
	svc *service.AIService
}

func NewAIAdminHandler(svc *service.AIService) *AIAdminHandler {
	return &AIAdminHandler{svc: svc}
}

// Connection GET /api/v1/admin/ai/connection
// 只读返回服务端 .env 配置的连接状态（与 MinIO「存储」同款）；连接改由
// 运维在服务器环境变量中配置，客户端无写入入口。
func (h *AIAdminHandler) Connection(c *gin.Context) {
	OK(c, h.svc.ConnectionStatus())
}

// ToolsList GET /api/v1/admin/ai/tools
// 平台内置工具清单（名称/描述/权限门槛/模式/当前可用状态）。
func (h *AIAdminHandler) ToolsList(c *gin.Context) {
	OK(c, h.svc.ListAgentTools(c.Request.Context()))
}

// Sandbox GET /api/v1/admin/ai/sandbox
// 返回生效的沙箱设置（管理端设置行优先，未配置回落 .env）。
func (h *AIAdminHandler) Sandbox(c *gin.Context) {
	view, err := h.svc.SandboxSetting(c.Request.Context())
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "沙箱设置加载失败")
		return
	}
	OK(c, view)
}

type aiSandboxUpdateReq struct {
	Enabled bool   `json:"enabled"`
	Domain  string `json:"domain"`
	Protocol string `json:"protocol"`
	Image   string `json:"image"`
	APIKey  string `json:"api_key"`
}

// UpdateSandbox PUT /api/v1/admin/ai/sandbox
// 保存沙箱设置（密钥加密落库、永不返回；留空表示保留原密钥）。
func (h *AIAdminHandler) UpdateSandbox(c *gin.Context) {
	var req aiSandboxUpdateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	view, err := h.svc.UpdateSandboxSetting(c.Request.Context(), service.AISandboxSettingInput{
		Enabled: req.Enabled, Domain: req.Domain, Protocol: req.Protocol,
		Image: req.Image, APIKey: req.APIKey,
	})
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "沙箱设置保存失败")
		return
	}
	OK(c, view)
}

// SandboxProbe POST /api/v1/admin/ai/sandbox/probe
// 轻量探测沙箱控制面连通性。
func (h *AIAdminHandler) SandboxProbe(c *gin.Context) {
	result, err := h.svc.SandboxProbe(c.Request.Context())
	if err != nil {
		h.failProxy(c, err, "沙箱控制面地址未配置，请先在「沙箱」中填写", "沙箱控制面连接失败")
		return
	}
	OK(c, result)
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

type aiPromptReq struct {
	RoleScope string `json:"role_scope"`
	Title     string `json:"title"`
	Prompt    string `json:"prompt"`
	Enabled   bool   `json:"enabled"`
}

// AdminPromptList GET /api/v1/admin/ai/prompts?role=caregiver|doctor
func (h *AIAdminHandler) AdminPromptList(c *gin.Context) {
	rows, err := h.svc.AdminListPrompts(c.Request.Context(), c.Query("role"))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "提示词列表加载失败")
		return
	}
	OK(c, rows)
}

// AdminPromptCreate POST /api/v1/admin/ai/prompts
func (h *AIAdminHandler) AdminPromptCreate(c *gin.Context) {
	var req aiPromptReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminCreatePrompt(c.Request.Context(), service.AdminPromptInput{
		RoleScope: req.RoleScope, Title: req.Title, Prompt: req.Prompt, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "提示词创建失败")
		return
	}
	OK(c, row)
}

// AdminPromptUpdate PUT /api/v1/admin/ai/prompts/:id
func (h *AIAdminHandler) AdminPromptUpdate(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	var req aiPromptReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminUpdatePrompt(c.Request.Context(), uint(id), service.AdminPromptInput{
		RoleScope: req.RoleScope, Title: req.Title, Prompt: req.Prompt, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "提示词不存在")
			return
		}
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "提示词保存失败")
		return
	}
	OK(c, row)
}

// AdminPromptDelete DELETE /api/v1/admin/ai/prompts/:id
func (h *AIAdminHandler) AdminPromptDelete(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if err := h.svc.AdminDeletePrompt(c.Request.Context(), uint(id)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "提示词不存在")
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "提示词删除失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

// ---- Skills 管理 ----

type aiSkillReq struct {
	RoleScope    string `json:"role_scope"`
	Code         string `json:"code"`
	Name         string `json:"name"`
	Description  string `json:"description"`
	Version      string `json:"version"`
	Tags         string `json:"tags"`
	Instructions string `json:"instructions"`
	SortOrder    int    `json:"sort_order"`
	Enabled      bool   `json:"enabled"`
}

// AdminSkillList GET /api/v1/admin/ai/skills?role=caregiver|doctor|all
func (h *AIAdminHandler) AdminSkillList(c *gin.Context) {
	rows, err := h.svc.AdminListSkills(c.Request.Context(), c.Query("role"))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "技能列表加载失败")
		return
	}
	OK(c, rows)
}

// AdminSkillCreate POST /api/v1/admin/ai/skills
func (h *AIAdminHandler) AdminSkillCreate(c *gin.Context) {
	var req aiSkillReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminCreateSkill(c.Request.Context(), service.AISkillInput{
		RoleScope: req.RoleScope, Code: req.Code, Name: req.Name, Description: req.Description,
		Version: req.Version, Tags: req.Tags, Instructions: req.Instructions,
		SortOrder: req.SortOrder, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "技能创建失败")
		return
	}
	OK(c, row)
}

// AdminSkillUpdate PUT /api/v1/admin/ai/skills/:id
func (h *AIAdminHandler) AdminSkillUpdate(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	var req aiSkillReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminUpdateSkill(c.Request.Context(), uint(id), service.AISkillInput{
		RoleScope: req.RoleScope, Code: req.Code, Name: req.Name, Description: req.Description,
		Version: req.Version, Tags: req.Tags, Instructions: req.Instructions,
		SortOrder: req.SortOrder, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "技能不存在")
			return
		}
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "技能保存失败")
		return
	}
	OK(c, row)
}

// AdminSkillDelete DELETE /api/v1/admin/ai/skills/:id
func (h *AIAdminHandler) AdminSkillDelete(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if err := h.svc.AdminDeleteSkill(c.Request.Context(), uint(id)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "技能不存在")
			return
		}
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "技能删除失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

// ---- MCP 管理 ----

type aiMCPServerReq struct {
	Name     string `json:"name"`
	Endpoint string `json:"endpoint"`
	APIKey   string `json:"api_key"`
	Enabled  bool   `json:"enabled"`
}

// AdminMCPServerList GET /api/v1/admin/ai/mcp/servers
func (h *AIAdminHandler) AdminMCPServerList(c *gin.Context) {
	rows, err := h.svc.AdminListMCPServers(c.Request.Context())
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "MCP 服务列表加载失败")
		return
	}
	OK(c, rows)
}

// AdminMCPServerCreate POST /api/v1/admin/ai/mcp/servers
func (h *AIAdminHandler) AdminMCPServerCreate(c *gin.Context) {
	var req aiMCPServerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminCreateMCPServer(c.Request.Context(), service.AdminMCPServerInput{
		Name: req.Name, Endpoint: req.Endpoint, APIKey: req.APIKey, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "MCP 服务创建失败")
		return
	}
	OK(c, row)
}

// AdminMCPServerUpdate PUT /api/v1/admin/ai/mcp/servers/:id
func (h *AIAdminHandler) AdminMCPServerUpdate(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	var req aiMCPServerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminUpdateMCPServer(c.Request.Context(), uint(id), service.AdminMCPServerInput{
		Name: req.Name, Endpoint: req.Endpoint, APIKey: req.APIKey, Enabled: req.Enabled,
	})
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "MCP 服务不存在")
			return
		}
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "MCP 服务保存失败")
		return
	}
	OK(c, row)
}

// AdminMCPServerDelete DELETE /api/v1/admin/ai/mcp/servers/:id
func (h *AIAdminHandler) AdminMCPServerDelete(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if err := h.svc.AdminDeleteMCPServer(c.Request.Context(), uint(id)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "MCP 服务不存在")
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "MCP 服务删除失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

// AdminMCPServerProbe POST /api/v1/admin/ai/mcp/servers/:id/probe
func (h *AIAdminHandler) AdminMCPServerProbe(c *gin.Context) {
	id, parseErr := strconv.ParseUint(c.Param("id"), 10, 64)
	if parseErr != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	row, err := h.svc.AdminProbeMCPServer(c.Request.Context(), uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "MCP 服务不存在")
			return
		}
		Fail(c, http.StatusInternalServerError, 500, "MCP 探测失败")
		return
	}
	OK(c, row)
}

// RagEmbeddingModels GET /api/v1/admin/ai/rag/embedding-models
func (h *AIAdminHandler) RagEmbeddingModels(c *gin.Context) {
	models, err := h.svc.ListRAGModels(c.Request.Context(), "text-embedding")
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "嵌入模型列表获取失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, models)
}

// RagRerankModels GET /api/v1/admin/ai/rag/rerank-models
func (h *AIAdminHandler) RagRerankModels(c *gin.Context) {
	models, err := h.svc.ListRAGModels(c.Request.Context(), "rerank")
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "重排模型列表获取失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, models)
}

// UploadRagDocument POST /api/v1/admin/ai/rag/datasets/:datasetId/documents
// multipart 转发：file + embedding_model（解析模型，可选）。
func (h *AIAdminHandler) UploadRagDocument(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "请选择要上传的文件")
		return
	}
	source, err := file.Open()
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "文件读取失败")
		return
	}
	content, err := io.ReadAll(source)
	source.Close()
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "文件读取失败")
		return
	}
	result, err := h.svc.UploadRAGDocument(c.Request.Context(), c.Param("datasetId"),
		file.Filename, content, c.PostForm("data"))
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "文档上传失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, result)
}

type aiCreateDatasetReq struct {
	Name              string                 `json:"name"`
	IndexingTechnique string                 `json:"indexing_technique"`
	EmbeddingModel    string                 `json:"embedding_model"`
	RetrievalModel    map[string]interface{} `json:"retrieval_model"`
}

// CreateRagDataset POST /api/v1/admin/ai/rag/datasets/create 创建即用型知识库。
func (h *AIAdminHandler) CreateRagDataset(c *gin.Context) {
	var req aiCreateDatasetReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	result, err := h.svc.CreateRAGDataset(c.Request.Context(), service.CreateRAGDatasetInput{
		Name: req.Name, IndexingTechnique: req.IndexingTechnique,
		EmbeddingModel: req.EmbeddingModel, RetrievalModel: req.RetrievalModel,
	})
	if err != nil {
		if errors.Is(err, service.ErrAIValidation) {
			Fail(c, http.StatusBadRequest, 400, err.Error())
			return
		}
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "知识库创建失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, result)
}

// RagIndexingStatus GET /api/v1/admin/ai/rag/datasets/:datasetId/documents/:batch/indexing-status
func (h *AIAdminHandler) RagIndexingStatus(c *gin.Context) {
	result, err := h.svc.GetRAGIndexingStatus(c.Request.Context(),
		c.Param("datasetId"), c.Param("batch"))
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "解析进度获取失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, result)
}

// RagProxy ANY /api/v1/admin/ai/rag/proxy/*path
// 通用知识库 API 转发：更新/删除知识库、文档管理、分段、元数据、标签、检索测试等
// 全部端点都经此代理（仅管理端可用，密钥注入在服务端）。
func (h *AIAdminHandler) RagProxy(c *gin.Context) {
	subPath := strings.Trim(c.Param("path"), "/")
	if subPath == "" {
		Fail(c, http.StatusBadRequest, 400, "缺少 API 路径")
		return
	}
	allowed := strings.HasPrefix(subPath, "datasets") || strings.HasPrefix(subPath, "workspaces/") ||
		strings.HasPrefix(subPath, "tags")
	if !allowed {
		Fail(c, http.StatusBadRequest, 400, "不支持的 API 路径")
		return
	}
	var body []byte
	if c.Request.Method == http.MethodPost || c.Request.Method == http.MethodPut ||
		c.Request.Method == http.MethodPatch {
		raw, readErr := io.ReadAll(c.Request.Body)
		if readErr != nil {
			Fail(c, http.StatusBadRequest, 400, "请求体读取失败")
			return
		}
		body = raw
	}
	result, upstreamStatus, err := h.svc.RagProxyAPI(c.Request.Context(), c.Request.Method,
		subPath, c.Request.URL.RawQuery, body)
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "知识库请求失败，请检查 Dify 地址与密钥")
		return
	}
	if upstreamStatus < 200 || upstreamStatus >= 300 {
		// 上游业务错误：把 Dify 的 message 原样带给前端（业务码 <500，避免被网络层吞掉）。
		message := "知识库请求失败"
		if result != nil {
			if m, ok := result["message"].(string); ok && m != "" {
				message = m
			}
		}
		respond(c, http.StatusOK, 400, message, nil)
		return
	}
	if result == nil {
		result = gin.H{}
	}
	OK(c, result)
}

// ListRAGDatasets GET /api/v1/admin/ai/rag/datasets
func (h *AIAdminHandler) ListRAGDatasets(c *gin.Context) {
	datasets, err := h.svc.ListRAGDatasets(c.Request.Context())
	if err != nil {
		h.failProxy(c, err, "未配置 Dify RAG 连接，请在服务端 .env 配置 KXB_DIFY_BASE_URL / KXB_DIFY_API_KEY 后重启服务", "知识库连接失败，请检查 Dify 地址与密钥")
		return
	}
	OK(c, datasets)
}

// ListProviderModels GET /api/v1/admin/ai/llm/models
func (h *AIAdminHandler) ListProviderModels(c *gin.Context) {
	models, err := h.svc.ListProviderModels(c.Request.Context())
	if err != nil {
		h.failProxy(c, err, "未配置模型服务连接，请在服务端 .env 配置 KXB_AI_BASE_URL / KXB_AI_API_KEY 后重启服务", "模型服务连接失败，请检查地址与密钥")
		return
	}
	OK(c, models)
}

// failProxy 探测/测试类失败统一以 HTTP 200 + 业务码返回，让管理端能把具体
// 原因（未配置/连接失败）原样展示给管理员，而不是被网络层吞掉。
func (h *AIAdminHandler) failProxy(c *gin.Context, err error, notConfiguredMsg, unavailableMsg string) {
	// 业务码必须 < 500：前端网络层把 >=500 的业务码转成通用异常，会吞掉具体原因。
	switch {
	case errors.Is(err, service.ErrRAGNotConfigured), errors.Is(err, service.ErrModelSourceNotConfigured):
		respond(c, http.StatusOK, 400, notConfiguredMsg, nil)
	case errors.Is(err, service.ErrRAGUnavailable), errors.Is(err, service.ErrModelSourceUnavailable):
		statusHint := ""
		if match := regexp.MustCompile(`HTTP \d+$`).FindStringSubmatch(err.Error()); len(match) > 0 {
			statusHint = "（上游 " + match[0] + "，密钥可能已失效，请检查服务端 .env 配置）"
		}
		respond(c, http.StatusOK, 400, unavailableMsg+statusHint, nil)
	default:
		respond(c, http.StatusOK, 400, "AI 管理代理请求失败", nil)
	}
}
