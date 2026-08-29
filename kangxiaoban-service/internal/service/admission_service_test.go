package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"kangxiaoban-service/internal/auth"
	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

func TestAdmissionTemplateSeedAndScoring(t *testing.T) {
	svc, _, _, ctx := newAdmissionTestService(t)
	bundle, err := svc.TemplateBundle(ctx)
	if err != nil {
		t.Fatalf("TemplateBundle: %v", err)
	}
	if got := len(bundle.Template.Questions); got != 26 {
		t.Fatalf("question count = %d, want 26", got)
	}
	groupMax := map[string]int{}
	totalMax := 0
	for _, question := range bundle.Template.Questions {
		totalMax += question.MaxScore
		groupMax[question.GroupCode] += question.MaxScore
	}
	if totalMax != 90 {
		t.Fatalf("max score = %d, want 90", totalMax)
	}
	for code, want := range map[string]int{"B1": 32, "B2": 15, "B3": 28, "B4": 15} {
		if groupMax[code] != want {
			t.Errorf("group %s max = %d, want %d", code, groupMax[code], want)
		}
	}
	if len(bundle.LevelRules) != 5 || len(bundle.CarePlanTemplates) != 5 {
		t.Fatalf("level rules=%d care plans=%d, want 5 each", len(bundle.LevelRules), len(bundle.CarePlanTemplates))
	}

	template := &model.AssessmentTemplate{
		MaxScore:        90,
		LevelRules:      testAbilityRules(),
		AdjustmentRules: bundle.Template.AdjustmentRules,
		Questions: []model.AssessmentQuestion{{
			Base: model.Base{ID: 1}, Code: "B3.9", GroupCode: "B3", GroupName: "精神状态", Required: true, MaxScore: 90,
		}},
	}
	tests := []struct {
		name       string
		score      int
		admission  model.AdmissionAssessment
		optionCode string
		want       string
	}{
		{"90 intact", 90, model.AdmissionAssessment{}, "clear", "intact"},
		{"89 mild", 89, model.AdmissionAssessment{}, "clear", "mild"},
		{"66 mild", 66, model.AdmissionAssessment{}, "clear", "mild"},
		{"65 moderate", 65, model.AdmissionAssessment{}, "clear", "moderate"},
		{"46 moderate", 46, model.AdmissionAssessment{}, "clear", "moderate"},
		{"45 severe", 45, model.AdmissionAssessment{}, "clear", "severe"},
		{"30 severe", 30, model.AdmissionAssessment{}, "clear", "severe"},
		{"29 complete", 29, model.AdmissionAssessment{}, "clear", "complete"},
		{"zero complete", 0, model.AdmissionAssessment{}, "clear", "complete"},
		{"coma override", 90, model.AdmissionAssessment{}, "coma", "complete"},
		{"mental worsens one", 90, model.AdmissionAssessment{Diagnoses: []string{"F00-F03"}}, "clear", "mild"},
		{"risk below threshold", 90, model.AdmissionAssessment{RiskEvents: []model.AdmissionRiskEvent{{Code: "fall", Count: 1}}}, "clear", "intact"},
		{"risk worsens one", 90, model.AdmissionAssessment{RiskEvents: []model.AdmissionRiskEvent{{Code: "fall", Count: 2}}}, "clear", "mild"},
		{"two adjustment reasons worsen once", 90, model.AdmissionAssessment{Diagnoses: []string{"F04-F99"}, RiskEvents: []model.AdmissionRiskEvent{{Code: "fall", Count: 1}, {Code: "choke", Count: 1}}}, "clear", "mild"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			optionID := uint(11)
			template.Questions[0].Options = []model.AssessmentOption{{Base: model.Base{ID: optionID}, QuestionID: 1, Code: tt.optionCode, Score: tt.score}}
			answer := model.AdmissionAssessmentAnswer{QuestionID: 1, OptionID: &optionID, QuestionCode: "forged-question", OptionCode: "forged-option", Score: -999}
			got, err := calculateAbilityResult(template, &tt.admission, []model.AdmissionAssessmentAnswer{answer})
			if err != nil {
				t.Fatalf("calculateAbilityResult: %v", err)
			}
			if got.FinalLevel != tt.want {
				t.Errorf("final level = %s, want %s", got.FinalLevel, tt.want)
			}
			if tt.name == "two adjustment reasons worsen once" && len(got.LevelChangeReasons) != 2 {
				t.Errorf("change reasons = %d, want 2", len(got.LevelChangeReasons))
			}
		})
	}
}

