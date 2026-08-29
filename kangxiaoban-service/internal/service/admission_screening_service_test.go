package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestAdmissionScreeningTemplatesAreOptionalAndPersisted(t *testing.T) {
	svc, db, _, ctx := newAdmissionTestService(t)
	templates, err := svc.ScreeningTemplates(ctx)
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]int{"GAD7": 21, "GDS15": 15, "SLEEP5": 0, "MINI_COG": 5, "MMSE": 30, "MOCA_BEIJING": 30}
	if len(templates) != len(want) {
		t.Fatalf("screening template count = %d, want %d", len(templates), len(want))
	}
	for _, template := range templates {
		maxScore, ok := want[template.Code]
		if !ok {
			t.Fatalf("unexpected screening template %q", template.Code)
		}
		if template.Required || template.Category != "admission_screening" || template.MaxScore != maxScore || len(template.Questions) == 0 {
			t.Fatalf("invalid screening template: %+v", template)
		}
		var persisted int64
		if err := db.Model(&model.AssessmentTemplate{}).Where("id = ?", template.ID).Count(&persisted).Error; err != nil {
			t.Fatal(err)
		}
		if persisted != 1 {
			t.Fatalf("template %s not persisted", template.Code)
		}
	}
}

func TestAdmissionScreeningServerScoringDraftCorrectionAndCompletion(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	gad7 := screeningTemplate(t, svc, ctx, "GAD7")

	partial := AdmissionScreeningInput{Answers: screeningAnswers(gad7, 3)[:3]}
	partialResult, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, partial)
	if err != nil {
		t.Fatal(err)
	}
	if partialResult.Screening.Status != "draft" || partialResult.AnsweredCount != 3 || partialResult.RequiredCount != 7 || partialResult.Complete {
		t.Fatalf("unexpected partial result: %+v", partialResult)
	}
	if partialResult.Screening.RawScore != 9 || partialResult.Screening.ResultCode != "" {
		t.Fatalf("unexpected partial score: %+v", partialResult.Screening)
	}
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{Completed: true, Answers: partial.Answers}); !errors.Is(err, ErrAdmissionIncomplete) {
		t.Fatalf("incomplete screening completion error = %v", err)
	}

	completed, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{Completed: true, Answers: screeningAnswers(gad7, 3)})
	if err != nil {
		t.Fatal(err)
	}
	if completed.Screening.Status != "completed" || completed.Screening.RawScore != 21 || completed.Screening.AdjustedScore != 21 || completed.Screening.ResultCode != "score_recorded" {
		t.Fatalf("unexpected completed GAD-7: %+v", completed.Screening)
	}

	corrected, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{Completed: true, Answers: screeningAnswers(gad7, 0), Notes: "复核后修正"})
	if err != nil {
		t.Fatal(err)
	}
	if corrected.Screening.RawScore != 0 || corrected.Screening.ResultCode != "score_recorded" || corrected.Screening.Notes != "复核后修正" {
		t.Fatalf("completed screening correction not applied: %+v", corrected.Screening)
	}
	assertCount(t, db, &model.AdmissionScreening{}, "admission_id = ? AND template_id = ?", 1, draft.ID, gad7.ID)
	assertCount(t, db, &model.AdmissionScreeningAnswer{}, "screening_id = ?", 7, corrected.Screening.ID)
}

func TestAdmissionScreeningRejectsForgedOptionAndForeignActor(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	gad7 := screeningTemplate(t, svc, ctx, "GAD7")
	gds15 := screeningTemplate(t, svc, ctx, "GDS15")

	foreignOption := gds15.Questions[0].Options[0]
	_, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{
		Answers: []AdmissionScreeningAnswerInput{{QuestionID: gad7.Questions[0].ID, OptionID: foreignOption.ID}},
	})
	if !errors.Is(err, ErrAdmissionValidation) {
		t.Fatalf("forged option error = %v", err)
	}
	_, err = svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID + 999}, draft.ID, gad7.Code, AdmissionScreeningInput{Answers: screeningAnswers(gad7, 0)})
	if !errors.Is(err, ErrAdmissionForbidden) {
		t.Fatalf("foreign actor error = %v", err)
	}
}

