package service

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
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
		fmt.Fprint(w, `{"data":[{"id":"ds-1","name":"照护SOP","document_count":12},{"id":"ds-2","name":"急救手册","document_count":3}],"total":2}`)
	}))
	t.Cleanup(server.Close)
	ragKey, err := security.Encrypt("", "dify-key")
	if err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "local", Model: "kxb-local",
		Enabled: true, Allowed: true, IsDefault: true,
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
	if len(datasets) != 2 || datasets[0].ID != "ds-1" || datasets[0].Name != "照护SOP" || datasets[0].DocumentCount != 12 {
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
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "local", Model: "kxb-local",
		Enabled: true, Allowed: true, IsDefault: true,
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
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "doctor", Provider: "http", BaseURL: server.URL, Model: "Qwen2.5-7B-Instruct",
		APIKeyEncrypted: apiKey, Enabled: true, Allowed: true, IsDefault: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	models, err := svc.ListProviderModels(ctx, "doctor")
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

func TestListProviderModelsRespectsRoleScope(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"data":[{"id":"m"}]}`)
	}))
	t.Cleanup(server.Close)
	if err := db.WithContext(ctx).Create(&model.AIModelConfig{
		RoleScope: "caregiver", Provider: "http", BaseURL: server.URL, Model: "m",
		Enabled: true, Allowed: true, IsDefault: true,
	}).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ListProviderModels(ctx, "caregiver"); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ListProviderModels(ctx, "doctor"); !errors.Is(err, ErrModelSourceNotConfigured) {
		t.Fatalf("doctor error = %v, want ErrModelSourceNotConfigured", err)
	}
	// 空 role 默认回退到护工端。
	if _, err := svc.ListProviderModels(ctx, ""); err != nil {
		t.Fatalf("empty role error = %v, want nil", err)
	}
}
