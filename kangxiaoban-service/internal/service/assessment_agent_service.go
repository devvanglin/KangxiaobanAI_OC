package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"kangxiaoban-service/internal/model"
)

const (
	defaultAssessmentAgentTitle   = "老年人综合能力评估（问诊版）"
	defaultAssessmentAgentTimeout = 15
)

var (
	ErrAssessmentAgentNotFound     = errors.New("assessment agent resource not found")
	ErrAssessmentAgentForbidden    = errors.New("assessment agent forbidden")
	ErrAssessmentAgentValidation   = errors.New("assessment agent validation failed")
	ErrAssessmentAgentInvalidState = errors.New("assessment agent invalid state")
)

type AssessmentAgentQuestionBankInput struct {
	Title           string                          `json:"title"`
	NoAnswerTimeout int                             `json:"no_answer_timeout"`
	Questions       []model.AssessmentAgentQuestion `json:"questions"`
}

type AssessmentAgentCompletion struct {
	ExternalRecordID string                        `json:"record_id"`
	Report           string                        `json:"report"`
	Answers          []model.AssessmentAgentAnswer `json:"records"`
	Answered         int                           `json:"answered"`
	Total            int                           `json:"total"`
}

type AssessmentAgentService struct{ db *gorm.DB }

func NewAssessmentAgentService(db *gorm.DB) *AssessmentAgentService {
	return &AssessmentAgentService{db: db}
}

func defaultAssessmentAgentQuestions() []model.AssessmentAgentQuestion {
	return []model.AssessmentAgentQuestion{
		{ID: "sleep", Topic: "睡眠", Question: "您最近睡得怎么样？入睡难不难，夜里会不会经常醒？"},
		{ID: "adl", Topic: "日常生活能力", Question: "平时吃饭、穿衣、洗澡、上厕所这些事，您都能自己完成吗？有没有需要别人帮忙的？"},
		{ID: "memory", Topic: "记忆与认知", Question: "您最近记性怎么样？有没有出现过忘记重要事情，或者出门找不到回家的路的情况？"},
		{ID: "mood", Topic: "情绪状态", Question: "最近心情怎么样？有没有经常觉得闷闷不乐、提不起兴趣，或者晚上睡不好老是想事情？"},
		{ID: "fall", Topic: "跌倒风险", Question: "最近半年有没有摔倒过？平时走路稳不稳，需不需要拐杖或者有人扶着？"},
		{ID: "chronic", Topic: "慢病与用药", Question: "有没有高血压、糖尿病、心脏病这些慢性病？平时都在吃哪些药，规律吗？"},
		{ID: "sensory", Topic: "视听感官", Question: "眼睛看东西清楚吗？别人跟您说话，听得清吗？有没有戴眼镜或助听器？"},
		{ID: "elimination", Topic: "二便情况", Question: "小便和大便还正常吗？有没有尿频、便秘或者控制不住的情况？"},
		{ID: "social", Topic: "社会支持", Question: "平时谁来照顾您、陪您说话？多久能见一次家人或老朋友？"},
		{ID: "appetite", Topic: "饮食营养", Question: "最近胃口怎么样？体重有没有明显变轻？平时一天吃几顿，吃得多吗？"},
	}
}

