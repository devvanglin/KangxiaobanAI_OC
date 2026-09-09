package service

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"kangxiaoban-service/internal/agent"
	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
)

// agentNativeToolsDefault mirrors the deployment reality: on-prem vLLM builds
// usually run without --enable-auto-tool-choice and reject the OpenAI tools
// field, so prompt-based hermes tool calling is the default. Set
// KXB_AGENT_NATIVE_TOOLS=1 when the endpoint parses tool calls server-side.
const agentNativeToolsDefault = false

// chatWithAgent runs one agent exchange for a persisted conversation:
// role prompt + skills + budgeted history + tools → bounded loop → trace.
// The http provider runs the full loop; the local deterministic provider
// answers directly (it cannot call tools by design).
func (s *AIService) chatWithAgent(ctx context.Context, userID uint, conversation model.AIConversation, content string, mode agent.Mode, emit agent.StreamCallback) (answer, modelName, reasoning, traceJSON string, err error) {
	cfg, configRow := s.configForContext(ctx)
	if cfg == nil || !cfg.Enabled {
		return "", "", "", "", ErrAIProviderUnavailable
	}
	provider := strings.ToLower(strings.TrimSpace(cfg.Provider))
	startedAt := time.Now()
	if provider != "http" {
		answer := s.localAnswer(ctx, content)
		promptTokens := estimateTokens(content)
		completionTokens := estimateTokens(answer)
		s.recordUsage(ctx, userID, configRow, provider, localModelName(cfg), promptTokens, completionTokens, promptTokens+completionTokens, false, true, time.Since(startedAt))
		return answer, localModelName(cfg), "", "", nil
	}

	temperature := 0.3
	contextWindow := 4096
	if configRow != nil {
		if configRow.Temperature > 0 {
			temperature = configRow.Temperature
		}
		if configRow.ContextWindow > 0 {
			contextWindow = configRow.ContextWindow
		}
	}

	connection := s.connectionForContext(ctx)
	permissions := s.permissionsForUser(ctx, userID)
	tools := s.buildAgentTools(ctx, connection, permissions, mode)
	skills := s.skillFragments(ctx)

	// Context management: keep the newest turns inside the model window and
	// roll anything older into a persisted conversation summary.
	history := s.recentTurns(ctx, userID, conversation.ID, 40)
	systemPrompt := cfg.SystemPrompt
	budgetPrompt := systemPrompt + strings.Join(skills, "")
	kept, _, droppedText := agent.BudgetContext(history, budgetPrompt, content, contextWindow)
	summary := conversation.Summary
	if droppedText != "" {
		client := s.agentClient(cfg)
		if updated := agent.SummarizeDropped(ctx, client, cfg.Model, summary, droppedText); updated != "" && updated != summary {
			summary = updated
			_ = s.db.WithContext(ctx).Model(&model.AIConversation{}).
				Where("id = ?", conversation.ID).Update("summary", summary).Error
		}
	}

	runner := &agent.Agent{LLM: s.agentClient(cfg), Model: cfg.Model}
	result, runErr := runner.Run(ctx, agent.RunRequest{
		Mode:          mode,
		SystemPrompt:  systemPrompt,
		Skills:        skills,
		History:       kept,
		UserMessage:   content,
		Tools:         tools,
		Temperature:   temperature,
		ContextWindow: contextWindow,
		Summary:       summary,
		OnStream:      emit,
	})
	if runErr != nil {
		s.recordUsage(ctx, userID, configRow, provider, cfg.Model, resultTokens(result), 0, resultTokens(result), false, false, time.Since(startedAt))
		return "", "", "", "", fmt.Errorf("%w: %v", ErrAIProviderUnavailable, runErr)
	}
	ragUsed := false
	for _, step := range result.Steps {
		if step.Tool == "search_knowledge_base" && step.OK {
			ragUsed = true
			break
		}
	}
	trace := ""
	if encoded, marshalErr := json.Marshal(result.Steps); marshalErr == nil {
		trace = string(encoded)
	}
	s.recordUsage(ctx, userID, configRow, provider, cfg.Model, result.PromptTokens, result.CompletionTokens, result.TotalTokens, ragUsed, true, time.Since(startedAt))
	return result.Answer, cfg.Model, result.Reasoning, trace, nil
}

func resultTokens(result *agent.RunResult) int64 {
	if result == nil {
		return 0
	}
	return result.TotalTokens
}

func localModelName(cfg *config.AIConfig) string {
	if cfg != nil && strings.TrimSpace(cfg.Model) != "" {
		return strings.TrimSpace(cfg.Model)
	}
	return "kxb-local"
}

// agentClient builds the provider client for one exchange.
func (s *AIService) agentClient(cfg *config.AIConfig) agent.LLMClient {
	return &agent.OpenAIClient{
		BaseURL:     cfg.BaseURL,
		APIKey:      cfg.APIKey,
		NativeTools: s.agentNativeTools,
		HTTP:        &http.Client{},
	}
}

// permissionsForUser resolves the caller's effective permission codes once per
// exchange. The join is anchored on user_id, which is tenant-bound by the JWT,
// so the raw query stays tenant-safe even though it bypasses the scope hook.
func (s *AIService) permissionsForUser(ctx context.Context, userID uint) []string {
	var codes []string
	err := s.db.WithContext(ctx).Raw(
		"SELECT DISTINCT p.code FROM permissions p "+
			"JOIN sys_role_permission srp ON srp.permission_id = p.id "+
			"JOIN roles r ON r.id = srp.role_id AND r.deleted_at IS NULL AND r.status = 1 "+
			"JOIN sys_user_role sur ON sur.role_id = r.id "+
			"WHERE sur.user_id = ? AND p.deleted_at IS NULL", userID).Scan(&codes).Error
	if err != nil {
		return nil
	}
	return codes
}

// skillFragments returns enabled skills bound to the caller's role (or all
// roles), in display order. Failures degrade to no skills.
func (s *AIService) skillFragments(ctx context.Context) []string {
	role := s.roleScope(ctx)
	var skills []model.AISkill
	if err := s.db.WithContext(ctx).Where("enabled = ? AND role_scope IN ?", true, []string{role, "all"}).
		Order("sort_order ASC, id ASC").Limit(8).Find(&skills).Error; err != nil {
		return nil
	}
	fragments := make([]string, 0, len(skills))
	for _, skill := range skills {
		fragment := strings.TrimSpace(skill.Instructions)
		if fragment == "" {
			continue
		}
		fragments = append(fragments, skill.Name+"（v"+skill.Version+"）: "+fragment)
	}
	return fragments
}

// recentTurns replays the newest messages (ascending) as agent history.
func (s *AIService) recentTurns(ctx context.Context, userID, conversationID uint, limit int) []agent.Turn {
	var messages []model.AIMessage
	if err := s.db.WithContext(ctx).Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Order("sent_at DESC, id DESC").Limit(limit).Find(&messages).Error; err != nil {
		return nil
	}
	turns := make([]agent.Turn, 0, len(messages))
	for i := len(messages) - 1; i >= 0; i-- {
		role := strings.ToLower(strings.TrimSpace(messages[i].Role))
		if role != "user" && role != "assistant" {
			continue
		}
		turns = append(turns, agent.Turn{Role: role, Content: messages[i].Content})
	}
	return turns
}

// agentNativeToolsFromEnv reads the deployment toggle once at startup.
func agentNativeToolsFromEnv() bool {
	switch strings.TrimSpace(os.Getenv("KXB_AGENT_NATIVE_TOOLS")) {
	case "1", "true", "TRUE", "yes":
		return true
	}
	return agentNativeToolsDefault
}
