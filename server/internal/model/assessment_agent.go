package model

import "time"

// AssessmentAgentQuestion is the JSON-compatible question contract shared
// with the AsLive assessment runtime. The question bank remains editable as
// one versioned JSON document, while sessions snapshot it for auditability.
type AssessmentAgentQuestion struct {
	ID       string `json:"id"`
	Topic    string `json:"topic"`
	Question string `json:"question"`
}

// AssessmentAgentQuestionBank is the tenant-owned active voice-assessment
// questionnaire configured from the administrator AI workspace.
type AssessmentAgentQuestionBank struct {
	Base
	Title           string                    `gorm:"size:128;not null" json:"title"`
	Version         int                       `gorm:"not null;default:1" json:"version"`
	NoAnswerTimeout int                       `gorm:"not null;default:15" json:"no_answer_timeout"`
	Questions       []AssessmentAgentQuestion `gorm:"serializer:json" json:"questions"`
	Enabled         bool                      `gorm:"not null;default:true" json:"enabled"`
	UpdatedBy       uint                      `gorm:"index" json:"updated_by"`
}

// AssessmentAgentAnswer is a persisted, immutable answer captured from the
// external runtime. It is kept separately from the generated report so the
// institution can audit exactly what was asked and recognized.
type AssessmentAgentAnswer struct {
	QuestionID string `json:"id"`
	Topic      string `json:"topic"`
	Question   string `json:"question"`
	Answer     string `json:"answer"`
	Skipped    bool   `json:"skipped"`
	NoResponse bool   `json:"no_response,omitempty"`
}

// AssessmentAgentSession binds one isolated AsLive exchange to an admitted
// elder. The external runtime never owns institutional identity or records.
type AssessmentAgentSession struct {
	Base
	SessionKey                      string                    `gorm:"size:64;uniqueIndex;not null" json:"session_key"`
	IntakeID                        uint                      `gorm:"uniqueIndex;not null" json:"intake_id"`
	ElderID                         uint                      `gorm:"index;not null" json:"elder_id"`
	AssessorID                      uint                      `gorm:"index;not null" json:"assessor_id"`
	QuestionBankID                  uint                      `gorm:"index;not null" json:"question_bank_id"`
	QuestionVersion                 int                       `gorm:"not null" json:"question_version"`
	Title                           string                    `gorm:"size:128;not null" json:"title"`
	ResidentName                    string                    `gorm:"size:64;not null" json:"resident_name"`
	Gender                          string                    `gorm:"size:4" json:"gender"`
	Address                         string                    `gorm:"size:16" json:"address"`
	NoAnswerTimeout                 int                       `gorm:"not null" json:"no_answer_timeout"`
	QuestionSnapshot                []AssessmentAgentQuestion `gorm:"serializer:json" json:"questions"`
	Answers                         []AssessmentAgentAnswer   `gorm:"serializer:json" json:"answers"`
	Status                          string                    `gorm:"size:16;index;not null;default:pending" json:"status"`
	CurrentIndex                    int                       `gorm:"not null;default:0" json:"current_index"`
	ExternalRecordID                string                    `gorm:"size:128" json:"external_record_id"`
	ReportMarkdown                  string                    `gorm:"type:text" json:"report"`
	AssessmentID                    *uint                     `gorm:"index" json:"assessment_id,omitempty"`
	StartedAt                       *time.Time                `json:"started_at,omitempty"`
	CompletedAt                     *time.Time                `json:"completed_at,omitempty"`
	PackageRecommendationStatus     string                    `gorm:"size:16;index" json:"package_recommendation_status,omitempty"`
	PackageRecommendationTemplateID *uint                     `gorm:"index" json:"package_recommendation_template_id,omitempty"`
	PackageRecommendationError      string                    `gorm:"size:512" json:"package_recommendation_error,omitempty"`
}
