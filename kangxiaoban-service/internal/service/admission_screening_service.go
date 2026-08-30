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

var (
	errAdmissionScreeningMissing    = errors.New("admission screening record missing")
	errAdmissionScreeningIncomplete = errors.New("admission screening record incomplete")
)

// AdmissionScreeningAnswerInput contains a server-owned option and optional examiner notes.
type AdmissionScreeningAnswerInput struct {
	QuestionID uint                               `json:"question_id" binding:"required"`
	OptionID   uint                               `json:"option_id" binding:"required"`
	AnswerText string                             `json:"answer_text"`
	Evidence   []model.AdmissionScreeningEvidence `json:"evidence,omitempty"`
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
	ruleContext   admissionRuleContext
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
	if err != nil {
		return nil, err
	}
	// Score columns and answer snapshots are denormalized audit fields. Rebuild
	// them for every read so a stale or tampered snapshot cannot leak into the
	// clinician UI; submission uses the same calculation path below.
	for i := range screenings {
		template, err := s.screeningTemplateByIDForRead(db, screenings[i].TemplateID)
		if err != nil {
			return nil, err
		}
		if !strings.EqualFold(screenings[i].TemplateCode, template.Code) {
			return nil, fmt.Errorf("%w: screening template code does not match persisted template", ErrAdmissionValidation)
		}
		if strings.TrimSpace(screenings[i].TemplateVersion) != strings.TrimSpace(template.Version) {
			return nil, fmt.Errorf("%w: screening template version does not match persisted template", ErrAdmissionValidation)
		}
		calculated, err := calculateAdmissionScreening(template, screenings[i].Answers, screenings[i].EducationYears, screenings[i].Status == "completed")
		if err != nil {
			return nil, err
		}
		if screenings[i].Status == "completed" && adjustmentRulesRequireEducationYears(template.AdjustmentRules, calculated.ruleContext) && screenings[i].EducationYears == nil {
			return nil, fmt.Errorf("%w: education_years is required by screening %s adjustment rules", ErrAdmissionValidation, screenings[i].TemplateCode)
		}
		screenings[i].RawScore = calculated.rawScore
		screenings[i].AdjustedScore = calculated.adjustedScore
		screenings[i].ResultCode = calculated.resultCode
		screenings[i].ResultLabel = calculated.resultLabel
		for answerIndex := range screenings[i].Answers {
			answer := &screenings[i].Answers[answerIndex]
			question, ok := screeningQuestionByID(template, answer.QuestionID)
			if !ok || answer.OptionID == nil {
				return nil, fmt.Errorf("%w: saved screening answer does not match template", ErrAdmissionValidation)
			}
			option, ok := screeningOptionByID(question, *answer.OptionID)
			if !ok {
				return nil, fmt.Errorf("%w: saved screening option does not match template", ErrAdmissionValidation)
			}
			answer.QuestionCode = question.Code
			answer.OptionCode = option.Code
			answer.Score = option.Score
		}
	}
	return screenings, nil
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
		// MMSE and MoCA are the second stage of the PDF flow. A draft may be
		// saved early, but completing either scale requires a completed positive
		// first-stage screen (Mini-Cog or AD8).
		if input.Completed {
			if err := validateFurtherScreeningPrerequisites(tx, admissionID, template.Code); err != nil {
				return err
			}
		}
		score, err := calculateAdmissionScreening(template, answers, input.EducationYears, input.Completed)
		if err != nil {
			return err
		}
		if input.Completed && !score.complete {
			return fmt.Errorf("%w: answered %d of %d required screening questions", ErrAdmissionIncomplete, score.answeredCount, score.requiredCount)
		}
		if input.Completed && adjustmentRulesRequireEducationYears(template.AdjustmentRules, score.ruleContext) && input.EducationYears == nil {
			return fmt.Errorf("%w: education_years is required by the screening adjustment rules", ErrAdmissionValidation)
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
	template, err := loadEnabledScreeningTemplate(db, code)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: screening template not found", ErrAdmissionValidation)
	}
	return template, err
}

