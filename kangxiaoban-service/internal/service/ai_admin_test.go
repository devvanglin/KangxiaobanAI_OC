package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

func TestListRAGDatasetsReturnsDifyInventory(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	var auth string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/datasets" {
			http.NotFound(w, r)
			return
		}
		auth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"data":[{"id":"ds-1","name":"照护SOP","description":"护理规范与应急流程","document_count":12,"word_count":8500000},{"id":"ds-2","name":"急救手册","document_count":3}],"total":2}`)
	}))
	t.Cleanup(server.Close)
	ragKey, err := security.Encrypt("", "dify-key")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", Enabled: true,
		RAGEnabled: true, RAGBaseURL: server.URL, RAGDatasetID: "ds-1", RAGAPIKeyEncrypted: ragKey,
	}).Error; err != nil {
		t.Fatal(err)
	}
	datasets, err := svc.ListRAGDatasets(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer dify-key" {
		t.Fatalf("dify auth header = %q", auth)
	}
	if len(datasets) != 2 || datasets[0].ID != "ds-1" || datasets[0].Name != "照护SOP" ||
		datasets[0].DocumentCount != 12 || datasets[0].Description != "护理规范与应急流程" || datasets[0].WordCount != 8500000 {
		t.Fatalf("datasets = %+v", datasets)
	}
}

func TestListRAGDatasetsWithoutConnectionIsTyped(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	if _, err := svc.ListRAGDatasets(ctx); !errors.Is(err, ErrRAGNotConfigured) {
		t.Fatalf("error = %v, want ErrRAGNotConfigured", err)
	}
}

func TestListRAGDatasetsUnavailableIsTyped(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", Enabled: true,
		RAGEnabled: true, RAGBaseURL: server.URL,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ListRAGDatasets(ctx); !errors.Is(err, ErrRAGUnavailable) {
		t.Fatalf("error = %v, want ErrRAGUnavailable", err)
	}
}

func TestListProviderModelsReturnsVLLMInventory(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	var auth string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/models" {
			http.NotFound(w, r)
			return
		}
		auth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"object":"list","data":[{"id":"Qwen2.5-7B-Instruct"},{"id":"Qwen2.5-14B-Instruct"}]}`)
	}))
	t.Cleanup(server.Close)
	apiKey, err := security.Encrypt("", "vllm-key")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", BaseURL: server.URL, APIKeyEncrypted: apiKey, Enabled: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	models, err := svc.ListProviderModels(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer vllm-key" {
		t.Fatalf("vllm auth header = %q", auth)
	}
	if len(models) != 2 || models[0].ID != "Qwen2.5-7B-Instruct" || models[1].ID != "Qwen2.5-14B-Instruct" {
		t.Fatalf("models = %+v", models)
	}
}

func TestListProviderModelsWithoutConnectionIsTyped(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	if _, err := svc.ListProviderModels(ctx); !errors.Is(err, ErrModelSourceNotConfigured) {
		t.Fatalf("error = %v, want ErrModelSourceNotConfigured", err)
	}
}

