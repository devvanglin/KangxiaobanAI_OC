package service

import (
	"testing"

	"kangxiaoban-service/internal/model"
)

func TestAdmissionCodeRangeSupportsCrossPrefixICD(t *testing.T) {
	tests := []struct {
		value string
		want  bool
	}{
		{value: "C00", want: true},
		{value: "C99", want: true},
		{value: "D48", want: true},
		{value: "D49", want: false},
		{value: "E01", want: false},
	}
	for _, tt := range tests {
		t.Run(tt.value, func(t *testing.T) {
			if got := admissionCodeMatches(tt.value, "C00-D48"); got != tt.want {
				t.Fatalf("admissionCodeMatches(%q, C00-D48) = %v, want %v", tt.value, got, tt.want)
			}
		})
	}
	if admissionCodeMatches("C00.1", "C00-D48") {
		t.Fatal("decimal ICD subcode must not bypass the normalized range matcher")
	}
}

func TestAdmissionRuleOutcomeUsesStrongestWorseningAndPreservesReasons(t *testing.T) {
	rules := []model.AdmissionAdjustmentRule{
		{
			Code: "one", Description: "一级加重", LevelDelta: 1,
			Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "trigger_one"}},
		},
		{
			Code: "two", Description: "两级加重", LevelDelta: 2,
			Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "trigger_two"}},
		},
		{
			Code: "score", Description: "分数校正", ScoreDelta: -1,
			Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "trigger_one"}},
		},
	}
	outcome := evaluateAdmissionAdjustmentRules(rules, admissionRuleContext{
		BooleanFields: map[string]bool{"trigger_one": true, "trigger_two": true},
	})
	if outcome.LevelDelta != 2 {
		t.Fatalf("strongest level delta = %d, want 2", outcome.LevelDelta)
	}
	if outcome.ScoreDelta != -1 {
		t.Fatalf("score delta = %d, want -1", outcome.ScoreDelta)
	}
	if len(outcome.Reasons) != 3 {
		t.Fatalf("reasons = %d, want 3", len(outcome.Reasons))
	}
}

func TestAdmissionLevelAdjustmentNeverDowngradesInitialResult(t *testing.T) {
	template := &model.AssessmentTemplate{
		MaxScore: 90,
		LevelRules: []model.AbilityLevelRule{
			{Code: "intact", Label: "完好", MinScore: 90, MaxScore: 90, CareLevel: 1},
			{Code: "mild", Label: "轻度", MinScore: 66, MaxScore: 89, CareLevel: 2},
			{Code: "moderate", Label: "中度", MinScore: 46, MaxScore: 65, CareLevel: 3},
			{Code: "severe", Label: "重度", MinScore: 30, MaxScore: 45, CareLevel: 4},
			{Code: "complete", Label: "完全", MinScore: 0, MaxScore: 29, CareLevel: 5},
		},
		Questions: []model.AssessmentQuestion{{
			Base: model.Base{ID: 1}, Code: "Q1", Required: true, MaxScore: 90,
			Options: []model.AssessmentOption{{Base: model.Base{ID: 2}, Code: "score_80", Score: 80}},
		}},
		AdjustmentRules: []model.AdmissionAdjustmentRule{
			{
				Code: "weak_target", TargetLevel: "intact",
				Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "coma"}},
			},
		},
	}
	optionID := uint(2)
	preview, err := calculateAbilityResult(template, &model.AdmissionAssessment{Coma: true}, []model.AdmissionAssessmentAnswer{{
		QuestionID: 1, OptionID: &optionID,
	}})
	if err != nil {
		t.Fatal(err)
	}
	// The target is intentionally less severe than the initial result. The
	// interpreter must never use it to improve a resident's level.
	if preview.InitialLevel != "mild" || preview.FinalLevel != "mild" {
		t.Fatalf("level was downgraded: initial=%s final=%s", preview.InitialLevel, preview.FinalLevel)
	}
}

func TestAdmissionLevelDeltaAndAbsoluteTargetUseMoreSevereResult(t *testing.T) {
	template := &model.AssessmentTemplate{
		MaxScore: 90, LevelRules: testAbilityRules(),
		Questions: []model.AssessmentQuestion{{
			Base: model.Base{ID: 1}, Code: "Q1", Required: true, MaxScore: 90,
			Options: []model.AssessmentOption{{Base: model.Base{ID: 2}, Code: "score_90", Score: 90}},
		}},
		AdjustmentRules: []model.AdmissionAdjustmentRule{{
			Code: "combined", TargetLevel: "moderate", LevelDelta: 1,
			Conditions: []model.AdmissionRuleCondition{{Type: "boolean_field", Field: "coma"}},
		}},
	}
	optionID := uint(2)
	preview, err := calculateAbilityResult(template, &model.AdmissionAssessment{Coma: true}, []model.AdmissionAssessmentAnswer{{
		QuestionID: 1, OptionID: &optionID,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if preview.InitialLevel != "intact" || preview.FinalLevel != "moderate" {
		t.Fatalf("combined adjustment = initial:%s final:%s, want intact:moderate", preview.InitialLevel, preview.FinalLevel)
	}
}

func TestWorsenLevelSupportsNonContiguousCareLevels(t *testing.T) {
	rules := []model.AbilityLevelRule{
		{Code: "intact", CareLevel: 1},
		{Code: "moderate", CareLevel: 3},
		{Code: "complete", CareLevel: 5},
	}
	first, _ := levelRuleByCode(rules, "intact")
	if got := worsenLevelBy(rules, first, 1).Code; got != "moderate" {
		t.Fatalf("first non-contiguous worsening = %s, want moderate", got)
	}
	if got := worsenLevelBy(rules, first, 2).Code; got != "complete" {
		t.Fatalf("second non-contiguous worsening = %s, want complete", got)
	}
}

func TestEducationRequirementOnlyWhenRuleCanStillMatch(t *testing.T) {
	educationRule := model.AdmissionAdjustmentRule{
		Code: "education", MatchMode: "all",
		Conditions: []model.AdmissionRuleCondition{
			{Type: "diagnosis_code", MatchCodes: []string{"F00-F03"}},
			{Type: "education_years", Operator: "lte", Threshold: 12},
		},
	}
	if !adjustmentRulesRequireEducationYears([]model.AdmissionAdjustmentRule{educationRule}, admissionRuleContext{
		Diagnoses: []string{"F01"},
	}) {
		t.Fatal("education years should be required when diagnosis predicate matches")
	}
	if adjustmentRulesRequireEducationYears([]model.AdmissionAdjustmentRule{educationRule}, admissionRuleContext{
		Diagnoses: []string{"E01"},
	}) {
		t.Fatal("education years should not be required when another all-mode predicate fails")
	}

	anyRule := model.AdmissionAdjustmentRule{
		Code: "education_any", MatchMode: "any",
		Conditions: []model.AdmissionRuleCondition{
			{Type: "diagnosis_code", MatchCodes: []string{"F00-F03"}},
			{Type: "education_years", Operator: "lte", Threshold: 12},
		},
	}
	if adjustmentRulesRequireEducationYears([]model.AdmissionAdjustmentRule{anyRule}, admissionRuleContext{
		Diagnoses: []string{"F01"},
	}) {
		t.Fatal("education years should not be required when any-mode diagnosis already matches")
	}
}
