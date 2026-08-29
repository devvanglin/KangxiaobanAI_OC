package model

import "time"

// AbilityLevelRule is one persisted score band from appendix C.
type AbilityLevelRule struct {
	Code      string `json:"code"`
	Label     string `json:"label"`
	MinScore  int    `json:"min_score"`
	MaxScore  int    `json:"max_score"`
	CareLevel int8   `json:"care_level"`
	SortOrder int    `json:"sort_order"`
}

// AdmissionRuleCondition describes one database-configured predicate for an
// assessment adjustment. Conditions are intentionally data-only so the same
// interpreter can be used by the ability form and optional screenings.
type AdmissionRuleCondition struct {
	Type         string   `json:"type"`
	Field        string   `json:"field,omitempty"`
	QuestionCode string   `json:"question_code,omitempty"`
	MatchCodes   []string `json:"match_codes,omitempty"`
	RiskCodes    []string `json:"risk_codes,omitempty"`
	Operator     string   `json:"operator,omitempty"`
	Threshold    int      `json:"threshold,omitempty"`
}

// AdmissionAdjustmentRule describes a server-enforced, database-configured
// assessment adjustment. LevelDelta is capped by the interpreter to the
// strongest matching rule, while ScoreDelta values are accumulated.
type AdmissionAdjustmentRule struct {
	Code        string                   `json:"code"`
	Label       string                   `json:"label"`
	Description string                   `json:"description"`
	MatchMode   string                   `json:"match_mode,omitempty"`
	Conditions  []AdmissionRuleCondition `json:"conditions,omitempty"`
	TargetLevel string                   `json:"target_level,omitempty"`
	LevelDelta  int                      `json:"level_delta,omitempty"`
	ScoreDelta  int                      `json:"score_delta,omitempty"`
}

// AssessmentTemplate defines a versioned assessment form stored in the server database.
type AssessmentTemplate struct {
	Base
	Code            string                    `gorm:"size:64;index;not null" json:"code"`
	Name            string                    `gorm:"size:128;not null" json:"name"`
	Version         string                    `gorm:"size:32;index;not null" json:"version"`
	Description     string                    `gorm:"size:1024" json:"description"`
	Category        string                    `gorm:"size:32;index" json:"category"`
	MaxScore        int                       `json:"max_score"`
	Required        bool                      `gorm:"default:false" json:"required"`
	Enabled         bool                      `gorm:"default:true;index" json:"enabled"`
	SortOrder       int                       `gorm:"index" json:"sort_order"`
	LevelRules      []AbilityLevelRule        `gorm:"serializer:json" json:"level_rules"`
	AdjustmentRules []AdmissionAdjustmentRule `gorm:"serializer:json" json:"adjustment_rules"`
	ScoringNotes    []string                  `gorm:"serializer:json" json:"scoring_notes"`
	Questions       []AssessmentQuestion      `gorm:"foreignKey:TemplateID;constraint:OnDelete:CASCADE" json:"questions,omitempty"`
}

// AssessmentQuestion is one persisted question in an assessment template.
type AssessmentQuestion struct {
	Base
	TemplateID uint               `gorm:"index;not null" json:"template_id"`
	Code       string             `gorm:"size:32;index;not null" json:"code"`
	GroupCode  string             `gorm:"size:32;index" json:"group_code"`
	GroupName  string             `gorm:"size:128" json:"group_name"`
	Title      string             `gorm:"size:512;not null" json:"title"`
	Guidance   string             `gorm:"size:2048" json:"guidance"`
	AnswerType string             `gorm:"size:16;default:choice" json:"answer_type"`
	Required   bool               `gorm:"default:true" json:"required"`
	MaxScore   int                `json:"max_score"`
	SortOrder  int                `gorm:"index" json:"sort_order"`
	Options    []AssessmentOption `gorm:"foreignKey:QuestionID;constraint:OnDelete:CASCADE" json:"options,omitempty"`
}

// AssessmentOption is a server-owned answer and score. Clients never submit a trusted score.
type AssessmentOption struct {
	Base
	QuestionID uint   `gorm:"index;not null" json:"question_id"`
	Code       string `gorm:"size:32;not null" json:"code"`
	Label      string `gorm:"size:1024;not null" json:"label"`
	Score      int    `json:"score"`
	SortOrder  int    `gorm:"index" json:"sort_order"`
}

// AdmissionDictionaryItem stores server-managed choices used by appendix A.
type AdmissionDictionaryItem struct {
	Base
	TemplateID uint   `gorm:"index;not null" json:"template_id"`
	Category   string `gorm:"size:64;index;not null" json:"category"`
	Code       string `gorm:"size:64;not null" json:"code"`
	Label      string `gorm:"size:255;not null" json:"label"`
	SortOrder  int    `gorm:"index" json:"sort_order"`
	Enabled    bool   `gorm:"default:true" json:"enabled"`
}

