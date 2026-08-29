package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

const currentAdmissionTemplateCode = "GB_T_42195_2022_ADMISSION"

var (
	ErrAdmissionNotFound      = errors.New("admission assessment not found")
	ErrAdmissionForbidden     = errors.New("admission assessment forbidden")
	ErrAdmissionInvalidState  = errors.New("admission assessment state does not allow operation")
	ErrAdmissionValidation    = errors.New("admission assessment validation failed")
	ErrAdmissionIncomplete    = errors.New("admission assessment answers incomplete")
	ErrAdmissionBedConflict   = errors.New("admission bed conflict")
	ErrAdmissionElderConflict = errors.New("admission elder conflict")
)

// AdmissionActor is the authenticated staff member performing an admission operation.
type AdmissionActor struct {
	UserID  uint
	IsAdmin bool
}

// AdmissionAnswerInput contains only identifiers and free text. Client scores are intentionally absent.
type AdmissionAnswerInput struct {
	QuestionID uint   `json:"question_id" binding:"required"`
	OptionID   uint   `json:"option_id" binding:"required"`
	AnswerText string `json:"answer_text"`
}

// AdmissionDraftInput is the writable appendix A/C confirmation data and appendix B selections.
type AdmissionDraftInput struct {
	ElderID                  *uint                       `json:"elder_id"`
	CurrentStep              int                         `json:"current_step"`
	AssessmentReason         string                      `json:"assessment_reason"`
	BaselineDate             string                      `json:"baseline_date"`
	ResidentName             string                      `json:"resident_name"`
	Gender                   string                      `json:"gender"`
	BirthDate                string                      `json:"birth_date"`
	IDCard                   string                      `json:"id_card"`
	HeightCM                 float64                     `json:"height_cm"`
	WeightKG                 float64                     `json:"weight_kg"`
	Ethnicity                string                      `json:"ethnicity"`
	Religion                 string                      `json:"religion"`
	Education                string                      `json:"education"`
	LivingSituations         []string                    `json:"living_situations"`
	MaritalStatus            string                      `json:"marital_status"`
	MedicalPayments          []string                    `json:"medical_payments"`
	IncomeSources            []string                    `json:"income_sources"`
	RiskEvents               []model.AdmissionRiskEvent  `json:"risk_events"`
	Diagnoses                []string                    `json:"diagnoses"`
	DementiaOrMentalDisorder bool                        `json:"dementia_or_mental_disorder"`
	Medications              []model.AdmissionMedication `json:"medications"`
	HealthIssues             []string                    `json:"health_issues"`
	Coma                     bool                        `json:"coma"`
	InfoProviderName         string                      `json:"info_provider_name"`
	InfoProviderRelation     string                      `json:"info_provider_relation"`
	ContactName              string                      `json:"contact_name"`
	ContactPhone             string                      `json:"contact_phone"`
	TargetBedID              *uint                       `json:"target_bed_id"`
	SelectedCarePlanCode     string                      `json:"selected_care_plan_code"`
	SelectedOptionalServices []string                    `json:"selected_optional_services"`
	AssessmentLocation       string                      `json:"assessment_location"`
	DoctorConfirmed          bool                        `json:"doctor_confirmed"`
	PlanConsentConfirmed     bool                        `json:"plan_consent_confirmed"`
	ServiceFeeInformed       bool                        `json:"service_fee_informed"`
	InfoProviderSigned       bool                        `json:"info_provider_signed"`
	Answers                  []AdmissionAnswerInput      `json:"answers"`
}

type AdmissionTemplateBundle struct {
	Template          model.AssessmentTemplate          `json:"template"`
	Dictionaries      []model.AdmissionDictionaryItem   `json:"dictionaries"`
	CarePlanTemplates []model.AdmissionCarePlanTemplate `json:"care_plan_templates"`
	LevelRules        []model.AbilityLevelRule          `json:"level_rules"`
	ScoringNotes      []string                          `json:"scoring_notes"`
}

type AdmissionGroupScore struct {
	Code     string `json:"code"`
	Label    string `json:"label"`
	Score    int    `json:"score"`
	MaxScore int    `json:"max_score"`
}

type AdmissionPreview struct {
	AbilityScore       int                              `json:"ability_score"`
	AnsweredCount      int                              `json:"answered_count"`
	RequiredCount      int                              `json:"required_count"`
	Complete           bool                             `json:"complete"`
	InitialLevel       string                           `json:"initial_level"`
	InitialLevelLabel  string                           `json:"initial_level_label"`
	FinalLevel         string                           `json:"final_level"`
	FinalLevelLabel    string                           `json:"final_level_label"`
	LevelChangeReasons []string                         `json:"level_change_reasons"`
	GroupScores        []AdmissionGroupScore            `json:"group_scores"`
	SuggestedCarePlan  *model.AdmissionCarePlanTemplate `json:"suggested_care_plan"`
}

type AdmissionSubmissionResult struct {
	Admission  model.AdmissionAssessment `json:"admission"`
	Idempotent bool                      `json:"idempotent"`
}

type admissionEventPublisher interface {
	SendToRole(tenantID uint, role, eventType string, data interface{})
}

type AdmissionService struct {
	db     *gorm.DB
	events admissionEventPublisher
}

func NewAdmissionService(db *gorm.DB, events ...admissionEventPublisher) *AdmissionService {
	svc := &AdmissionService{db: db}
	if len(events) > 0 {
		svc.events = events[0]
	}
	return svc
}

