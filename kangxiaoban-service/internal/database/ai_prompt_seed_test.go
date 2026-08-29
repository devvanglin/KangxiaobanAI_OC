package database

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestAIPromptSuggestionSeedIsTenantScopedAndPreservesEdits(t *testing.T) {
	dsn := fmt.Sprintf("file:ai_prompt_seed_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}

	ctx1 := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	assertAIPromptSuggestionCount(t, db.WithContext(ctx1), 9)
	if err := db.WithContext(ctx1).Model(&model.AIPromptSuggestion{}).
		Where("code = ?", "care-summary").
		Updates(map[string]interface{}{"title": "机构自定义照护摘要", "enabled": false}).Error; err != nil {
		t.Fatal(err)
	}

	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "ai-prompt-tenant-two", Name: "AI 提示词第二机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}

	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	assertAIPromptSuggestionCount(t, db.WithContext(ctx1), 9)
	assertAIPromptSuggestionCount(t, db.WithContext(ctx2), 9)
	var edited model.AIPromptSuggestion
	if err := db.WithContext(ctx1).Where("code = ?", "care-summary").First(&edited).Error; err != nil {
		t.Fatal(err)
	}
	if edited.Title != "机构自定义照护摘要" || edited.Enabled {
		t.Fatalf("tenant edit was overwritten: %+v", edited)
	}
	var tenantTwoDefault model.AIPromptSuggestion
	if err := db.WithContext(ctx2).Where("code = ?", "care-summary").First(&tenantTwoDefault).Error; err != nil {
		t.Fatal(err)
	}
	if tenantTwoDefault.Title == edited.Title || !tenantTwoDefault.Enabled {
		t.Fatalf("tenant two did not receive an independent default: %+v", tenantTwoDefault)
	}

	duplicate := model.AIPromptSuggestion{Code: "care-summary", GroupIndex: 0, Title: "重复", Prompt: "重复", Enabled: true}
	if err := db.WithContext(ctx1).Create(&duplicate).Error; err == nil {
		t.Fatal("duplicate suggestion code in one tenant was accepted")
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	assertAIPromptSuggestionCount(t, db.WithContext(ctx1), 9)
}

func assertAIPromptSuggestionCount(t *testing.T, db *gorm.DB, want int64) {
	t.Helper()
	var count int64
	if err := db.Model(&model.AIPromptSuggestion{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != want {
		t.Fatalf("AI prompt suggestion count = %d, want %d", count, want)
	}
}