func validateAssessmentAgentQuestionBank(input *AssessmentAgentQuestionBankInput) error {
	input.Title = strings.TrimSpace(input.Title)
	if input.Title == "" || utf8.RuneCountInString(input.Title) > 128 {
		return fmt.Errorf("%w: title is required and must not exceed 128 characters", ErrAssessmentAgentValidation)
	}
	if input.NoAnswerTimeout < 10 || input.NoAnswerTimeout > 120 {
		return fmt.Errorf("%w: no_answer_timeout must be between 10 and 120", ErrAssessmentAgentValidation)
	}
	if len(input.Questions) == 0 || len(input.Questions) > 50 {
		return fmt.Errorf("%w: questions must contain 1 to 50 items", ErrAssessmentAgentValidation)
	}
	seen := make(map[string]struct{}, len(input.Questions))
	for i := range input.Questions {
		q := &input.Questions[i]
		q.ID = strings.TrimSpace(q.ID)
		q.Topic = strings.TrimSpace(q.Topic)
		q.Question = strings.TrimSpace(q.Question)
		if q.ID == "" || q.Topic == "" || q.Question == "" {
			return fmt.Errorf("%w: every question requires id, topic and question", ErrAssessmentAgentValidation)
		}
		if utf8.RuneCountInString(q.ID) > 64 || utf8.RuneCountInString(q.Topic) > 64 || utf8.RuneCountInString(q.Question) > 512 {
			return fmt.Errorf("%w: question field is too long", ErrAssessmentAgentValidation)
		}
		if _, exists := seen[q.ID]; exists {
			return fmt.Errorf("%w: duplicate question id %q", ErrAssessmentAgentValidation, q.ID)
		}
		seen[q.ID] = struct{}{}
	}
	return nil
}

func (s *AssessmentAgentService) CurrentQuestionBank(ctx context.Context) (*model.AssessmentAgentQuestionBank, error) {
	var bank model.AssessmentAgentQuestionBank
	err := s.db.WithContext(ctx).Where("enabled = ?", true).Order("version DESC, id DESC").First(&bank).Error
	if err == nil {
		return &bank, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	bank = model.AssessmentAgentQuestionBank{
		Title: defaultAssessmentAgentTitle, Version: 1, NoAnswerTimeout: defaultAssessmentAgentTimeout,
		Questions: defaultAssessmentAgentQuestions(), Enabled: true,
	}
	if err := s.db.WithContext(ctx).Create(&bank).Error; err != nil {
		// A concurrent first request may have created it. Reload instead of
		// returning a spurious failure.
		if loadErr := s.db.WithContext(ctx).Where("enabled = ?", true).Order("version DESC, id DESC").First(&bank).Error; loadErr != nil {
			return nil, err
		}
	}
	return &bank, nil
}

func (s *AssessmentAgentService) UpdateQuestionBank(ctx context.Context, actorID uint, input AssessmentAgentQuestionBankInput) (*model.AssessmentAgentQuestionBank, error) {
	if actorID == 0 {
		return nil, ErrAssessmentAgentForbidden
	}
	if err := validateAssessmentAgentQuestionBank(&input); err != nil {
		return nil, err
	}
	var saved model.AssessmentAgentQuestionBank
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var current model.AssessmentAgentQuestionBank
		err := tx.Where("enabled = ?", true).Order("version DESC, id DESC").First(&current).Error
		version := 1
		if err == nil {
			version = current.Version + 1
			if updateErr := tx.Model(&model.AssessmentAgentQuestionBank{}).Where("enabled = ?", true).Update("enabled", false).Error; updateErr != nil {
				return updateErr
			}
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		saved = model.AssessmentAgentQuestionBank{
			Title: input.Title, Version: version, NoAnswerTimeout: input.NoAnswerTimeout,
			Questions: input.Questions, Enabled: true, UpdatedBy: actorID,
		}
		return tx.Create(&saved).Error
	})
	return &saved, err
}