func (s *AdmissionService) TemplateBundle(ctx context.Context) (*AdmissionTemplateBundle, error) {
	template, err := s.currentTemplate(s.db.WithContext(ctx))
	if err != nil {
		return nil, err
	}
	var dictionaries []model.AdmissionDictionaryItem
	if err := s.db.WithContext(ctx).Where("template_id = ? AND enabled = ?", template.ID, true).
		Order("category asc, sort_order asc, id asc").Find(&dictionaries).Error; err != nil {
		return nil, err
	}
	var plans []model.AdmissionCarePlanTemplate
	if err := s.db.WithContext(ctx).Where("template_id = ? AND enabled = ?", template.ID, true).
		Order("sort_order asc, id asc").Find(&plans).Error; err != nil {
		return nil, err
	}
	return &AdmissionTemplateBundle{
		Template: *template, Dictionaries: dictionaries, CarePlanTemplates: plans,
		LevelRules: template.LevelRules, ScoringNotes: template.ScoringNotes,
	}, nil
}

func (s *AdmissionService) List(ctx context.Context, actor AdmissionActor, status string, mine bool, page, size int) ([]model.AdmissionAssessment, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.AdmissionAssessment{}).Where("status IN ?", []string{"draft", "submitted"})
	if status != "" {
		if status != "draft" && status != "submitted" {
			return nil, 0, fmt.Errorf("%w: invalid status", ErrAdmissionValidation)
		}
		q = q.Where("status = ?", status)
	}
	if mine {
		q = q.Where("assessor_id = ?", actor.UserID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.AdmissionAssessment
	err := q.Order("updated_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (s *AdmissionService) Get(ctx context.Context, _ AdmissionActor, id uint) (*model.AdmissionAssessment, error) {
	return s.getAdmission(s.db.WithContext(ctx), id)
}

func (s *AdmissionService) Create(ctx context.Context, actor AdmissionActor, input AdmissionDraftInput) (*model.AdmissionAssessment, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	template, err := s.currentTemplate(s.db.WithContext(ctx))
	if err != nil {
		return nil, err
	}
	admission := input.toModel()
	admission.AssessmentNo = newAssessmentNo()
	admission.AssessorID = actor.UserID
	admission.TemplateID = template.ID
	admission.TemplateCode = template.Code
	admission.TemplateVersion = template.Version
	admission.Status = "draft"
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateRiskEvents(admission.RiskEvents); err != nil {
			return err
		}
		if err := tx.Create(&admission).Error; err != nil {
			return err
		}
		return s.replaceAnswers(tx, &admission, template, input.Answers)
	})
	if err != nil {
		return nil, err
	}
	return s.getAdmission(s.db.WithContext(ctx), admission.ID)
}

