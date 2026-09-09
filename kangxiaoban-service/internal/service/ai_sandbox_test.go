package service

import (
	"strings"
	"testing"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
)

func TestSandboxSettingOverridesEnvAndPersists(t *testing.T) {
	svc, db, ctx := newAIServiceTest(t)
	svc.sandboxCfg = config.SandboxConfig{
		Enabled: false, Domain: "10.0.0.9:18081", Protocol: "http",
		Image: "python:3.12-slim", APIKey: "env-key",
	}

	// 未建行：回落 .env 配置。
	view, err := svc.SandboxSetting(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if view.Source != "env" || view.Domain != "10.0.0.9:18081" || !view.APIKeyConfigured {
		t.Fatalf("env fallback view = %+v", view)
	}

	// 保存管理端设置后：DB 行覆盖 env，密钥加密落库、视图只回旗标。
	saved, err := svc.UpdateSandboxSetting(ctx, AISandboxSettingInput{
		Enabled: true, Domain: "10.0.0.8:18081", Protocol: "http",
		Image: "python:3.12-slim", APIKey: "sb-key",
	})
	if err != nil {
		t.Fatal(err)
	}
	if saved.Source != "db" || !saved.Enabled || saved.Domain != "10.0.0.8:18081" || !saved.APIKeyConfigured {
		t.Fatalf("saved view = %+v", saved)
	}
	var row model.AISandboxSetting
	if err := db.WithContext(ctx).Order("id ASC").First(&row).Error; err != nil {
		t.Fatal(err)
	}
	if row.APIKeyEncrypted == "" || strings.Contains(row.APIKeyEncrypted, "sb-key") {
		t.Fatalf("sandbox key must be stored encrypted: %q", row.APIKeyEncrypted)
	}

	// 运行时生效配置来自 DB 行；密钥留空表示保留原值。
	if _, err := svc.UpdateSandboxSetting(ctx, AISandboxSettingInput{
		Enabled: true, Domain: "10.0.0.8:18081", Protocol: "http", Image: "python:3.12-slim",
	}); err != nil {
		t.Fatal(err)
	}
	effective := svc.effectiveSandboxConfig(ctx)
	if !effective.Enabled || effective.Domain != "10.0.0.8:18081" || effective.APIKey != "sb-key" {
		t.Fatalf("effective config = %+v", effective)
	}
}

func TestListAgentToolsReflectsAvailability(t *testing.T) {
	svc, _, ctx := newAIServiceTest(t)

	// 默认（无 RAG、无沙箱）：数据工具可用，知识库工具不可用，无沙箱工具。
	tools := svc.ListAgentTools(ctx)
	byName := map[string]AgentToolInfo{}
	for _, tool := range tools {
		byName[tool.Name] = tool
	}
	if elders, ok := byName["get_elders"]; !ok || !elders.Active || elders.Permission != "elder:read" {
		t.Fatalf("get_elders = %+v", elders)
	}
	if kb, ok := byName["search_knowledge_base"]; !ok || kb.Active || kb.Mode != "all" {
		t.Fatalf("search_knowledge_base = %+v", kb)
	}
	for _, tool := range tools {
		if tool.Kind == "sandbox" {
			t.Fatalf("sandbox tool must be hidden while disabled: %+v", tool)
		}
	}

	// 配置 RAG 与沙箱后：知识库可用，4 个沙箱工具出现。
	svc.cfg.RAG = config.DifyConfig{BaseURL: "http://dify.example.com", DatasetID: "ds-1", APIKey: "k"}
	svc.cfg.ConfigKey = "test-key"
	if _, err := svc.UpdateSandboxSetting(ctx, AISandboxSettingInput{
		Enabled: true, Domain: "10.0.0.8:18081", Protocol: "http",
		Image: "python:3.12-slim", APIKey: "sb-key",
	}); err != nil {
		t.Fatal(err)
	}
	tools = svc.ListAgentTools(ctx)
	byName = map[string]AgentToolInfo{}
	sandboxCount := 0
	for _, tool := range tools {
		byName[tool.Name] = tool
		if tool.Kind == "sandbox" && tool.Active {
			sandboxCount++
		}
	}
	if !byName["search_knowledge_base"].Active {
		t.Fatalf("knowledge tool should be active with rag configured")
	}
	if sandboxCount != 4 {
		t.Fatalf("sandbox tools = %d, want 4", sandboxCount)
	}
}
