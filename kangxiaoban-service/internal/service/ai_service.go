package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

const (
	defaultAIConversationTitle = "默认对话"
	newAIConversationTitle     = "新对话"
)

var (
	ErrAIConversationNotFound   = errors.New("ai conversation not found")
	ErrAIValidation             = errors.New("ai request validation failed")
	ErrAIProviderUnavailable    = errors.New("ai provider unavailable")
	ErrRAGNotConfigured         = errors.New("rag connection not configured")
	ErrRAGUnavailable           = errors.New("rag service unavailable")
	ErrModelSourceNotConfigured = errors.New("model service connection not configured")
	ErrModelSourceUnavailable   = errors.New("model service unavailable")
)

// AIExchange is the persisted result of one user message and one AI reply.
type AIExchange struct {
	Conversation     model.AIConversation `json:"conversation"`
	UserMessage      model.AIMessage      `json:"user_message"`
	AssistantMessage model.AIMessage      `json:"assistant_message"`
	Answer           string               `json:"answer"`
	Model            string               `json:"model"`
}

// AIService 对话网关：provider=local 使用离线规则，provider=http 走真实模型。
type AIService struct {
	cfg *config.AIConfig
	db  *gorm.DB
}

type aiRoleScopeKey struct{}

// WithAIRoleScope selects the role-specific tenant configuration for one AI request.
func WithAIRoleScope(ctx context.Context, scope string) context.Context {
	return context.WithValue(ctx, aiRoleScopeKey{}, strings.TrimSpace(scope))
}

func (s *AIService) roleScope(ctx context.Context) string {
	if value, ok := ctx.Value(aiRoleScopeKey{}).(string); ok && value != "" {
		return value
	}
	return "caregiver"
}

// connectionForContext loads the tenant's unified model-service connection.
func (s *AIService) connectionForContext(ctx context.Context) *model.AIConnection {
	var row model.AIConnection
	if err := s.db.WithContext(ctx).Order("id ASC").First(&row).Error; err != nil {
		return nil
	}
	return &row
}

// configForContext merges the tenant connection (endpoint, keys, enable) with
// the role assignment (model, system prompt) into one chat configuration.
func (s *AIService) configForContext(ctx context.Context) (*config.AIConfig, *model.AIModelConfig) {
	base := *s.cfg
	if base.SystemPrompt == "" {
		base.SystemPrompt = "你是康小伴智慧康养护理平台的照护助理，回答须谨慎、贴题、仅作参考，不做临床诊断。"
	}
	connection := s.connectionForContext(ctx)
	if connection != nil {
		base.Enabled = base.Enabled && connection.Enabled
		base.Provider = connection.Provider
		base.BaseURL = connection.BaseURL
		base.APIKey = ""
		if value, decryptErr := security.Decrypt(s.cfg.ConfigKey, connection.APIKeyEncrypted); decryptErr == nil {
			base.APIKey = value
		}
	}
	var row model.AIModelConfig
	err := s.db.WithContext(ctx).Where("role_scope IN ? AND enabled = ? AND allowed = ?", []string{s.roleScope(ctx), "all"}, true, true).
		Order("is_default DESC, id DESC").First(&row).Error
	if err != nil {
		return &base, nil
	}
	base.ConfigKey = s.cfg.ConfigKey
	if row.SystemPrompt != "" {
		base.SystemPrompt = row.SystemPrompt
	}
	if strings.TrimSpace(row.Model) != "" {
		base.Model = row.Model
	}
	return &base, &row
}

func NewAIService(cfg *config.AIConfig, db *gorm.DB) *AIService {
	return &AIService{cfg: cfg, db: db}
}

// ListPromptSuggestions returns the current tenant's enabled starter prompts.
func (s *AIService) ListPromptSuggestions(ctx context.Context) ([]model.AIPromptSuggestion, error) {
	var suggestions []model.AIPromptSuggestion
	role := s.roleScope(ctx)
	err := s.db.WithContext(ctx).Where("enabled = ? AND role_scope IN ?", true, []string{role, "all"}).
		Order("group_index ASC, sort_order ASC, id ASC").Find(&suggestions).Error
	return suggestions, err
}

// ListAvailableModels exposes only non-secret model metadata to a logged-in
// caregiver or doctor. The admin configuration endpoint is the only writer.
func (s *AIService) ListAvailableModels(ctx context.Context) ([]model.AIModelConfig, error) {
	role := s.roleScope(ctx)
	var rows []model.AIModelConfig
	err := s.db.WithContext(ctx).Where("role_scope IN ? AND enabled = ? AND allowed = ?", []string{role, "all"}, true, true).
		Order("is_default DESC, id DESC").Find(&rows).Error
	for i := range rows {
		rows[i].APIKeyEncrypted = ""
		rows[i].RAGAPIKeyEncrypted = ""
	}
	return rows, err
}

// ListConversations returns only conversations owned by the authenticated user.
func (s *AIService) ListConversations(ctx context.Context, userID uint) ([]model.AIConversation, error) {
	if userID == 0 {
		return nil, fmt.Errorf("%w: user_id is required", ErrAIValidation)
	}
	var conversations []model.AIConversation
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("CASE WHEN last_message_at IS NULL THEN 1 ELSE 0 END, last_message_at DESC, updated_at DESC, id DESC").
		Find(&conversations).Error
	return conversations, err
}

// CreateConversation creates an empty non-default conversation for one user.
func (s *AIService) CreateConversation(ctx context.Context, userID uint, title string) (*model.AIConversation, error) {
	if userID == 0 {
		return nil, fmt.Errorf("%w: user_id is required", ErrAIValidation)
	}
	title = normalizeAIConversationTitle(title, newAIConversationTitle)
	conversation := &model.AIConversation{UserID: userID, Title: title}
	if err := s.db.WithContext(ctx).Create(conversation).Error; err != nil {
		return nil, err
	}
	return conversation, nil
}

