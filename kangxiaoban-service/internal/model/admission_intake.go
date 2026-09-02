package model

import "time"

// AdmissionIntake is the operational admission order created by the basic
// intake form. It is intentionally separate from AdmissionAssessment: a basic
// intake never implies that the 26-item ability assessment was completed.
type AdmissionIntake struct {
	Base
	IntakeNo       string `gorm:"size:64;index;not null" json:"intake_no"`
	IdempotencyKey string `gorm:"size:128;index" json:"-"`
	RequestHash    string `gorm:"size:64;index" json:"-"`
	AssessorID     uint   `gorm:"index;not null" json:"assessor_id"`
	ElderID        uint   `gorm:"index;not null" json:"elder_id"`
	BedID          uint   `gorm:"index;not null" json:"bed_id"`
	// Keep the submitted identity as an immutable admission snapshot. The
	// linked elder profile can be corrected or archived later; historical
	// intake records must still show what was accepted at entry time.
	ResidentNameSnapshot      string     `gorm:"size:50" json:"resident_name_snapshot"`
	ResidentIDCardSnapshot    string     `gorm:"size:28" json:"resident_id_card_snapshot"`
	ResidentGenderSnapshot    string     `gorm:"size:4" json:"resident_gender_snapshot"`
	ResidentBirthDateSnapshot string     `gorm:"size:10" json:"resident_birth_date_snapshot"`
	ResidentAgeSnapshot       int        `json:"resident_age_snapshot"`
	AdmissionStartDate        string     `gorm:"size:10;not null" json:"admission_start_date"`
	AdmissionEndDate          string     `gorm:"size:10" json:"admission_end_date"`
	FeeStartDate              string     `gorm:"size:10" json:"fee_start_date"`
	FeeEndDate                string     `gorm:"size:10" json:"fee_end_date"`
	RoomType                  string     `gorm:"size:32" json:"room_type"`
	CareLevel                 int8       `gorm:"index;not null;default:1" json:"care_level"`
	CareLevelCode             string     `gorm:"size:32;index" json:"care_level_code"`
	FamilyAddress             string     `gorm:"size:500" json:"family_address"`
	FamilyName                string     `gorm:"size:64" json:"family_name"`
	FamilyPhone               string     `gorm:"size:32" json:"family_phone"`
	FamilyRelation            string     `gorm:"size:32" json:"family_relation"`
	Deposit                   float64    `gorm:"type:decimal(12,2);default:0" json:"deposit"`
	CareFee                   float64    `gorm:"type:decimal(12,2);default:0" json:"care_fee"`
	BedFee                    float64    `gorm:"type:decimal(12,2);default:0" json:"bed_fee"`
	OtherFee                  float64    `gorm:"type:decimal(12,2);default:0" json:"other_fee"`
	MedicalInsurance          float64    `gorm:"type:decimal(12,2);default:0" json:"medical_insurance"`
	Subsidy                   float64    `gorm:"type:decimal(12,2);default:0" json:"subsidy"`
	Note                      string     `gorm:"size:1000" json:"note"`
	Status                    string     `gorm:"size:16;index;not null;default:completed" json:"status"`
	CompletedAt               *time.Time `json:"completed_at"`
	CarePlanID                *uint      `gorm:"index" json:"care_plan_id"`
	BillID                    *uint      `gorm:"index" json:"bill_id"`
}

// AdmissionIntakePhoto records one private image submitted with an intake.
// The bytes live on disk; only validated metadata and a generated storage key
// are persisted here. Never expose StorageKey directly to clients.
type AdmissionIntakePhoto struct {
	Base
	IntakeID     uint   `gorm:"index;default:0" json:"intake_id"`
	ElderID      uint   `gorm:"index;default:0" json:"elder_id"`
	Kind         string `gorm:"size:16;not null" json:"kind"` // portrait/id_front/id_back
	OriginalName string `gorm:"size:255" json:"-"`
	StorageKey   string `gorm:"size:255;uniqueIndex;not null" json:"-"`
	ContentType  string `gorm:"size:64;not null" json:"content_type"`
	Size         int64  `gorm:"not null" json:"size"`
	// Hash and uploader are retained for integrity/audit, but are not part of
	// the client-facing photo metadata response.
	SHA256     string `gorm:"size:64;not null" json:"-"`
	UploadedBy uint   `gorm:"index;not null" json:"-"`
	UploadKey  string `gorm:"size:128;index;not null;default:''" json:"-"`
}
