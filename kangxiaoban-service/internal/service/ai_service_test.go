package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/model"
)

func TestAIConversationUserAndTenantIsolation(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	first, err := svc.CreateConversation(ctx, 11, "护理建议")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateConversation(ctx, 22, "其他用户"); err != nil {
		t.Fatal(err)
	}
	items, err := svc.ListConversations(ctx, 11)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != first.ID {
		t.Fatalf("user 11 conversations = %+v", items)
	}
	if _, err := svc.ListMessages(ctx, 22, first.ID); !errors.Is(err, ErrAIConversationNotFound) {
		t.Fatalf("other user ListMessages error = %v, want not found", err)
	}
	if err := svc.DeleteConversation(ctx, 22, first.ID); !errors.Is(err, ErrAIConversationNotFound) {
		t.Fatalf("other user DeleteConversation error = %v, want not found", err)
	}

	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "tenant-ai-two", Name: "AI 第二机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	second, err := svc.CreateConversation(ctx2, 11, "第二机构会话")
	if err != nil {
		t.Fatal(err)
	}
	if second.TenantID != 2 {
		t.Fatalf("tenant two conversation tenant_id = %d", second.TenantID)
	}
	items, err = svc.ListConversations(ctx, 11)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != first.ID {
		t.Fatalf("tenant one saw cross-tenant data: %+v", items)
	}
	items, err = svc.ListConversations(ctx2, 11)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != second.ID {
		t.Fatalf("tenant two conversations = %+v", items)
	}
}