// DeleteConversation soft-deletes a user-owned conversation and all of its messages.
func (s *AIService) DeleteConversation(ctx context.Context, userID, conversationID uint) error {
	if userID == 0 || conversationID == 0 {
		return fmt.Errorf("%w: user_id and conversation_id are required", ErrAIValidation)
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var conversation model.AIConversation
		if err := tx.Where("id = ? AND user_id = ?", conversationID, userID).First(&conversation).Error; err != nil {
			return mapAIConversationNotFound(err)
		}
		if err := tx.Where("conversation_id = ? AND user_id = ?", conversationID, userID).
			Delete(&model.AIMessage{}).Error; err != nil {
			return err
		}
		result := tx.Where("id = ? AND user_id = ?", conversationID, userID).Delete(&model.AIConversation{})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 1 {
			return ErrAIConversationNotFound
		}
		return nil
	})
}

// ListMessages returns a conversation's messages in display order.
func (s *AIService) ListMessages(ctx context.Context, userID, conversationID uint) ([]model.AIMessage, error) {
	if userID == 0 || conversationID == 0 {
		return nil, fmt.Errorf("%w: user_id and conversation_id are required", ErrAIValidation)
	}
	var conversation model.AIConversation
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", conversationID, userID).
		First(&conversation).Error; err != nil {
		return nil, mapAIConversationNotFound(err)
	}
	var messages []model.AIMessage
	err := s.db.WithContext(ctx).Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Order("sent_at ASC, id ASC").Find(&messages).Error
	return messages, err
}

// AIUsageSummary is the aggregate shown by the admin model page stat cards.
type AIUsageSummary struct {
	TotalTokens   int64   `json:"total_tokens"`
	TodayCalls    int64   `json:"today_calls"`
	AvgDailyCalls float64 `json:"avg_daily_calls"`
	RAGCalls      int64   `json:"rag_calls"`
}

// UsageSummary 汇总当前租户的按次 AI 用量：累计 token、今日调用次数、
// 最近 30 天日均调用次数与 RAG 知识库调用次数。
func (s *AIService) UsageSummary(ctx context.Context) (*AIUsageSummary, error) {
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	windowStart := todayStart.AddDate(0, 0, -29)
	var agg struct {
		TotalTokens int64
		TodayCalls  int64
		WindowCalls int64
		RAGCalls    int64
	}
	// 用 Find 而非 Scan：Scan 走 GORM RowQuery 处理器，会绕过统一租户隔离回调。
	err := s.db.WithContext(ctx).Model(&model.AIUsageLog{}).Select(
		"COALESCE(SUM(total_tokens), 0) AS total_tokens, "+
			"COALESCE(SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END), 0) AS today_calls, "+
			"COALESCE(SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END), 0) AS window_calls, "+
			"COALESCE(SUM(CASE WHEN rag_used = ? THEN 1 ELSE 0 END), 0) AS rag_calls",
		todayStart, windowStart, true,
	).Find(&agg).Error
	if err != nil {
		return nil, err
	}
	return &AIUsageSummary{
		TotalTokens:   agg.TotalTokens,
		TodayCalls:    agg.TodayCalls,
		AvgDailyCalls: float64(agg.WindowCalls) / 30.0,
		RAGCalls:      agg.RAGCalls,
	}, nil
}

// ModelUsageStat is one model's per-day usage rollup for the model card grid.
type ModelUsageStat struct {
	Model         string  `json:"model"`
	TodayCalls    int64   `json:"today_calls"`
	AvgDurationMS float64 `json:"avg_duration_ms"`
	SuccessRate   float64 `json:"success_rate"`
}

// UsageByModel aggregates today's per-call logs into per-model stats
// (calls, average successful duration, success rate) for the current tenant.
func (s *AIService) UsageByModel(ctx context.Context) ([]ModelUsageStat, error) {
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	var rows []ModelUsageStat
	err := s.db.WithContext(ctx).Model(&model.AIUsageLog{}).
		Select("model, COUNT(*) AS today_calls, "+
			"COALESCE(AVG(CASE WHEN success = ? THEN duration_ms END), 0) AS avg_duration_ms, "+
			"COALESCE(AVG(CASE WHEN success = ? THEN 100.0 ELSE 0 END), 0) AS success_rate", true, true).
		Where("created_at >= ?", todayStart).
		Group("model").Order("today_calls DESC").Find(&rows).Error
	if err != nil {
		return nil, err
	}
	return rows, nil
}

// SendMessage asks the configured AI and atomically persists both sides of the exchange.
func (s *AIService) SendMessage(ctx context.Context, userID, conversationID uint, content string) (*AIExchange, error) {
	content = strings.TrimSpace(content)
	if userID == 0 || conversationID == 0 || content == "" {
		return nil, fmt.Errorf("%w: user_id, conversation_id and content are required", ErrAIValidation)
	}
	var owned model.AIConversation
	if err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", conversationID, userID).
		First(&owned).Error; err != nil {
		return nil, mapAIConversationNotFound(err)
	}
	answer, modelName, err := s.Chat(ctx, userID, content)
	if err != nil {
		return nil, err
	}
	exchange := &AIExchange{Answer: answer, Model: modelName}
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var conversation model.AIConversation
		if err := tx.Where("id = ? AND user_id = ?", conversationID, userID).
			First(&conversation).Error; err != nil {
			return mapAIConversationNotFound(err)
		}
		return persistAIExchange(tx, &conversation, userID, content, answer, modelName, exchange)
	})
	if err != nil {
		return nil, err
	}
	return exchange, nil
}

