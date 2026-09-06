package service

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

func TestChatRecordsUsageLogForLocalProvider(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	answer, modelName, err := svc.Chat(ctx, 7, "心率异常怎么判断？")
	if err != nil {
		t.Fatal(err)
	}
	if answer == "" || modelName != "test-local" {
		t.Fatalf("unexpected chat result %q / %q", answer, modelName)
	}
	var logs []model.AIUsageLog
	if err := db.WithContext(ctx).Order("id ASC").Find(&logs).Error; err != nil {
		t.Fatal(err)
	}
	if len(logs) != 1 {
		t.Fatalf("usage logs = %d, want 1", len(logs))
	}
	entry := logs[0]
	if entry.UserID != 7 || entry.RoleScope != "caregiver" || entry.Provider != "local" {
		t.Fatalf("usage log identity = %+v", entry)
	}
	if entry.TotalTokens <= 0 || entry.PromptTokens <= 0 || entry.CompletionTokens <= 0 {
		t.Fatalf("estimated tokens missing: %+v", entry)
	}
	if entry.TotalTokens != entry.PromptTokens+entry.CompletionTokens {
		t.Fatalf("token accounting mismatch: %+v", entry)
	}
	if !entry.Success || entry.RAGUsed {
		t.Fatalf("unexpected success/rag flags: %+v", entry)
	}

	summary, err := svc.UsageSummary(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if summary.TotalTokens != entry.TotalTokens || summary.TodayCalls != 1 || summary.RAGCalls != 0 {
		t.Fatalf("summary mismatch: %+v", summary)
	}
	if math.Abs(summary.AvgDailyCalls-1.0/30.0) > 1e-9 {
		t.Fatalf("avg daily calls = %f", summary.AvgDailyCalls)
	}
}

func TestUsageSummaryAggregatesAcrossDays(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	now := time.Now()
	seeds := []struct {
		ageDays int
		tokens  int64
		ragUsed bool
	}{
		{ageDays: 0, tokens: 100, ragUsed: true},
		{ageDays: 0, tokens: 50},
		{ageDays: 10, tokens: 200},
		{ageDays: 40, tokens: 999},
	}
	for i, seed := range seeds {
		entry := model.AIUsageLog{
			Base:        model.Base{CreatedAt: now.AddDate(0, 0, -seed.ageDays)},
			UserID:      uint(i + 1),
			RoleScope:   "caregiver",
			Provider:    "local",
			TotalTokens: seed.tokens,
			RAGUsed:     seed.ragUsed,
			Success:     true,
		}
		if err := db.WithContext(ctx).Create(&entry).Error; err != nil {
			t.Fatal(err)
		}
	}
	summary, err := svc.UsageSummary(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if summary.TotalTokens != 1349 {
		t.Fatalf("total tokens = %d, want 1349", summary.TotalTokens)
	}
	if summary.TodayCalls != 2 {
		t.Fatalf("today calls = %d, want 2", summary.TodayCalls)
	}
	if summary.RAGCalls != 1 {
		t.Fatalf("rag calls = %d, want 1", summary.RAGCalls)
	}
	if math.Abs(summary.AvgDailyCalls-0.1) > 1e-9 {
		t.Fatalf("avg daily calls = %f, want 0.1", summary.AvgDailyCalls)
	}
}

func TestChatHTTPRecordsProviderUsageTokens(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"choices":[{"message":{"content":"好的，请注意休息。"}}],"usage":{"prompt_tokens":12,"completion_tokens":34,"total_tokens":46}}`)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "http", BaseURL: server.URL, Model: "remote-model",
		Enabled: true, Allowed: true, IsDefault: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	answer, modelName, err := svc.Chat(ctx, 7, "你好")
	if err != nil {
		t.Fatal(err)
	}
	if answer != "好的，请注意休息。" || modelName != "remote-model" {
		t.Fatalf("unexpected chat result %q / %q", answer, modelName)
	}
	var entry model.AIUsageLog
	if err := db.WithContext(ctx).Order("id DESC").First(&entry).Error; err != nil {
		t.Fatal(err)
	}
	if entry.PromptTokens != 12 || entry.CompletionTokens != 34 || entry.TotalTokens != 46 {
		t.Fatalf("provider tokens not recorded: %+v", entry)
	}
	if entry.Provider != "http" || entry.ConfigID == 0 {
		t.Fatalf("usage log identity = %+v", entry)
	}
}

func TestChatHTTPInjectsRAGContextAndCountsCall(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	var chatBody, ragAuth string
	chatServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		chatBody = string(raw)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"choices":[{"message":{"content":"请按跌倒处置流程处理。"}}],"usage":{"prompt_tokens":20,"completion_tokens":10,"total_tokens":30}}`)
	}))
	t.Cleanup(chatServer.Close)
	ragServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/datasets/ds-1/retrieve" {
			http.NotFound(w, r)
			return
		}
		ragAuth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"records":[{"segment":{"content":"跌倒处置流程：先评估意识与伤情。"}}]}`)
	}))
	t.Cleanup(ragServer.Close)
	ragKey, err := security.Encrypt("", "rag-key")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "http", BaseURL: chatServer.URL, Model: "remote-model",
		Enabled: true, Allowed: true, IsDefault: true,
		RAGEnabled: true, RAGBaseURL: ragServer.URL, RAGDatasetID: "ds-1", RAGAPIKeyEncrypted: ragKey,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if _, _, err := svc.Chat(ctx, 7, "长者跌倒了怎么办？"); err != nil {
		t.Fatal(err)
	}
	if ragAuth != "Bearer rag-key" {
		t.Fatalf("rag auth header = %q", ragAuth)
	}
	if !strings.Contains(chatBody, "跌倒处置流程：先评估意识与伤情。") || !strings.Contains(chatBody, "长者跌倒了怎么办？") {
		t.Fatalf("rag context not injected into chat request: %s", chatBody)
	}
	var entry model.AIUsageLog
	if err := db.WithContext(ctx).Order("id DESC").First(&entry).Error; err != nil {
		t.Fatal(err)
	}
	if !entry.RAGUsed {
		t.Fatalf("rag usage not recorded: %+v", entry)
	}
	summary, err := svc.UsageSummary(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if summary.RAGCalls != 1 {
		t.Fatalf("rag calls = %d, want 1", summary.RAGCalls)
	}
}

func TestChatHTTPFailureStillRecordsAttempt(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "provider unavailable", http.StatusBadGateway)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "http", BaseURL: server.URL, Model: "remote-model",
		Enabled: true, Allowed: true, IsDefault: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if _, _, err := svc.Chat(ctx, 7, "你好"); !errors.Is(err, ErrAIProviderUnavailable) {
		t.Fatalf("Chat error = %v, want provider unavailable", err)
	}
	var entry model.AIUsageLog
	if err := db.WithContext(ctx).Order("id DESC").First(&entry).Error; err != nil {
		t.Fatal(err)
	}
	if entry.Success || entry.TotalTokens != 0 {
		t.Fatalf("failed attempt log = %+v", entry)
	}
	summary, err := svc.UsageSummary(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if summary.TodayCalls != 1 {
		t.Fatalf("failed attempt should still count as a call: %+v", summary)
	}
}

func TestUsageLogIsTenantScoped(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	if _, _, err := svc.Chat(ctx, 7, "心率异常怎么判断？"); err != nil {
		t.Fatal(err)
	}
	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "usage-tenant-two", Name: "用量第二机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	if _, _, err := svc.Chat(ctx2, 8, "长者跌倒了怎么办？"); err != nil {
		t.Fatal(err)
	}
	first, err := svc.UsageSummary(ctx)
	if err != nil {
		t.Fatal(err)
	}
	second, err := svc.UsageSummary(ctx2)
	if err != nil {
		t.Fatal(err)
	}
	if first.TodayCalls != 1 || second.TodayCalls != 1 {
		t.Fatalf("tenant scoping broken: %+v / %+v", first, second)
	}
}
