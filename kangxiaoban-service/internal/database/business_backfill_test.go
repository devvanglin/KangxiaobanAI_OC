package database

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestBusinessFieldsSeedAndBackfill(t *testing.T) {
	dsn := fmt.Sprintf("file:business_backfill_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, true); err != nil {
		t.Fatal(err)
	}

	assertBusinessSeed(t, db)

	var task model.CareTask
	if err := db.Where("kind = ?", "medication").First(&task).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&task).Updates(map[string]interface{}{"category": "", "priority": ""}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&task).Update("remark", "").Error; err != nil {
		t.Fatal(err)
	}
	customTask := model.CareTask{ElderID: task.ElderID, Title: "早间翻身", Kind: "turnover", Remark: "机构定制：先检查术侧肢体，再按康复师要求翻身"}
	if err := db.Create(&customTask).Error; err != nil {
		t.Fatal(err)
	}
	var planItem model.CarePlanItem
	if err := db.Where("instructions <> ''").Order("id").First(&planItem).Error; err != nil {
		t.Fatal(err)
	}
	linkedTask := model.CareTask{ElderID: task.ElderID, PlanItemID: &planItem.ID, Title: "护理计划关联任务", Kind: planItem.Kind}
	if err := db.Create(&linkedTask).Error; err != nil {
		t.Fatal(err)
	}
	var medication model.MedicationRecord
	if err := db.Where("status = ?", "taken").First(&medication).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&medication).Updates(map[string]interface{}{"frequency": "", "route": "", "today_total": 0, "today_done": 0}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.Elder{}).Where("name = ?", "张素英").UpdateColumn("allergies", nil).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.HealthThreshold{}).Where("metric = ?", "temperature").Update("warning_max", 38.8).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, true); err != nil {
		t.Fatal(err)
	}
	assertBusinessSeed(t, db)

	var temperature model.HealthThreshold
	if err := db.Where("metric = ?", "temperature").First(&temperature).Error; err != nil {
		t.Fatal(err)
	}
	if temperature.WarningMax == nil || *temperature.WarningMax != 38.8 {
		t.Fatalf("custom threshold was overwritten: %+v", temperature)
	}
	var upgradedMedication model.CareTask
	if err := db.First(&upgradedMedication, task.ID).Error; err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(upgradedMedication.Remark, "核对长者、医嘱") || !strings.Contains(upgradedMedication.Remark, "完成用药记录") {
		t.Fatalf("bootstrap medication instructions were not backfilled: %q", upgradedMedication.Remark)
	}
	var preservedCustom model.CareTask
	if err := db.First(&preservedCustom, customTask.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedCustom.Remark != customTask.Remark {
		t.Fatalf("custom task remark was overwritten: %q", preservedCustom.Remark)
	}
	var copiedPlanInstructions model.CareTask
	if err := db.First(&copiedPlanInstructions, linkedTask.ID).Error; err != nil {
		t.Fatal(err)
	}
	if copiedPlanInstructions.Remark != planItem.Instructions {
		t.Fatalf("linked plan instructions were not copied: got %q want %q", copiedPlanInstructions.Remark, planItem.Instructions)
	}
}

func TestHealthThresholdMetricIsUniquePerTenant(t *testing.T) {
	dsn := fmt.Sprintf("file:health_threshold_unique_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	duplicate := model.HealthThreshold{Metric: "temperature", DisplayName: "重复体温阈值", Enabled: true}
	if err := db.WithContext(ctx1).Create(&duplicate).Error; err == nil {
		t.Fatal("duplicate threshold in one tenant was accepted")
	}

	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "threshold-tenant-two", Name: "阈值测试机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	secondTenant := model.HealthThreshold{Metric: "temperature", DisplayName: "第二机构体温", Enabled: true}
	if err := db.WithContext(ctx2).Create(&secondTenant).Error; err != nil {
		t.Fatalf("same metric in another tenant was rejected: %v", err)
	}
}

func assertBusinessSeed(t *testing.T, db *gorm.DB) {
	t.Helper()
	var thresholdCount int64
	if err := db.Model(&model.HealthThreshold{}).Count(&thresholdCount).Error; err != nil {
		t.Fatal(err)
	}
	if thresholdCount != 8 {
		t.Fatalf("health threshold count = %d, want 8", thresholdCount)
	}
	var healthCategoryCount int64
	if err := db.Model(&model.AdmissionDictionaryItem{}).Where("category = ?", "health_category").Count(&healthCategoryCount).Error; err != nil {
		t.Fatal(err)
	}
	if healthCategoryCount != 10 {
		t.Fatalf("health_category count = %d, want 10", healthCategoryCount)
	}

	var elder model.Elder
	if err := db.Where("name = ?", "张素英").First(&elder).Error; err != nil {
		t.Fatal(err)
	}
	if len(elder.Allergies) != 1 || elder.Allergies[0] != "青霉素" {
		t.Fatalf("elder allergies not seeded/backfilled: %+v", elder.Allergies)
	}

	var task model.CareTask
	if err := db.Where("kind = ?", "medication").First(&task).Error; err != nil {
		t.Fatal(err)
	}
	if task.Category != "medication" || task.Priority == "" {
		t.Fatalf("task business fields incomplete: %+v", task)
	}
	if strings.TrimSpace(task.Remark) == "" {
		t.Fatalf("task execution instructions are empty: %+v", task)
	}

	var health model.HealthRecord
	if err := db.Where("elder_id = ?", elder.ID).Order("id").First(&health).Error; err != nil {
		t.Fatal(err)
	}
	if health.RespiratoryRate == nil || health.Steps == nil || health.SleepHours == nil || health.RiskLevel == "" {
		t.Fatalf("health business fields incomplete: %+v", health)
	}

	var device model.IotDevice
	if err := db.Where("elder_id = ?", elder.ID).First(&device).Error; err != nil {
		t.Fatal(err)
	}
	if device.Battery == nil || device.Building == "" || device.Room == "" || device.Bed == "" {
		t.Fatalf("device business fields or relation incomplete: %+v", device)
	}

	var medication model.MedicationRecord
	if err := db.Where("status = ?", "taken").First(&medication).Error; err != nil {
		t.Fatal(err)
	}
	if medication.Frequency == "" || medication.Route == "" || medication.TodayTotal <= 0 || medication.TodayDone != medication.TodayTotal {
		t.Fatalf("medication business fields incomplete: %+v", medication)
	}
}