// ChatAndPersistDefault preserves the legacy /ai/chat contract while storing its history.
func (s *AIService) ChatAndPersistDefault(ctx context.Context, userID uint, question string) (string, string, error) {
	question = strings.TrimSpace(question)
	if userID == 0 || question == "" {
		return "", "", fmt.Errorf("%w: user_id and question are required", ErrAIValidation)
	}
	answer, modelName, err := s.Chat(ctx, userID, question)
	if err != nil {
		return "", "", err
	}
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var conversation model.AIConversation
		err := tx.Where("user_id = ? AND is_default = ?", userID, true).
			Order("id ASC").First(&conversation).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			conversation = model.AIConversation{UserID: userID, Title: defaultAIConversationTitle, IsDefault: true}
			if err := tx.Create(&conversation).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		return persistAIExchange(tx, &conversation, userID, question, answer, modelName, nil)
	})
	if err != nil {
		return "", "", err
	}
	return answer, modelName, nil
}

// Chat 返回模型答复（advisory，非临床诊断）。每次到达网关的调用都会记录一条
// 用量日志，供管理端大模型页统计 token 消耗、调用次数与 RAG 知识库调用次数。
func (s *AIService) Chat(ctx context.Context, userID uint, question string) (string, string, error) {
	question = strings.TrimSpace(question)
	if question == "" {
		return "", "", fmt.Errorf("question 不能为空")
	}
	cfg, configRow := s.configForContext(ctx)
	if cfg == nil || !cfg.Enabled {
		return "", "", ErrAIProviderUnavailable
	}
	provider := strings.ToLower(strings.TrimSpace(cfg.Provider))
	startedAt := time.Now()
	ragUsed := false
	if provider == "http" {
		connection := s.connectionForContext(ctx)
		if connection != nil {
			ragContext, attempted := s.ragContextForChat(ctx, connection, question)
			ragUsed = attempted
			if ragContext != "" {
				cfg.SystemPrompt = strings.TrimSpace(cfg.SystemPrompt) +
					"\n\n以下是机构知识库检索到的参考资料，回答时请优先依据其内容并保持谨慎：\n" + ragContext
			}
		}
	}
	answer, modelName, promptTokens, completionTokens, totalTokens, chatErr := s.dispatchChat(ctx, cfg, provider, question)
	s.recordUsage(ctx, userID, configRow, provider, modelName, promptTokens, completionTokens, totalTokens, ragUsed, chatErr == nil, time.Since(startedAt))
	if chatErr != nil {
		return "", "", chatErr
	}
	return answer, modelName, nil
}

// dispatchChat 按 provider 分发一次对话，并返回 token 计量（无计量时由估算补齐）。
func (s *AIService) dispatchChat(ctx context.Context, cfg *config.AIConfig, provider, question string) (string, string, int64, int64, int64, error) {
	switch provider {
	case "local":
		modelName := strings.TrimSpace(cfg.Model)
		if modelName == "" {
			modelName = "kxb-local"
		}
		answer := s.localAnswer(ctx, question)
		promptTokens := estimateTokens(question)
		completionTokens := estimateTokens(answer)
		return answer, modelName, promptTokens, completionTokens, promptTokens + completionTokens, nil
	case "http":
		if strings.TrimSpace(cfg.BaseURL) == "" || strings.TrimSpace(cfg.Model) == "" {
			return "", "", 0, 0, 0, fmt.Errorf("%w: http provider is not fully configured", ErrAIProviderUnavailable)
		}
		answer, promptTokens, completionTokens, totalTokens, err := s.chatHTTP(ctx, cfg, question)
		if err != nil {
			return "", "", 0, 0, 0, fmt.Errorf("%w: %v", ErrAIProviderUnavailable, err)
		}
		return answer, strings.TrimSpace(cfg.Model), promptTokens, completionTokens, totalTokens, nil
	default:
		return "", "", 0, 0, 0, fmt.Errorf("%w: unsupported provider %q", ErrAIProviderUnavailable, provider)
	}
}

// estimateTokens 在 provider 未返回 usage 时提供粗略估算：中文按约 1 字符
// 1 token 计。仅用于管理端统计展示，不用于计费。
func estimateTokens(text string) int64 {
	return int64(len([]rune(text)))
}

// recordUsage 写入一条按次用量日志；记录失败只影响统计，不能影响对话本身。
func (s *AIService) recordUsage(ctx context.Context, userID uint, configRow *model.AIModelConfig, provider, modelName string, promptTokens, completionTokens, totalTokens int64, ragUsed, success bool, duration time.Duration) {
	if s.db == nil {
		return
	}
	entry := model.AIUsageLog{
		UserID:           userID,
		RoleScope:        s.roleScope(ctx),
		Provider:         provider,
		Model:            modelName,
		PromptTokens:     promptTokens,
		CompletionTokens: completionTokens,
		TotalTokens:      totalTokens,
		RAGUsed:          ragUsed,
		Success:          success,
		DurationMS:       duration.Milliseconds(),
	}
	if configRow != nil {
		entry.ConfigID = configRow.ID
	}
	if err := s.db.WithContext(ctx).Create(&entry).Error; err != nil {
		log.Printf("ai usage log create failed: %v", err)
	}
}