// screeningTemplateByIDForRead loads a historical screening template even if
// an administrator has since disabled it. Existing records must remain
// inspectable, while their score is still interpreted from server-owned data.
func (s *AdmissionService) screeningTemplateByIDForRead(db *gorm.DB, id uint) (*model.AssessmentTemplate, error) {
	template, err := loadScreeningTemplateByID(db, id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: screening template not found", ErrAdmissionValidation)
	}
	return template, err
}

func preloadScreeningTemplate(db *gorm.DB) *gorm.DB {
	return db.Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") })
}

// loadEnabledScreeningTemplate resolves the active template for a code using
// the same deterministic ordering as the template API. The template ID and
// version are then used together when selecting a screening record, so an old
// version cannot win merely because it happens to be returned by First.
func loadEnabledScreeningTemplate(db *gorm.DB, code string) (*model.AssessmentTemplate, error) {
	var template model.AssessmentTemplate
	err := preloadScreeningTemplate(db).
		Where("code = ? AND category = ? AND enabled = ?", strings.ToUpper(strings.TrimSpace(code)), "admission_screening", true).
		Order("sort_order asc, id desc").First(&template).Error
	if err != nil {
		return nil, err
	}
	return &template, nil
}

func loadScreeningTemplateByID(db *gorm.DB, id uint) (*model.AssessmentTemplate, error) {
	var template model.AssessmentTemplate
	err := preloadScreeningTemplate(db).
		Where("id = ? AND category = ?", id, "admission_screening").First(&template).Error
	if err != nil {
		return nil, err
	}
	return &template, nil
}

func screeningQuestionByID(template *model.AssessmentTemplate, id uint) (model.AssessmentQuestion, bool) {
	for _, question := range template.Questions {
		if question.ID == id {
			return question, true
		}
	}
	return model.AssessmentQuestion{}, false
}

func screeningOptionByID(question model.AssessmentQuestion, id uint) (model.AssessmentOption, bool) {
	for _, option := range question.Options {
		if option.ID == id {
			return option, true
		}
	}
	return model.AssessmentOption{}, false
}

func (s *AdmissionService) getScreening(db *gorm.DB, id uint) (*model.AdmissionScreening, error) {
	var screening model.AdmissionScreening
	err := db.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).First(&screening, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAdmissionNotFound
	}
	return &screening, err
}

// loadAndCalculateScreening reads a screening using the active template ID
// and version when that version has been started for the admission. If an
// admission only has an older screening, the newest historical record is
// retained as the fallback; its own template ID/version is still validated
// and used for scoring. This keeps historical records readable without
// allowing an arbitrary same-code row to win a gate check.
func loadAndCalculateScreening(tx *gorm.DB, admissionID uint, code string) (*model.AdmissionScreening, *model.AssessmentTemplate, *admissionScreeningScore, error) {
	screening, template, err := loadAdmissionScreeningForCode(tx, admissionID, code)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, nil, fmt.Errorf("%w: %w: required screening %s is not completed", ErrAdmissionIncomplete, errAdmissionScreeningMissing, code)
	}
	if err != nil {
		return nil, nil, nil, err
	}
	if screening.Status != "completed" {
		return screening, template, nil, fmt.Errorf("%w: %w: required screening %s is not completed", ErrAdmissionIncomplete, errAdmissionScreeningIncomplete, code)
	}
	calculated, err := calculateAdmissionScreening(template, screening.Answers, screening.EducationYears, true)
	if err != nil {
		return screening, template, nil, err
	}
	if !calculated.complete {
		return screening, template, calculated, fmt.Errorf("%w: %w: required screening %s answers are incomplete", ErrAdmissionIncomplete, errAdmissionScreeningIncomplete, code)
	}
	if adjustmentRulesRequireEducationYears(template.AdjustmentRules, calculated.ruleContext) && screening.EducationYears == nil {
		return screening, template, calculated, fmt.Errorf("%w: education_years is required by screening %s adjustment rules", ErrAdmissionValidation, code)
	}
	return screening, template, calculated, nil
}