func newAssessmentAgentSessionKey() (string, error) {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func assessmentAddress(gender string) string {
	if strings.EqualFold(strings.TrimSpace(gender), "F") || strings.TrimSpace(gender) == "女" {
		return "奶奶"
	}
	return "爷爷"
}

func (s *AssessmentAgentService) CreateSession(ctx context.Context, actorID, intakeID uint) (*model.AssessmentAgentSession, error) {
	if actorID == 0 {
		return nil, ErrAssessmentAgentForbidden
	}
	if intakeID == 0 {
		return nil, fmt.Errorf("%w: intake_id is required", ErrAssessmentAgentValidation)
	}
	var intake model.AdmissionIntake
	if err := s.db.WithContext(ctx).Where("id = ? AND status = ?", intakeID, "completed").First(&intake).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAssessmentAgentNotFound
		}
		return nil, err
	}
	var existing model.AssessmentAgentSession
	if err := s.db.WithContext(ctx).Where("intake_id = ?", intakeID).First(&existing).Error; err == nil {
		if existing.AssessorID != actorID {
			return nil, ErrAssessmentAgentForbidden
		}
		return &existing, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	bank, err := s.CurrentQuestionBank(ctx)
	if err != nil {
		return nil, err
	}
	key, err := newAssessmentAgentSessionKey()
	if err != nil {
		return nil, err
	}
	session := &model.AssessmentAgentSession{
		SessionKey: key, IntakeID: intake.ID, ElderID: intake.ElderID, AssessorID: actorID,
		QuestionBankID: bank.ID, QuestionVersion: bank.Version, Title: bank.Title,
		ResidentName: intake.ResidentNameSnapshot, Gender: intake.ResidentGenderSnapshot,
		Address: assessmentAddress(intake.ResidentGenderSnapshot), NoAnswerTimeout: bank.NoAnswerTimeout,
		QuestionSnapshot: append([]model.AssessmentAgentQuestion(nil), bank.Questions...),
		Answers:          []model.AssessmentAgentAnswer{}, Status: "pending",
	}
	if err := s.db.WithContext(ctx).Create(session).Error; err != nil {
		if loadErr := s.db.WithContext(ctx).Where("intake_id = ?", intakeID).First(&existing).Error; loadErr == nil {
			if existing.AssessorID != actorID {
				return nil, ErrAssessmentAgentForbidden
			}
			return &existing, nil
		}
		return nil, err
	}
	_ = s.db.WithContext(ctx).Create(&model.AuditLog{UserID: actorID, Action: "create", Module: "assessment_agent", Method: "POST", Path: "/api/v1/assessment-agent/sessions"}).Error
	return session, nil
}

func (s *AssessmentAgentService) GetSession(ctx context.Context, actorID uint, key string) (*model.AssessmentAgentSession, error) {
	if actorID == 0 {
		return nil, ErrAssessmentAgentForbidden
	}
	var session model.AssessmentAgentSession
	err := s.db.WithContext(ctx).Where("session_key = ? AND assessor_id = ?", strings.TrimSpace(key), actorID).First(&session).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAssessmentAgentNotFound
	}
	return &session, err
}

func (s *AssessmentAgentService) SessionForIntake(ctx context.Context, actorID, intakeID uint) (*model.AssessmentAgentSession, error) {
	if actorID == 0 || intakeID == 0 {
		return nil, ErrAssessmentAgentValidation
	}
	var session model.AssessmentAgentSession
	err := s.db.WithContext(ctx).Where("intake_id = ?", intakeID).First(&session).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAssessmentAgentNotFound
	}
	if err != nil {
		return nil, err
	}
	if session.AssessorID != actorID {
		return nil, ErrAssessmentAgentForbidden
	}
	return &session, nil
}

func (s *AssessmentAgentService) MarkStarted(ctx context.Context, actorID uint, key string) (*model.AssessmentAgentSession, error) {
	session, err := s.GetSession(ctx, actorID, key)
	if err != nil {
		return nil, err
	}
	if session.Status == "completed" || session.Status == "cancelled" {
		return nil, ErrAssessmentAgentInvalidState
	}
	if session.StartedAt == nil {
		now := time.Now()
		if err := s.db.WithContext(ctx).Model(&model.AssessmentAgentSession{}).Where("id = ?", session.ID).
			Updates(map[string]interface{}{"status": "active", "started_at": now}).Error; err != nil {
			return nil, err
		}
		session.Status = "active"
		session.StartedAt = &now
	}
	return session, nil
}