func (s *AdmissionService) Update(ctx context.Context, actor AdmissionActor, id uint, input AdmissionDraftInput) (*model.AdmissionAssessment, error) {
	db := s.db.WithContext(ctx)
	err := db.Transaction(func(tx *gorm.DB) error {
		var admission model.AdmissionAssessment
		if err := tx.First(&admission, id).Error; err != nil {
			return mapAdmissionNotFound(err)
		}
		if err := authorizeAdmissionMutation(&admission, actor); err != nil {
			return err
		}
		if admission.Status != "draft" {
			return ErrAdmissionInvalidState
		}
		if err := validateRiskEvents(input.RiskEvents); err != nil {
			return err
		}
		writable := input.toModel()
		if err := tx.Model(&admission).Select(
			"ElderID", "CurrentStep", "AssessmentReason", "BaselineDate", "ResidentName", "Gender",
			"BirthDate", "IDCard", "HeightCM", "WeightKG", "Ethnicity", "Religion", "Education",
			"LivingSituations", "MaritalStatus", "MedicalPayments", "IncomeSources", "RiskEvents",
			"Diagnoses", "DementiaOrMentalDisorder", "Medications", "HealthIssues", "Coma",
			"InfoProviderName", "InfoProviderRelation", "ContactName", "ContactPhone", "TargetBedID",
			"SelectedCarePlanCode", "SelectedOptionalServices", "AssessmentLocation", "DoctorConfirmed",
			"PlanConsentConfirmed", "ServiceFeeInformed", "InfoProviderSigned",
		).Updates(&writable).Error; err != nil {
			return err
		}
		if input.Answers != nil {
			template, err := s.templateByID(tx, admission.TemplateID)
			if err != nil {
				return err
			}
			if err := s.replaceAnswers(tx, &admission, template, input.Answers); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.getAdmission(db, id)
}

func (s *AdmissionService) Preview(ctx context.Context, actor AdmissionActor, id uint, override []AdmissionAnswerInput) (*AdmissionPreview, error) {
	db := s.db.WithContext(ctx)
	admission, err := s.getAdmission(db, id)
	if err != nil {
		return nil, err
	}
	if err := authorizeAdmissionMutation(admission, actor); err != nil {
		return nil, err
	}
	if admission.Status != "draft" {
		return nil, ErrAdmissionInvalidState
	}
	template, err := s.templateByID(db, admission.TemplateID)
	if err != nil {
		return nil, err
	}
	answers := admission.Answers
	if override != nil {
		answers, err = buildAnswers(template, admission.ID, override)
		if err != nil {
			return nil, err
		}
	}
	return s.preview(db, admission, template, answers)
}

func (s *AdmissionService) Submit(ctx context.Context, actor AdmissionActor, id uint) (*AdmissionSubmissionResult, error) {
	result := &AdmissionSubmissionResult{}
	db := s.db.WithContext(ctx)
	err := db.Transaction(func(tx *gorm.DB) error {
		admission, err := s.getAdmission(tx, id)
		if err != nil {
			return err
		}
		if err := authorizeAdmissionMutation(admission, actor); err != nil {
			return err
		}
		if admission.Status == "submitted" {
			result.Admission = *admission
			result.Idempotent = true
			return nil
		}
		if admission.Status != "draft" {
			return ErrAdmissionInvalidState
		}
		claimed := tx.Model(&model.AdmissionAssessment{}).
			Where("id = ? AND status = ?", admission.ID, "draft").Update("status", "submitting")
		if claimed.Error != nil {
			return claimed.Error
		}
		if claimed.RowsAffected != 1 {
			return ErrAdmissionInvalidState
		}

		template, err := s.templateByID(tx, admission.TemplateID)
		if err != nil {
			return err
		}
		preview, err := s.preview(tx, admission, template, admission.Answers)
		if err != nil {
			return err
		}
		if err := validateAdmissionForSubmit(admission, preview); err != nil {
			return err
		}
		planTemplate, err := s.selectPlanTemplate(tx, admission, preview.FinalLevel)
		if err != nil {
			return err
		}
		levelRule, ok := levelRuleByCode(template.LevelRules, preview.FinalLevel)
		if !ok {
			return fmt.Errorf("%w: missing final level rule", ErrAdmissionValidation)
		}

		elder, err := s.createOrLinkElder(tx, admission, levelRule.CareLevel)
		if err != nil {
			return err
		}
		bed, err := occupyAdmissionBed(tx, admission.TargetBedID, elder.ID)
		if err != nil {
			return err
		}
		if err := tx.Model(elder).Updates(map[string]interface{}{
			"status": 2, "bed_id": bed.ID, "care_level": levelRule.CareLevel,
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.Room{}).Where("id = ?", bed.RoomID).Update("status", "occupied").Error; err != nil {
			return err
		}

		now := time.Now()
		score := float64(preview.AbilityScore)
		assessment := model.Assessment{
			ElderID: elder.ID, AssessorID: actor.UserID, AssessmentType: "admission_ability",
			Score: &score, RiskLevel: preview.FinalLevel,
			Notes:      fmt.Sprintf("初步等级：%s；最终等级：%s；变更依据：%s", preview.InitialLevelLabel, preview.FinalLevelLabel, strings.Join(preview.LevelChangeReasons, "；")),
			AssessedAt: now,
		}
		if err := tx.Create(&assessment).Error; err != nil {
			return err
		}
		if err := createAdmissionScreeningAssessments(tx, admission.ID, elder.ID, now); err != nil {
			return err
		}
		caregiver, err := firstAvailableCaregiver(tx)
		if err != nil {
			return err
		}
		var caregiverID *uint
		caregiverName := ""
		if caregiver != nil {
			caregiverID = &caregiver.ID
			caregiverName = strings.TrimSpace(caregiver.RealName)
			if caregiverName == "" {
				caregiverName = caregiver.Username
			}
		}
		carePlan, err := createCarePlanFromTemplate(tx, elder.ID, actor.UserID, caregiverID, caregiverName, planTemplate, admission.SelectedOptionalServices, now)
		if err != nil {
			return err
		}
		if err := createAdmissionTasks(tx, elder.ID, caregiverID, caregiverName, carePlan.Items); err != nil {
			return err
		}
		familyUserIDs, err := bindMatchingFamilyUsers(tx, elder.ID, admission.ContactPhone)
		if err != nil {
			return err
		}

		notification := model.Notification{
			Role: "caregiver", Channel: "in_app", Type: "admission_completed", Severity: "important",
			Title: "新长者入住", Content: fmt.Sprintf("%s 已完成入住评估并分配床位，请执行%s。", admission.ResidentName, planTemplate.Name), SentAt: &now,
		}
		if err := tx.Create(&notification).Error; err != nil {
			return err
		}
		for _, familyUserID := range familyUserIDs {
			familyNotification := model.Notification{
				UserID: familyUserID, Channel: "in_app", Type: "admission_completed", Severity: "important",
				Title: "入住办理完成", Content: fmt.Sprintf("%s 已完成入住评估和床位分配。", admission.ResidentName), SentAt: &now,
			}
			if err := tx.Create(&familyNotification).Error; err != nil {
				return err
			}
		}
		audit := model.AuditLog{
			UserID: actor.UserID, Action: "submit", Module: "admission_assessment", Method: "POST",
			Path: fmt.Sprintf("/api/v1/admission-assessments/%d/submit", admission.ID),
		}
		if err := tx.Create(&audit).Error; err != nil {
			return err
		}

		admission.Status = "submitted"
		admission.ElderID = &elder.ID
		admission.AbilityScore = preview.AbilityScore
		admission.InitialLevel = preview.InitialLevel
		admission.FinalLevel = preview.FinalLevel
		admission.LevelChangeReasons = preview.LevelChangeReasons
		admission.SelectedCarePlanCode = planTemplate.Code
		admission.CarePlanID = &carePlan.ID
		admission.SubmittedAt = &now
		completedUpdate := tx.Model(&model.AdmissionAssessment{}).Where("id = ? AND status = ?", admission.ID, "submitting").Select(
			"Status", "ElderID", "AbilityScore", "InitialLevel", "FinalLevel", "LevelChangeReasons",
			"SelectedCarePlanCode", "CarePlanID", "SubmittedAt",
		).Updates(admission)
		if completedUpdate.Error != nil {
			return completedUpdate.Error
		}
		if completedUpdate.RowsAffected != 1 {
			return ErrAdmissionInvalidState
		}
		completed, err := s.getAdmission(tx, admission.ID)
		if err != nil {
			return err
		}
		result.Admission = *completed
		return nil
	})
	if err != nil {
		return nil, err
	}
	if !result.Idempotent && s.events != nil {
		elderID, carePlanID := uint(0), uint(0)
		if result.Admission.ElderID != nil {
			elderID = *result.Admission.ElderID
		}
		if result.Admission.CarePlanID != nil {
			carePlanID = *result.Admission.CarePlanID
		}
		s.events.SendToRole(result.Admission.TenantID, "caregiver", "admission.submitted", map[string]interface{}{
			"admission_id":  result.Admission.ID,
			"assessment_no": result.Admission.AssessmentNo,
			"elder_id":      elderID,
			"care_plan_id":  carePlanID,
		})
	}
	return result, nil
}

func (s *AdmissionService) currentTemplate(db *gorm.DB) (*model.AssessmentTemplate, error) {
	var template model.AssessmentTemplate
	err := db.Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Where("code = ? AND enabled = ?", currentAdmissionTemplateCode, true).
		Order("sort_order asc, id desc").First(&template).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: active template missing", ErrAdmissionValidation)
	}
	return &template, err
}

func (s *AdmissionService) templateByID(db *gorm.DB, id uint) (*model.AssessmentTemplate, error) {
	var template model.AssessmentTemplate
	err := db.Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
		First(&template, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: template missing", ErrAdmissionValidation)
	}
	return &template, err
}

func (s *AdmissionService) getAdmission(db *gorm.DB, id uint) (*model.AdmissionAssessment, error) {
	var admission model.AdmissionAssessment
	err := db.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).
		Preload("Screenings", func(q *gorm.DB) *gorm.DB { return q.Order("updated_at desc, id desc") }).
		Preload("Screenings.Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).
		First(&admission, id).Error
	if err != nil {
		return nil, mapAdmissionNotFound(err)
	}
	return &admission, nil
}

func (s *AdmissionService) replaceAnswers(tx *gorm.DB, admission *model.AdmissionAssessment, template *model.AssessmentTemplate, input []AdmissionAnswerInput) error {
	answers, err := buildAnswers(template, admission.ID, input)
	if err != nil {
		return err
	}
	if err := tx.Unscoped().Where("admission_id = ?", admission.ID).Delete(&model.AdmissionAssessmentAnswer{}).Error; err != nil {
		return err
	}
	if len(answers) == 0 {
		return nil
	}
	return tx.Create(&answers).Error
}

func buildAnswers(template *model.AssessmentTemplate, admissionID uint, input []AdmissionAnswerInput) ([]model.AdmissionAssessmentAnswer, error) {
	questionByID := make(map[uint]model.AssessmentQuestion, len(template.Questions))
	for _, question := range template.Questions {
		questionByID[question.ID] = question
	}
	seen := make(map[uint]bool, len(input))
	answers := make([]model.AdmissionAssessmentAnswer, 0, len(input))
	for _, item := range input {
		question, ok := questionByID[item.QuestionID]
		if !ok {
			return nil, fmt.Errorf("%w: question_id %d is not in template", ErrAdmissionValidation, item.QuestionID)
		}
		if seen[item.QuestionID] {
			return nil, fmt.Errorf("%w: duplicate question_id %d", ErrAdmissionValidation, item.QuestionID)
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
			return nil, fmt.Errorf("%w: option_id %d does not belong to question_id %d", ErrAdmissionValidation, item.OptionID, item.QuestionID)
		}
		optionID := selected.ID
		answers = append(answers, model.AdmissionAssessmentAnswer{
			AdmissionID: admissionID, QuestionID: question.ID, OptionID: &optionID,
			QuestionCode: question.Code, OptionCode: selected.Code, AnswerText: item.AnswerText, Score: selected.Score,
		})
	}
	return answers, nil
}

func (s *AdmissionService) preview(db *gorm.DB, admission *model.AdmissionAssessment, template *model.AssessmentTemplate, answers []model.AdmissionAssessmentAnswer) (*AdmissionPreview, error) {
	preview, err := calculateAbilityResult(template, admission, answers)
	if err != nil {
		return nil, err
	}
	var plan model.AdmissionCarePlanTemplate
	err = db.Where("template_id = ? AND target_level = ? AND enabled = ?", template.ID, preview.FinalLevel, true).
		Order("sort_order asc, id asc").First(&plan).Error
	if err == nil {
		preview.SuggestedCarePlan = &plan
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	return preview, nil
}

func calculateAbilityResult(template *model.AssessmentTemplate, admission *model.AdmissionAssessment, answers []model.AdmissionAssessmentAnswer) (*AdmissionPreview, error) {
	questionByID := make(map[uint]model.AssessmentQuestion, len(template.Questions))
	groupMax := map[string]int{}
	groupLabels := map[string]string{}
	groupOrder := []string{}
	required := 0
	for _, question := range template.Questions {
		questionByID[question.ID] = question
		if question.Required {
			required++
		}
		if _, exists := groupMax[question.GroupCode]; !exists {
			groupOrder = append(groupOrder, question.GroupCode)
		}
		groupMax[question.GroupCode] += question.MaxScore
		groupLabels[question.GroupCode] = question.GroupName
	}
	seen := map[uint]bool{}
	groupScores := map[string]int{}
	score := 0
	hasComaAnswer := false
	for _, answer := range answers {
		question, ok := questionByID[answer.QuestionID]
		if !ok || seen[answer.QuestionID] {
			return nil, fmt.Errorf("%w: saved answers do not match template", ErrAdmissionValidation)
		}
		if answer.OptionID == nil {
			return nil, fmt.Errorf("%w: saved answer has no server option", ErrAdmissionValidation)
		}
		var selected *model.AssessmentOption
		for i := range question.Options {
			if question.Options[i].ID == *answer.OptionID {
				selected = &question.Options[i]
				break
			}
		}
		if selected == nil {
			return nil, fmt.Errorf("%w: saved option does not belong to template question", ErrAdmissionValidation)
		}
		seen[answer.QuestionID] = true
		// The template option is authoritative. Stored/client snapshot scores are never trusted.
		score += selected.Score
		groupScores[question.GroupCode] += selected.Score
		if question.Code == "B3.9" && selected.Code == "coma" {
			hasComaAnswer = true
		}
	}
	if score < 0 || score > template.MaxScore {
		return nil, fmt.Errorf("%w: score outside template range", ErrAdmissionValidation)
	}
	initial, ok := ruleForScore(template.LevelRules, score)
	if !ok {
		return nil, fmt.Errorf("%w: no level rule for score %d", ErrAdmissionValidation, score)
	}
	final := initial
	reasons := []string{}
	if admission.Coma || hasComaAnswer || containsString(admission.HealthIssues, "coma") || containsString(admission.HealthIssues, "coma_status:present") {
		if complete, found := levelRuleByCode(template.LevelRules, "complete"); found {
			final = complete
		}
		reasons = append(reasons, "昏迷：直接评定为能力完全丧失（完全失能）")
	} else {
		mentalAdjustment := admission.DementiaOrMentalDisorder || diagnosesContainMentalDisorder(admission.Diagnoses)
		riskAdjustment := totalRiskEvents(admission.RiskEvents) >= 2
		if mentalAdjustment {
			reasons = append(reasons, "确诊痴呆F00-F03或其他精神和行为障碍F04-F99：加重一级")
		}
		if riskAdjustment {
			reasons = append(reasons, "近30天照护风险事件合计达到2次及以上：加重一级")
		}
		if mentalAdjustment || riskAdjustment {
			final = worsenLevel(template.LevelRules, initial)
		}
	}
	groups := make([]AdmissionGroupScore, 0, len(groupOrder))
	for _, code := range groupOrder {
		groups = append(groups, AdmissionGroupScore{Code: code, Label: groupLabels[code], Score: groupScores[code], MaxScore: groupMax[code]})
	}
	return &AdmissionPreview{
		AbilityScore: score, AnsweredCount: len(seen), RequiredCount: required, Complete: len(seen) == required,
		InitialLevel: initial.Code, InitialLevelLabel: initial.Label, FinalLevel: final.Code, FinalLevelLabel: final.Label,
		LevelChangeReasons: reasons, GroupScores: groups,
	}, nil
}

func validateAdmissionForSubmit(admission *model.AdmissionAssessment, preview *AdmissionPreview) error {
	if !preview.Complete {
		return fmt.Errorf("%w: answered %d of %d required questions", ErrAdmissionIncomplete, preview.AnsweredCount, preview.RequiredCount)
	}
	missing := []string{}
	for field, value := range map[string]string{
		"assessment_reason": admission.AssessmentReason, "baseline_date": admission.BaselineDate,
		"resident_name": admission.ResidentName, "gender": admission.Gender, "birth_date": admission.BirthDate,
		"id_card": admission.IDCard, "info_provider_name": admission.InfoProviderName,
		"info_provider_relation": admission.InfoProviderRelation, "contact_name": admission.ContactName,
		"contact_phone": admission.ContactPhone, "assessment_location": admission.AssessmentLocation,
	} {
		if strings.TrimSpace(value) == "" {
			missing = append(missing, field)
		}
	}
	if admission.HeightCM <= 0 {
		missing = append(missing, "height_cm")
	}
	if admission.WeightKG <= 0 {
		missing = append(missing, "weight_kg")
	}
	if admission.TargetBedID == nil || *admission.TargetBedID == 0 {
		missing = append(missing, "target_bed_id")
	}
	if !admission.DoctorConfirmed {
		missing = append(missing, "doctor_confirmed")
	}
	if !admission.PlanConsentConfirmed {
		missing = append(missing, "plan_consent_confirmed")
	}
	if !admission.ServiceFeeInformed {
		missing = append(missing, "service_fee_informed")
	}
	if !admission.InfoProviderSigned {
		missing = append(missing, "info_provider_signed")
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return fmt.Errorf("%w: missing %s", ErrAdmissionValidation, strings.Join(missing, ", "))
	}
	if _, err := time.Parse("2006-01-02", admission.BaselineDate); err != nil {
		return fmt.Errorf("%w: baseline_date must be YYYY-MM-DD", ErrAdmissionValidation)
	}
	if _, err := time.Parse("2006-01-02", admission.BirthDate); err != nil {
		return fmt.Errorf("%w: birth_date must be YYYY-MM-DD", ErrAdmissionValidation)
	}
	return validateRiskEvents(admission.RiskEvents)
}

func validateRiskEvents(events []model.AdmissionRiskEvent) error {
	allowed := map[string]bool{"fall": true, "wander": true, "choke": true, "suicide_self_harm": true, "other": true}
	seen := map[string]bool{}
	for _, event := range events {
		if !allowed[event.Code] {
			return fmt.Errorf("%w: invalid risk event %q", ErrAdmissionValidation, event.Code)
		}
		if seen[event.Code] {
			return fmt.Errorf("%w: duplicate risk event %q", ErrAdmissionValidation, event.Code)
		}
		if event.Count < 0 {
			return fmt.Errorf("%w: negative risk event count", ErrAdmissionValidation)
		}
		seen[event.Code] = true
	}
	return nil
}

func (s *AdmissionService) selectPlanTemplate(tx *gorm.DB, admission *model.AdmissionAssessment, finalLevel string) (*model.AdmissionCarePlanTemplate, error) {
	q := tx.Where("template_id = ? AND target_level = ? AND enabled = ?", admission.TemplateID, finalLevel, true)
	if admission.SelectedCarePlanCode != "" {
		q = q.Where("code = ?", admission.SelectedCarePlanCode)
	}
	var plan model.AdmissionCarePlanTemplate
	err := q.Order("sort_order asc, id asc").First(&plan).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("%w: selected care plan does not match final level", ErrAdmissionValidation)
	}
	return &plan, err
}

func (s *AdmissionService) createOrLinkElder(tx *gorm.DB, admission *model.AdmissionAssessment, careLevel int8) (*model.Elder, error) {
	identity := strings.TrimSpace(admission.IDCard)
	contacts := []model.ElderContact{{
		Name: admission.ContactName, Relation: admission.InfoProviderRelation, Phone: admission.ContactPhone, IsEmergency: true,
	}}
	if admission.ElderID != nil && *admission.ElderID > 0 {
		var elder model.Elder
		if err := tx.First(&elder, *admission.ElderID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, fmt.Errorf("%w: linked elder not found", ErrAdmissionValidation)
			}
			return nil, err
		}
		if elder.Status == 2 || elder.BedID != nil {
			return nil, fmt.Errorf("%w: linked elder is already admitted", ErrAdmissionElderConflict)
		}
		if err := ensureAdmissionIdentityAvailable(tx, identity, elder.ID); err != nil {
			return nil, err
		}
		updated := model.Elder{
			Name: admission.ResidentName, IDCard: identity, Gender: admission.Gender,
			BirthDate: admission.BirthDate, ContactPhone: admission.ContactPhone,
			CareLevel: careLevel, EmergencyContacts: contacts, Remark: strings.Join(admission.Diagnoses, "；"),
		}
		if err := tx.Model(&elder).Select(
			"Name", "IDCard", "Gender", "BirthDate", "ContactPhone", "CareLevel", "EmergencyContacts", "Remark",
		).Updates(&updated).Error; err != nil {
			if isElderIdentityConstraintError(err) {
				return nil, fmt.Errorf("%w: id_card already exists", ErrAdmissionElderConflict)
			}
			return nil, err
		}
		return &elder, nil
	}
	if err := ensureAdmissionIdentityAvailable(tx, identity, 0); err != nil {
		return nil, err
	}
	elder := model.Elder{
		Name: admission.ResidentName, IDCard: identity, Gender: admission.Gender,
		BirthDate: admission.BirthDate, ContactPhone: admission.ContactPhone, CareLevel: careLevel,
		Status: 1, EmergencyContacts: contacts, Allergies: []string{}, Remark: strings.Join(admission.Diagnoses, "；"),
	}
	if err := tx.Create(&elder).Error; err != nil {
		if isElderIdentityConstraintError(err) {
			return nil, fmt.Errorf("%w: id_card already exists", ErrAdmissionElderConflict)
		}
		return nil, err
	}
	return &elder, nil
}

func ensureAdmissionIdentityAvailable(tx *gorm.DB, idCard string, excludeElderID uint) error {
	if idCard == "" {
		return nil
	}
	q := tx.Model(&model.Elder{}).Where("id_card = ?", idCard)
	if excludeElderID > 0 {
		q = q.Where("id <> ?", excludeElderID)
	}
	var count int64
	if err := q.Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("%w: id_card already exists; link the existing elder explicitly", ErrAdmissionElderConflict)
	}
	return nil
}

func isElderIdentityConstraintError(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "uk_elders_tenant_id_card") ||
		strings.Contains(message, "uk_elders_tenant_active_id_card") ||
		(strings.Contains(message, "unique constraint") && strings.Contains(message, "elders")) ||
		(strings.Contains(message, "duplicate entry") && strings.Contains(message, "id_card"))
}