func TestAdmissionRiskCodesAndThresholdComeFromTemplateRules(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	bundle, err := svc.TemplateBundle(ctx)
	if err != nil {
		t.Fatal(err)
	}
	template := bundle.Template
	for i := range template.AdjustmentRules {
		if template.AdjustmentRules[i].Code != "risk_events_2_plus" {
			continue
		}
		template.AdjustmentRules[i].Conditions[0].RiskCodes = []string{"slip"}
		template.AdjustmentRules[i].Conditions[0].Threshold = 3
	}
	if err := db.Model(&template).Select("AdjustmentRules").Updates(&template).Error; err != nil {
		t.Fatal(err)
	}

	input := validAdmissionInput(t, svc, db, ctx)
	input.RiskEvents = []model.AdmissionRiskEvent{{Code: "slip", Count: 2}}
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatalf("configured risk code rejected: %v", err)
	}
	preview, err := svc.Preview(ctx, AdmissionActor{UserID: doctorID}, draft.ID, nil)
	if err != nil {
		t.Fatal(err)
	}
	if preview.FinalLevel != "intact" {
		t.Fatalf("count below configured threshold changed level to %s", preview.FinalLevel)
	}

	input.RiskEvents[0].Count = 3
	updated, err := svc.Update(ctx, AdmissionActor{UserID: doctorID}, draft.ID, input)
	if err != nil {
		t.Fatal(err)
	}
	preview, err = svc.Preview(ctx, AdmissionActor{UserID: doctorID}, updated.ID, nil)
	if err != nil {
		t.Fatal(err)
	}
	if preview.FinalLevel != "mild" {
		t.Fatalf("count at configured threshold produced %s, want mild", preview.FinalLevel)
	}

	input.RiskEvents = []model.AdmissionRiskEvent{{Code: "fall", Count: 3}}
	if _, err := svc.Update(ctx, AdmissionActor{UserID: doctorID}, draft.ID, input); !errors.Is(err, ErrAdmissionValidation) {
		t.Fatalf("removed risk code error = %v, want validation", err)
	}
}

func TestAdmissionAdjustmentRejectsUnknownTargetLevel(t *testing.T) {
	template := &model.AssessmentTemplate{
		MaxScore: 90, LevelRules: testAbilityRules(),
		AdjustmentRules: []model.AdmissionAdjustmentRule{{
			Code: "bad_target", TargetLevel: "missing",
			Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "coma"}},
		}},
		Questions: []model.AssessmentQuestion{{
			Base: model.Base{ID: 1}, Code: "Q1", Required: true, MaxScore: 90,
			Options: []model.AssessmentOption{{Base: model.Base{ID: 2}, Code: "ok", Score: 90}},
		}},
	}
	optionID := uint(2)
	_, err := calculateAbilityResult(template, &model.AdmissionAssessment{Coma: true}, []model.AdmissionAssessmentAnswer{{QuestionID: 1, OptionID: &optionID}})
	if !errors.Is(err, ErrAdmissionValidation) {
		t.Fatalf("unknown target error = %v, want validation", err)
	}
}

