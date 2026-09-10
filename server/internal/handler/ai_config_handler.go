package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

type AIConfigHandler struct {
	db  *gorm.DB
	cfg *config.AIConfig
}

func NewAIConfigHandler(db *gorm.DB, cfg *config.AIConfig) *AIConfigHandler {
	return &AIConfigHandler{db: db, cfg: cfg}
}

type aiConfigView struct {
	model.AIModelConfig
	APIKeyConfigured    bool `json:"api_key_configured"`
	RAGAPIKeyConfigured bool `json:"rag_api_key_configured"`
}

func (h *AIConfigHandler) List(c *gin.Context) {
	query := h.db.WithContext(c.Request.Context()).Model(&model.AIModelConfig{})
	if role := strings.TrimSpace(c.Query("role_scope")); role != "" {
		query = query.Where("role_scope = ?", role)
	}
	var rows []model.AIModelConfig
	if err := query.Order("role_scope asc, is_default desc, id desc").Find(&rows).Error; err != nil {
		Fail(c, 500, 500, "查询 AI 配置失败")
		return
	}
	views := make([]aiConfigView, 0, len(rows))
	for _, row := range rows {
		views = append(views, aiConfigView{AIModelConfig: row, APIKeyConfigured: row.APIKeyEncrypted != "", RAGAPIKeyConfigured: row.RAGAPIKeyEncrypted != ""})
	}
	OK(c, gin.H{"list": views})
}

type aiConfigInput struct {
	RoleScope     string  `json:"role_scope" binding:"required"`
	Name          string  `json:"name" binding:"required"`
	Provider      string  `json:"provider" binding:"required"`
	BaseURL       string  `json:"base_url"`
	Model         string  `json:"model" binding:"required"`
	APIKey        string  `json:"api_key"`
	SystemPrompt  string  `json:"system_prompt"`
	ContextWindow int     `json:"context_window"`
	Temperature   float64 `json:"temperature"`
	Enabled       *bool   `json:"enabled"`
	Allowed       *bool   `json:"allowed"`
	IsDefault     *bool   `json:"is_default"`
	RAGEnabled    bool    `json:"rag_enabled"`
	RAGBaseURL    string  `json:"rag_base_url"`
	RAGDatasetID  string  `json:"rag_dataset_id"`
	RAGAPIKey     string  `json:"rag_api_key"`
}

func normalizeAIScope(scope string) bool { return scope == "caregiver" || scope == "doctor" }

func (h *AIConfigHandler) Create(c *gin.Context) {
	var input aiConfigInput
	if err := c.ShouldBindJSON(&input); err != nil || !normalizeAIScope(strings.TrimSpace(input.RoleScope)) || strings.TrimSpace(input.Name) == "" || strings.TrimSpace(input.Provider) == "" || strings.TrimSpace(input.Model) == "" {
		Fail(c, 400, 400, "角色、名称、Provider 和模型必填")
		return
	}
	apiKey, err := security.Encrypt(h.cfg.ConfigKey, input.APIKey)
	if err != nil {
		Fail(c, 500, 500, "API Key 加密失败")
		return
	}
	ragKey, err := security.Encrypt(h.cfg.ConfigKey, input.RAGAPIKey)
	if err != nil {
		Fail(c, 500, 500, "RAG Key 加密失败")
		return
	}
	enabled, allowed, defaulted := true, true, false
	if input.Enabled != nil {
		enabled = *input.Enabled
	}
	if input.Allowed != nil {
		allowed = *input.Allowed
	}
	if input.IsDefault != nil {
		defaulted = *input.IsDefault
	}
	row := &model.AIModelConfig{RoleScope: strings.TrimSpace(input.RoleScope), Name: strings.TrimSpace(input.Name), Provider: strings.TrimSpace(input.Provider), BaseURL: strings.TrimSpace(input.BaseURL), Model: strings.TrimSpace(input.Model), APIKeyEncrypted: apiKey, SystemPrompt: strings.TrimSpace(input.SystemPrompt), ContextWindow: input.ContextWindow, Temperature: input.Temperature, Enabled: enabled, Allowed: allowed, IsDefault: defaulted, RAGEnabled: input.RAGEnabled, RAGBaseURL: strings.TrimSpace(input.RAGBaseURL), RAGDatasetID: strings.TrimSpace(input.RAGDatasetID), RAGAPIKeyEncrypted: ragKey}
	if row.ContextWindow <= 0 {
		row.ContextWindow = 8192
	}
	if row.Temperature <= 0 {
		row.Temperature = 0.3
	}
	if err := h.db.WithContext(c.Request.Context()).Create(row).Error; err != nil {
		Fail(c, 409, 409, "AI 配置保存失败")
		return
	}
	OK(c, aiConfigView{AIModelConfig: *row, APIKeyConfigured: row.APIKeyEncrypted != "", RAGAPIKeyConfigured: row.RAGAPIKeyEncrypted != ""})
}