// loadAdmissionScreeningForCode returns one unambiguous screening/template
// pair. A current enabled template is preferred only when a record for that
// exact template ID and version exists; otherwise the latest historical row
// is used and validated against the template it persisted.
func loadAdmissionScreeningForCode(tx *gorm.DB, admissionID uint, code string) (*model.AdmissionScreening, *model.AssessmentTemplate, error) {
	normalizedCode := strings.ToUpper(strings.TrimSpace(code))
	activeTemplate, activeErr := loadEnabledScreeningTemplate(tx, normalizedCode)
	if activeErr != nil && !errors.Is(activeErr, gorm.ErrRecordNotFound) {
		return nil, nil, activeErr
	}
	// Bind the gate lookup to the active template's immutable identity. This
	// prevents a historical row with the same code from being selected by an
	// unconstrained First query.
	if activeErr == nil {
		var current model.AdmissionScreening
		err := preloadAdmissionScreening(tx).
			Where("admission_id = ? AND template_id = ? AND template_version = ?", admissionID, activeTemplate.ID, activeTemplate.Version).
			Order("updated_at desc, id desc").First(&current).Error
		if err == nil {
			return validateAdmissionScreeningPair(&current, activeTemplate, normalizedCode)
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil, err
		}
		// A row for the active template ID with a different version is corrupt,
		// not a valid historical fallback. Surface it instead of silently using
		// another version.
		var mismatched model.AdmissionScreening
		mismatchErr := preloadAdmissionScreening(tx).
			Where("admission_id = ? AND template_id = ?", admissionID, activeTemplate.ID).
			Order("updated_at desc, id desc").First(&mismatched).Error
		if mismatchErr == nil {
			return nil, nil, fmt.Errorf("%w: screening %s template version does not match active template", ErrAdmissionValidation, normalizedCode)
		}
		if !errors.Is(mismatchErr, gorm.ErrRecordNotFound) {
			return nil, nil, mismatchErr
		}
	}

	// No active-version row exists. Keep older records readable by selecting
	// the newest persisted row deterministically, then validate its own
	// template ID/version before calculating any score.
	var historical model.AdmissionScreening
	err := preloadAdmissionScreening(tx).
		Where("admission_id = ? AND template_code = ?", admissionID, normalizedCode).
		Order("updated_at desc, id desc").First(&historical).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, gorm.ErrRecordNotFound
	}
	if err != nil {
		return nil, nil, err
	}
	template, err := loadScreeningTemplateByID(tx, historical.TemplateID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, fmt.Errorf("%w: screening template %s is missing", ErrAdmissionValidation, normalizedCode)
	}
	if err != nil {
		return nil, nil, err
	}
	return validateAdmissionScreeningPair(&historical, template, normalizedCode)
}

func preloadAdmissionScreening(db *gorm.DB) *gorm.DB {
	return db.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") })
}

func validateAdmissionScreeningPair(screening *model.AdmissionScreening, template *model.AssessmentTemplate, code string) (*model.AdmissionScreening, *model.AssessmentTemplate, error) {
	if !strings.EqualFold(strings.TrimSpace(screening.TemplateCode), strings.TrimSpace(template.Code)) {
		return nil, nil, fmt.Errorf("%w: screening template code does not match persisted template", ErrAdmissionValidation)
	}
	if strings.TrimSpace(screening.TemplateVersion) != strings.TrimSpace(template.Version) {
		return nil, nil, fmt.Errorf("%w: screening %s template version does not match persisted template", ErrAdmissionValidation, code)
	}
	return screening, template, nil
}