func TestAdmissionScreeningScoringRules(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)

	tests := []struct {
		code           string
		score          int
		educationYears *int
		wantRaw        int
		wantAdjusted   int
		wantResult     string
	}{
		{"GDS15", 0, nil, 0, 0, "score_recorded"},
		{"GDS15", 1, nil, 15, 15, "score_recorded"},
		{"SLEEP5", 1, nil, 0, 0, "recorded"},
		{"MINI_COG", -1, nil, 5, 5, "negative"},
		{"MMSE", -1, intPointer(6), 30, 30, "normal_range"},
		{"MOCA_BEIJING", 0, intPointer(12), 0, 1, "specialist_referral"},
	}
	for _, tt := range tests {
		t.Run(tt.code, func(t *testing.T) {
			draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
			if tt.code == "MMSE" || tt.code == "MOCA_BEIJING" {
				completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
			}
			template := screeningTemplate(t, svc, ctx, tt.code)
			answers := screeningAnswers(template, tt.score)
			result, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{
				Completed: true, EducationYears: tt.educationYears, Answers: answers,
			})
			if err != nil {
				t.Fatal(err)
			}
			if result.Screening.RawScore != tt.wantRaw || result.Screening.AdjustedScore != tt.wantAdjusted || result.Screening.ResultCode != tt.wantResult {
				t.Fatalf("unexpected score: %+v", result.Screening)
			}
		})
	}
}

func TestScreeningsWithoutPdfThresholdsOnlyRecordTotals(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
	tests := []struct {
		code string
		want string
	}{
		{"GAD7", "score_recorded"}, {"GDS15", "score_recorded"}, {"MMSE", "normal_range"}, {"SLEEP5", "recorded"},
	}
	for _, tt := range tests {
		t.Run(tt.code, func(t *testing.T) {
			template := screeningTemplate(t, svc, ctx, tt.code)
			answers := screeningAnswers(template, -1)
			result, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{Completed: true, Answers: answers})
			if err != nil {
				t.Fatal(err)
			}
			if result.Screening.ResultCode != tt.want {
				t.Fatalf("%s result = %s, want %s", tt.code, result.Screening.ResultCode, tt.want)
			}
		})
	}
}

func TestMoCAEducationRequiredOnlyOnCompletion(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
	template := screeningTemplate(t, svc, ctx, "MOCA_BEIJING")
	answers := screeningAnswers(template, 0)
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{Answers: answers}); err != nil {
		t.Fatalf("MoCA draft without education failed: %v", err)
	}
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{Completed: true, Answers: answers}); !errors.Is(err, ErrAdmissionValidation) {
		t.Fatalf("MoCA completion without education error = %v", err)
	}
}

func TestScreeningAdjustmentsAndLabelsComeFromTemplateRules(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)

	moca := screeningTemplate(t, svc, ctx, "MOCA_BEIJING")
	for i := range moca.AdjustmentRules {
		if moca.AdjustmentRules[i].Code == "moca_education_bonus" {
			moca.AdjustmentRules[i].Conditions[0].Threshold = 5
		}
	}
	if err := db.Model(moca).Select("AdjustmentRules").Updates(moca).Error; err != nil {
		t.Fatal(err)
	}
	moca = screeningTemplate(t, svc, ctx, "MOCA_BEIJING")
	answers := screeningAnswers(moca, 0)
	result, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, moca.Code, AdmissionScreeningInput{
		Completed: true, EducationYears: intPointer(6), Answers: answers,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Screening.AdjustedScore != 0 {
		t.Fatalf("education above configured threshold adjusted to %d, want 0", result.Screening.AdjustedScore)
	}
	result, err = svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, moca.Code, AdmissionScreeningInput{
		Completed: true, EducationYears: intPointer(5), Answers: answers,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Screening.AdjustedScore != 1 {
		t.Fatalf("education at configured threshold adjusted to %d, want 1", result.Screening.AdjustedScore)
	}

	sleep := screeningTemplate(t, svc, ctx, "SLEEP5")
	sleep.LevelRules[0].Label = "机构自定义睡眠记录"
	if err := db.Model(sleep).Select("LevelRules").Updates(sleep).Error; err != nil {
		t.Fatal(err)
	}
	sleep = screeningTemplate(t, svc, ctx, "SLEEP5")
	sleepResult, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, sleep.Code, AdmissionScreeningInput{
		Completed: true, Answers: screeningAnswers(sleep, 0),
	})
	if err != nil {
		t.Fatal(err)
	}
	if sleepResult.Screening.ResultCode != "recorded" || sleepResult.Screening.ResultLabel != "机构自定义睡眠记录" {
		t.Fatalf("sleep result did not use level rules: %+v", sleepResult.Screening)
	}
}