func occupyAdmissionBed(tx *gorm.DB, bedID *uint, elderID uint) (*model.Bed, error) {
	if bedID == nil || *bedID == 0 {
		return nil, fmt.Errorf("%w: target bed is required", ErrAdmissionValidation)
	}
	var bed model.Bed
	if err := tx.First(&bed, *bedID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("%w: bed not found", ErrAdmissionBedConflict)
		}
		return nil, err
	}
	updated := tx.Model(&model.Bed{}).Where("id = ? AND status = ? AND elder_id IS NULL", bed.ID, "free").
		Updates(map[string]interface{}{"status": "occupied", "elder_id": elderID})
	if updated.Error != nil {
		return nil, updated.Error
	}
	if updated.RowsAffected != 1 {
		return nil, ErrAdmissionBedConflict
	}
	bed.Status = "occupied"
	bed.ElderID = &elderID
	return &bed, nil
}

func createCarePlanFromTemplate(tx *gorm.DB, elderID, actorID uint, caregiverID *uint, caregiverName string, template *model.AdmissionCarePlanTemplate, optionalCodes []string, now time.Time) (*model.CarePlan, error) {
	selected := make(map[string]bool, len(optionalCodes))
	for _, code := range optionalCodes {
		selected[code] = true
	}
	services := append([]model.AdmissionCareService{}, template.BaseServices...)
	for _, optional := range template.OptionalServices {
		if selected[optional.Code] {
			services = append(services, optional)
			delete(selected, optional.Code)
		}
	}
	if len(selected) > 0 {
		return nil, fmt.Errorf("%w: unknown optional care service", ErrAdmissionValidation)
	}
	plan := model.CarePlan{
		ElderID: elderID, Name: template.Name, Status: "active", StartDate: now.Format("2006-01-02"), CreatedBy: actorID,
	}
	if err := tx.Create(&plan).Error; err != nil {
		return nil, err
	}
	items := make([]model.CarePlanItem, 0, len(services))
	for _, service := range services {
		dueAt := now
		items = append(items, model.CarePlanItem{
			CarePlanID: plan.ID, Title: service.Title, Kind: service.Kind, Frequency: service.Frequency,
			DueAt: &dueAt, AssigneeID: caregiverID, Assignee: caregiverName, RiskLevel: service.RiskLevel, Instructions: service.Instructions, Active: true,
		})
	}
	if len(items) > 0 {
		if err := tx.Create(&items).Error; err != nil {
			return nil, err
		}
	}
	plan.Items = items
	return &plan, nil
}

