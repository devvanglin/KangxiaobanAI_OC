package service

import (
	"errors"
	"testing"

	"kangxiaoban-service/internal/healthrisk"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

func TestHealthServiceReadsThresholdsFromDatabase(t *testing.T) {
	_, db, _, ctx := newAdmissionTestService(t)
	service := NewHealthService(repository.NewHealthRepository(db))

	if err := db.WithContext(ctx).Model(&model.HealthThreshold{}).Where("metric = ?", "temperature").
		Updates(map[string]interface{}{"warning_max": 40.0, "critical_max": 42.0}).Error; err != nil {
		t.Fatal(err)
	}
	temperature := 38.2
	normal := model.HealthRecord{ElderID: 1, Temperature: &temperature}
	if err := service.Create(ctx, &normal); err != nil {
		t.Fatal(err)
	}
	if normal.RiskLevel != "normal" || normal.IsAbnormal || normal.RiskSummary != "" {
		t.Fatalf("database-adjusted normal result = %+v", normal)
	}

	if err := db.WithContext(ctx).Model(&model.HealthThreshold{}).Where("metric = ?", "temperature").
		Updates(map[string]interface{}{"warning_max": 37.3, "critical_max": 39.0}).Error; err != nil {
		t.Fatal(err)
	}
	warning := model.HealthRecord{ElderID: 1, Temperature: &temperature}
	if err := service.Create(ctx, &warning); err != nil {
		t.Fatal(err)
	}
	if warning.RiskLevel != "warning" || !warning.IsAbnormal || warning.RiskSummary == "" {
		t.Fatalf("database-adjusted warning result = %+v", warning)
	}

	if err := db.WithContext(ctx).Where("metric = ?", "temperature").Delete(&model.HealthThreshold{}).Error; err != nil {
		t.Fatal(err)
	}
	missing := model.HealthRecord{ElderID: 1, Temperature: &temperature}
	if err := service.Create(ctx, &missing); !errors.Is(err, healthrisk.ErrThresholdMissing) {
		t.Fatalf("missing threshold error = %v, want ErrThresholdMissing", err)
	}
}

func TestTaskAndMedicationServerDefaults(t *testing.T) {
	_, db, _, ctx := newAdmissionTestService(t)

	taskService := NewTaskService(repository.NewTaskRepository(db))
	task := model.CareTask{ElderID: 1, Title: "测试用药任务", Kind: "medication"}
	if err := taskService.Create(ctx, &task); err != nil {
		t.Fatal(err)
	}
	if task.Category != "medication" || task.Priority != "normal" {
		t.Fatalf("task defaults not normalized: %+v", task)
	}

	medicationService := NewMedicationService(repository.NewMedicationRepository(db))
	medication := model.MedicationRecord{ElderID: 1, MedicineName: "测试药品", Dosage: "5mg"}
	if err := medicationService.Create(ctx, &medication); err != nil {
		t.Fatal(err)
	}
	if medication.Frequency != "按医嘱" || medication.Route != "口服" || medication.TodayTotal != 1 || medication.TodayDone != 0 || medication.Status != "pending" {
		t.Fatalf("medication defaults not normalized: %+v", medication)
	}
	if err := medicationService.MarkStatus(ctx, medication.ID, "taken"); err != nil {
		t.Fatal(err)
	}
	stored, err := medicationService.Get(ctx, medication.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.TodayDone != stored.TodayTotal || stored.TakenTime == nil {
		t.Fatalf("taken progress not persisted: %+v", stored)
	}
}

func TestTaskServicePreloadsCarePlanInstructions(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	elder := model.Elder{Name: "护理说明测试长者"}
	if err := db.WithContext(ctx).Create(&elder).Error; err != nil {
		t.Fatal(err)
	}
	plan := model.CarePlan{ElderID: elder.ID, Name: "护理说明测试计划", Status: "active", CreatedBy: doctorID}
	if err := db.WithContext(ctx).Create(&plan).Error; err != nil {
		t.Fatal(err)
	}
	item := model.CarePlanItem{CarePlanID: plan.ID, Title: "巡视", Kind: "round", Instructions: "确认呼叫器\n记录巡视结果", Active: true}
	if err := db.WithContext(ctx).Create(&item).Error; err != nil {
		t.Fatal(err)
	}
	task := model.CareTask{ElderID: elder.ID, PlanItemID: &item.ID, Title: item.Title, Kind: item.Kind, Status: "todo"}
	service := NewTaskService(repository.NewTaskRepository(db))
	if err := service.Create(ctx, &task); err != nil {
		t.Fatal(err)
	}

	loaded, err := service.Get(ctx, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.PlanItem == nil || loaded.PlanItem.Instructions != item.Instructions {
		t.Fatalf("Get did not preload care plan instructions: %+v", loaded.PlanItem)
	}
	items, total, err := service.List(ctx, elder.ID, "", 0, 1, 20)
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(items) != 1 || items[0].PlanItem == nil || items[0].PlanItem.Instructions != item.Instructions {
		t.Fatalf("List did not preload care plan instructions: total=%d items=%+v", total, items)
	}
}

func TestElderAllergiesRemainCompatibleWithOlderClients(t *testing.T) {
	_, db, _, ctx := newAdmissionTestService(t)
	service := NewElderService(repository.NewElderRepository(db))

	created := model.Elder{Name: "无过敏史测试长者"}
	if err := service.Create(ctx, &created); err != nil {
		t.Fatal(err)
	}
	if created.Allergies == nil || len(created.Allergies) != 0 {
		t.Fatalf("create should normalize allergies to an empty array: %#v", created.Allergies)
	}

	created.Allergies = []string{"磺胺类"}
	if err := service.Update(ctx, &created); err != nil {
		t.Fatal(err)
	}
	created.Allergies = nil
	if err := service.Update(ctx, &created); err != nil {
		t.Fatal(err)
	}
	reloaded, err := service.Get(ctx, created.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(reloaded.Allergies) != 1 || reloaded.Allergies[0] != "磺胺类" {
		t.Fatalf("legacy update erased allergies: %#v", reloaded.Allergies)
	}
}
