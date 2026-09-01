package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestCreateIntakeCreatesOperationalRecordsWithoutAssessment(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	bed := freeIntakeBed(t, db, ctx)
	var assessmentsBefore, eldersBefore, plansBefore, tasksBefore, billsBefore, flowsBefore, auditsBefore int64
	if err := db.WithContext(ctx).Model(&model.AdmissionAssessment{}).Count(&assessmentsBefore).Error; err != nil {
		t.Fatal(err)
	}
	for modelValue, target := range map[interface{}]*int64{
		&model.Elder{}:    &eldersBefore,
		&model.CarePlan{}: &plansBefore,
		&model.CareTask{}: &tasksBefore,
		&model.Bill{}:     &billsBefore,
		&model.FundFlow{}: &flowsBefore,
		&model.AuditLog{}: &auditsBefore,
	} {
		if err := db.WithContext(ctx).Model(modelValue).Count(target).Error; err != nil {
			t.Fatal(err)
		}
	}

	input := validIntakeInput(bed, "intake-success")
	input.CareFee, input.BedFee, input.Deposit = 2400, 1500, 3000
	result, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatalf("CreateIntake: %v", err)
	}
	if result.Idempotent || result.Intake.ID == 0 || result.Intake.Status != "completed" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if result.Elder.Status != 2 || result.Elder.BedID == nil || *result.Elder.BedID != bed.ID {
		t.Fatalf("elder was not admitted to selected bed: %+v", result.Elder)
	}
	if result.Bed.Status != "occupied" || result.Bed.ElderID == nil || *result.Bed.ElderID != result.Elder.ID {
		t.Fatalf("bed was not occupied: %+v", result.Bed)
	}
	if result.Intake.ResidentNameSnapshot != input.ResidentName ||
		result.Intake.ResidentIDCardSnapshot != input.IDCard ||
		result.Intake.ResidentGenderSnapshot != "F" ||
		result.Intake.ResidentBirthDateSnapshot != input.BirthDate ||
		result.Intake.ResidentAgeSnapshot != input.Age {
		t.Fatalf("identity snapshot was not persisted: %+v", result.Intake)
	}
	if result.CarePlan == nil || len(result.CarePlan.Items) == 0 {
		t.Fatalf("care plan/items missing: %+v", result.CarePlan)
	}
	if result.Bill == nil || result.Bill.Amount != 3900 {
		t.Fatalf("bill = %+v, want amount 3900", result.Bill)
	}
	assertCount(t, db.WithContext(ctx), &model.AdmissionAssessment{}, "", assessmentsBefore)
	assertCount(t, db.WithContext(ctx), &model.Elder{}, "", eldersBefore+1)
	assertCount(t, db.WithContext(ctx), &model.CarePlan{}, "", plansBefore+1)
	assertCount(t, db.WithContext(ctx), &model.CareTask{}, "", tasksBefore+int64(len(result.CarePlan.Items)))
	assertCount(t, db.WithContext(ctx), &model.Bill{}, "", billsBefore+1)
	assertCount(t, db.WithContext(ctx), &model.FundFlow{}, "", flowsBefore+1)
	assertCount(t, db.WithContext(ctx), &model.AuditLog{}, "", auditsBefore+1)

	retry, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatalf("idempotent retry: %v", err)
	}
	if !retry.Idempotent || retry.Intake.ID != result.Intake.ID || retry.Elder.ID != result.Elder.ID {
		t.Fatalf("retry did not return same intake: %+v", retry)
	}
	assertCount(t, db.WithContext(ctx), &model.Elder{}, "", eldersBefore+1)
	assertCount(t, db.WithContext(ctx), &model.CarePlan{}, "", plansBefore+1)
	assertCount(t, db.WithContext(ctx), &model.Bill{}, "", billsBefore+1)
	assertCount(t, db.WithContext(ctx), &model.FundFlow{}, "", flowsBefore+1)

	// Reusing an idempotency key for a different request must not silently
	// return the first resident's admission result.
	changed := input
	changed.ResidentName = "另一位长者"
	if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, changed); !errors.Is(err, ErrAdmissionIdempotencyConflict) {
		t.Fatalf("changed idempotency payload error = %v, want conflict", err)
	}
}

