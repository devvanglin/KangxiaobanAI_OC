package service

import (
	"context"
	"errors"
	"testing"

	"kangxiaoban-service/internal/model"
)

func TestAssessmentAgentQuestionBankIsTenantVersionedAndValidated(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	svc := NewAssessmentAgentService(db)
	bank, err := svc.CurrentQuestionBank(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if bank.Version != 1 || len(bank.Questions) != 10 || bank.NoAnswerTimeout != 15 {
		t.Fatalf("unexpected default bank: %+v", bank)
	}
	updated, err := svc.UpdateQuestionBank(ctx, doctorID, AssessmentAgentQuestionBankInput{
		Title: "机构评估题库", NoAnswerTimeout: 30,
		Questions: []model.AssessmentAgentQuestion{{ID: "q1", Topic: "睡眠", Question: "最近睡得好吗？"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if updated.Version != 2 || updated.Title != "机构评估题库" || len(updated.Questions) != 1 {
		t.Fatalf("unexpected updated bank: %+v", updated)
	}
	if _, err := svc.UpdateQuestionBank(ctx, doctorID, AssessmentAgentQuestionBankInput{
		Title: "重复", NoAnswerTimeout: 15,
		Questions: []model.AssessmentAgentQuestion{
			{ID: "same", Topic: "A", Question: "A?"}, {ID: "same", Topic: "B", Question: "B?"},
		},
	}); !errors.Is(err, ErrAssessmentAgentValidation) {
		t.Fatalf("duplicate question error = %v", err)
	}

	tenant := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "agent-two", Name: "第二机构", Status: 1}
	if err := db.Create(&tenant).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	bank2, err := svc.CurrentQuestionBank(ctx2)
	if err != nil {
		t.Fatal(err)
	}
	if bank2.TenantID != 2 || bank2.Version != 1 || bank2.Title == updated.Title {
		t.Fatalf("tenant two bank leaked tenant one: %+v", bank2)
	}
}

func TestAssessmentAgentCompletionCreatesOneAuditableAssessment(t *testing.T) {
	admissionSvc, db, doctorID, ctx := newAdmissionTestService(t)
	bed := freeIntakeBed(t, db, ctx)
	intake, err := admissionSvc.CreateIntake(ctx, AdmissionActor{UserID: doctorID}, validIntakeInput(bed, "agent-intake"))
	if err != nil {
		t.Fatal(err)
	}
	svc := NewAssessmentAgentService(db)
	session, err := svc.CreateSession(ctx, doctorID, intake.Intake.ID)
	if err != nil {
		t.Fatal(err)
	}
	if session.ElderID != intake.Elder.ID || session.Address != "奶奶" || len(session.QuestionSnapshot) == 0 {
		t.Fatalf("unexpected session: %+v", session)
	}
	first := model.AssessmentAgentAnswer{QuestionID: session.QuestionSnapshot[0].ID, Topic: session.QuestionSnapshot[0].Topic,
		Question: session.QuestionSnapshot[0].Question, Answer: "睡得还可以"}
	if err := svc.SaveProgress(ctx, doctorID, session.SessionKey, first, 0); err != nil {
		t.Fatal(err)
	}
	resumed, err := svc.CreateSession(ctx, doctorID, intake.Intake.ID)
	if err != nil || resumed.ID != session.ID || len(resumed.Answers) != 1 || resumed.CurrentIndex != 1 {
		t.Fatalf("resume = %+v err=%v", resumed, err)
	}
	completion := AssessmentAgentCompletion{
		ExternalRecordID: "external-1", Report: "# 综合评估报告\n\n需要医师复核。",
		Answers: []model.AssessmentAgentAnswer{first},
	}
	completed, err := svc.CompleteSession(ctx, doctorID, session.SessionKey, completion)
	if err != nil {
		t.Fatal(err)
	}
	if completed.Status != "completed" || completed.AssessmentID == nil || completed.ReportMarkdown == "" {
		t.Fatalf("completion not persisted: %+v", completed)
	}
	var assessment model.Assessment
	if err := db.WithContext(ctx).Where("id = ?", *completed.AssessmentID).First(&assessment).Error; err != nil {
		t.Fatal(err)
	}
	if assessment.ElderID != intake.Elder.ID || assessment.AssessmentType != "comprehensive_agent" ||
		assessment.Source != "assessment_agent" || assessment.AgentSessionID == nil || assessment.Report == "" {
		t.Fatalf("unexpected assessment: %+v", assessment)
	}
	completedAgain, err := svc.CompleteSession(ctx, doctorID, session.SessionKey, completion)
	if err != nil || completedAgain.AssessmentID == nil || *completedAgain.AssessmentID != assessment.ID {
		t.Fatalf("idempotent completion failed: %+v err=%v", completedAgain, err)
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.Assessment{}).Where("agent_session_id = ?", session.ID).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("assessment count = %d, want 1", count)
	}
	var reloaded model.AssessmentAgentSession
	if err := db.WithContext(ctx).Where("id = ?", session.ID).First(&reloaded).Error; err != nil {
		t.Fatal(err)
	}
	if len(reloaded.Answers) != 1 || reloaded.Answers[0].Answer != "睡得还可以" {
		t.Fatalf("reloaded answers = %+v", reloaded.Answers)
	}
}