func (h *AIConfigHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input aiConfigInput
	if err := c.ShouldBindJSON(&input); err != nil || !normalizeAIScope(strings.TrimSpace(input.RoleScope)) || strings.TrimSpace(input.Name) == "" || strings.TrimSpace(input.Provider) == "" || strings.TrimSpace(input.Model) == "" {
		Fail(c, 400, 400, "角色、名称、Provider 和模型必填")
		return
	}
	db := h.db.WithContext(c.Request.Context())
	var row model.AIModelConfig
	if err := db.First(&row, uint(id)).Error; err != nil {
		Fail(c, http.StatusNotFound, 404, "AI 配置不存在")
		return
	}
	updates := map[string]interface{}{"role_scope": strings.TrimSpace(input.RoleScope), "name": strings.TrimSpace(input.Name), "provider": strings.TrimSpace(input.Provider), "base_url": strings.TrimSpace(input.BaseURL), "model": strings.TrimSpace(input.Model), "system_prompt": strings.TrimSpace(input.SystemPrompt), "context_window": input.ContextWindow, "temperature": input.Temperature, "rag_enabled": input.RAGEnabled, "rag_base_url": strings.TrimSpace(input.RAGBaseURL), "rag_dataset_id": strings.TrimSpace(input.RAGDatasetID)}
	if input.Enabled != nil {
		updates["enabled"] = *input.Enabled
	}
	if input.Allowed != nil {
		updates["allowed"] = *input.Allowed
	}
	if input.IsDefault != nil {
		updates["is_default"] = *input.IsDefault
	}
	if strings.TrimSpace(input.APIKey) != "" {
		encrypted, err := security.Encrypt(h.cfg.ConfigKey, input.APIKey)
		if err != nil {
			Fail(c, 500, 500, "API Key 加密失败")
			return
		}
		updates["api_key_encrypted"] = encrypted
	}
	if strings.TrimSpace(input.RAGAPIKey) != "" {
		encrypted, err := security.Encrypt(h.cfg.ConfigKey, input.RAGAPIKey)
		if err != nil {
			Fail(c, 500, 500, "RAG Key 加密失败")
			return
		}
		updates["rag_api_key_encrypted"] = encrypted
	}
	if input.ContextWindow <= 0 {
		updates["context_window"] = 8192
	}
	if input.Temperature <= 0 {
		updates["temperature"] = 0.3
	}
	if err := db.Model(&row).Updates(updates).Error; err != nil {
		Fail(c, 409, 409, "AI 配置更新失败")
		return
	}
	db.First(&row, uint(id))
	OK(c, aiConfigView{AIModelConfig: row, APIKeyConfigured: row.APIKeyEncrypted != "", RAGAPIKeyConfigured: row.RAGAPIKeyEncrypted != ""})
}

func (h *AIConfigHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.db.WithContext(c.Request.Context()).Delete(&model.AIModelConfig{}, uint(id)).Error; err != nil {
		Fail(c, 500, 500, "删除 AI 配置失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}