func TestCreateIntakeRejectsRoomMismatchAndRollsBack(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	bed := freeIntakeBed(t, db, ctx)
	wrongType := "normal"
	if bed.Room != nil && wrongType == bed.Room.Type {
		wrongType = "nursing"
	}
	input := validIntakeInput(bed, "intake-room-mismatch")
	input.RoomType = wrongType
	var eldersBefore, intakesBefore int64
	if err := db.WithContext(ctx).Model(&model.Elder{}).Count(&eldersBefore).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Model(&model.AdmissionIntake{}).Count(&intakesBefore).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input); !errors.Is(err, ErrAdmissionBedConflict) {
		t.Fatalf("room mismatch error = %v, want bed conflict", err)
	}
	assertCount(t, db.WithContext(ctx), &model.Elder{}, "", eldersBefore)
	assertCount(t, db.WithContext(ctx), &model.AdmissionIntake{}, "", intakesBefore)
	var refreshed model.Bed
	if err := db.WithContext(ctx).First(&refreshed, bed.ID).Error; err != nil {
		t.Fatal(err)
	}
	if refreshed.Status != "free" || refreshed.ElderID != nil {
		t.Fatalf("bed changed after rollback: %+v", refreshed)
	}
}

func TestCreateIntakeRejectsMaintenanceAndOrphanBeds(t *testing.T) {
	t.Run("maintenance room", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		bed := freeIntakeBed(t, db, ctx)
		if err := db.WithContext(ctx).Model(&model.Room{}).Where("id = ?", bed.RoomID).Update("status", "maintenance").Error; err != nil {
			t.Fatal(err)
		}
		input := validIntakeInput(bed, "intake-maintenance")
		if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input); !errors.Is(err, ErrAdmissionBedConflict) {
			t.Fatalf("maintenance room error = %v, want bed conflict", err)
		}
		var refreshed model.Bed
		if err := db.WithContext(ctx).First(&refreshed, bed.ID).Error; err != nil {
			t.Fatal(err)
		}
		if refreshed.Status != "free" || refreshed.ElderID != nil {
			t.Fatalf("maintenance bed changed after rollback: %+v", refreshed)
		}
	})

	t.Run("orphan bed", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		orphan := model.Bed{RoomID: 0, BedNo: "ORPHAN", Status: "free"}
		if err := db.WithContext(ctx).Create(&orphan).Error; err != nil {
			t.Fatal(err)
		}
		input := validIntakeInput(orphan, "intake-orphan")
		if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input); !errors.Is(err, ErrAdmissionBedConflict) {
			t.Fatalf("orphan bed error = %v, want bed conflict", err)
		}
		var refreshed model.Bed
		if err := db.WithContext(ctx).First(&refreshed, orphan.ID).Error; err != nil {
			t.Fatal(err)
		}
		if refreshed.Status != "free" || refreshed.ElderID != nil {
			t.Fatalf("orphan bed changed after rollback: %+v", refreshed)
		}
	})
}

func TestUpdateAdmissionRoomStatusAllowsAlreadyOccupiedRoom(t *testing.T) {
	_, db, _, ctx := newAdmissionTestService(t)
	room := model.Room{Building: "X", Floor: 1, RoomNo: "X-01", Type: "normal", Status: "occupied"}
	if err := db.WithContext(ctx).Create(&room).Error; err != nil {
		t.Fatal(err)
	}
	ell := model.Elder{Name: "已入住长者", IDCard: "ROOM-STATUS-ELDER"}
	if err := db.WithContext(ctx).Create(&ell).Error; err != nil {
		t.Fatal(err)
	}
	bed := model.Bed{RoomID: room.ID, BedNo: "1", Status: "occupied", ElderID: &ell.ID}
	if err := db.WithContext(ctx).Create(&bed).Error; err != nil {
		t.Fatal(err)
	}
	if err := updateAdmissionRoomStatus(db.WithContext(ctx), room.ID); err != nil {
		t.Fatalf("already occupied room update: %v", err)
	}
	var refreshed model.Room
	if err := db.WithContext(ctx).First(&refreshed, room.ID).Error; err != nil {
		t.Fatal(err)
	}
	if refreshed.Status != "occupied" {
		t.Fatalf("room status = %q, want occupied", refreshed.Status)
	}
}

func TestCreateIntakeTenantIsolation(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	bed := freeIntakeBed(t, db, ctx)
	input := validIntakeInput(bed, "intake-tenant-one")
	created, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	tenantTwo := model.Tenant{Base: model.Base{TenantID: 2}, Code: "intake-tenant-two", Name: "入住二号机构", Status: 1}
	if err := db.Create(&tenantTwo).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, tenantTwo.ID)
	if _, err := svc.GetIntake(ctx2, AdmissionActor{UserID: doctorID}, created.Intake.ID); !errors.Is(err, ErrAdmissionNotFound) {
		t.Fatalf("cross-tenant GetIntake error = %v, want not found", err)
	}
	items, total, err := svc.ListIntakes(ctx2, AdmissionActor{UserID: doctorID}, "", false, 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if total != 0 || len(items) != 0 {
		t.Fatalf("tenant two saw tenant one intakes: total=%d items=%d", total, len(items))
	}
}

