package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

func TestCareExecutionIgnoresClientReviewFields(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	plan := model.CarePlan{ElderID: 1, Name: "安全测试计划", Status: "active"}
	if err := db.WithContext(ctx).Create(&plan).Error; err != nil {
		t.Fatal(err)
	}
	item := model.CarePlanItem{CarePlanID: plan.ID, Title: "安全测试项目", Active: true}
	if err := db.WithContext(ctx).Create(&item).Error; err != nil {
		t.Fatal(err)
	}
	svc := NewCareService(repository.NewCareRepository(db))
	reviewedAt := time.Now().Add(-time.Hour)
	execution := model.CareExecution{
		PlanItemID: item.ID, ElderID: plan.ElderID, ExecutorID: doctorID,
		Status: "reviewed", ReviewedBy: doctorID, ReviewedAt: &reviewedAt,
		Result: "完成", ExecutedAt: time.Now(),
	}
	if err := svc.CreateExecution(ctx, &execution); err != nil {
		t.Fatal(err)
	}
	if execution.Status != "completed" || execution.ReviewedBy != 0 || execution.ReviewedAt != nil {
		t.Fatalf("server-owned fields were not reset: status=%q reviewer=%d reviewed_at=%v", execution.Status, execution.ReviewedBy, execution.ReviewedAt)
	}
	var stored model.CareExecution
	if err := db.WithContext(ctx).First(&stored, execution.ID).Error; err != nil {
		t.Fatal(err)
	}
	if stored.Status != "completed" || stored.ReviewedBy != 0 || stored.ReviewedAt != nil {
		t.Fatalf("persisted server-owned fields are unsafe: %+v", stored)
	}
}

func TestMessagePeerMustBelongToCurrentTenant(t *testing.T) {
	_, db, doctorID, ctx1 := newAdmissionTestService(t)
	tenant2 := model.Tenant{Base: model.Base{TenantID: 2}, Code: "message-tenant-two", Name: "消息测试机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, tenant2.ID)
	peer := model.User{Username: "message-tenant-two-user", PasswordHash: "unused", Status: 1}
	if err := db.WithContext(ctx2).Create(&peer).Error; err != nil {
		t.Fatal(err)
	}
	svc := NewMessageService(repository.NewMessageRepository(db))
	if _, err := svc.Send(ctx1, doctorID, peer.ID, nil, "cross tenant", "chat"); !errors.Is(err, ErrMessagePeerUnavailable) {
		t.Fatalf("cross-tenant send error = %v, want ErrMessagePeerUnavailable", err)
	}
	if _, err := svc.Send(ctx2, peer.ID, doctorID, nil, "cross tenant", "chat"); !errors.Is(err, ErrMessagePeerUnavailable) {
		t.Fatalf("reverse cross-tenant send error = %v, want ErrMessagePeerUnavailable", err)
	}
}

func TestAdmissionRejectsLinkedElderIdentityConflict(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	var existing model.Elder
	if err := db.WithContext(ctx).Where("id_card <> ''").First(&existing).Error; err != nil {
		t.Fatal(err)
	}
	linked := model.Elder{Name: "待入住档案", IDCard: "LINKED-ORIGINAL", Status: 1}
	if err := db.WithContext(ctx).Create(&linked).Error; err != nil {
		t.Fatal(err)
	}
	input := validAdmissionInput(t, svc, db, ctx)
	input.ElderID = &linked.ID
	input.IDCard = existing.IDCard
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	_, err = svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if !errors.Is(err, ErrAdmissionElderConflict) {
		t.Fatalf("linked elder identity conflict = %v, want ErrAdmissionElderConflict", err)
	}
}

func TestTenantContextAcrossBusinessModules(t *testing.T) {
	_, db, _, ctx1 := newAdmissionTestService(t)
	tenant2 := model.Tenant{Base: model.Base{TenantID: 2}, Code: "business-tenant-two", Name: "业务测试机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, tenant2.ID)
	elder := model.Elder{Name: "二号机构专属长者", IDCard: "TENANT-2-ELDER", Status: 2}
	if err := db.WithContext(ctx2).Create(&elder).Error; err != nil {
		t.Fatal(err)
	}
	stock := model.MedicineStock{MedicineName: "二号机构专属药品", Qty: 1}
	if err := db.WithContext(ctx2).Create(&stock).Error; err != nil {
		t.Fatal(err)
	}
	schedule := model.Schedule{Staff: "二号机构专属员工", WorkDate: "2099-01-01", Shift: "morning"}
	if err := db.WithContext(ctx2).Create(&schedule).Error; err != nil {
		t.Fatal(err)
	}
	health := model.HealthRecord{ElderID: elder.ID, Source: "manual", RecordTime: time.Now()}
	if err := db.WithContext(ctx2).Create(&health).Error; err != nil {
		t.Fatal(err)
	}

	elderSvc := NewElderService(repository.NewElderRepository(db))
	elders, total, err := elderSvc.List(ctx1, "二号机构专属", 0, 0, 1, 20)
	if err != nil || total != 0 || len(elders) != 0 {
		t.Fatalf("tenant 1 elder query leaked tenant 2: total=%d len=%d err=%v", total, len(elders), err)
	}
	supplySvc := NewSupplyService(repository.NewSupplyRepository(db))
	stocks, stockTotal, err := supplySvc.ListStock(ctx1, "二号机构专属", 1, 20)
	if err != nil || stockTotal != 0 || len(stocks) != 0 {
		t.Fatalf("tenant 1 stock query leaked tenant 2: total=%d len=%d err=%v", stockTotal, len(stocks), err)
	}
	scheduleSvc := NewScheduleService(repository.NewScheduleRepository(db))
	schedules, scheduleTotal, err := scheduleSvc.ListSchedules(ctx1, "2099-01-01", 1, 20)
	if err != nil || scheduleTotal != 0 || len(schedules) != 0 {
		t.Fatalf("tenant 1 schedule query leaked tenant 2: total=%d len=%d err=%v", scheduleTotal, len(schedules), err)
	}
	healthSvc := NewHealthService(repository.NewHealthRepository(db))
	records, recordTotal, err := healthSvc.ListByElder(ctx1, elder.ID, 1, 20)
	if err != nil || recordTotal != 0 || len(records) != 0 {
		t.Fatalf("tenant 1 health query leaked tenant 2: total=%d len=%d err=%v", recordTotal, len(records), err)
	}
}