func createAdmissionTasks(tx *gorm.DB, elderID uint, caregiverID *uint, caregiverName string, items []model.CarePlanItem) error {
	tasks := make([]model.CareTask, 0, len(items))
	for i := range items {
		itemID := items[i].ID
		dueAt := time.Now()
		if items[i].DueAt != nil {
			dueAt = *items[i].DueAt
		}
		remark := strings.TrimSpace(items[i].Instructions)
		if items[i].Frequency != "" {
			if remark != "" {
				remark = items[i].Frequency + "；" + remark
			} else {
				remark = items[i].Frequency
			}
		}
		tasks = append(tasks, model.CareTask{
			ElderID: elderID, PlanItemID: &itemID, Title: items[i].Title, Kind: items[i].Kind,
			Category: normalizeTaskCategory("", items[i].Kind), Priority: normalizeTaskPriority("", items[i].RiskLevel),
			AssigneeID: caregiverID, DueAt: &dueAt, Assignee: caregiverName, Status: "todo", Remark: truncateRunes(remark, 500),
		})
	}
	if len(tasks) == 0 {
		return nil
	}
	return tx.Create(&tasks).Error
}

func createAdmissionScreeningAssessments(tx *gorm.DB, admissionID, elderID uint, fallbackTime time.Time) error {
	var screenings []model.AdmissionScreening
	if err := tx.Preload("Answers", func(q *gorm.DB) *gorm.DB { return q.Order("question_id asc, id asc") }).
		Where("admission_id = ? AND status = ?", admissionID, "completed").
		Order("id asc").Find(&screenings).Error; err != nil {
		return err
	}
	for _, screening := range screenings {
		var template model.AssessmentTemplate
		if err := tx.Preload("Questions", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
			Preload("Questions.Options", func(q *gorm.DB) *gorm.DB { return q.Order("sort_order asc, id asc") }).
			Where("id = ? AND category = ?", screening.TemplateID, "admission_screening").First(&template).Error; err != nil {
			return err
		}
		calculated, err := calculateAdmissionScreening(&template, screening.Answers, screening.EducationYears, true)
		if err != nil {
			return err
		}
		if !calculated.complete {
			return fmt.Errorf("%w: completed screening %s is incomplete", ErrAdmissionIncomplete, template.Code)
		}
		if err := tx.Model(&screening).Updates(map[string]interface{}{
			"raw_score": calculated.rawScore, "adjusted_score": calculated.adjustedScore,
			"result_code": calculated.resultCode, "result_label": calculated.resultLabel,
		}).Error; err != nil {
			return err
		}
		var assessmentScore *float64
		if template.Code != "SLEEP5" {
			score := float64(calculated.adjustedScore)
			assessmentScore = &score
		}
		assessedAt := fallbackTime
		if screening.CompletedAt != nil {
			assessedAt = *screening.CompletedAt
		}
		notes := calculated.resultLabel
		if template.Code != "SLEEP5" {
			notes = fmt.Sprintf("%s；原始分%d；校正分%d", calculated.resultLabel, calculated.rawScore, calculated.adjustedScore)
		}
		if strings.TrimSpace(screening.Notes) != "" {
			notes += "；" + strings.TrimSpace(screening.Notes)
		}
		assessment := model.Assessment{
			ElderID: elderID, AssessorID: screening.AssessorID,
			AssessmentType: "admission_screening:" + template.Code,
			Score:          assessmentScore, RiskLevel: truncateRunes(calculated.resultCode, 16),
			Notes: truncateRunes(notes, 1024), AssessedAt: assessedAt,
		}
		if err := tx.Create(&assessment).Error; err != nil {
			return err
		}
	}
	return nil
}

func firstAvailableCaregiver(tx *gorm.DB) (*model.User, error) {
	var role model.Role
	if err := tx.Where("code = ?", "caregiver").First(&role).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	var userIDs []uint
	if err := tx.Table("sys_user_role").Where("role_id = ?", role.ID).Pluck("user_id", &userIDs).Error; err != nil {
		return nil, err
	}
	if len(userIDs) == 0 {
		return nil, nil
	}
	var caregiver model.User
	if err := tx.Where("id IN ? AND status = ?", userIDs, 1).Order("id asc").First(&caregiver).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &caregiver, nil
}

func bindMatchingFamilyUsers(tx *gorm.DB, elderID uint, contactPhone string) ([]uint, error) {
	phone := strings.TrimSpace(contactPhone)
	if phone == "" {
		return nil, nil
	}
	var role model.Role
	if err := tx.Where("code = ?", "family").First(&role).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	var roleUserIDs []uint
	if err := tx.Table("sys_user_role").Where("role_id = ?", role.ID).Pluck("user_id", &roleUserIDs).Error; err != nil {
		return nil, err
	}
	if len(roleUserIDs) == 0 {
		return nil, nil
	}
	var users []model.User
	if err := tx.Where("id IN ? AND phone = ? AND status = ?", roleUserIDs, phone, 1).Order("id asc").Find(&users).Error; err != nil {
		return nil, err
	}
	userIDs := make([]uint, 0, len(users))
	for _, user := range users {
		binding := model.FamilyElder{UserID: user.ID, ElderID: elderID}
		if err := tx.Where("user_id = ? AND elder_id = ?", user.ID, elderID).FirstOrCreate(&binding).Error; err != nil {
			return nil, err
		}
		userIDs = append(userIDs, user.ID)
	}
	return userIDs, nil
}

func truncateRunes(value string, max int) string {
	runes := []rune(value)
	if len(runes) <= max {
		return value
	}
	return string(runes[:max])
}

func (input AdmissionDraftInput) toModel() model.AdmissionAssessment {
	return model.AdmissionAssessment{
		ElderID: input.ElderID, CurrentStep: input.CurrentStep, AssessmentReason: input.AssessmentReason,
		BaselineDate: input.BaselineDate, ResidentName: input.ResidentName, Gender: input.Gender,
		BirthDate: input.BirthDate, IDCard: input.IDCard, HeightCM: input.HeightCM, WeightKG: input.WeightKG,
		Ethnicity: input.Ethnicity, Religion: input.Religion, Education: input.Education,
		LivingSituations: input.LivingSituations, MaritalStatus: input.MaritalStatus,
		MedicalPayments: input.MedicalPayments, IncomeSources: input.IncomeSources,
		RiskEvents: input.RiskEvents, Diagnoses: input.Diagnoses,
		DementiaOrMentalDisorder: input.DementiaOrMentalDisorder, Medications: input.Medications,
		HealthIssues: input.HealthIssues, Coma: input.Coma, InfoProviderName: input.InfoProviderName,
		InfoProviderRelation: input.InfoProviderRelation, ContactName: input.ContactName,
		ContactPhone: input.ContactPhone, TargetBedID: input.TargetBedID,
		SelectedCarePlanCode: input.SelectedCarePlanCode, SelectedOptionalServices: input.SelectedOptionalServices,
		AssessmentLocation: input.AssessmentLocation, DoctorConfirmed: input.DoctorConfirmed,
		PlanConsentConfirmed: input.PlanConsentConfirmed, ServiceFeeInformed: input.ServiceFeeInformed,
		InfoProviderSigned: input.InfoProviderSigned,
	}
}

func authorizeAdmissionMutation(admission *model.AdmissionAssessment, actor AdmissionActor) error {
	if actor.UserID == 0 || (admission.AssessorID != actor.UserID && !actor.IsAdmin) {
		return ErrAdmissionForbidden
	}
	return nil
}

func mapAdmissionNotFound(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrAdmissionNotFound
	}
	return err
}