func TestCreateIntakeRejectsSecondAdmissionForLinkedElder(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	firstBed := freeIntakeBed(t, db, ctx)
	var secondBed model.Bed
	if err := db.WithContext(ctx).Preload("Room").Where("status = ? AND elder_id IS NULL AND id <> ?", "free", firstBed.ID).Order("id asc").First(&secondBed).Error; err != nil {
		t.Fatal(err)
	}
	registered := model.Elder{Name: "待入住长者", IDCard: "LINKED-ELDER-1", Status: 1}
	if err := db.WithContext(ctx).Create(&registered).Error; err != nil {
		t.Fatal(err)
	}
	first := validIntakeInput(firstBed, "linked-first")
	first.ElderID = &registered.ID
	first.IDCard = registered.IDCard
	if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, first); err != nil {
		t.Fatalf("first linked intake: %v", err)
	}
	second := validIntakeInput(secondBed, "linked-second")
	second.ElderID = &registered.ID
	second.IDCard = registered.IDCard
	if _, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, second); !errors.Is(err, ErrAdmissionElderConflict) {
		t.Fatalf("second linked intake error = %v, want elder conflict", err)
	}
	var occupied int64
	if err := db.WithContext(ctx).Model(&model.Bed{}).Where("elder_id = ? AND status = ?", registered.ID, "occupied").Count(&occupied).Error; err != nil {
		t.Fatal(err)
	}
	if occupied != 1 {
		t.Fatalf("linked elder occupied beds = %d, want 1", occupied)
	}
}

func TestCreateIntakeDoesNotBindFamilyFromResidentContactPhone(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	bed := freeIntakeBed(t, db, ctx)

	// Deliberately create an enabled family account whose phone matches the
	// resident's contact phone.  The account must not be bound unless the
	// explicit family_phone field is supplied.
	var familyRole model.Role
	if err := db.WithContext(ctx).Where("code = ?", "family").First(&familyRole).Error; err != nil {
		t.Fatal(err)
	}
	family := model.User{Username: "intake-family-contact-only", Phone: "13800000000", Status: 1}
	if err := db.WithContext(ctx).Create(&family).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).Model(&family).Association("Roles").Replace([]model.Role{familyRole}); err != nil {
		t.Fatal(err)
	}

	input := validIntakeInput(bed, "intake-contact-only")
	input.FamilyName = ""
	input.FamilyPhone = ""
	input.FamilyRelation = ""
	input.ContactPhone = family.Phone
	result, err := svc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatalf("CreateIntake: %v", err)
	}
	if result.Intake.ID == 0 {
		t.Fatal("CreateIntake returned an empty intake")
	}

	var bindings int64
	if err := db.WithContext(ctx).Model(&model.FamilyElder{}).
		Where("user_id = ? AND elder_id = ?", family.ID, result.Elder.ID).Count(&bindings).Error; err != nil {
		t.Fatal(err)
	}
	if bindings != 0 {
		t.Fatalf("family bindings = %d, want 0 when family_phone is omitted", bindings)
	}
	var familyNotifications int64
	if err := db.WithContext(ctx).Model(&model.Notification{}).
		Where("user_id = ? AND type = ?", family.ID, "admission_intake_completed").Count(&familyNotifications).Error; err != nil {
		t.Fatal(err)
	}
	if familyNotifications != 0 {
		t.Fatalf("family notifications = %d, want 0 when family_phone is omitted", familyNotifications)
	}
}

