package database

import (
	"context"
	"fmt"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

var defaultAIPromptSuggestions = []model.AIPromptSuggestion{
	{Code: "care-summary", GroupIndex: 0, Title: "资讯：汇总今日重点照护事项", Prompt: "请汇总今天需要优先关注的照护事项", SortOrder: 10, Enabled: true},
	{Code: "health-change", GroupIndex: 0, Title: "健康：解读晨间健康指标变化", Prompt: "请解读今天晨间健康指标的变化和关注重点", SortOrder: 20, Enabled: true},
	{Code: "care-priority", GroupIndex: 0, Title: "如何安排今天的护理优先级", Prompt: "请根据风险和时间节点安排今天的护理优先级", SortOrder: 30, Enabled: true},
	{Code: "shift-records", GroupIndex: 1, Title: "交班：整理下午班重点记录", Prompt: "请帮我整理下午班新增的重点交班记录", SortOrder: 10, Enabled: true},
	{Code: "rehab-progress", GroupIndex: 1, Title: "分享一下近期康复训练的完成情况", Prompt: "请总结近期康复训练完成情况并给出后续建议", SortOrder: 30, Enabled: true},
	{Code: "shift-plan", GroupIndex: 2, Title: "帮我整理一份当班护理工作计划", Prompt: "请帮我整理一份清晰可执行的当班护理工作计划", SortOrder: 10, Enabled: true},
	{Code: "health-trend", GroupIndex: 2, Title: "解读本周异常健康数据趋势", Prompt: "请深度解读本周异常健康数据的变化趋势", SortOrder: 20, Enabled: true},
}

// ensureAIPromptSuggestionConstraint keeps one active suggestion code per tenant.
func ensureAIPromptSuggestionConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID uint
		Code     string
		Count    int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, code, COUNT(*) AS count FROM ai_prompt_suggestions WHERE deleted_at IS NULL GROUP BY tenant_id, code HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active AI prompt suggestion in tenant %d: %s", duplicates[0].TenantID, duplicates[0].Code)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_ai_prompt_suggestions_tenant_code ON ai_prompt_suggestions(tenant_id, code) WHERE deleted_at IS NULL").Error
	case "mysql":
		if !db.Migrator().HasColumn(&model.AIPromptSuggestion{}, "active_code") {
			if err := db.Exec("ALTER TABLE ai_prompt_suggestions ADD COLUMN active_code VARCHAR(64) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN code ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.AIPromptSuggestion{}, "uk_ai_prompt_suggestions_tenant_code") {
			return db.Exec("CREATE UNIQUE INDEX uk_ai_prompt_suggestions_tenant_code ON ai_prompt_suggestions(tenant_id, active_code)").Error
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}

// seedAIPromptSuggestions creates only missing defaults. Institution changes,
// including disabled rows, remain untouched on subsequent starts.
func seedAIPromptSuggestions(db *gorm.DB) error {
	// Retired family prompts are removed globally during startup migration;
	// a normal tenant-scoped context would only clean the default tenant.
	migrationDB := db.WithContext(withoutTenantScope(context.Background()))
	if err := migrationDB.Where("code IN ?", []string{"family-follow-up", "family-script"}).Delete(&model.AIPromptSuggestion{}).Error; err != nil {
		return err
	}
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		tenantDB := db.WithContext(ctx)
		for _, defaultSuggestion := range defaultAIPromptSuggestions {
			var suggestion model.AIPromptSuggestion
			if err := tenantDB.Where("code = ?", defaultSuggestion.Code).
				Attrs(defaultSuggestion).FirstOrCreate(&suggestion).Error; err != nil {
				return err
			}
		}
	}
	return nil
}