func newAssessmentNo() string {
	b := make([]byte, 4)
	if _, err := rand.Read(b); err == nil {
		return fmt.Sprintf("ADM-%s-%s", time.Now().Format("20060102"), strings.ToUpper(hex.EncodeToString(b)))
	}
	return fmt.Sprintf("ADM-%s-%d", time.Now().Format("20060102"), time.Now().UnixNano())
}

func ruleForScore(rules []model.AbilityLevelRule, score int) (model.AbilityLevelRule, bool) {
	for _, rule := range rules {
		if score >= rule.MinScore && score <= rule.MaxScore {
			return rule, true
		}
	}
	return model.AbilityLevelRule{}, false
}

func levelRuleByCode(rules []model.AbilityLevelRule, code string) (model.AbilityLevelRule, bool) {
	for _, rule := range rules {
		if rule.Code == code {
			return rule, true
		}
	}
	return model.AbilityLevelRule{}, false
}

func worsenLevel(rules []model.AbilityLevelRule, current model.AbilityLevelRule) model.AbilityLevelRule {
	targetCareLevel := current.CareLevel + 1
	for _, rule := range rules {
		if rule.CareLevel == targetCareLevel {
			return rule
		}
	}
	return current
}

func diagnosesContainMentalDisorder(diagnoses []string) bool {
	for _, diagnosis := range diagnoses {
		value := strings.ToUpper(strings.TrimSpace(diagnosis))
		if !strings.HasPrefix(value, "F") || len(value) < 3 {
			continue
		}
		code, err := strconv.Atoi(value[1:3])
		if err == nil && code >= 0 && code <= 99 {
			return true
		}
	}
	return false
}

func totalRiskEvents(events []model.AdmissionRiskEvent) int {
	total := 0
	for _, event := range events {
		if event.Count > 0 {
			total += event.Count
		}
	}
	return total
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if strings.EqualFold(strings.TrimSpace(value), expected) {
			return true
		}
	}
	return false
}