// AdmissionCareService is one concrete item in a level-specific care package.
type AdmissionCareService struct {
	Code         string `json:"code"`
	Title        string `json:"title"`
	Kind         string `json:"kind"`
	Frequency    string `json:"frequency"`
	Instructions string `json:"instructions"`
	RiskLevel    string `json:"risk_level"`
}

// AdmissionCarePlanTemplate is a care package linked to a final ability level.
type AdmissionCarePlanTemplate struct {
	Base
	TemplateID       uint                   `gorm:"index;not null" json:"template_id"`
	Code             string                 `gorm:"size:64;index;not null" json:"code"`
	Name             string                 `gorm:"size:128;not null" json:"name"`
	TargetLevel      string                 `gorm:"size:32;index" json:"target_level"`
	Target           string                 `gorm:"size:512" json:"target"`
	BaseServices     []AdmissionCareService `gorm:"serializer:json" json:"base_services"`
	OptionalServices []AdmissionCareService `gorm:"serializer:json" json:"optional_services"`
	SortOrder        int                    `gorm:"index" json:"sort_order"`
	Enabled          bool                   `gorm:"default:true" json:"enabled"`
}

// AdmissionRiskEvent records the occurrence count in the 30 days before assessment.
type AdmissionRiskEvent struct {
	Code  string `json:"code"`
	Count int    `json:"count"`
}

// AdmissionMedication captures the medication reconciliation snapshot at admission.
type AdmissionMedication struct {
	Name      string `json:"name"`
	Method    string `json:"method"`
	Dose      string `json:"dose"`
	Frequency string `json:"frequency"`
}

// AdmissionAssessment is the server-side draft/submission for the complete admission workflow.
type AdmissionAssessment struct {
	Base
	AssessmentNo             string                      `gorm:"size:64;index;not null" json:"assessment_no"`
	ElderID                  *uint                       `gorm:"index" json:"elder_id"`
	AssessorID               uint                        `gorm:"index;not null" json:"assessor_id"`
	TemplateID               uint                        `gorm:"index;not null" json:"template_id"`
	TemplateCode             string                      `gorm:"size:64;not null" json:"template_code"`
	TemplateVersion          string                      `gorm:"size:32;not null" json:"template_version"`
	Status                   string                      `gorm:"size:16;default:draft;index" json:"status"`
	CurrentStep              int                         `gorm:"default:0" json:"current_step"`
	AssessmentReason         string                      `gorm:"size:32" json:"assessment_reason"`
	BaselineDate             string                      `gorm:"size:10" json:"baseline_date"`
	ResidentName             string                      `gorm:"size:64;not null" json:"resident_name"`
	Gender                   string                      `gorm:"size:4" json:"gender"`
	BirthDate                string                      `gorm:"size:10" json:"birth_date"`
	IDCard                   string                      `gorm:"size:28" json:"id_card"`
	HeightCM                 float64                     `json:"height_cm"`
	WeightKG                 float64                     `json:"weight_kg"`
	Ethnicity                string                      `gorm:"size:64" json:"ethnicity"`
	Religion                 string                      `gorm:"size:64" json:"religion"`
	Education                string                      `gorm:"size:32" json:"education"`
	LivingSituations         []string                    `gorm:"serializer:json" json:"living_situations"`
	MaritalStatus            string                      `gorm:"size:32" json:"marital_status"`
	MedicalPayments          []string                    `gorm:"serializer:json" json:"medical_payments"`
	IncomeSources            []string                    `gorm:"serializer:json" json:"income_sources"`
	RiskEvents               []AdmissionRiskEvent        `gorm:"serializer:json" json:"risk_events"`
	Diagnoses                []string                    `gorm:"serializer:json" json:"diagnoses"`
	DementiaOrMentalDisorder bool                        `gorm:"default:false" json:"dementia_or_mental_disorder"`
	Medications              []AdmissionMedication       `gorm:"serializer:json" json:"medications"`
	HealthIssues             []string                    `gorm:"serializer:json" json:"health_issues"`
	Coma                     bool                        `gorm:"default:false" json:"coma"`
	InfoProviderName         string                      `gorm:"size:64" json:"info_provider_name"`
	InfoProviderRelation     string                      `gorm:"size:32" json:"info_provider_relation"`
	ContactName              string                      `gorm:"size:64" json:"contact_name"`
	ContactPhone             string                      `gorm:"size:32" json:"contact_phone"`
	TargetBedID              *uint                       `gorm:"index" json:"target_bed_id"`
	AbilityScore             int                         `json:"ability_score"`
	InitialLevel             string                      `gorm:"size:32" json:"initial_level"`
	FinalLevel               string                      `gorm:"size:32" json:"final_level"`
	LevelChangeReasons       []string                    `gorm:"serializer:json" json:"level_change_reasons"`
	SelectedCarePlanCode     string                      `gorm:"size:64" json:"selected_care_plan_code"`
	SelectedOptionalServices []string                    `gorm:"serializer:json" json:"selected_optional_services"`
	CarePlanID               *uint                       `gorm:"index" json:"care_plan_id"`
	AssessmentLocation       string                      `gorm:"size:255" json:"assessment_location"`
	DoctorConfirmed          bool                        `gorm:"default:false" json:"doctor_confirmed"`
	PlanConsentConfirmed     bool                        `gorm:"default:false" json:"plan_consent_confirmed"`
	ServiceFeeInformed       bool                        `gorm:"default:false" json:"service_fee_informed"`
	InfoProviderSigned       bool                        `gorm:"default:false" json:"info_provider_signed"`
	SubmittedAt              *time.Time                  `json:"submitted_at"`
	Answers                  []AdmissionAssessmentAnswer `gorm:"foreignKey:AdmissionID;constraint:OnDelete:CASCADE" json:"answers,omitempty"`
	Screenings               []AdmissionScreening        `gorm:"foreignKey:AdmissionID;constraint:OnDelete:CASCADE" json:"screenings,omitempty"`
}