func (s *AssessmentAgentService) SaveProgress(ctx context.Context, actorID uint, key string, answer model.AssessmentAgentAnswer, index int) error {
	session, err := s.GetSession(ctx, actorID, key)
	if err != nil {
		return err
	}
	if session.Status == "completed" || session.Status == "cancelled" {
		return ErrAssessmentAgentInvalidState
	}
	answer.QuestionID = strings.TrimSpace(answer.QuestionID)
	answer.Topic = strings.TrimSpace(answer.Topic)
	answer.Question = strings.TrimSpace(answer.Question)
	answer.Answer = strings.TrimSpace(answer.Answer)
	if answer.QuestionID == "" || answer.Question == "" || index < 0 || index >= len(session.QuestionSnapshot) {
		return ErrAssessmentAgentValidation
	}
	if session.QuestionSnapshot[index].ID != answer.QuestionID {
		return ErrAssessmentAgentValidation
	}
	answers := append([]model.AssessmentAgentAnswer(nil), session.Answers...)
	if index < len(answers) {
		answers[index] = answer
	} else if index == len(answers) {
		answers = append(answers, answer)
	} else {
		return ErrAssessmentAgentValidation
	}
	updates := model.AssessmentAgentSession{Answers: answers, CurrentIndex: len(answers), Status: "active"}
	return s.db.WithContext(ctx).Model(&model.AssessmentAgentSession{}).Where("id = ?", session.ID).
		Select("Answers", "CurrentIndex", "Status").Updates(&updates).Error
}

func (s *AssessmentAgentService) CompleteSession(ctx context.Context, actorID uint, key string, completion AssessmentAgentCompletion) (*model.AssessmentAgentSession, error) {
	completion.ExternalRecordID = strings.TrimSpace(completion.ExternalRecordID)
	completion.Report = strings.TrimSpace(completion.Report)
	if completion.Report == "" {
		return nil, fmt.Errorf("%w: report is required", ErrAssessmentAgentValidation)
	}
	var completed model.AssessmentAgentSession
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("session_key = ? AND assessor_id = ?", key, actorID).First(&completed).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrAssessmentAgentNotFound
			}
			return err
		}
		if completed.Status == "completed" {
			return nil
		}
		if completed.Status == "cancelled" {
			return ErrAssessmentAgentInvalidState
		}
		now := time.Now()
		assessment := model.Assessment{
			ElderID: completed.ElderID, AssessorID: completed.AssessorID,
			AssessmentType: "comprehensive_agent", RiskLevel: "review_required",
			Notes:  fmt.Sprintf("AI 语音评估已完成：%d/%d 题，待医师复核。", len(completion.Answers), len(completed.QuestionSnapshot)),
			Source: "assessment_agent", AgentSessionID: &completed.ID, Report: completion.Report, AssessedAt: now,
		}
		if err := tx.Create(&assessment).Error; err != nil {
			return err
		}
		updates := model.AssessmentAgentSession{
			Status: "completed", ExternalRecordID: completion.ExternalRecordID,
			Answers: completion.Answers, CurrentIndex: len(completion.Answers),
			ReportMarkdown: completion.Report, AssessmentID: &assessment.ID, CompletedAt: &now,
		}
		if err := tx.Model(&model.AssessmentAgentSession{}).Where("id = ?", completed.ID).
			Select("Status", "ExternalRecordID", "Answers", "CurrentIndex", "ReportMarkdown", "AssessmentID", "CompletedAt").Updates(&updates).Error; err != nil {
			return err
		}
		if err := tx.Create(&model.AuditLog{UserID: actorID, Action: "complete", Module: "assessment_agent", Method: "WS", Path: "/api/v1/assessment-agent/sessions/:key/ws"}).Error; err != nil {
			return err
		}
		completed.Status = "completed"
		completed.ExternalRecordID = completion.ExternalRecordID
		completed.Answers = completion.Answers
		completed.CurrentIndex = len(completion.Answers)
		completed.ReportMarkdown = completion.Report
		completed.AssessmentID = &assessment.ID
		completed.CompletedAt = &now
		return nil
	})
	return &completed, err
}