func TestAdmissionSubmitKeepsScreeningsOptionalAndProjectsCompletedOnes(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 5)

	gad7 := screeningTemplate(t, svc, ctx, "GAD7")
	completed, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{
		Completed: true, Answers: screeningAnswers(gad7, 1), Notes: "入住前筛查",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.AdmissionScreening{}).Where("id = ?", completed.Screening.ID).Updates(map[string]interface{}{
		"raw_score": -999, "adjusted_score": -999, "result_code": "forged", "result_label": "forged",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.AdmissionScreeningAnswer{}).Where("screening_id = ?", completed.Screening.ID).Update("score", -999).Error; err != nil {
		t.Fatal(err)
	}
	sleep := screeningTemplate(t, svc, ctx, "SLEEP5")
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, sleep.Code, AdmissionScreeningInput{Answers: screeningAnswers(sleep, 0)[:1]}); err != nil {
		t.Fatal(err)
	}

	submitted, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if submitted.Admission.ElderID == nil {
		t.Fatal("submitted admission has no elder")
	}
	elderID := *submitted.Admission.ElderID
	assertCount(t, db, &model.Assessment{}, "elder_id = ? AND assessment_type = ?", 1, elderID, "admission_screening:GAD7")
	assertCount(t, db, &model.Assessment{}, "elder_id = ? AND assessment_type = ?", 0, elderID, "admission_screening:SLEEP5")
	var projected model.Assessment
	if err := db.Where("elder_id = ? AND assessment_type = ?", elderID, "admission_screening:GAD7").First(&projected).Error; err != nil {
		t.Fatal(err)
	}
	if projected.Score == nil || *projected.Score != float64(completed.Screening.AdjustedScore) || projected.RiskLevel != completed.Screening.ResultCode || !strings.Contains(projected.Notes, "入住前筛查") {
		t.Fatalf("bad projected screening assessment: %+v", projected)
	}
	second, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil || !second.Idempotent {
		t.Fatalf("second submission = %+v, %v", second, err)
	}
	assertCount(t, db, &model.Assessment{}, "elder_id = ? AND assessment_type = ?", 1, elderID, "admission_screening:GAD7")

	_, err = svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{Completed: true, Answers: screeningAnswers(gad7, 0)})
	if !errors.Is(err, ErrAdmissionInvalidState) {
		t.Fatalf("post-submit screening mutation error = %v", err)
	}
}

func TestAdmissionSubmitRequiresPrimaryScreenings(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID); !errors.Is(err, ErrAdmissionIncomplete) {
		t.Fatalf("submit without primary screenings error = %v, want ErrAdmissionIncomplete", err)
	}
	reloaded, err := svc.Get(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Status != "draft" || reloaded.ElderID != nil {
		t.Fatalf("incomplete admission was mutated: %+v", reloaded)
	}
}

func TestAdmissionScreeningGateFollowsMiniCogFlow(t *testing.T) {
	t.Run("missing Mini-Cog is blocked", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
		if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID); !errors.Is(err, ErrAdmissionIncomplete) {
			t.Fatalf("submit without Mini-Cog error = %v, want ErrAdmissionIncomplete", err)
		}
	})
	t.Run("negative Mini-Cog requires both second-stage scales", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
		completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
		if _, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID); !errors.Is(err, ErrAdmissionIncomplete) {
			t.Fatalf("submit without second-stage screens error = %v, want ErrAdmissionIncomplete", err)
		}
	})
	t.Run("negative Mini-Cog with second-stage scales passes", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
		completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
		completeFurtherScreenings(t, svc, db, doctorID, ctx, draft.ID)
		result, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
		if err != nil || result.Admission.Status != "submitted" {
			t.Fatalf("submit with second-stage screens = %+v, %v", result, err)
		}
	})
	t.Run("negative Mini-Cog is not required when score is above threshold", func(t *testing.T) {
		svc, db, doctorID, ctx := newAdmissionTestService(t)
		draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
		completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 3)
		result, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
		if err != nil || result.Admission.Status != "submitted" {
			t.Fatalf("submit with Mini-Cog 3 = %+v, %v", result, err)
		}
	})
}

func TestFurtherScreeningCannotCompleteBeforeMiniCog(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	mmse := screeningTemplate(t, svc, ctx, "MMSE")
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, mmse.Code, AdmissionScreeningInput{
		Completed: true, Answers: screeningAnswers(mmse, -1),
	}); !errors.Is(err, ErrAdmissionIncomplete) {
		t.Fatalf("MMSE before Mini-Cog error = %v, want ErrAdmissionIncomplete", err)
	}
	// A partial draft is intentionally allowed so a clinician can resume later.
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, mmse.Code, AdmissionScreeningInput{
		Answers: screeningAnswers(mmse, -1)[:1],
	}); err != nil {
		t.Fatalf("MMSE draft before Mini-Cog: %v", err)
	}
}

