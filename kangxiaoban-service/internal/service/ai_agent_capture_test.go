package service

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/model"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

// Reproduction: one work-mode exchange must put the tool schemas + skill
// fragments into the system message actually sent to the provider.
func TestChatWithAgentWorkModeSendsSchemas(t *testing.T) {
	var captured map[string]interface{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		captured = map[string]interface{}{}
		_ = json.Unmarshal(body, &captured)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"测试回答","reasoning_content":""},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}`))
	}))
	defer server.Close()

	dsn := "file:agent_capture?mode=memory&cache=shared"
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := database.RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := database.AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	ctx = WithAIRoleScope(ctx, "caregiver")

	// point the model service at the capture server through the env config
	cfg := &config.AIConfig{Enabled: true, Provider: "http", BaseURL: server.URL, ConfigKey: "test-key"}
	svc := NewAIService(cfg, db)

	var user model.User
	if err := db.Where("username = ?", "admin").First(&user).Error; err != nil {
		t.Fatal(err)
	}
	var conversation model.AIConversation
	if err := db.Where("user_id = ?", user.ID).First(&conversation).Error; err != nil {
		conversation = model.AIConversation{UserID: user.ID, Title: "t"}
		if err := db.Create(&conversation).Error; err != nil {
			t.Fatal(err)
		}
	}

	exchange, err := svc.SendMessage(ctx, user.ID, conversation.ID, "现在院里一共有多少位在住长者？", "work", nil)
	if err != nil {
		t.Fatal(err)
	}
	if exchange.Answer == "" {
		t.Fatal("empty answer")
	}
	raw, _ := json.Marshal(captured)
	bodyText := string(raw)
	for _, marker := range []string{"可用工具", "get_elders", "get_alerts", "search_knowledge_base", "工具使用规范"} {
		if !strings.Contains(bodyText, marker) {
			t.Fatalf("request body missing %q: %s", marker, bodyText[:min(len(bodyText), 600)])
		}
	}
	messages := captured["messages"].([]interface{})
	first := messages[0].(map[string]interface{})
	if first["role"] != "system" {
		t.Fatalf("first message must be system, got %v", first["role"])
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