func TestConnectionUpdatePersistsWithTenantScope(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	saved, err := svc.UpdateConnection(ctx, AIConnectionUpdate{
		Provider: "http", BaseURL: "http://10.0.0.8:8000", APIKey: "sk-test",
		RAGEnabled: true, RAGBaseURL: "https://dify.example.com", RAGDatasetID: "ds-9", RAGAPIKey: "dify-key",
		Enabled: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if saved.ID == 0 || saved.Provider != "http" || saved.APIKeyEncrypted == "" || saved.RAGAPIKeyEncrypted == "" {
		t.Fatalf("saved connection = %+v", saved)
	}
	if strings.Contains(saved.APIKeyEncrypted, "sk-test") {
		t.Fatal("connection key must be stored encrypted")
	}

	// 密钥留空表示保留原值。
	if _, err := svc.UpdateConnection(ctx, AIConnectionUpdate{
		Provider: "http", BaseURL: "http://10.0.0.9:8000", Enabled: true,
	}); err != nil {
		t.Fatal(err)
	}
	reloaded, err := svc.Connection(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.BaseURL != "http://10.0.0.9:8000" || reloaded.APIKeyEncrypted == "" {
		t.Fatalf("key not preserved across update: %+v", reloaded)
	}

	// 第二个租户的连接互不可见。
	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "conn-tenant-two", Name: "连接第二机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	second, err := svc.Connection(ctx2)
	if err != nil {
		t.Fatal(err)
	}
	if second.BaseURL != "" {
		t.Fatalf("tenant two saw tenant one connection: %+v", second)
	}
}

func TestChatUsesConnectionEndpointAndAssignmentModel(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Model    string `json:"model"`
			Messages []struct {
				Role    string `json:"role"`
				Content string `json:"content"`
			} `json:"messages"`
		}
		raw, _ := io.ReadAll(r.Body)
		if err := json.Unmarshal(raw, &body); err != nil {
			http.Error(w, "bad body", http.StatusBadRequest)
			return
		}
		if body.Model != "assigned-model" {
			http.Error(w, "assignment model not used", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"choices":[{"message":{"content":"好的。"}}],"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}`)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", BaseURL: server.URL, Enabled: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "http", Model: "assigned-model",
		SystemPrompt: "你是照护助理。", Enabled: true, Allowed: true, IsDefault: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	answer, modelName, err := svc.Chat(ctx, 7, "你好")
	if err != nil {
		t.Fatal(err)
	}
	if answer != "好的。" || modelName != "assigned-model" {
		t.Fatalf("unexpected chat result %q / %q", answer, modelName)
	}
}

func TestListRAGDatasetsFetchesAllPages(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	page := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		page += 1
		w.Header().Set("Content-Type", "application/json")
		if page == 1 {
			fmt.Fprint(w, `{"data":[{"id":"ds-1","name":"第一页"}],"has_more":true}`)
			return
		}
		fmt.Fprint(w, `{"data":[{"id":"ds-2","name":"第二页"}],"has_more":false}`)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", Enabled: true,
		RAGEnabled: true, RAGBaseURL: server.URL,
	}).Error; err != nil {
		t.Fatal(err)
	}
	datasets, err := svc.ListRAGDatasets(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if page != 2 {
		t.Fatalf("pages fetched = %d, want 2", page)
	}
	if len(datasets) != 2 || datasets[0].ID != "ds-1" || datasets[1].ID != "ds-2" {
		t.Fatalf("datasets = %+v", datasets)
	}
}

func TestProbeProviderModelsWithoutSavedConnection(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer probe-key" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		fmt.Fprint(w, `{"data":[{"id":"probe-model"}]}`)
	}))
	t.Cleanup(server.Close)
	models, err := svc.ProbeProviderModels(ctx, server.URL, "probe-key")
	if err != nil {
		t.Fatal(err)
	}
	if len(models) != 1 || models[0].ID != "probe-model" {
		t.Fatalf("models = %+v", models)
	}
}

func TestProbeProviderModelsFallsBackToStoredKey(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	var auth string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth = r.Header.Get("Authorization")
		fmt.Fprint(w, `{"data":[]}`)
	}))
	t.Cleanup(server.Close)
	storedKey, err := security.Encrypt("", "stored-key")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", BaseURL: server.URL, APIKeyEncrypted: storedKey, Enabled: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ProbeProviderModels(ctx, server.URL, ""); err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer stored-key" {
		t.Fatalf("auth = %q, want stored key fallback", auth)
	}
}

func TestTestProviderModelsReportsPerModel(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Model string `json:"model"`
		}
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		if body.Model == "bad-model" {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"pong"}}]}`)
	}))
	t.Cleanup(server.Close)
	results, err := svc.TestProviderModels(ctx, server.URL, "k", []string{"good-model", "bad-model", "bad-model", " "})
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 2 {
		t.Fatalf("results = %+v, want 2 (deduped)", results)
	}
	if !results[0].Success || results[0].LatencyMS < 0 {
		t.Fatalf("good model result = %+v", results[0])
	}
	if results[1].Success || results[1].Error != "HTTP 500" {
		t.Fatalf("bad model result = %+v", results[1])
	}
}

func TestTestProviderModelsUsesTypedEndpoints(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)
	paths := map[string]int{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths[r.URL.Path] += 1
		fmt.Fprint(w, `{"ok":true}`)
	}))
	t.Cleanup(server.Close)
	_, err := svc.TestProviderModels(ctx, server.URL, "k", []string{
		"Qwen3-VL-4B-Instruct", "Qwen3-VL-Embedding-2B", "Qwen3-Reranker-0.6B", "bge-large-zh",
	})
	if err != nil {
		t.Fatal(err)
	}
	if paths["/v1/chat/completions"] != 1 || paths["/v1/embeddings"] != 2 || paths["/v1/rerank"] != 1 {
		t.Fatalf("endpoint hits = %v", paths)
	}
}

func TestListRAGDatasetsToleratesV1Suffix(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	var hit string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hit = r.URL.Path
		fmt.Fprint(w, `{"data":[{"id":"ds-1","name":"知识库"}]}`)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIConnection{
		Provider: "http", Enabled: true,
		RAGEnabled: true, RAGBaseURL: server.URL + "/v1",
	}).Error; err != nil {
		t.Fatal(err)
	}
	datasets, err := svc.ListRAGDatasets(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if hit != "/v1/datasets" {
		t.Fatalf("probed path = %q, want /v1/datasets", hit)
	}
	if len(datasets) != 1 || datasets[0].ID != "ds-1" {
		t.Fatalf("datasets = %+v", datasets)
	}
}