func TestCognitiveScreeningThresholds(t *testing.T) {
	tests := []struct {
		code       string
		score      int
		education  *int
		wantResult string
	}{
		{code: "MMSE", score: 26, wantResult: "specialist_referral"},
		{code: "MMSE", score: 27, wantResult: "normal_range"},
		{code: "MMSE", score: 0, wantResult: "specialist_referral"},
		{code: "MMSE", score: 30, wantResult: "normal_range"},
		{code: "MOCA_BEIJING", score: 26, education: intPointer(30), wantResult: "specialist_referral"},
		{code: "MOCA_BEIJING", score: 27, education: intPointer(30), wantResult: "normal_range"},
		{code: "MOCA_BEIJING", score: 0, education: intPointer(30), wantResult: "specialist_referral"},
		{code: "MOCA_BEIJING", score: 30, education: intPointer(30), wantResult: "normal_range"},
	}
	for _, tt := range tests {
		t.Run(fmt.Sprintf("%s_%d", tt.code, tt.score), func(t *testing.T) {
			svc, db, doctorID, ctx := newAdmissionTestService(t)
			draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
			completePrimaryScreenings(t, svc, db, doctorID, ctx, draft.ID, 2)
			template := screeningTemplate(t, svc, ctx, tt.code)
			result, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{
				Completed: true, EducationYears: tt.education, Answers: screeningAnswersForTotal(template, tt.score),
			})
			if err != nil {
				t.Fatal(err)
			}
			if result.Screening.RawScore != tt.score || result.Screening.ResultCode != tt.wantResult {
				t.Fatalf("threshold result = raw:%d code:%s, want raw:%d code:%s", result.Screening.RawScore, result.Screening.ResultCode, tt.score, tt.wantResult)
			}
		})
	}
}

func TestScreeningEvidencePersistsAndCannotChangeScore(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	template := screeningTemplate(t, svc, ctx, "MINI_COG")
	answers := screeningAnswersForTotal(template, 2)
	answers[1].Evidence = []model.AdmissionScreeningEvidence{{
		ItemCode: "recall_word_1", OptionCode: "score_0", AnswerText: "未回忆", Score: 999,
	}}
	result, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{
		Completed: true, Answers: answers,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Screening.RawScore != 2 || len(result.Screening.Answers) < 2 {
		t.Fatalf("unexpected evidence screening result: %+v", result.Screening)
	}
	var stored model.AdmissionScreeningAnswer
	if err := db.Where("screening_id = ? AND question_id = ?", result.Screening.ID, answers[1].QuestionID).First(&stored).Error; err != nil {
		t.Fatal(err)
	}
	if len(stored.Evidence) != 1 || stored.Evidence[0].ItemCode != "recall_word_1" || stored.Evidence[0].Score != 999 {
		t.Fatalf("evidence was not persisted verbatim for audit: %+v", stored.Evidence)
	}
	// Corrupt both snapshots and the answer snapshot; server recalculation must
	// still derive the same score from the selected option.
	if err := db.Model(&model.AdmissionScreening{}).Where("id = ?", result.Screening.ID).Updates(map[string]interface{}{
		"raw_score": -999, "adjusted_score": -999, "result_code": "forged",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&model.AdmissionScreeningAnswer{}).Where("screening_id = ?", result.Screening.ID).Update("score", -999).Error; err != nil {
		t.Fatal(err)
	}
	listed, err := svc.ListScreenings(ctx, draft.ID)
	if err != nil || len(listed) != 1 {
		t.Fatalf("list screening = %d, %v", len(listed), err)
	}
	if listed[0].RawScore != 2 || listed[0].AdjustedScore != 2 || listed[0].ResultCode != "positive" {
		t.Fatalf("list returned forged score snapshot: raw=%d adjusted=%d result=%s", listed[0].RawScore, listed[0].AdjustedScore, listed[0].ResultCode)
	}
	if listed[0].Answers[1].Evidence[0].Score != 999 {
		t.Fatalf("evidence changed after snapshot tamper: %+v", listed[0].Answers[1].Evidence)
	}
	if listed[0].Answers[1].Score != 0 || listed[0].Answers[1].OptionCode != "score_0" {
		t.Fatalf("list returned forged answer score snapshot: %+v", listed[0].Answers[1])
	}
}

func TestAdmissionScreeningTenantIsolation(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)
	gad7 := screeningTemplate(t, svc, ctx, "GAD7")
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, gad7.Code, AdmissionScreeningInput{Completed: true, Answers: screeningAnswers(gad7, 0)}); err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	items, err := svc.ListScreenings(ctx2, draft.ID)
	if !errors.Is(err, ErrAdmissionNotFound) || len(items) != 0 {
		t.Fatalf("tenant two screening read = items:%d err:%v", len(items), err)
	}
}

