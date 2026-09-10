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

func TestAdmissionSeedPreservesExecutableAdjustmentRules(t *testing.T) {
	dsn := fmt.Sprintf("file:admission_seed_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))

	var ability model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("code = ?", admissionTemplateCode).First(&ability).Error; err != nil {
		t.Fatal(err)
	}
	ability.AdjustmentRules[2].Conditions[0].Threshold = 7
	if err := db.WithContext(ctx).Model(&ability).Select("AdjustmentRules").Updates(&ability).Error; err != nil {
		t.Fatal(err)
	}

	var moca model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("code = ?", "MOCA_BEIJING").First(&moca).Error; err != nil {
		t.Fatal(err)
	}
	moca.AdjustmentRules[0].Conditions[0].Threshold = 5
	if err := db.WithContext(ctx).Model(&moca).Select("AdjustmentRules").Updates(&moca).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Where("id = ?", ability.ID).First(&ability).Error; err != nil {
		t.Fatal(err)
	}
	if got := ability.AdjustmentRules[2].Conditions[0].Threshold; got != 7 {
		t.Fatalf("ability rule threshold overwritten: got %d, want 7", got)
	}
	if err := db.WithContext(ctx).Where("id = ?", moca.ID).First(&moca).Error; err != nil {
		t.Fatal(err)
	}
	if got := moca.AdjustmentRules[0].Conditions[0].Threshold; got != 5 {
		t.Fatalf("screening rule threshold overwritten: got %d, want 5", got)
	}
}

func TestAdmissionSeedPreservesInstitutionCustomizationsAcrossRestart(t *testing.T) {
	dsn := fmt.Sprintf("file:admission_seed_preserve_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))

	var ability model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("code = ?", admissionTemplateCode).First(&ability).Error; err != nil {
		t.Fatal(err)
	}
	ability.Name = "机构自定义入住评估"
	ability.Description = "机构版说明"
	ability.Enabled = false
	if err := db.WithContext(ctx).Model(&ability).Select("Name", "Description", "Enabled").Updates(&ability).Error; err != nil {
		t.Fatal(err)
	}

	var question model.AssessmentQuestion
	if err := db.WithContext(ctx).Where("template_id = ? AND code = ?", ability.ID, "B1.1").First(&question).Error; err != nil {
		t.Fatal(err)
	}
	question.Title = "机构自定义进食评估"
	question.Guidance = "机构自定义观察说明"
	if err := db.WithContext(ctx).Model(&question).Select("Title", "Guidance").Updates(&question).Error; err != nil {
		t.Fatal(err)
	}
	var option model.AssessmentOption
	if err := db.WithContext(ctx).Where("question_id = ? AND code = ?", question.ID, "score_4").First(&option).Error; err != nil {
		t.Fatal(err)
	}
	option.Label = "机构自定义独立完成"
	option.Score = 2
	option.SortOrder = 99
	if err := db.WithContext(ctx).Model(&option).Select("Label", "Score", "SortOrder").Updates(&option).Error; err != nil {
		t.Fatal(err)
	}

	var dictionary model.AdmissionDictionaryItem
	if err := db.WithContext(ctx).Where("template_id = ? AND category = ? AND code = ?", ability.ID, "gender", "M").First(&dictionary).Error; err != nil {
		t.Fatal(err)
	}
	dictionary.Label = "机构男"
	dictionary.Enabled = false
	if err := db.WithContext(ctx).Model(&dictionary).Select("Label", "Enabled").Updates(&dictionary).Error; err != nil {
		t.Fatal(err)
	}

	var plan model.AdmissionCarePlanTemplate
	if err := db.WithContext(ctx).Where("template_id = ? AND code = ?", ability.ID, "care_intact").First(&plan).Error; err != nil {
		t.Fatal(err)
	}
	plan.Name = "机构自定义完好照护方案"
	plan.BaseServices = []model.AdmissionCareService{{Code: "custom_service", Title: "机构服务", Kind: "custom", Frequency: "按需"}}
	if err := db.WithContext(ctx).Model(&plan).Select("Name", "BaseServices").Updates(&plan).Error; err != nil {
		t.Fatal(err)
	}

	var screening model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("code = ?", "MINI_COG").First(&screening).Error; err != nil {
		t.Fatal(err)
	}
	screening.Name = "机构版 Mini-Cog"
	screening.Enabled = false
	screening.LevelRules[0].Label = "机构版认知提示"
	if err := db.WithContext(ctx).Model(&screening).Select("Name", "Enabled", "LevelRules").Updates(&screening).Error; err != nil {
		t.Fatal(err)
	}
	var screeningQuestion model.AssessmentQuestion
	if err := db.WithContext(ctx).Where("template_id = ? AND code = ?", screening.ID, "MINICOG.RECALL").First(&screeningQuestion).Error; err != nil {
		t.Fatal(err)
	}
	screeningQuestion.Title = "机构版回忆题"
	if err := db.WithContext(ctx).Model(&screeningQuestion).Select("Title").Updates(&screeningQuestion).Error; err != nil {
		t.Fatal(err)
	}
	var screeningOption model.AssessmentOption
	if err := db.WithContext(ctx).Where("question_id = ? AND code = ?", screeningQuestion.ID, "score_1").First(&screeningOption).Error; err != nil {
		t.Fatal(err)
	}
	screeningOption.Label = "机构版1分"
	screeningOption.Score = 0
	if err := db.WithContext(ctx).Model(&screeningOption).Select("Label", "Score").Updates(&screeningOption).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}

	var gotAbility model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("id = ?", ability.ID).First(&gotAbility).Error; err != nil {
		t.Fatal(err)
	}
	if gotAbility.Name != "机构自定义入住评估" || gotAbility.Description != "机构版说明" || gotAbility.Enabled {
		t.Fatalf("ability metadata was overwritten: %+v", gotAbility)
	}
	var gotQuestion model.AssessmentQuestion
	if err := db.WithContext(ctx).Where("id = ?", question.ID).First(&gotQuestion).Error; err != nil {
		t.Fatal(err)
	}
	if gotQuestion.Title != "机构自定义进食评估" || gotQuestion.Guidance != "机构自定义观察说明" {
		t.Fatalf("ability question was overwritten: %+v", gotQuestion)
	}
	var gotOption model.AssessmentOption
	if err := db.WithContext(ctx).Where("id = ?", option.ID).First(&gotOption).Error; err != nil {
		t.Fatal(err)
	}
	if gotOption.Label != "机构自定义独立完成" || gotOption.Score != 2 || gotOption.SortOrder != 99 {
		t.Fatalf("ability option was overwritten: %+v", gotOption)
	}
	var gotDictionary model.AdmissionDictionaryItem
	if err := db.WithContext(ctx).Where("id = ?", dictionary.ID).First(&gotDictionary).Error; err != nil {
		t.Fatal(err)
	}
	if gotDictionary.Label != "机构男" || gotDictionary.Enabled {
		t.Fatalf("dictionary item was overwritten: %+v", gotDictionary)
	}
	var gotPlan model.AdmissionCarePlanTemplate
	if err := db.WithContext(ctx).Where("id = ?", plan.ID).First(&gotPlan).Error; err != nil {
		t.Fatal(err)
	}
	if gotPlan.Name != "机构自定义完好照护方案" || len(gotPlan.BaseServices) != 1 || gotPlan.BaseServices[0].Code != "custom_service" {
		t.Fatalf("care plan was overwritten: %+v", gotPlan)
	}
	var gotScreening model.AssessmentTemplate
	if err := db.WithContext(ctx).Where("id = ?", screening.ID).First(&gotScreening).Error; err != nil {
		t.Fatal(err)
	}
	if gotScreening.Name != "机构版 Mini-Cog" || gotScreening.Enabled || gotScreening.LevelRules[0].Label != "机构版认知提示" {
		t.Fatalf("screening metadata was overwritten: %+v", gotScreening)
	}
	var gotScreeningQuestion model.AssessmentQuestion
	if err := db.WithContext(ctx).Where("id = ?", screeningQuestion.ID).First(&gotScreeningQuestion).Error; err != nil {
		t.Fatal(err)
	}
	if gotScreeningQuestion.Title != "机构版回忆题" {
		t.Fatalf("screening question was overwritten: %+v", gotScreeningQuestion)
	}
	var gotScreeningOption model.AssessmentOption
	if err := db.WithContext(ctx).Where("id = ?", screeningOption.ID).First(&gotScreeningOption).Error; err != nil {
		t.Fatal(err)
	}
	if gotScreeningOption.Label != "机构版1分" || gotScreeningOption.Score != 0 {
		t.Fatalf("screening option was overwritten: %+v", gotScreeningOption)
	}
}
