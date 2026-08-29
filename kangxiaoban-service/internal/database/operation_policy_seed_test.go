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

func TestOperationPolicySeedPreservesConfiguredTenantValues(t *testing.T) {
	dsn := fmt.Sprintf("file:operation_policy_seed_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	if err := db.WithContext(ctx).Model(&model.OperationPolicy{}).
		Update("occupancy_warning_percent", 88).Error; err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	var policy model.OperationPolicy
	if err := db.WithContext(ctx).First(&policy).Error; err != nil {
		t.Fatal(err)
	}
	if policy.OccupancyWarningPercent != 88 {
		t.Fatalf("configured policy overwritten: got %.1f", policy.OccupancyWarningPercent)
	}
	if len(policy.MedicationTimePeriods) != 4 {
		t.Fatalf("medication time periods = %d, want 4", len(policy.MedicationTimePeriods))
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.OperationPolicy{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("policy row count = %d, want 1", count)
	}
}