func TestIntakePlanTemplateUsesCurrentAdmissionTemplate(t *testing.T) {
	svc, db, _, ctx := newAdmissionTestService(t)
	current, err := svc.currentTemplate(db.WithContext(ctx))
	if err != nil {
		t.Fatalf("currentTemplate: %v", err)
	}

	// A disabled historical template may still have an enabled plan row with a
	// lower sort order. The basic intake must follow the active-template
	// selection used by the complete assessment workflow, rather than picking
	// that unrelated row.
	legacy := model.AssessmentTemplate{
		Base:       model.Base{TenantID: 1},
		Code:       currentAdmissionTemplateCode,
		Name:       "历史入住模板",
		Version:    "legacy-test",
		Category:   "admission_ability",
		Enabled:    false,
		SortOrder:  current.SortOrder + 100,
		LevelRules: current.LevelRules,
	}
	if err := db.WithContext(ctx).Create(&legacy).Error; err != nil {
		t.Fatalf("create legacy template: %v", err)
	}
	legacyPlan := model.AdmissionCarePlanTemplate{
		Base:        model.Base{TenantID: 1},
		TemplateID:  legacy.ID,
		Code:        "legacy-complete",
		Name:        "历史错误照护方案",
		TargetLevel: "complete",
		Enabled:     true,
		SortOrder:   0,
	}
	if err := db.WithContext(ctx).Create(&legacyPlan).Error; err != nil {
		t.Fatalf("create legacy plan: %v", err)
	}

	selected, err := intakePlanTemplate(db.WithContext(ctx), "complete")
	if err != nil {
		t.Fatalf("intakePlanTemplate: %v", err)
	}
	if selected.TemplateID != current.ID {
		t.Fatalf("selected template id = %d, want current template %d", selected.TemplateID, current.ID)
	}
	if selected.Code == legacyPlan.Code {
		t.Fatalf("selected unrelated legacy plan: %+v", selected)
	}
}

func TestNormalizeAdmissionIntakeRejectsInvalidValues(t *testing.T) {
	base := AdmissionIntakeInput{IdempotencyKey: "normalize-test", ResidentName: "测试", Gender: "男", BirthDate: "1940-01-01", Age: 86, IDCard: "INTAKE-VALID", AdmissionStartDate: "2026-09-01", CareLevel: "全护理", BedID: 1}
	tests := []struct {
		name   string
		mutate func(*AdmissionIntakeInput)
	}{
		{"missing gender", func(v *AdmissionIntakeInput) { v.Gender = "" }},
		{"bad date", func(v *AdmissionIntakeInput) { v.BirthDate = "1940/01/01" }},
		{"bad care level", func(v *AdmissionIntakeInput) { v.CareLevel = "unknown" }},
		{"negative fee", func(v *AdmissionIntakeInput) { v.Deposit = -1 }},
		{"invalid age", func(v *AdmissionIntakeInput) { v.Age = 0 }},
		{"missing idempotency key", func(v *AdmissionIntakeInput) { v.IdempotencyKey = "" }},
		{"end before start", func(v *AdmissionIntakeInput) { v.AdmissionEndDate = "2026-08-31" }},
		{"fee start after admission end", func(v *AdmissionIntakeInput) {
			v.AdmissionEndDate = "2026-09-30"
			v.FeeStartDate = "2026-10-01"
		}},
		{"age does not match birth date", func(v *AdmissionIntakeInput) { v.Age = 85 }},
		{"resident name exceeds elder column", func(v *AdmissionIntakeInput) { v.ResidentName = strings.Repeat("长", 51) }},
		{"family address exceeds column", func(v *AdmissionIntakeInput) { v.FamilyAddress = strings.Repeat("地", 501) }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			input := base
			tt.mutate(&input)
			if _, err := normalizeAdmissionIntake(input); !errors.Is(err, ErrAdmissionValidation) {
				t.Fatalf("error = %v, want validation", err)
			}
		})
	}
}

func freeIntakeBed(t *testing.T, db *gorm.DB, ctx context.Context) model.Bed {
	t.Helper()
	var bed model.Bed
	if err := db.WithContext(ctx).Preload("Room").Where("status = ? AND elder_id IS NULL", "free").Order("id asc").First(&bed).Error; err != nil {
		t.Fatalf("free bed: %v", err)
	}
	return bed
}

func validIntakeInput(bed model.Bed, key string) AdmissionIntakeInput {
	roomType := ""
	if bed.Room != nil {
		roomType = bed.Room.Type
	}
	return AdmissionIntakeInput{
		IdempotencyKey: key + fmt.Sprintf("-%d", time.Now().UnixNano()), ResidentName: "简化入住测试",
		Gender: "女", BirthDate: "1940-01-02", Age: 86, IDCard: fmt.Sprintf("9%026d", time.Now().UnixNano()%1000000000000000000),
		ContactPhone: "13800000000", FamilyName: "测试联系人", FamilyPhone: "13900000000", FamilyRelation: "子女",
		AdmissionStartDate: "2026-09-01", FeeStartDate: "2026-09-01", RoomType: roomType,
		CareLevel: "全护理", BedID: bed.ID, Note: "测试入住",
	}
}