// AdmissionAssessmentAnswer links one admission to one persisted template question and option.
type AdmissionAssessmentAnswer struct {
	Base
	AdmissionID  uint   `gorm:"uniqueIndex:uk_admission_question;not null" json:"admission_id"`
	QuestionID   uint   `gorm:"uniqueIndex:uk_admission_question;not null" json:"question_id"`
	OptionID     *uint  `gorm:"index" json:"option_id"`
	QuestionCode string `gorm:"size:32;not null" json:"question_code"`
	OptionCode   string `gorm:"size:32" json:"option_code"`
	AnswerText   string `gorm:"size:2048" json:"answer_text"`
	Score        int    `json:"score"`
}

// AdmissionScreening is an optional appendix screening linked to one admission.
// Its score is always recalculated from the persisted template options.
type AdmissionScreening struct {
	Base
	AdmissionID     uint                       `gorm:"uniqueIndex:uk_admission_screening;not null" json:"admission_id"`
	TemplateID      uint                       `gorm:"uniqueIndex:uk_admission_screening;not null" json:"template_id"`
	TemplateCode    string                     `gorm:"size:64;index;not null" json:"template_code"`
	TemplateVersion string                     `gorm:"size:32;not null" json:"template_version"`
	AssessorID      uint                       `gorm:"index;not null" json:"assessor_id"`
	Status          string                     `gorm:"size:16;default:draft;index" json:"status"`
	RawScore        int                        `json:"raw_score"`
	AdjustedScore   int                        `json:"adjusted_score"`
	ResultCode      string                     `gorm:"size:64" json:"result_code"`
	ResultLabel     string                     `gorm:"size:255" json:"result_label"`
	EducationYears  *int                       `json:"education_years"`
	Notes           string                     `gorm:"size:2048" json:"notes"`
	CompletedAt     *time.Time                 `json:"completed_at"`
	Answers         []AdmissionScreeningAnswer `gorm:"foreignKey:ScreeningID;constraint:OnDelete:CASCADE" json:"answers,omitempty"`
}

// AdmissionScreeningAnswer stores the selected server-owned option for one screening question.
type AdmissionScreeningAnswer struct {
	Base
	ScreeningID  uint   `gorm:"uniqueIndex:uk_screening_question;not null" json:"screening_id"`
	QuestionID   uint   `gorm:"uniqueIndex:uk_screening_question;not null" json:"question_id"`
	OptionID     *uint  `gorm:"index" json:"option_id"`
	QuestionCode string `gorm:"size:32;not null" json:"question_code"`
	OptionCode   string `gorm:"size:32" json:"option_code"`
	AnswerText   string `gorm:"size:4096" json:"answer_text"`
	Score        int    `json:"score"`
	// Evidence stores item-level observations captured while administering a
	// screening question. Evidence is audit data; the authoritative score is
	// always recalculated from the persisted option above.
	Evidence []AdmissionScreeningEvidence `gorm:"serializer:json" json:"evidence,omitempty"`
}

// AdmissionScreeningEvidence is a structured observation belonging to one
// screening answer (for example, each orientation item in MMSE/MoCA). The
// client-provided score is retained for audit/context only and is never used
// to calculate RawScore or AdjustedScore.
type AdmissionScreeningEvidence struct {
	ItemCode   string `json:"item_code"`
	OptionCode string `json:"option_code,omitempty"`
	AnswerText string `json:"answer_text,omitempty"`
	Score      int    `json:"score,omitempty"`
}