func TestAdmissionPreviewCompletionCountsRequiredQuestionsOnly(t *testing.T) {
	template := &model.AssessmentTemplate{
		MaxScore:   10,
		LevelRules: []model.AbilityLevelRule{{Code: "ok", Label: "完成", MinScore: 0, MaxScore: 10, CareLevel: 1}},
		Questions: []model.AssessmentQuestion{
			{Base: model.Base{ID: 1}, Code: "REQUIRED", Required: true, MaxScore: 10,
				Options: []model.AssessmentOption{{Base: model.Base{ID: 11}, Code: "yes", Score: 10}}},
			{Base: model.Base{ID: 2}, Code: "OPTIONAL", Required: false, MaxScore: 0,
				Options: []model.AssessmentOption{{Base: model.Base{ID: 12}, Code: "recorded", Score: 0}}},
		},
	}
	requiredOption, optionalOption := uint(11), uint(12)
	preview, err := calculateAbilityResult(template, &model.AdmissionAssessment{}, []model.AdmissionAssessmentAnswer{
		{QuestionID: 1, OptionID: &requiredOption},
		{QuestionID: 2, OptionID: &optionalOption},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !preview.Complete || preview.AnsweredCount != 1 || preview.RequiredCount != 1 {
		t.Fatalf("optional answer changed completion: %+v", preview)
	}
}

func TestAdmissionPermissions(t *testing.T) {
	_, db, _, _ := newAdmissionTestService(t)
	userRepo := repository.NewUserRepository(db)
	gin.SetMode(gin.TestMode)
	router := gin.New()
	const secret = "admission-test-secret"
	router.GET("/protected", middleware.JWTAuth(secret), middleware.RequirePermission(userRepo, "admission:write"), func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	for _, tt := range []struct {
		username string
		roles    []string
		want     int
	}{
		{"doctor", []string{"doctor"}, http.StatusNoContent},
		{"admin", []string{"admin"}, http.StatusNoContent},
		{"caregiver", []string{"caregiver"}, http.StatusForbidden},
		{"family", []string{"family"}, http.StatusForbidden},
	} {
		t.Run(tt.username, func(t *testing.T) {
			var user model.User
			if err := db.Where("username = ?", tt.username).First(&user).Error; err != nil {
				t.Fatalf("load user: %v", err)
			}
			token, err := auth.GenerateTokenForTenant(secret, 3600, user.ID, user.TenantID, user.Username, tt.roles)
			if err != nil {
				t.Fatalf("token: %v", err)
			}
			req := httptest.NewRequest(http.MethodGet, "/protected", nil)
			req.Header.Set("Authorization", "Bearer "+token)
			res := httptest.NewRecorder()
			router.ServeHTTP(res, req)
			if res.Code != tt.want {
				t.Fatalf("status = %d, want %d; body=%s", res.Code, tt.want, res.Body.String())
			}
		})
	}
}

func TestAdmissionSubmitIsIdempotentAndTraceable(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	publisher := &recordingAdmissionPublisher{}
	svc.events = publisher
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 5)
	if _, err := svc.Update(ctx, AdmissionActor{UserID: doctorID + 999}, draft.ID, input); !errors.Is(err, ErrAdmissionForbidden) {
		t.Fatalf("non-owner Update error = %v, want forbidden", err)
	}
	// A corrupted or client-invented snapshot score must not affect the authoritative template score.
	if err := db.Model(&model.AdmissionAssessmentAnswer{}).Where("admission_id = ?", draft.ID).Update("score", -999).Error; err != nil {
		t.Fatalf("tamper score fixture: %v", err)
	}
	first, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatalf("first Submit: %v", err)
	}
	if first.Idempotent || first.Admission.Status != "submitted" || first.Admission.ElderID == nil || first.Admission.CarePlanID == nil {
		t.Fatalf("unexpected first result: %+v", first)
	}
	second, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatalf("second Submit: %v", err)
	}
	if !second.Idempotent || second.Admission.ElderID == nil || *second.Admission.ElderID != *first.Admission.ElderID {
		t.Fatalf("unexpected idempotent result: %+v", second)
	}
	if _, err := svc.Update(ctx, AdmissionActor{UserID: doctorID}, draft.ID, input); !errors.Is(err, ErrAdmissionInvalidState) {
		t.Fatalf("submitted Update error = %v, want invalid state", err)
	}

	elderID := *first.Admission.ElderID
	assertCount(t, db, &model.Elder{}, "id = ?", 1, elderID)
	assertCount(t, db, &model.Assessment{}, "elder_id = ? AND assessment_type = ?", 1, elderID, "admission_ability")
	assertCount(t, db, &model.CarePlan{}, "elder_id = ?", 1, elderID)
	assertCount(t, db, &model.Notification{}, "type = ?", 1, "admission_completed")
	assertCount(t, db, &model.AuditLog{}, "action = ? AND module = ?", 1, "submit", "admission_assessment")

	var assessment model.Assessment
	if err := db.Where("elder_id = ? AND assessment_type = ?", elderID, "admission_ability").First(&assessment).Error; err != nil {
		t.Fatal(err)
	}
	if assessment.AssessorID != doctorID || assessment.Score == nil || *assessment.Score != 90 {
		t.Fatalf("assessment trace mismatch: %+v", assessment)
	}
	var plan model.CarePlan
	if err := db.Preload("Items").First(&plan, *first.Admission.CarePlanID).Error; err != nil {
		t.Fatal(err)
	}
	if plan.CreatedBy != doctorID || plan.ElderID != elderID || len(plan.Items) == 0 {
		t.Fatalf("care plan trace mismatch: %+v", plan)
	}
	for _, item := range plan.Items {
		if item.AssigneeID == nil {
			t.Fatalf("care plan item has no caregiver assignment: %+v", item)
		}
	}
	assertCount(t, db, &model.CareTask{}, "elder_id = ?", int64(len(plan.Items)), elderID)
	var tasks []model.CareTask
	if err := db.Where("elder_id = ?", elderID).Find(&tasks).Error; err != nil {
		t.Fatal(err)
	}
	if len(tasks) != len(plan.Items) {
		t.Fatalf("care task count = %d, want %d", len(tasks), len(plan.Items))
	}
	var caregiver model.User
	if err := db.Where("username = ?", "caregiver").First(&caregiver).Error; err != nil {
		t.Fatal(err)
	}
	for _, task := range tasks {
		if task.PlanItemID == nil || task.AssigneeID == nil || *task.AssigneeID != caregiver.ID || task.ElderID != elderID || task.Status != "todo" {
			t.Fatalf("care task trace mismatch: %+v", task)
		}
	}
	taskSvc := NewTaskService(repository.NewTaskRepository(db))
	if err := taskSvc.SetStatus(ctx, tasks[0].ID, "doing", doctorID, "doctor", ""); !errors.Is(err, ErrTaskNotAssigned) {
		t.Fatalf("other user task update error = %v, want not assigned", err)
	}
	if err := taskSvc.SetStatus(ctx, tasks[0].ID, "doing", caregiver.ID, caregiver.Username, ""); err != nil {
		t.Fatalf("start linked care task: %v", err)
	}
	if err := taskSvc.SetStatus(ctx, tasks[0].ID, "done", caregiver.ID, caregiver.Username, "执行正常"); err != nil {
		t.Fatalf("complete linked care task: %v", err)
	}
	if err := taskSvc.SetStatus(ctx, tasks[0].ID, "done", caregiver.ID, caregiver.Username, "重复提交"); err != nil {
		t.Fatalf("idempotent task completion: %v", err)
	}
	assertCount(t, db, &model.CareExecution{}, "plan_item_id = ? AND elder_id = ?", 1, *tasks[0].PlanItemID, elderID)
	var execution model.CareExecution
	if err := db.Where("plan_item_id = ? AND elder_id = ?", *tasks[0].PlanItemID, elderID).First(&execution).Error; err != nil {
		t.Fatal(err)
	}
	if execution.ExecutorID != caregiver.ID || execution.Result != "执行正常" {
		t.Fatalf("care execution trace mismatch: %+v", execution)
	}
	var bed model.Bed
	if err := db.First(&bed, *input.TargetBedID).Error; err != nil {
		t.Fatal(err)
	}
	if bed.Status != "occupied" || bed.ElderID == nil || *bed.ElderID != elderID {
		t.Fatalf("bed trace mismatch: %+v", bed)
	}
	if publisher.calls != 1 || publisher.tenantID != 1 || publisher.role != "caregiver" || publisher.eventType != "admission.submitted" {
		t.Fatalf("unexpected admission event: %+v", publisher)
	}
}