// validateFurtherScreeningPrerequisites enforces the PDF's second-stage
// sequence when a doctor marks MMSE or MoCA complete. Either Mini-Cog or AD8
// may serve as the first-stage screen; a positive result on either one is
// required. Drafts can still be saved early so an interrupted assessment is
// recoverable.
func validateFurtherScreeningPrerequisites(tx *gorm.DB, admissionID uint, code string) error {
	code = strings.ToUpper(strings.TrimSpace(code))
	if code != "MMSE" && code != "MOCA_BEIJING" {
		return nil
	}
	primary, err := loadPrimaryScreenings(tx, admissionID)
	if err != nil {
		return err
	}
	if !primary.hasPositive {
		return fmt.Errorf("%w: %s requires a positive Mini-Cog (0-2) or AD8 (2-8) first-stage screen", ErrAdmissionValidation, code)
	}
	return nil
}

// validateAdmissionScreeningGate re-evaluates all required screenings inside
// the submission transaction. This prevents a client from bypassing the gate
// by editing status or score snapshots directly.
func validateAdmissionScreeningGate(tx *gorm.DB, admissionID uint) error {
	primary, err := loadPrimaryScreenings(tx, admissionID)
	if err != nil {
		return err
	}
	if !primary.hasPositive {
		return nil
	}
	for _, code := range []string{"MMSE", "MOCA_BEIJING"} {
		if _, _, _, err := loadAndCalculateScreening(tx, admissionID, code); err != nil {
			return fmt.Errorf("%w: a positive first-stage screen requires %s", err, code)
		}
	}
	return nil
}

type primaryScreeningState struct {
	hasCompleted bool
	hasPositive  bool
}

// loadPrimaryScreenings loads both first-stage alternatives when present. A
// missing alternative is expected; the gate only requires one completed
// primary screen. Any other error (tampered template/answers, for example) is
// returned so submission cannot proceed on unverifiable data.
func loadPrimaryScreenings(tx *gorm.DB, admissionID uint) (primaryScreeningState, error) {
	state := primaryScreeningState{}
	for _, code := range []string{"MINI_COG", "AD8"} {
		_, template, calculated, err := loadAndCalculateScreening(tx, admissionID, code)
		if err != nil {
			if errors.Is(err, errAdmissionScreeningMissing) || errors.Is(err, errAdmissionScreeningIncomplete) {
				continue
			}
			return state, err
		}
		state.hasCompleted = true
		if primaryScreeningIsPositive(code, template, calculated.adjustedScore) {
			state.hasPositive = true
		}
	}
	if !state.hasCompleted {
		return state, fmt.Errorf("%w: complete Mini-Cog or AD8 first-stage screening", ErrAdmissionIncomplete)
	}
	return state, nil
}

func primaryScreeningIsPositive(code string, template *model.AssessmentTemplate, adjustedScore int) bool {
	if template != nil {
		if rule, ok := ruleForScore(template.LevelRules, adjustedScore); ok {
			if rule.Code == "positive" {
				return true
			}
			if rule.Code == "negative" {
				return false
			}
		}
	}
	switch strings.ToUpper(strings.TrimSpace(code)) {
	case "MINI_COG":
		return adjustedScore <= 2
	case "AD8":
		return adjustedScore >= 2
	default:
		return false
	}
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
		evidence, err := normalizeScreeningEvidence(question, *selected, item.Evidence, item.AnswerText)
		if err != nil {
			return nil, err
		}
		optionID := selected.ID
		answers = append(answers, model.AdmissionScreeningAnswer{
			ScreeningID: screeningID, QuestionID: question.ID, OptionID: &optionID,
			QuestionCode: question.Code, OptionCode: selected.Code,
			AnswerText: item.AnswerText, Score: selected.Score, Evidence: evidence,
		})
	}
	return answers, nil
}

const (
	maxScreeningEvidenceItems = 128
	maxScreeningEvidenceCode  = 128
)