// ragContextForChat 调用租户统一 Dify 知识库检索接口并拼接参考片段。布尔值表示
// 是否发起了检索调用（即管理端统计的“RAG 知识库调用次数”）。检索失败不阻断对话。
func (s *AIService) ragContextForChat(ctx context.Context, row *model.AIConnection, question string) (string, bool) {
	baseURL := strings.TrimRight(strings.TrimSpace(row.RAGBaseURL), "/")
	datasetID := strings.TrimSpace(row.RAGDatasetID)
	if baseURL == "" || datasetID == "" {
		return "", false
	}
	apiKey := ""
	if value, err := security.Decrypt(s.cfg.ConfigKey, row.RAGAPIKeyEncrypted); err == nil {
		apiKey = value
	}
	body, _ := json.Marshal(map[string]interface{}{
		"query": question,
		"retrieval_model": map[string]interface{}{
			"search_method": "semantic_search", "reranking_enable": false,
			"top_k": 3, "score_threshold_enabled": false,
		},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/v1/datasets/"+datasetID+"/retrieve", bytes.NewReader(body))
	if err != nil {
		return "", true
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", true
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", true
	}
	var out struct {
		Records []struct {
			Segment struct {
				Content string `json:"content"`
			} `json:"segment"`
		} `json:"records"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", true
	}
	parts := make([]string, 0, len(out.Records))
	for _, record := range out.Records {
		content := strings.TrimSpace(record.Segment.Content)
		if content != "" {
			parts = append(parts, content)
		}
	}
	if len(parts) == 0 {
		return "", true
	}
	return strings.Join(parts, "\n---\n"), true
}

func persistAIExchange(tx *gorm.DB, conversation *model.AIConversation, userID uint, question, answer, modelName string, exchange *AIExchange) error {
	now := time.Now()
	userMessage := model.AIMessage{
		ConversationID: conversation.ID, UserID: userID, Role: "user", Content: question, SentAt: now,
	}
	if err := tx.Create(&userMessage).Error; err != nil {
		return err
	}
	assistantMessage := model.AIMessage{
		ConversationID: conversation.ID, UserID: userID, Role: "assistant", Content: answer, Model: modelName, SentAt: now,
	}
	if err := tx.Create(&assistantMessage).Error; err != nil {
		return err
	}
	updates := map[string]interface{}{"last_message_at": now}
	if conversation.LastMessageAt == nil && isGeneratedAIConversationTitle(conversation.Title) {
		updates["title"] = normalizeAIConversationTitle(question, conversation.Title)
	}
	result := tx.Model(&model.AIConversation{}).
		Where("id = ? AND user_id = ?", conversation.ID, userID).Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return ErrAIConversationNotFound
	}
	if exchange != nil {
		if err := tx.Where("id = ? AND user_id = ?", conversation.ID, userID).
			First(&exchange.Conversation).Error; err != nil {
			return mapAIConversationNotFound(err)
		}
		exchange.UserMessage = userMessage
		exchange.AssistantMessage = assistantMessage
	}
	return nil
}

func normalizeAIConversationTitle(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		value = fallback
	}
	runes := []rune(value)
	if len(runes) > 40 {
		value = string(runes[:40])
	}
	return value
}

func isGeneratedAIConversationTitle(title string) bool {
	title = strings.TrimSpace(title)
	return title == "" || title == newAIConversationTitle || title == defaultAIConversationTitle
}

func mapAIConversationNotFound(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrAIConversationNotFound
	}
	return err
}

// chatHTTP 兼容 OpenAI /v1/chat/completions 的远端模型，并返回 provider 的 token 计量。
func (s *AIService) chatHTTP(ctx context.Context, cfg *config.AIConfig, question string) (string, int64, int64, int64, error) {
	body, _ := json.Marshal(map[string]interface{}{
		"model": cfg.Model,
		"messages": []map[string]string{
			{"role": "system", "content": cfg.SystemPrompt},
			{"role": "user", "content": question},
		},
		"temperature": 0.3,
	})
	baseURL := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", 0, 0, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	if cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", 0, 0, 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", 0, 0, 0, fmt.Errorf("provider returned HTTP %d", resp.StatusCode)
	}
	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Usage struct {
			PromptTokens     int64 `json:"prompt_tokens"`
			CompletionTokens int64 `json:"completion_tokens"`
			TotalTokens      int64 `json:"total_tokens"`
		} `json:"usage"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", 0, 0, 0, err
	}
	if len(out.Choices) == 0 || strings.TrimSpace(out.Choices[0].Message.Content) == "" {
		return "", 0, 0, 0, fmt.Errorf("empty response")
	}
	answer := strings.TrimSpace(out.Choices[0].Message.Content)
	promptTokens, completionTokens := out.Usage.PromptTokens, out.Usage.CompletionTokens
	totalTokens := out.Usage.TotalTokens
	if totalTokens <= 0 {
		totalTokens = promptTokens + completionTokens
	}
	if totalTokens <= 0 {
		promptTokens = estimateTokens(cfg.SystemPrompt + question)
		completionTokens = estimateTokens(answer)
		totalTokens = promptTokens + completionTokens
	}
	return answer, promptTokens, completionTokens, totalTokens, nil
}

// localAnswer 本地确定性答复：按关键词给出审慎、贴题的帮助。
func (s *AIService) localAnswer(ctx context.Context, q string) string {
	qq := strings.ToLower(q)
	switch {
	case strings.Contains(qq, "跌倒") || strings.Contains(qq, "摔倒"):
		return "跌倒属于高风险事件：请先保持现场、评估长者意识与伤情，勿贸然搬动疑似骨折/头颈部伤者，立即呼叫值班医师并按 SOP 处置，同时在系统标记处置状态。建议关注跌倒高发时段（起身/如厕）并核对离床告警。以上仅为系统建议，具体处置遵循医嘱与机构流程。"
	case strings.Contains(qq, "呼吸") || strings.Contains(qq, "心率"):
		return s.vitalThresholdAnswer(ctx)
	case strings.Contains(qq, "费用") || strings.Contains(qq, "账单") || strings.Contains(qq, "缴费"):
		return "机构按要求为在院长者按床费+护理费+餐费生成月度账单；缴费后系统自动更新已缴金额与账单状态，并写资金流水。账单与缴费数据可在费用账单页查看与操作。"
	case strings.Contains(qq, "排班") || strings.Contains(qq, "交接"):
		return "系统支持按日期/班次维护排班，并记录交接班摘要与待办问题，确保责任到人、信息不断档。"
	default:
		return "您好，我是康小伴照护助理。您可以问我比如：跌倒如何处理、毫米波监测的呼吸/心率指标、账单与缴费、排班与交接等日常照护问题。我的回答仅作参考，紧急情况请联系值班人员。"
	}
}

func (s *AIService) vitalThresholdAnswer(ctx context.Context) string {
	const fallback = "系统会依据当前机构在服务器中配置的呼吸与心率阈值判定风险并推送告警。若多次异常，请结合血氧和现场情况复核，必要时联系医师评估，勿仅凭单次读数判断。"
	if s.db == nil {
		return fallback
	}
	var thresholds []model.HealthThreshold
	if err := s.db.WithContext(ctx).Where("metric IN ? AND enabled = ?", []string{"respiratory_rate", "heart_rate"}, true).
		Find(&thresholds).Error; err != nil {
		return fallback
	}
	byMetric := make(map[string]model.HealthThreshold, len(thresholds))
	for _, threshold := range thresholds {
		byMetric[threshold.Metric] = threshold
	}
	parts := make([]string, 0, 2)
	for _, metric := range []string{"respiratory_rate", "heart_rate"} {
		if threshold, ok := byMetric[metric]; ok {
			if description := describeAIHealthThreshold(threshold); description != "" {
				parts = append(parts, description)
			}
		}
	}
	if len(parts) == 0 {
		return fallback
	}
	return "系统依据当前机构在服务器中配置的阈值判定风险：" + strings.Join(parts, "；") + "。若多次异常，请结合血氧和现场情况复核，必要时联系医师评估，勿仅凭单次读数判断。"
}

func describeAIHealthThreshold(threshold model.HealthThreshold) string {
	name := strings.TrimSpace(threshold.DisplayName)
	if name == "" {
		name = threshold.Metric
	}
	unit := strings.TrimSpace(threshold.Unit)
	parts := make([]string, 0, 2)
	if threshold.WarningMin != nil && threshold.WarningMax != nil {
		parts = append(parts, fmt.Sprintf("%s参考区间%s-%s%s", name, formatAIThreshold(*threshold.WarningMin), formatAIThreshold(*threshold.WarningMax), unit))
	}
	if threshold.CriticalMin != nil && threshold.CriticalMax != nil {
		parts = append(parts, fmt.Sprintf("低于%s%s或高于%s%s为危险范围", formatAIThreshold(*threshold.CriticalMin), unit, formatAIThreshold(*threshold.CriticalMax), unit))
	}
	return strings.Join(parts, "，")
}

func formatAIThreshold(value float64) string {
	return strconv.FormatFloat(value, 'f', -1, 64)
}

// ModelTestResult is one model's real connectivity test outcome.
type ModelTestResult struct {
	Model     string `json:"model"`
	Success   bool   `json:"success"`
	LatencyMS int64  `json:"latency_ms"`
	Error     string `json:"error,omitempty"`
}

// TestProviderModels 对选定模型逐个发起一次最小对话补全，验证网关连通性。
// 只返回测试结果（耗时与失败原因），不落库、不影响对话统计。
func (s *AIService) TestProviderModels(ctx context.Context, baseURL, apiKey string, models []string) ([]ModelTestResult, error) {
	baseURL = normalizeAPIBase(baseURL)
	if baseURL == "" {
		return nil, ErrModelSourceNotConfigured
	}
	cleaned := make([]string, 0, len(models))
	seen := map[string]bool{}
	for _, item := range models {
		model := strings.TrimSpace(item)
		if model == "" || seen[model] {
			continue
		}
		seen[model] = true
		cleaned = append(cleaned, model)
		if len(cleaned) >= 20 {
			break
		}
	}
	results := make([]ModelTestResult, 0, len(cleaned))
	client := &http.Client{Timeout: 10 * time.Second}
	for _, model := range cleaned {
		endpoint, body := modelProbeRequest(model)
		result := ModelTestResult{Model: model}
		startedAt := time.Now()
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+endpoint, bytes.NewReader(body))
		if err != nil {
			result.Error = "请求构造失败"
			result.LatencyMS = time.Since(startedAt).Milliseconds()
			results = append(results, result)
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		if apiKey != "" {
			req.Header.Set("Authorization", "Bearer "+apiKey)
		}
		resp, err := client.Do(req)
		if err != nil {
			result.Error = "连接失败"
			result.LatencyMS = time.Since(startedAt).Milliseconds()
			results = append(results, result)
			continue
		}
		resp.Body.Close()
		result.LatencyMS = time.Since(startedAt).Milliseconds()
		if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
			result.Error = fmt.Sprintf("HTTP %d", resp.StatusCode)
		} else {
			result.Success = true
		}
		results = append(results, result)
	}
	return results, nil
}

// modelProbeRequest 按模型角色选择正确的探测端点与请求体：
// 对话模型走 /v1/chat/completions，向量模型走 /v1/embeddings，重排模型走 /v1/rerank。
func modelProbeRequest(model string) (string, []byte) {
	lower := strings.ToLower(model)
	switch {
	case strings.Contains(lower, "rerank"):
		body, _ := json.Marshal(map[string]interface{}{
			"model":     model,
			"query":     "ping",
			"documents": []string{"ping"},
		})
		return "/v1/rerank", body
	case strings.Contains(lower, "embed"), strings.Contains(lower, "bge"), strings.Contains(lower, "gte"):
		body, _ := json.Marshal(map[string]interface{}{
			"model": model,
			"input": []string{"ping"},
		})
		return "/v1/embeddings", body
	default:
		body, _ := json.Marshal(map[string]interface{}{
			"model":       model,
			"messages":    []map[string]string{{"role": "user", "content": "ping"}},
			"max_tokens":  1,
			"temperature": 0,
		})
		return "/v1/chat/completions", body
	}
}

// RAGEmbeddingModel is one embedding model available on the Dify instance.
type RAGEmbeddingModel struct {
	Model  string            `json:"model"`
	Label  map[string]string `json:"label,omitempty"`
	Status string            `json:"status,omitempty"`
}

// ListRAGModels 列出 Dify 实例当前可用的指定类型模型（text-embedding / rerank）。
func (s *AIService) ListRAGModels(ctx context.Context, modelType string) ([]RAGEmbeddingModel, error) {
	if modelType != "text-embedding" && modelType != "rerank" {
		modelType = "text-embedding"
	}
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, ErrRAGNotConfigured
	}
	baseURL := normalizeAPIBase(connection.RAGBaseURL)
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		baseURL+"/workspaces/current/models/model-types/"+modelType, nil)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
	}
	var out struct {
		Data []struct {
			Model  string            `json:"model"`
			Label  map[string]string `json:"label"`
			Status string            `json:"status"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	models := make([]RAGEmbeddingModel, 0, len(out.Data))
	for _, item := range out.Data {
		models = append(models, RAGEmbeddingModel{Model: item.Model, Label: item.Label, Status: item.Status})
	}
	return models, nil
}

// UploadRAGDocument 把文件与客户端构造的 data 配置 JSON 转发到 Dify
// create-by-file，返回文档创建结果（id/name/batch 等）。
func (s *AIService) UploadRAGDocument(ctx context.Context, datasetID, fileName string, content []byte, dataJSON string) (map[string]interface{}, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, ErrRAGNotConfigured
	}
	baseURL := normalizeAPIBase(connection.RAGBaseURL)
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	if strings.TrimSpace(dataJSON) == "" {
		dataJSON = `{"indexing_technique":"high_quality","process_rule":{"mode":"automatic"}}`
	}

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	if err := writer.WriteField("data", string(dataJSON)); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	part, err := writer.CreateFormFile("file", fileName)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	if _, err := part.Write(content); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		baseURL+"/v1/datasets/"+datasetID+"/documents", body)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
	}
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	return result, nil
}

// CreateRAGDatasetInput 是“创建即用型知识库”的完整配置。
type CreateRAGDatasetInput struct {
	Name              string
	IndexingTechnique string
	EmbeddingModel    string
	RetrievalModel    map[string]interface{}
}

// CreateRAGDataset 在 Dify 上创建知识库，返回数据集信息（含 id）。
func (s *AIService) CreateRAGDataset(ctx context.Context, in CreateRAGDatasetInput) (map[string]interface{}, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, ErrRAGNotConfigured
	}
	baseURL := normalizeAPIBase(connection.RAGBaseURL)
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	if strings.TrimSpace(in.Name) == "" {
		return nil, fmt.Errorf("%w: 知识库名称必填", ErrAIValidation)
	}
	technique := in.IndexingTechnique
	if technique != "high_quality" && technique != "economy" {
		technique = "high_quality"
	}
	payload := map[string]interface{}{
		"name":               strings.TrimSpace(in.Name),
		"indexing_technique": technique,
		"permission":         "only_me",
	}
	if technique == "high_quality" && strings.TrimSpace(in.EmbeddingModel) != "" {
		payload["embedding_model"] = strings.TrimSpace(in.EmbeddingModel)
	}
	if in.RetrievalModel != nil {
		payload["retrieval_model"] = in.RetrievalModel
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/v1/datasets", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
	}
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	return result, nil
}

// GetRAGIndexingStatus 查询一批文档的解析（嵌入）进度。
func (s *AIService) GetRAGIndexingStatus(ctx context.Context, datasetID, batchID string) (map[string]interface{}, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, ErrRAGNotConfigured
	}
	baseURL := normalizeAPIBase(connection.RAGBaseURL)
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		baseURL+"/v1/datasets/"+datasetID+"/documents/"+batchID+"/indexing-status", nil)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
	}
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	return result, nil
}

// RAGDataset is one knowledge-base inventory entry fetched from the configured Dify service.
type RAGDataset struct {
	ID                string `json:"id"`
	Name              string `json:"name"`
	Description       string `json:"description"`
	DocumentCount     int64  `json:"document_count"`
	WordCount         int64  `json:"word_count"`
	UpdatedAt         string `json:"updated_at,omitempty"`
	EmbeddingModel    string `json:"embedding_model,omitempty"`
	IndexingTechnique string `json:"indexing_technique,omitempty"`
}

// ProviderModel is one model id fetched from the role's configured
// OpenAI-compatible service (vLLM and friends).
type ProviderModel struct {
	ID string `json:"id"`
}

// ListRAGDatasets 代理读取已配置 Dify 的知识库清单，供管理端大模型页展示与选择。
// 密钥只存在服务端，客户端永远不接触 Dify API Key。
func (s *AIService) ListRAGDatasets(ctx context.Context) ([]RAGDataset, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, ErrRAGNotConfigured
	}
	ragAPIKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	return s.ListRAGDatasetsAt(ctx, connection.RAGBaseURL, ragAPIKey)
}

// ProbeRAGDatasets 用调用方提供的地址/密钥做保存前探测；密钥留空时回退到已存密钥。
func (s *AIService) ProbeRAGDatasets(ctx context.Context, baseURL, apiKey string) ([]RAGDataset, error) {
	if strings.TrimSpace(apiKey) == "" {
		if connection := s.connectionForContext(ctx); connection != nil {
			if value, decryptErr := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted); decryptErr == nil {
				apiKey = value
			}
		}
	}
	return s.ListRAGDatasetsAt(ctx, baseURL, apiKey)
}

// ListRAGDatasetsAt 直接按给定 Dify 端点分页拉取全部知识库。
func (s *AIService) ListRAGDatasetsAt(ctx context.Context, baseURL, apiKey string) ([]RAGDataset, error) {
	baseURL = normalizeAPIBase(baseURL)
	if baseURL == "" {
		return nil, ErrRAGNotConfigured
	}
	// 分页拉全量知识库清单（每页 100，最多 20 页），避免大机构列表被截断。
	client := &http.Client{Timeout: 8 * time.Second}
	datasets := make([]RAGDataset, 0, 64)
	for page := 1; page <= 20; page++ {
		pageReq, err := http.NewRequestWithContext(ctx, http.MethodGet,
			baseURL+"/v1/datasets?page="+strconv.Itoa(page)+"&limit=100", nil)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
		}
		if apiKey != "" {
			pageReq.Header.Set("Authorization", "Bearer "+apiKey)
		}
		resp, err := client.Do(pageReq)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
		}
		if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
			resp.Body.Close()
			return nil, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
		}
		// Dify 不同版本/配置下字段类型不稳定（null、数字时间戳等），
		// 用 map + 类型自适应逐字段提取，避免严格解码整表失败。
		var out struct {
			Data    []map[string]interface{} `json:"data"`
			HasMore bool                     `json:"has_more"`
		}
		decodeErr := json.NewDecoder(resp.Body).Decode(&out)
		resp.Body.Close()
		if decodeErr != nil {
			return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, decodeErr)
		}
		for _, item := range out.Data {
			datasets = append(datasets, RAGDataset{
				ID:                ragStringField(item, "id"),
				Name:              ragStringField(item, "name"),
				Description:       ragStringField(item, "description"),
				DocumentCount:     ragIntField(item, "document_count"),
				WordCount:         ragIntField(item, "word_count"),
				UpdatedAt:         ragTimeField(item, "updated_at"),
				EmbeddingModel:    ragStringField(item, "embedding_model"),
				IndexingTechnique: ragStringField(item, "indexing_technique"),
			})
		}
		if !out.HasMore || len(out.Data) == 0 {
			break
		}
	}
	return datasets, nil
}

// ListProviderModels 代理读取租户统一模型服务（vLLM 等 OpenAI 兼容部署）的可用模型清单。
func (s *AIService) ListProviderModels(ctx context.Context) ([]ProviderModel, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || connection.Provider != "http" || strings.TrimSpace(connection.BaseURL) == "" {
		return nil, ErrModelSourceNotConfigured
	}
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.APIKeyEncrypted)
	return s.ListProviderModelsAt(ctx, connection.BaseURL, apiKey)
}

// ProbeProviderModels 用调用方提供的地址/密钥做保存前探测；密钥留空时回退到已存密钥。
func (s *AIService) ProbeProviderModels(ctx context.Context, baseURL, apiKey string) ([]ProviderModel, error) {
	if strings.TrimSpace(apiKey) == "" {
		if connection := s.connectionForContext(ctx); connection != nil {
			if value, decryptErr := security.Decrypt(s.cfg.ConfigKey, connection.APIKeyEncrypted); decryptErr == nil {
				apiKey = value
			}
		}
	}
	return s.ListProviderModelsAt(ctx, baseURL, apiKey)
}

// RagProxyAPI 通用知识库 API 转发：把管理端的任意知识库子路径请求
// （更新/删除知识库、文档管理、分段、元数据、标签、检索测试等）
// 转发到已配置的 Dify 实例。body 为客户端构造的 JSON（可为空）。
// 返回 Dify 的 JSON 响应与上游状态码。
func (s *AIService) RagProxyAPI(ctx context.Context, method, subPath, rawQuery string, body []byte) (map[string]interface{}, int, error) {
	connection := s.connectionForContext(ctx)
	if connection == nil || !connection.RAGEnabled || strings.TrimSpace(connection.RAGBaseURL) == "" {
		return nil, 0, ErrRAGNotConfigured
	}
	baseURL := normalizeAPIBase(connection.RAGBaseURL)
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, connection.RAGAPIKeyEncrypted)
	subPath = strings.Trim(subPath, "/")
	if subPath == "" {
		return nil, 0, fmt.Errorf("%w: 缺少 API 路径", ErrAIValidation)
	}
	target := baseURL + "/v1/" + subPath
	if rawQuery != "" {
		target += "?" + rawQuery
	}
	var reader io.Reader
	if len(body) > 0 {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, target, reader)
	if err != nil {
		return nil, 0, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	if len(body) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	defer resp.Body.Close()
	var result map[string]interface{}
	decodeErr := json.NewDecoder(resp.Body).Decode(&result)
	if decodeErr != nil && resp.StatusCode != http.StatusNoContent {
		return nil, resp.StatusCode, fmt.Errorf("%w: %v", ErrRAGUnavailable, decodeErr)
	}
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return result, resp.StatusCode, fmt.Errorf("%w: HTTP %d", ErrRAGUnavailable, resp.StatusCode)
	}
	return result, resp.StatusCode, nil
}

func ragStringField(item map[string]interface{}, key string) string {
	if value, ok := item[key]; ok && value != nil {
		if text, ok := value.(string); ok {
			return text
		}
		if number, ok := value.(float64); ok {
			return strconv.FormatFloat(number, 'f', -1, 64)
		}
	}
	return ""
}

func ragIntField(item map[string]interface{}, key string) int64 {
	if number, ok := item[key].(float64); ok {
		return int64(number)
	}
	return 0
}

// ragTimeField 兼容字符串与 Unix 时间戳两种 updated_at 形态。
func ragTimeField(item map[string]interface{}, key string) string {
	switch value := item[key].(type) {
	case string:
		return value
	case float64:
		return time.Unix(int64(value), 0).Format("2006-01-02 15:04:05")
	}
	return ""
}

// normalizeAPIBase 统一网关地址：去尾部斜杠与冗余的 /v1 后缀，
// 内部统一补 /v1 前缀（Dify/OpenAI 文档的基础 URL 本身带 /v1）。
func normalizeAPIBase(baseURL string) string {
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	return strings.TrimSuffix(base, "/v1")
}

// ListProviderModelsAt 直接按给定 OpenAI 兼容端点拉取模型清单。
func (s *AIService) ListProviderModelsAt(ctx context.Context, baseURL, apiKey string) ([]ProviderModel, error) {
	baseURL = normalizeAPIBase(baseURL)
	if baseURL == "" {
		return nil, ErrModelSourceNotConfigured
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/v1/models", nil)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrModelSourceUnavailable, err)
	}
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrModelSourceUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("%w: HTTP %d", ErrModelSourceUnavailable, resp.StatusCode)
	}
	var out struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrModelSourceUnavailable, err)
	}
	models := make([]ProviderModel, 0, len(out.Data))
	for _, item := range out.Data {
		if strings.TrimSpace(item.ID) == "" {
			continue
		}
		models = append(models, ProviderModel{ID: item.ID})
	}
	return models, nil
}

// AIConnectionUpdate carries the editable unified connection fields. Empty key
// fields keep the stored secrets, mirroring the assignment update contract.
type AIConnectionUpdate struct {
	Provider     string
	BaseURL      string
	APIKey       string
	RAGEnabled   bool
	RAGBaseURL   string
	RAGDatasetID string
	RAGAPIKey    string
	Enabled      bool
}

// Connection 返回租户统一模型服务连接；尚无记录时返回本地默认值（不落库）。
func (s *AIService) Connection(ctx context.Context) (*model.AIConnection, error) {
	if connection := s.connectionForContext(ctx); connection != nil {
		return connection, nil
	}
	return &model.AIConnection{Provider: "local", Enabled: true}, nil
}

// UpdateConnection 创建或更新租户唯一的模型服务连接。
func (s *AIService) UpdateConnection(ctx context.Context, input AIConnectionUpdate) (*model.AIConnection, error) {
	provider := strings.ToLower(strings.TrimSpace(input.Provider))
	if provider != "local" && provider != "http" {
		provider = "local"
	}
	var saved *model.AIConnection
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row model.AIConnection
		err := tx.Order("id ASC").First(&row).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row = model.AIConnection{Provider: provider}
		} else if err != nil {
			return err
		}
		row.Provider = provider
		row.BaseURL = strings.TrimSpace(input.BaseURL)
		row.RAGEnabled = input.RAGEnabled
		row.RAGBaseURL = strings.TrimSpace(input.RAGBaseURL)
		row.RAGDatasetID = strings.TrimSpace(input.RAGDatasetID)
		row.Enabled = input.Enabled
		if strings.TrimSpace(input.APIKey) != "" {
			encrypted, encryptErr := security.Encrypt(s.cfg.ConfigKey, strings.TrimSpace(input.APIKey))
			if encryptErr != nil {
				return encryptErr
			}
			row.APIKeyEncrypted = encrypted
		}
		if strings.TrimSpace(input.RAGAPIKey) != "" {
			encrypted, encryptErr := security.Encrypt(s.cfg.ConfigKey, strings.TrimSpace(input.RAGAPIKey))
			if encryptErr != nil {
				return encryptErr
			}
			row.RAGAPIKeyEncrypted = encrypted
		}
		if row.ID == 0 {
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		} else if err := tx.Save(&row).Error; err != nil {
			return err
		}
		saved = &row
		return nil
	})
	if err != nil {
		return nil, err
	}
	return saved, nil
}

// AdminPromptInput 是管理端维护提示词建议的字段。
type AdminPromptInput struct {
	RoleScope string
	Title     string
	Prompt    string
	Enabled   bool
}

// AdminListPrompts 管理端列出提示词建议（可按角色过滤，含停用项）。
func (s *AIService) AdminListPrompts(ctx context.Context, role string) ([]model.AIPromptSuggestion, error) {
	query := s.db.WithContext(ctx).Order("role_scope ASC, group_index ASC, sort_order ASC, id ASC")
	role = strings.TrimSpace(role)
	if role != "" {
		query = query.Where("role_scope = ?", role)
	}
	var rows []model.AIPromptSuggestion
	err := query.Find(&rows).Error
	return rows, err
}

// AdminCreatePrompt 管理端新建一条提示词建议。
func (s *AIService) AdminCreatePrompt(ctx context.Context, in AdminPromptInput) (*model.AIPromptSuggestion, error) {
	role := strings.TrimSpace(in.RoleScope)
	if role != "caregiver" && role != "doctor" {
		return nil, fmt.Errorf("%w: role_scope 必须是 caregiver 或 doctor", ErrAIValidation)
	}
	title := strings.TrimSpace(in.Title)
	prompt := strings.TrimSpace(in.Prompt)
	if title == "" || prompt == "" {
		return nil, fmt.Errorf("%w: title 与 prompt 必填", ErrAIValidation)
	}
	var maxSort int
	if err := s.db.WithContext(ctx).Model(&model.AIPromptSuggestion{}).
		Where("role_scope = ?", role).
		Select("COALESCE(MAX(sort_order), 0)").Scan(&maxSort).Error; err != nil {
		return nil, err
	}
	row := model.AIPromptSuggestion{
		RoleScope:  role,
		Code:       fmt.Sprintf("custom-%s-%d", role, time.Now().UnixMilli()),
		GroupIndex: 9,
		Title:      title,
		Prompt:     prompt,
		SortOrder:  maxSort + 10,
		Enabled:    in.Enabled,
	}
	if err := s.db.WithContext(ctx).Create(&row).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

// AdminUpdatePrompt 管理端更新提示词建议的标题、内容与启用状态。
func (s *AIService) AdminUpdatePrompt(ctx context.Context, id uint, in AdminPromptInput) (*model.AIPromptSuggestion, error) {
	title := strings.TrimSpace(in.Title)
	prompt := strings.TrimSpace(in.Prompt)
	if title == "" || prompt == "" {
		return nil, fmt.Errorf("%w: title 与 prompt 必填", ErrAIValidation)
	}
	var row model.AIPromptSuggestion
	if err := s.db.WithContext(ctx).First(&row, id).Error; err != nil {
		return nil, err
	}
	updates := map[string]interface{}{
		"title":   title,
		"prompt":  prompt,
		"enabled": in.Enabled,
	}
	if err := s.db.WithContext(ctx).Model(&model.AIPromptSuggestion{}).Where("id = ?", id).
		Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := s.db.WithContext(ctx).First(&row, id).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

// AdminDeletePrompt 管理端删除提示词建议。
func (s *AIService) AdminDeletePrompt(ctx context.Context, id uint) error {
	result := s.db.WithContext(ctx).Delete(&model.AIPromptSuggestion{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