func TestAdmissionSubmitBindsFamilyByContactPhone(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	var family model.User
	if err := db.Where("username = ?", "family").First(&family).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&family).Update("phone", input.ContactPhone).Error; err != nil {
		t.Fatal(err)
	}
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 5)
	result, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if result.Admission.ElderID == nil {
		t.Fatal("submitted admission has no elder")
	}
	assertCount(t, db, &model.FamilyElder{}, "user_id = ? AND elder_id = ?", 1, family.ID, *result.Admission.ElderID)
	assertCount(t, db, &model.Notification{}, "user_id = ? AND type = ?", 1, family.ID, "admission_completed")
}

func TestAdmissionSubmitKeepsTasksUnassignedWithoutCaregiver(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	if err := db.Model(&model.User{}).Where("username = ?", "caregiver").Update("status", 0).Error; err != nil {
		t.Fatal(err)
	}
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 5)
	result, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	var tasks []model.CareTask
	if err := db.Where("elder_id = ?", *result.Admission.ElderID).Find(&tasks).Error; err != nil {
		t.Fatal(err)
	}
	if len(tasks) == 0 {
		t.Fatal("admission created no care tasks")
	}
	for _, task := range tasks {
		if task.AssigneeID != nil || task.Assignee != "" {
			t.Fatalf("task should remain explicitly unassigned: %+v", task)
		}
	}
}

