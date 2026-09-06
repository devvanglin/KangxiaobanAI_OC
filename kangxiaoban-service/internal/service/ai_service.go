package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
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

func (s *AIService) configForContext(ctx context.Context) (*config.AIConfig, *model.AIModelConfig) {
	base := *s.cfg
	if base.SystemPrompt == "" {
		base.SystemPrompt = "你是康小伴智慧康养护理平台的照护助理，回答须谨慎、贴题、仅作参考，不做临床诊断。"
	}
	var row model.AIModelConfig
	err := s.db.WithContext(ctx).Where("role_scope IN ? AND enabled = ? AND allowed = ?", []string{s.roleScope(ctx), "all"}, true, true).
		Order("is_default DESC, id DESC").First(&row).Error
	if err != nil {
		return &base, nil
	}
	base.Provider, base.BaseURL, base.Model, base.APIKey = row.Provider, row.BaseURL, row.Model, ""
	base.ConfigKey = s.cfg.ConfigKey
	if value, decryptErr := security.Decrypt(base.ConfigKey, row.APIKeyEncrypted); decryptErr == nil {
		base.APIKey = value
	}
	if row.SystemPrompt != "" {
		base.SystemPrompt = row.SystemPrompt
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
	if provider == "http" && configRow != nil {
		ragContext, attempted := s.ragContextForChat(ctx, configRow, question)
		ragUsed = attempted
		if ragContext != "" {
			cfg.SystemPrompt = strings.TrimSpace(cfg.SystemPrompt) +
				"\n\n以下是机构知识库检索到的参考资料，回答时请优先依据其内容并保持谨慎：\n" + ragContext
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

// ragContextForChat 调用配置的 Dify 知识库检索接口并拼接参考片段。布尔值表示
// 是否发起了检索调用（即管理端统计的“RAG 知识库调用次数”）。检索失败不阻断对话。
func (s *AIService) ragContextForChat(ctx context.Context, row *model.AIModelConfig, question string) (string, bool) {
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

// RAGDataset is one knowledge-base inventory entry fetched from the configured Dify service.
type RAGDataset struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	DocumentCount int64  `json:"document_count"`
}

// ProviderModel is one model id fetched from the role's configured
// OpenAI-compatible service (vLLM and friends).
type ProviderModel struct {
	ID string `json:"id"`
}

// ListRAGDatasets 代理读取已配置 Dify 的知识库清单，供管理端大模型页展示与选择。
// 密钥只存在服务端，客户端永远不接触 Dify API Key。
func (s *AIService) ListRAGDatasets(ctx context.Context) ([]RAGDataset, error) {
	var row model.AIModelConfig
	err := s.db.WithContext(ctx).Where("rag_enabled = ? AND rag_base_url <> ''", true).
		Order("is_default DESC, id DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRAGNotConfigured
	}
	if err != nil {
		return nil, err
	}
	baseURL := strings.TrimRight(strings.TrimSpace(row.RAGBaseURL), "/")
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, row.RAGAPIKeyEncrypted)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/v1/datasets?page=1&limit=100", nil)
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
			ID            string `json:"id"`
			Name          string `json:"name"`
			DocumentCount int64  `json:"document_count"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRAGUnavailable, err)
	}
	datasets := make([]RAGDataset, 0, len(out.Data))
	for _, item := range out.Data {
		datasets = append(datasets, RAGDataset{ID: item.ID, Name: item.Name, DocumentCount: item.DocumentCount})
	}
	return datasets, nil
}

// ListProviderModels 代理读取角色 http 模型服务（vLLM 等 OpenAI 兼容部署）的可用模型清单。
func (s *AIService) ListProviderModels(ctx context.Context, role string) ([]ProviderModel, error) {
	role = strings.TrimSpace(role)
	if role == "" {
		role = "caregiver"
	}
	var row model.AIModelConfig
	err := s.db.WithContext(ctx).Where("role_scope IN ? AND provider = ? AND base_url <> ''", []string{role, "all"}, "http").
		Order("is_default DESC, id DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrModelSourceNotConfigured
	}
	if err != nil {
		return nil, err
	}
	baseURL := strings.TrimRight(strings.TrimSpace(row.BaseURL), "/")
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, row.APIKeyEncrypted)
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
