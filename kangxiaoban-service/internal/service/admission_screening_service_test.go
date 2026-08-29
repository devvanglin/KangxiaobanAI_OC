package service

import (
	"context"
	"errors"
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
	draft := createAdmissionDraftForScreening(t, svc, db, doctorID, ctx)

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
		{"MMSE", -1, intPointer(6), 30, 30, "score_recorded"},
		{"MOCA_BEIJING", 0, intPointer(12), 0, 1, "positive"},
	}
	for _, tt := range tests {
		t.Run(tt.code, func(t *testing.T) {
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
	tests := []struct {
		code string
		want string
	}{
		{"GAD7", "score_recorded"}, {"GDS15", "score_recorded"}, {"MMSE", "score_recorded"}, {"SLEEP5", "recorded"},
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
	template := screeningTemplate(t, svc, ctx, "MOCA_BEIJING")
	answers := screeningAnswers(template, 0)
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{Answers: answers}); err != nil {
		t.Fatalf("MoCA draft without education failed: %v", err)
	}
	if _, err := svc.SaveScreening(ctx, AdmissionActor{UserID: doctorID}, draft.ID, template.Code, AdmissionScreeningInput{Completed: true, Answers: answers}); !errors.Is(err, ErrAdmissionValidation) {
		t.Fatalf("MoCA completion without education error = %v", err)
	}
}

func TestAdmissionSubmitKeepsScreeningsOptionalAndProjectsCompletedOnes(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}

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

func TestAdmissionSubmitWithoutScreeningsStillSucceeds(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	input := validAdmissionInput(t, svc, db, ctx)
	draft, err := svc.Create(ctx, AdmissionActor{UserID: doctorID}, input)
	if err != nil {
		t.Fatal(err)
	}
	result, err := svc.Submit(ctx, AdmissionActor{UserID: doctorID}, draft.ID)
	if err != nil {
		t.Fatal(err)
	}
	if result.Admission.ElderID == nil {
		t.Fatal("submitted admission has no elder")
	}
	assertCount(t, db, &model.Assessment{}, "elder_id = ? AND assessment_type LIKE ?", 0, *result.Admission.ElderID, "admission_screening:%")
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