func TestAdmissionSubmitBedConflict(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	firstInput := validAdmissionInput(t, svc, db, ctx)
	secondInput := firstInput
	secondInput.ResidentName = "床位冲突测试二"
	secondInput.IDCard = fmt.Sprintf("TEST-%d", time.Now().UnixNano()+1)
	secondInput.Answers = append([]AdmissionAnswerInput(nil), firstInput.Answers...)
	firstDraft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, firstInput)
	if err != nil {
		t.Fatal(err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, firstDraft.ID, 5)
	secondDraft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, secondInput)
	if err != nil {
		t.Fatal(err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, secondDraft.ID, 5)
	if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, firstDraft.ID); err != nil {
		t.Fatalf("first submit: %v", err)
	}
	if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, secondDraft.ID); !errors.Is(err, ErrAdmissionBedConflict) {
		t.Fatalf("second submit error = %v, want bed conflict", err)
	}
	reloaded, err := svc.Get(ctx, AdmissionActor{UserID: doctorID}, secondDraft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Status != "draft" || reloaded.ElderID != nil {
		t.Fatalf("conflicting draft was not rolled back: %+v", reloaded)
	}
	assertCount(t, db, &model.Elder{}, "id_card = ?", 0, secondInput.IDCard)
}

func TestAdmissionSubmitRollsBackOnDownstreamFailure(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	var taskCountBefore int64
	if err := db.Model(&model.CareTask{}).Count(&taskCountBefore).Error; err != nil {
		t.Fatal(err)
	}
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	trigger := `CREATE TRIGGER fail_admission_notification
		BEFORE INSERT ON notifications
		WHEN NEW.type = 'admission_completed'
		BEGIN SELECT RAISE(ABORT, 'forced admission notification failure'); END;`
	if err := db.Exec(trigger).Error; err != nil {
		t.Fatalf("create trigger: %v", err)
	}
	if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID); err == nil {
		t.Fatal("Submit succeeded, want forced downstream failure")
	}
	reloaded, err := svc.Get(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Status != "draft" || reloaded.ElderID != nil || reloaded.CarePlanID != nil {
		t.Fatalf("admission transaction did not roll back: %+v", reloaded)
	}
	var bed model.Bed
	if err := db.First(&bed, *input.TargetBedID).Error; err != nil {
		t.Fatal(err)
	}
	if bed.Status != "free" || bed.ElderID != nil {
		t.Fatalf("bed was not rolled back: %+v", bed)
	}
	assertCount(t, db, &model.Elder{}, "id_card = ?", 0, input.IDCard)
	var taskCountAfter int64
	if err := db.Model(&model.CareTask{}).Count(&taskCountAfter).Error; err != nil {
		t.Fatal(err)
	}
	if taskCountAfter != taskCountBefore {
		t.Fatalf("care tasks were not rolled back: before=%d after=%d", taskCountBefore, taskCountAfter)
	}
	assertCount(t, db, &model.AuditLog{}, "action = ? AND module = ?", 0, "submit", "admission_assessment")
}