func createAdmissionDraftForScreening(t *testing.T, svc *AdmissionService, db *gorm.DB, doctorID uint, ctx context.Context) *model.AdmissionAssessment {
	t.Helper()
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	return draft
}

func screeningTemplate(t *testing.T, svc *AdmissionService, ctx context.Context, code string) *model.AssessmentTemplate {
	t.Helper()
	templates, err := svc.ScreeningTemplates(ctx)
	if err != nil {
		t.Fatal(err)
	}
	for i := range templates {
		if templates[i].Code == code {
			return &templates[i]
		}
	}
	t.Fatalf("screening template %s not found", code)
	return nil
}

func screeningAnswers(template *model.AssessmentTemplate, preferredScore int) []AdmissionScreeningAnswerInput {
	answers := make([]AdmissionScreeningAnswerInput, 0, len(template.Questions))
	for _, question := range template.Questions {
		if !question.Required {
			continue
		}
		selected := question.Options[0]
		if preferredScore < 0 {
			for _, option := range question.Options[1:] {
				if option.Score > selected.Score {
					selected = option
				}
			}
		} else {
			for _, option := range question.Options {
				if option.Score == preferredScore {
					selected = option
					break
				}
			}
		}
		answers = append(answers, AdmissionScreeningAnswerInput{QuestionID: question.ID, OptionID: selected.ID})
	}
	return answers
}

func intPointer(value int) *int { return &value }

// completePrimaryScreenings creates the mandatory first-stage Mini-Cog record
// used by submission tests. GDS-15 remains an optional independent screen.
// miniCogScore may be 0-5; scores <=2 exercise the second-stage gate and
// therefore should be paired with MMSE/MoCA by callers.
func completePrimaryScreenings(t *testing.T, svc *AdmissionService, db *gorm.DB, doctorID uint, ctx context.Context, admissionID uint, miniCogScore int) {
	t.Helper()
	miniCog := screeningTemplate(t, svc, ctx, "MINI_COG")
	answers := screeningAnswersForTotal(miniCog, miniCogScore)
	miniResult, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, admissionID, miniCog.Code, AdmissionScreeningInput{
		Completed: true, Answers: answers,
	})
	if err != nil {
		t.Fatalf("complete Mini-Cog: %v", err)
	}
	if miniResult.Screening.AdjustedScore != miniCogScore {
		t.Fatalf("Mini-Cog helper score = %d, want %d (answers=%+v)", miniResult.Screening.AdjustedScore, miniCogScore, answers)
	}
}

func completeFurtherScreenings(t *testing.T, svc *AdmissionService, db *gorm.DB, doctorID uint, ctx context.Context, admissionID uint) {
	t.Helper()
	mmse := screeningTemplate(t, svc, ctx, "MMSE")
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, admissionID, mmse.Code, AdmissionScreeningInput{
		Completed: true, Answers: screeningAnswers(mmse, -1),
	}); err != nil {
		t.Fatalf("complete MMSE: %v", err)
	}
	moca := screeningTemplate(t, svc, ctx, "MOCA_BEIJING")
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, admissionID, moca.Code, AdmissionScreeningInput{
		Completed: true, EducationYears: intPointer(30), Answers: screeningAnswers(moca, -1),
	}); err != nil {
		t.Fatalf("complete MoCA: %v", err)
	}
}

func screeningAnswersForTotal(template *model.AssessmentTemplate, target int) []AdmissionScreeningAnswerInput {
	if target < 0 {
		return screeningAnswers(template, target)
	}
	required := make([]model.AssessmentQuestion, 0, len(template.Questions))
	for _, question := range template.Questions {
		if question.Required {
			required = append(required, question)
		}
	}
	result := make([]AdmissionScreeningAnswerInput, 0, len(required))
	var visit func(int, int) bool
	visit = func(index, score int) bool {
		if index == len(required) {
			return score == target
		}
		question := required[index]
		for _, option := range question.Options {
			if score+option.Score > target {
				continue
			}
			result = append(result, AdmissionScreeningAnswerInput{QuestionID: question.ID, OptionID: option.ID})
			if visit(index+1, score+option.Score) {
				return true
			}
			result = result[:len(result)-1]
		}
		return false
	}
	if visit(0, 0) {
		return result
	}
	return screeningAnswers(template, -1)
}
