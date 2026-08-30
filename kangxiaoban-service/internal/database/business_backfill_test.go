package database

import (
	"context"
	"errors"
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

func TestLegacyDemoDisplayNamesAndRelationsAreNormalized(t *testing.T) {
	dsn := fmt.Sprintf("file:legacy_display_names_%d?mode=memory&cache=shared", time.Now().UnixNano())
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

	var caregiver, doctor model.User
	if err := db.Where("username = ?", "caregiver").First(&caregiver).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Where("username = ?", "doctor").First(&doctor).Error; err != nil {
		t.Fatal(err)
	}
	var seedElder model.Elder
	if err := db.Where("id_card = ?", "110101193805120011").First(&seedElder).Error; err != nil {
		t.Fatal(err)
	}
	var seedPlan model.CarePlan
	if err := db.Where("elder_id = ?", seedElder.ID).First(&seedPlan).Error; err != nil {
		t.Fatal(err)
	}
	var seedItem model.CarePlanItem
	if err := db.Where("care_plan_id = ?", seedPlan.ID).First(&seedItem).Error; err != nil {
		t.Fatal(err)
	}
	doctorExecution := model.CareExecution{PlanItemID: seedItem.ID, ElderID: seedElder.ID, ExecutorID: doctor.ID, Executor: "演示医师", Status: "completed", ExecutedAt: time.Now(), Result: "医师复核"}
	if err := db.Create(&doctorExecution).Error; err != nil {
		t.Fatal(err)
	}
	customElder := model.Elder{Name: "机构自定义长者", Gender: "F", BirthDate: "1940-01-01", IDCard: "110101194001010099", Status: 2}
	if err := db.Create(&customElder).Error; err != nil {
		t.Fatal(err)
	}
	customTask := model.CareTask{ElderID: customElder.ID, Title: "早间翻身", Kind: "turnover", Assignee: "李护工", Status: "todo"}
	if err := db.Create(&customTask).Error; err != nil {
		t.Fatal(err)
	}
	yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
	customSchedule := model.Schedule{Staff: "护理员", WorkDate: yesterday, Shift: "morning", RoomScope: "custom"}
	if err := db.Create(&customSchedule).Error; err != nil {
		t.Fatal(err)
	}
	customPlan := model.CarePlan{ElderID: customElder.ID, Name: "机构自定义计划", Status: "active", StartDate: yesterday, CreatedBy: doctor.ID}
	if err := db.Create(&customPlan).Error; err != nil {
		t.Fatal(err)
	}
	customItem := model.CarePlanItem{CarePlanID: customPlan.ID, Title: "机构自定义项目", Kind: "round", Assignee: "李护工", Active: true}
	if err := db.Create(&customItem).Error; err != nil {
		t.Fatal(err)
	}
	customExecution := model.CareExecution{PlanItemID: customItem.ID, ElderID: customElder.ID, Executor: "刘护工", Status: "completed", ExecutedAt: time.Now(), Result: "机构记录"}
	if err := db.Create(&customExecution).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&caregiver).Update("real_name", "演示护工").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&doctor).Update("real_name", "演示医师").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.CareTask{}).Where("assignee_id = ?", caregiver.ID).Update("assignee", "演示护工").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.Schedule{}).Where("staff = ?", "护理员").Update("staff", "演示护工").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.Schedule{}).Where("staff = ?", "医师").Update("staff", "演示医师").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.ShiftHandover{}).Updates(map[string]interface{}{"from_staff": "演示护工", "to_staff": "演示医师"}).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, true); err != nil {
		t.Fatal(err)
	}
	if err := db.Where("username = ?", "caregiver").First(&caregiver).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Where("username = ?", "doctor").First(&doctor).Error; err != nil {
		t.Fatal(err)
	}
	if caregiver.RealName != "护理员" || doctor.RealName != "医师" {
		t.Fatalf("legacy demo display names were retained: caregiver=%q doctor=%q", caregiver.RealName, doctor.RealName)
	}
	var task model.CareTask
	if err := db.Where("assignee_id = ?", caregiver.ID).First(&task).Error; err != nil {
		t.Fatal(err)
	}
	if task.Assignee != "护理员" {
		t.Fatalf("task assignee was not normalized: %q", task.Assignee)
	}
	var schedule model.Schedule
	if err := db.Where("staff = ?", "演示护工").First(&schedule).Error; !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("demo caregiver schedule remains: %+v err=%v", schedule, err)
	}
	if err := db.Where("staff = ?", "演示医师").First(&schedule).Error; !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("demo doctor schedule remains: %+v err=%v", schedule, err)
	}
	var preservedCustomTask model.CareTask
	if err := db.First(&preservedCustomTask, customTask.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedCustomTask.Assignee != "李护工" || preservedCustomTask.AssigneeID != nil {
		t.Fatalf("custom task relation was overwritten: %+v", preservedCustomTask)
	}
	var preservedCustomSchedule model.Schedule
	if err := db.First(&preservedCustomSchedule, customSchedule.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedCustomSchedule.Staff != "护理员" {
		t.Fatalf("historical custom schedule was overwritten: %+v", preservedCustomSchedule)
	}
	var preservedCustomItem model.CarePlanItem
	if err := db.First(&preservedCustomItem, customItem.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedCustomItem.Assignee != "李护工" || preservedCustomItem.AssigneeID != nil {
		t.Fatalf("custom plan item relation was overwritten: %+v", preservedCustomItem)
	}
	var preservedCustomExecution model.CareExecution
	if err := db.First(&preservedCustomExecution, customExecution.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedCustomExecution.Executor != "刘护工" || preservedCustomExecution.ExecutorID != 0 {
		t.Fatalf("custom execution relation was overwritten: %+v", preservedCustomExecution)
	}
	var preservedDoctorExecution model.CareExecution
	if err := db.First(&preservedDoctorExecution, doctorExecution.ID).Error; err != nil {
		t.Fatal(err)
	}
	if preservedDoctorExecution.Executor != "医师" || preservedDoctorExecution.ExecutorID != doctor.ID {
		t.Fatalf("doctor execution was not kept with doctor account: %+v", preservedDoctorExecution)
	}
}

func TestLegacyDuplicateAccountMergePreservesUserReferences(t *testing.T) {
	dsn := fmt.Sprintf("file:legacy_duplicate_accounts_%d?mode=memory&cache=shared", time.Now().UnixNano())
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

	var formalFamily, formalCaregiver, formalDoctor model.User
	for username, target := range map[string]*model.User{
		"family": &formalFamily, "caregiver": &formalCaregiver, "doctor": &formalDoctor,
	} {
		if err := db.Where("username = ?", username).First(target).Error; err != nil {
			t.Fatal(err)
		}
	}
	var elder model.Elder
	if err := db.Order("id").First(&elder).Error; err != nil {
		t.Fatal(err)
	}

	legacyFamily := model.User{Username: "family_demo", PasswordHash: "legacy-family-hash", RealName: "演示家属", Status: 1}
	if err := db.Create(&legacyFamily).Error; err != nil {
		t.Fatal(err)
	}
	legacyCaregiver := model.User{Username: "caregiver_demo", PasswordHash: "legacy-caregiver-hash", RealName: "演示护工", Status: 1}
	if err := db.Create(&legacyCaregiver).Error; err != nil {
		t.Fatal(err)
	}
	var caregiverRole model.Role
	if err := db.Where("code = ?", "caregiver").First(&caregiverRole).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&legacyCaregiver).Association("Roles").Replace([]model.Role{caregiverRole}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.FamilyElder{UserID: legacyFamily.ID, ElderID: elder.ID}).Error; err != nil {
		t.Fatal(err)
	}
	legacyTask := model.CareTask{ElderID: elder.ID, Title: "重复账号关联任务", Kind: "round", AssigneeID: &legacyCaregiver.ID, Assignee: "演示护工", Status: "todo"}
	if err := db.Create(&legacyTask).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Message{SenderID: legacyFamily.ID, ReceiverID: formalDoctor.ID, ElderID: &elder.ID, Content: "历史消息", SentAt: time.Now()}).Error; err != nil {
		t.Fatal(err)
	}

	if err := migrateLegacyAccountNames(db); err != nil {
		t.Fatal(err)
	}
	var reloadedTask model.CareTask
	if err := db.First(&reloadedTask, legacyTask.ID).Error; err != nil {
		t.Fatal(err)
	}
	if reloadedTask.AssigneeID == nil || *reloadedTask.AssigneeID != formalCaregiver.ID {
		t.Fatalf("task assignee reference was not rebound: %+v", reloadedTask)
	}
	var message model.Message
	if err := db.Where("content = ?", "历史消息").First(&message).Error; err != nil {
		t.Fatal(err)
	}
	if message.SenderID != formalFamily.ID {
		t.Fatalf("message sender reference was not rebound: %+v", message)
	}
	var familyBindingCount int64
	if err := db.Model(&model.FamilyElder{}).Where("user_id = ? AND elder_id = ?", formalFamily.ID, elder.ID).Count(&familyBindingCount).Error; err != nil {
		t.Fatal(err)
	}
	if familyBindingCount != 1 {
		t.Fatalf("formal family binding count = %d, want 1", familyBindingCount)
	}
	var oldBindingCount int64
	if err := db.Model(&model.FamilyElder{}).Where("user_id = ?", legacyFamily.ID).Count(&oldBindingCount).Error; err != nil {
		t.Fatal(err)
	}
	if oldBindingCount != 0 {
		t.Fatalf("legacy family binding remains: %d", oldBindingCount)
	}
	for username := range map[string]struct{}{"family_demo": {}, "caregiver_demo": {}} {
		var user model.User
		if err := db.Where("username = ?", username).First(&user).Error; !errors.Is(err, gorm.ErrRecordNotFound) {
			t.Fatalf("legacy account %q remains queryable: %+v err=%v", username, user, err)
		}
	}
	var roleMembership int64
	if err := db.Table("sys_user_role").Where("user_id = ? AND role_id = ?", formalCaregiver.ID, caregiverRole.ID).Count(&roleMembership).Error; err != nil {
		t.Fatal(err)
	}
	if roleMembership != 1 {
		t.Fatalf("formal caregiver role membership count = %d, want 1", roleMembership)
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
