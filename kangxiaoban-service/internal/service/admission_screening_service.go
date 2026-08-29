package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// AdmissionScreeningAnswerInput contains a server-owned option and optional examiner notes.
type AdmissionScreeningAnswerInput struct {
	QuestionID uint   `json:"question_id" binding:"required"`
	OptionID   uint   `json:"option_id" binding:"required"`
	AnswerText string `json:"answer_text"`
}

// AdmissionScreeningInput saves a partial draft or completes one optional screening.
type AdmissionScreeningInput struct {
	Completed      bool                            `json:"completed"`
	EducationYears *int                            `json:"education_years"`
	Notes          string                          `json:"notes"`
	Answers        []AdmissionScreeningAnswerInput `json:"answers"`
}

type AdmissionScreeningSaveResult struct {
	Screening     model.AdmissionScreening `json:"screening"`
	AnsweredCount int                      `json:"answered_count"`
	RequiredCount int                      `json:"required_count"`
	Complete      bool                     `json:"complete"`
}

type admissionScreeningScore struct {
	rawScore      int
	adjustedScore int
	answeredCount int
	requiredCount int
	complete      bool
	resultCode    string
	resultLabel   string
}

func (s *AdmissionService) ScreeningTemplates(ctx context.Context) ([]model.AssessmentTemplate, error) {
	var templates []model.AssessmentTemplate
	err := s.db.WithContext(ctx).
		Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Where("category = ? AND enabled = ?", "admission_screening", true).
		Order("sort_order asc, id asc").Find(&templates).Error
	return templates, err
}

func (s *AdmissionService) ListScreenings(ctx context.Context, admissionID uint) ([]model.AdmissionScreening, error) {
	db := s.db.WithContext(ctx)
	if _, err := s.getAdmission(db, admissionID); err != nil {
		return nil, err
	}
	var screenings []model.AdmissionScreening
	err := db.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).
		Where("admission_id = ?", admissionID).Order("updated_at desc, id desc").Find(&screenings).Error
	return screenings, err
}

func (s *AdmissionService) SaveScreening(ctx context.Context, actor AdmissionActor, admissionID uint, templateCode string, input AdmissionScreeningInput) (*AdmissionScreeningSaveResult, error) {
	templateCode = strings.ToUpper(strings.TrimSpace(templateCode))
	if templateCode == "" {
		return nil, fmt.Errorf("%w: screening template code is required", ErrAdmissionValidation)
	}
	if input.EducationYears != nil && (*input.EducationYears < 0 || *input.EducationYears > 30) {
		return nil, fmt.Errorf("%w: education_years must be between 0 and 30", ErrAdmissionValidation)
	}
	if len(input.Notes) > 2048 {
		return nil, fmt.Errorf("%w: notes is too long", ErrAdmissionValidation)
	}
	for _, answer := range input.Answers {
		if len(answer.AnswerText) > 4096 {
			return nil, fmt.Errorf("%w: answer_text is too long", ErrAdmissionValidation)
		}
	}

	result := &AdmissionScreeningSaveResult{}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		admission, err := s.getAdmission(tx, admissionID)
		if err != nil {
			return err
		}
		if err := authorizeAdmissionMutation(admission, actor); err != nil {
			return err
		}
		if admission.Status != "draft" {
			return ErrAdmissionInvalidState
		}
		template, err := s.screeningTemplateByCode(tx, templateCode)
		if err != nil {
			return err
		}

		var screening model.AdmissionScreening
		err = tx.Where("admission_id = ? AND template_id = ?", admissionID, template.ID).First(&screening).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			screening = model.AdmissionScreening{
				AdmissionID: admissionID, TemplateID: template.ID, TemplateCode: template.Code,
				TemplateVersion: template.Version, AssessorID: actor.UserID, Status: "draft",
			}
			if err := tx.Create(&screening).Error; err != nil {
				return err
			}
		}

		answers, err := buildAdmissionScreeningAnswers(template, screening.ID, input.Answers)
		if err != nil {
			return err
		}
		score, err := calculateAdmissionScreening(template, answers, input.EducationYears, input.Completed)
		if err != nil {
			return err
		}
		if input.Completed && !score.complete {
			return fmt.Errorf("%w: answered %d of %d required screening questions", ErrAdmissionIncomplete, score.answeredCount, score.requiredCount)
		}
		if input.Completed && template.Code == "MOCA_BEIJING" && input.EducationYears == nil {
			return fmt.Errorf("%w: education_years is required to complete MoCA", ErrAdmissionValidation)
		}

		if err := tx.Unscoped().Where("screening_id = ?", screening.ID).Delete(&model.AdmissionScreeningAnswer{}).Error; err != nil {
			return err
		}
		if len(answers) > 0 {
			if err := tx.Create(&answers).Error; err != nil {
				return err
			}
		}

		status := "draft"
		var completedAt *time.Time
		if input.Completed {
			status = "completed"
			now := time.Now()
			completedAt = &now
		}
		updates := map[string]interface{}{
			"assessor_id": actor.UserID, "status": status, "raw_score": score.rawScore,
			"adjusted_score": score.adjustedScore, "result_code": score.resultCode,
			"result_label": score.resultLabel, "education_years": input.EducationYears,
			"notes": input.Notes, "completed_at": completedAt,
		}
		if err := tx.Model(&screening).Updates(updates).Error; err != nil {
			return err
		}
		saved, err := s.getScreening(tx, screening.ID)
		if err != nil {
			return err
		}
		result.Screening = *saved
		result.AnsweredCount = score.answeredCount
		result.RequiredCount = score.requiredCount
		result.Complete = score.complete
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *AdmissionService) screeningTemplateByCode(db *gorm.DB, code string) (*model.AssessmentTemplate, error) {
	var template model.AssessmentTemplate
	err := db.Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Where("code = ? AND category = ? AND enabled = ?", code, "admission_screening", true).
		Order("sort_order asc, id desc").First(&template).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: screening template not found", ErrAdmissionValidation)
	}
	return &template, err
}