func TestAIListPromptSuggestionsReturnsEnabledTenantConfiguration(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	items, err := svc.ListPromptSuggestions(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 9 {
		t.Fatalf("suggestions = %d, want 9", len(items))
	}
	if items[0].Code != "care-summary" || items[3].Code != "shift-records" || items[6].Code != "shift-plan" {
		t.Fatalf("unexpected suggestion order: %+v", items)
	}
	if err := db.WithContext(ctx).Model(&model.AIPromptSuggestion{}).
		Where("code = ?", "health-change").Update("enabled", false).Error; err != nil {
		t.Fatal(err)
	}
	items, err = svc.ListPromptSuggestions(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 8 {
		t.Fatalf("enabled suggestions = %d, want 8", len(items))
	}
	for _, item := range items {
		if item.Code == "health-change" {
			t.Fatal("disabled suggestion was returned")
		}
	}
}

func TestAISendMessagePersistsPairAndDeleteCascades(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	conversation, err := svc.CreateConversation(ctx, 31, "")
	if err != nil {
		t.Fatal(err)
	}
	exchange, err := svc.SendMessage(ctx, 31, conversation.ID, " 跌倒后应该怎么处理？ ")
	if err != nil {
		t.Fatal(err)
	}
	if exchange.Conversation.ID != conversation.ID || exchange.Conversation.LastMessageAt == nil {
		t.Fatalf("conversation was not updated: %+v", exchange.Conversation)
	}
	if exchange.Conversation.Title != "跌倒后应该怎么处理？" {
		t.Fatalf("first-message title = %q", exchange.Conversation.Title)
	}
	if exchange.UserMessage.Role != "user" || exchange.UserMessage.Content != "跌倒后应该怎么处理？" {
		t.Fatalf("unexpected user message: %+v", exchange.UserMessage)
	}
	if exchange.AssistantMessage.Role != "assistant" || exchange.AssistantMessage.Model != "test-local" || exchange.AssistantMessage.Content == "" {
		t.Fatalf("unexpected assistant message: %+v", exchange.AssistantMessage)
	}
	messages, err := svc.ListMessages(ctx, 31, conversation.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(messages) != 2 || messages[0].Role != "user" || messages[1].Role != "assistant" {
		t.Fatalf("messages = %+v", messages)
	}
	if err := svc.DeleteConversation(ctx, 31, conversation.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ListMessages(ctx, 31, conversation.ID); !errors.Is(err, ErrAIConversationNotFound) {
		t.Fatalf("ListMessages after delete error = %v", err)
	}
	var activeMessages int64
	if err := db.Model(&model.AIMessage{}).Where("conversation_id = ? AND user_id = ?", conversation.ID, 31).Count(&activeMessages).Error; err != nil {
		t.Fatal(err)
	}
	if activeMessages != 0 {
		t.Fatalf("active messages after delete = %d", activeMessages)
	}
	var deletedMessages int64
	if err := db.Unscoped().Model(&model.AIMessage{}).Where("conversation_id = ? AND user_id = ?", conversation.ID, 31).Count(&deletedMessages).Error; err != nil {
		t.Fatal(err)
	}
	if deletedMessages != 2 {
		t.Fatalf("soft-deleted messages = %d, want 2", deletedMessages)
	}
}

func TestAISendMessagePreservesExplicitConversationTitle(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	conversation, err := svc.CreateConversation(ctx, 32, "夜间护理复盘")
	if err != nil {
		t.Fatal(err)
	}
	exchange, err := svc.SendMessage(ctx, 32, conversation.ID, "昨晚有哪些注意事项？")
	if err != nil {
		t.Fatal(err)
	}
	if exchange.Conversation.Title != "夜间护理复盘" {
		t.Fatalf("explicit title was replaced with %q", exchange.Conversation.Title)
	}
}

func TestAISendMessageRollsBackBothMessages(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	conversation, err := svc.CreateConversation(ctx, 41, "回滚测试")
	if err != nil {
		t.Fatal(err)
	}
	trigger := `CREATE TRIGGER fail_ai_assistant_message
		BEFORE INSERT ON ai_messages
		WHEN NEW.role = 'assistant'
		BEGIN SELECT RAISE(ABORT, 'forced assistant failure'); END;`
	if err := db.Exec(trigger).Error; err != nil {
		t.Fatalf("create trigger: %v", err)
	}
	if _, err := svc.SendMessage(ctx, 41, conversation.ID, "测试原子写入"); err == nil {
		t.Fatal("SendMessage succeeded, want forced assistant failure")
	}
	var count int64
	if err := db.Model(&model.AIMessage{}).Where("conversation_id = ? AND user_id = ?", conversation.ID, 41).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("messages after rollback = %d, want 0", count)
	}
	var reloaded model.AIConversation
	if err := db.Where("id = ? AND user_id = ?", conversation.ID, 41).First(&reloaded).Error; err != nil {
		t.Fatal(err)
	}
	if reloaded.LastMessageAt != nil || reloaded.Title != "回滚测试" {
		t.Fatalf("conversation update was not rolled back: %+v", reloaded)
	}
}

func TestAILegacyChatPersistsOneDefaultConversation(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	for _, question := range []string{"排班怎么查看？", "账单怎么处理？"} {
		answer, modelName, err := svc.ChatAndPersistDefault(ctx, 51, question)
		if err != nil {
			t.Fatal(err)
		}
		if answer == "" || modelName != "test-local" {
			t.Fatalf("answer=%q model=%q", answer, modelName)
		}
	}
	items, err := svc.ListConversations(ctx, 51)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || !items[0].IsDefault || items[0].Title != "排班怎么查看？" {
		t.Fatalf("default conversations = %+v", items)
	}
	messages, err := svc.ListMessages(ctx, 51, items[0].ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(messages) != 4 {
		t.Fatalf("default conversation messages = %d, want 4", len(messages))
	}
}

func TestAILocalVitalAnswerUsesTenantThresholds(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	answer, _, err := svc.Chat(ctx, "呼吸和心率异常怎么判断？")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(answer, "8次/分") || !strings.Contains(answer, "30次/分") ||
		!strings.Contains(answer, "45bpm") || !strings.Contains(answer, "130bpm") {
		t.Fatalf("answer does not use seeded thresholds: %q", answer)
	}
	if err := db.WithContext(ctx).Model(&model.HealthThreshold{}).Where("metric = ?", "heart_rate").
		Updates(map[string]interface{}{"critical_min": 43, "critical_max": 135}).Error; err != nil {
		t.Fatal(err)
	}
	answer, _, err = svc.Chat(ctx, "心率异常怎么判断？")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(answer, "43bpm") || !strings.Contains(answer, "135bpm") || strings.Contains(answer, "45bpm") {
		t.Fatalf("answer did not refresh persisted thresholds: %q", answer)
	}
}

func TestAIHTTPFailureDoesNotFallBackOrPersistMessages(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "provider unavailable", http.StatusBadGateway)
	}))
	t.Cleanup(server.Close)
	svc.cfg = &config.AIConfig{Enabled: true, Provider: "http", BaseURL: server.URL, Model: "remote-model"}

	conversation, err := svc.CreateConversation(ctx, 61, "远程模型失败")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.SendMessage(ctx, 61, conversation.ID, "测试远程失败"); !errors.Is(err, ErrAIProviderUnavailable) {
		t.Fatalf("SendMessage error = %v, want provider unavailable", err)
	}
	var count int64
	if err := db.Model(&model.AIMessage{}).Where("conversation_id = ?", conversation.ID).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("persisted messages after provider failure = %d, want 0", count)
	}
}

func TestAIDisabledProviderReturnsUnavailable(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	svc.cfg = &config.AIConfig{Enabled: false, Provider: "local", Model: "disabled-local"}
	if _, _, err := svc.Chat(ctx, "测试"); !errors.Is(err, ErrAIProviderUnavailable) {
		t.Fatalf("Chat error = %v, want provider unavailable", err)
	}
}

func newAIServiceTest(t *testing.T) (*AIService, *gorm.DB, context.Context) {
	t.Helper()
	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name())
	db, err := database.Connect(&config.DBConfig{Driver: "sqlite", SQLitePath: fmt.Sprintf("file:%s?mode=memory&cache=shared", name)})
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	db.Logger = logger.Default.LogMode(logger.Silent)
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := database.AutoMigrateAndSeed(db, false); err != nil {
		t.Fatalf("AutoMigrateAndSeed: %v", err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	return NewAIService(&config.AIConfig{Enabled: true, Provider: "local", Model: "test-local"}, db), db, ctx
}