func TestAdmissionTenantIsolation(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	tenant2 := model.Tenant{Base: model.Base{TenantID: 2}, Code: "tenant-two", Name: "第二机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, tenant2.ID)
	if _, err := svc.Get(ctx2, AdmissionActor{UserID: doctorID}, draft.ID); !errors.Is(err, ErrAdmissionNotFound) {
		t.Fatalf("cross-tenant Get error = %v, want not found", err)
	}
	items, total, err := svc.List(ctx2, AdmissionActor{UserID: doctorID}, "", false, 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if total != 0 || len(items) != 0 {
		t.Fatalf("tenant two saw tenant one admissions: total=%d items=%d", total, len(items))
	}
	careSvc := NewCareService(repository.NewCareRepository(db))
	plans, planTotal, err := careSvc.ListPlans(ctx2, 0, 1, 20, nil)
	if err != nil {
		t.Fatal(err)
	}
	if planTotal != 0 || len(plans) != 0 {
		t.Fatalf("tenant two saw tenant one care plans: total=%d items=%d", planTotal, len(plans))
	}
}

func newAdmissionTestService(t *testing.T) (*AdmissionService, *gorm.DB, uint, context.Context) {
	t.Helper()
	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name())
	db, err := database.Connect(&config.DBConfig{Driver: "sqlite", SQLitePath: "file:" + name + "?mode=memory&cache=shared"})
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	db.Logger = logger.Default.LogMode(logger.Silent)
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := database.AutoMigrateAndSeed(db, false); err != nil {
		t.Fatalf("AutoMigrateAndSeed: %v", err)
	}
	var doctor model.User
	if err := db.Where("username = ?", "doctor").First(&doctor).Error; err != nil {
		t.Fatalf("load doctor: %v", err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	return NewAdmissionService(db), db, doctor.ID, ctx
}

func validAdmissionInput(t *testing.T, svc *AdmissionService, db *gorm.DB, ctx context.Context) AdmissionDraftInput {
	t.Helper()
	bundle, err := svc.TemplateBundle(ctx)
	if err != nil {
		t.Fatal(err)
	}
	answers := make([]AdmissionAnswerInput, 0, len(bundle.Template.Questions))
	for _, question := range bundle.Template.Questions {
		if len(question.Options) == 0 {
			t.Fatalf("question %s has no options", question.Code)
		}
		selected := question.Options[0]
		for _, option := range question.Options[1:] {
			if option.Score > selected.Score {
				selected = option
			}
		}
		answers = append(answers, AdmissionAnswerInput{QuestionID: question.ID, OptionID: selected.ID})
	}
	var bed model.Bed
	if err := db.Where("status = ? AND elder_id IS NULL", "free").Order("id asc").First(&bed).Error; err != nil {
		t.Fatalf("free bed: %v", err)
	}
	return AdmissionDraftInput{
		CurrentStep: 4, AssessmentReason: "first", BaselineDate: "2026-08-30",
		ResidentName: "入住评估测试", Gender: "F", BirthDate: "1940-01-02",
		IDCard: fmt.Sprintf("TEST-%d", time.Now().UnixNano()), HeightCM: 158, WeightKG: 52,
		Ethnicity: "han", Religion: "none", Education: "primary",
		LivingSituations: []string{"children"}, MaritalStatus: "widowed",
		MedicalPayments: []string{"employee_insurance"}, IncomeSources: []string{"pension"},
		RiskEvents: []model.AdmissionRiskEvent{}, Diagnoses: []string{"I10-I15"},
		InfoProviderName: "测试联系人", InfoProviderRelation: "child",
		ContactName: "测试联系人", ContactPhone: "13800000000", TargetBedID: &bed.ID,
		AssessmentLocation: "康养中心评估室", DoctorConfirmed: true, PlanConsentConfirmed: true,
		ServiceFeeInformed: true, InfoProviderSigned: true, Answers: answers,
	}
}

func assertCount(t *testing.T, db *gorm.DB, value interface{}, query string, want int64, args ...interface{}) {
	t.Helper()
	var count int64
	if err := db.Model(value).Where(query, args...).Count(&count).Error; err != nil {
		t.Fatalf("count %T: %v", value, err)
	}
	if count != want {
		t.Fatalf("count %T = %d, want %d", value, count, want)
	}
}

type recordingAdmissionPublisher struct {
	calls     int
	tenantID  uint
	role      string
	eventType string
}

func (p *recordingAdmissionPublisher) SendToRole(tenantID uint, role, eventType string, data interface{}) {
	p.calls++
	p.tenantID = tenantID
	p.role = role
	p.eventType = eventType
}

func testAbilityRules() []model.AbilityLevelRule {
	return []model.AbilityLevelRule{
		{Code: "intact", Label: "能力完好", MinScore: 90, MaxScore: 90, CareLevel: 1, SortOrder: 1},
		{Code: "mild", Label: "能力轻度受损（轻度失能）", MinScore: 66, MaxScore: 89, CareLevel: 2, SortOrder: 2},
		{Code: "moderate", Label: "能力中度受损（中度失能）", MinScore: 46, MaxScore: 65, CareLevel: 3, SortOrder: 3},
		{Code: "severe", Label: "能力重度受损（重度失能）", MinScore: 30, MaxScore: 45, CareLevel: 4, SortOrder: 4},
		{Code: "complete", Label: "能力完全丧失（完全失能）", MinScore: 0, MaxScore: 29, CareLevel: 5, SortOrder: 5},
	}
}