func (s *AdmissionService) getScreening(db *gorm.DB, id uint) (*model.AdmissionScreening, error) {
	var screening model.AdmissionScreening
	err := db.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).First(&screening, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAdmissionNotFound
	}
	return &screening, err
}

func buildAdmissionScreeningAnswers(template *model.AssessmentTemplate, screeningID uint, input []AdmissionScreeningAnswerInput) ([]model.AdmissionScreeningAnswer, error) {
	questionByID := make(map[uint]model.AssessmentQuestion, len(template.Questions))
	for _, question := range template.Questions {
		questionByID[question.ID] = question
	}
	seen := make(map[uint]bool, len(input))
	answers := make([]model.AdmissionScreeningAnswer, 0, len(input))
	for _, item := range input {
		question, ok := questionByID[item.QuestionID]
		if !ok {
			return nil, fmt.Errorf("%w: screening question_id %d is not in template", ErrAdmissionValidation, item.QuestionID)
		}
		if seen[item.QuestionID] {
			return nil, fmt.Errorf("%w: duplicate screening question_id %d", ErrAdmissionValidation, item.QuestionID)
		}
		seen[item.QuestionID] = true
		var selected *model.AssessmentOption
		for i := range question.Options {
			if question.Options[i].ID == item.OptionID {
				selected = &question.Options[i]
				break
			}
		}
		if selected == nil {
			return nil, fmt.Errorf("%w: screening option_id %d does not belong to question_id %d", ErrAdmissionValidation, item.OptionID, item.QuestionID)
		}
		optionID := selected.ID
		answers = append(answers, model.AdmissionScreeningAnswer{
			ScreeningID: screeningID, QuestionID: question.ID, OptionID: &optionID,
			QuestionCode: question.Code, OptionCode: selected.Code,
			AnswerText: item.AnswerText, Score: selected.Score,
		})
	}
	return answers, nil
}

func calculateAdmissionScreening(template *model.AssessmentTemplate, answers []model.AdmissionScreeningAnswer, educationYears *int, final bool) (*admissionScreeningScore, error) {
	questionByID := make(map[uint]model.AssessmentQuestion, len(template.Questions))
	requiredCount := 0
	for _, question := range template.Questions {
		questionByID[question.ID] = question
		if question.Required {
			requiredCount++
		}
	}
	seen := make(map[uint]bool, len(answers))
	answeredRequired := 0
	rawScore := 0
	for _, answer := range answers {
		question, ok := questionByID[answer.QuestionID]
		if !ok || seen[answer.QuestionID] || answer.OptionID == nil {
			return nil, fmt.Errorf("%w: saved screening answers do not match template", ErrAdmissionValidation)
		}
		var selected *model.AssessmentOption
		for i := range question.Options {
			if question.Options[i].ID == *answer.OptionID {
				selected = &question.Options[i]
				break
			}
		}
		if selected == nil {
			return nil, fmt.Errorf("%w: saved screening option does not belong to template question", ErrAdmissionValidation)
		}
		seen[answer.QuestionID] = true
		if question.Required {
			answeredRequired++
		}
		rawScore += selected.Score
	}
	if rawScore < 0 || rawScore > template.MaxScore {
		return nil, fmt.Errorf("%w: screening score outside template range", ErrAdmissionValidation)
	}
	adjustedScore := rawScore
	if template.Code == "MOCA_BEIJING" && educationYears != nil && *educationYears <= 12 && adjustedScore < template.MaxScore {
		adjustedScore++
	}
	complete := answeredRequired == requiredCount
	resultCode, resultLabel := "", ""
	if final && complete {
		resultCode, resultLabel = admissionScreeningResult(template, adjustedScore)
	}
	return &admissionScreeningScore{
		rawScore: rawScore, adjustedScore: adjustedScore, answeredCount: answeredRequired,
		requiredCount: requiredCount, complete: complete, resultCode: resultCode, resultLabel: resultLabel,
	}, nil
}

func admissionScreeningResult(template *model.AssessmentTemplate, adjustedScore int) (string, string) {
	if template.Code == "SLEEP5" {
		return "recorded", "已记录睡眠问题答案（附表未设置总分或分级）"
	}
	if rule, ok := ruleForScore(template.LevelRules, adjustedScore); ok {
		return rule.Code, rule.Label
	}
	return "score_recorded", fmt.Sprintf("总分%d/%d", adjustedScore, template.MaxScore)
}