// normalizeScreeningEvidence validates the audit payload without allowing it
// to influence the server-owned option score. Older clients do not send
// evidence, so one aggregate observation is synthesized for compatibility.
func normalizeScreeningEvidence(question model.AssessmentQuestion, selected model.AssessmentOption, input []model.AdmissionScreeningEvidence, answerText string) ([]model.AdmissionScreeningEvidence, error) {
	if len(input) > maxScreeningEvidenceItems {
		return nil, fmt.Errorf("%w: too many evidence items for screening question %s", ErrAdmissionValidation, question.Code)
	}
	if len(input) == 0 {
		return []model.AdmissionScreeningEvidence{{
			ItemCode: question.Code, OptionCode: selected.Code, AnswerText: answerText, Score: selected.Score,
		}}, nil
	}
	evidence := make([]model.AdmissionScreeningEvidence, 0, len(input))
	seen := make(map[string]bool, len(input))
	for _, item := range input {
		item.ItemCode = strings.TrimSpace(item.ItemCode)
		item.OptionCode = strings.TrimSpace(item.OptionCode)
		item.AnswerText = strings.TrimSpace(item.AnswerText)
		if item.ItemCode == "" || len([]rune(item.ItemCode)) > maxScreeningEvidenceCode {
			return nil, fmt.Errorf("%w: evidence item_code is required and must be at most %d characters", ErrAdmissionValidation, maxScreeningEvidenceCode)
		}
		if item.OptionCode != "" && len([]rune(item.OptionCode)) > maxScreeningEvidenceCode {
			return nil, fmt.Errorf("%w: evidence option_code is too long", ErrAdmissionValidation)
		}
		if len([]rune(item.AnswerText)) > 4096 {
			return nil, fmt.Errorf("%w: evidence answer_text is too long", ErrAdmissionValidation)
		}
		key := strings.ToUpper(item.ItemCode)
		if seen[key] {
			return nil, fmt.Errorf("%w: duplicate evidence item_code %q", ErrAdmissionValidation, item.ItemCode)
		}
		seen[key] = true
		evidence = append(evidence, item)
	}
	return evidence, nil
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
	normalizedAnswers := make([]model.AdmissionAssessmentAnswer, 0, len(answers))
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
		normalizedAnswers = append(normalizedAnswers, model.AdmissionAssessmentAnswer{
			QuestionID: question.ID, OptionID: answer.OptionID, QuestionCode: question.Code,
			OptionCode: selected.Code, AnswerText: answer.AnswerText, Score: selected.Score,
		})
	}
	if rawScore < 0 || rawScore > template.MaxScore {
		return nil, fmt.Errorf("%w: screening score outside template range", ErrAdmissionValidation)
	}
	ruleContext := admissionRuleContext{Answers: normalizedAnswers, EducationYears: educationYears}
	outcome := evaluateAdmissionAdjustmentRules(template.AdjustmentRules, ruleContext)
	adjustedScore := rawScore + outcome.ScoreDelta
	if adjustedScore < 0 {
		adjustedScore = 0
	}
	if adjustedScore > template.MaxScore {
		adjustedScore = template.MaxScore
	}
	complete := answeredRequired == requiredCount
	resultCode, resultLabel := "", ""
	if final && complete {
		resultCode, resultLabel = admissionScreeningResult(template, adjustedScore)
	}
	return &admissionScreeningScore{
		rawScore: rawScore, adjustedScore: adjustedScore, answeredCount: answeredRequired,
		requiredCount: requiredCount, complete: complete, resultCode: resultCode, resultLabel: resultLabel,
		ruleContext: ruleContext,
	}, nil
}

func admissionScreeningResult(template *model.AssessmentTemplate, adjustedScore int) (string, string) {
	if rule, ok := ruleForScore(template.LevelRules, adjustedScore); ok {
		return rule.Code, rule.Label
	}
	return "score_recorded", fmt.Sprintf("总分%d/%d", adjustedScore, template.MaxScore)
}
