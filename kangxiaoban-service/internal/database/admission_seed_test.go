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
