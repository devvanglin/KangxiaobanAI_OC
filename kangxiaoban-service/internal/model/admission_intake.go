package model

import "time"

// AdmissionIntake is the operational admission order created by the basic
// intake form. It is intentionally separate from AdmissionAssessment: a basic
// intake never implies that the 26-item ability assessment was completed.
// AdmissionIntake 入院登记实体（后端 GORM 模型），对应前端 AdmissionIntakePayload
type AdmissionIntake struct {
    Base                     // 基础字段（ID、创建时间等）

    // ----- 业务标识 -----
    IntakeNo       string `gorm:"size:64;index;not null" json:"intake_no"`          // 登记编号（业务单号）
    IdempotencyKey string `gorm:"size:128;index" json:"-"`                          // 幂等键（前端生成，仅后端使用）
    RequestHash    string `gorm:"size:64;index" json:"-"`                           // 请求哈希（防重复）

    // ----- 关联ID -----
    AssessorID     uint   `gorm:"index;not null" json:"assessor_id"`               // 评估人ID
    ElderID        uint   `gorm:"index;not null" json:"elder_id"`                  // 入住老人ID
    BedID          uint   `gorm:"index;not null" json:"bed_id"`                    // 床位ID

    // ----- 入住人信息快照（不可变，记录提交时的原始数据）-----
    ResidentNameSnapshot      string     `gorm:"size:50" json:"resident_name_snapshot"`          // 姓名
    ResidentIDCardSnapshot    string     `gorm:"size:28" json:"resident_id_card_snapshot"`       // 身份证号
    ResidentGenderSnapshot    string     `gorm:"size:4" json:"resident_gender_snapshot"`         // 性别
    ResidentBirthDateSnapshot string     `gorm:"size:10" json:"resident_birth_date_snapshot"`    // 出生日期
    ResidentAgeSnapshot       int        `json:"resident_age_snapshot"`                          // 年龄

    // ----- 入住与计费日期 -----
    AdmissionStartDate        string     `gorm:"size:10;not null" json:"admission_start_date"`   // 入住开始日
    AdmissionEndDate          string     `gorm:"size:10" json:"admission_end_date"`               // 入住结束日
    FeeStartDate              string     `gorm:"size:10" json:"fee_start_date"`                   // 计费开始日
    FeeEndDate                string     `gorm:"size:10" json:"fee_end_date"`                     // 计费结束日

    // ----- 房间与护理配置 -----
    RoomType                  string     `gorm:"size:32" json:"room_type"`                        // 房间类型
    CareLevel                 int8       `gorm:"index;not null;default:1" json:"care_level"`      // 护理等级（数值）
    CareLevelCode             string     `gorm:"size:32;index" json:"care_level_code"`            // 护理等级编码

    // ----- 家属联系信息 -----
    FamilyAddress             string     `gorm:"size:500" json:"family_address"`                  // 家庭地址
    FamilyName                string     `gorm:"size:64" json:"family_name"`                      // 家属姓名
    FamilyPhone               string     `gorm:"size:32" json:"family_phone"`                     // 家属电话
    FamilyRelation            string     `gorm:"size:32" json:"family_relation"`                  // 与入住人关系

    // ----- 费用（金额） -----
    Deposit                   float64    `gorm:"type:decimal(12,2);default:0" json:"deposit"`     // 押金
    CareFee                   float64    `gorm:"type:decimal(12,2);default:0" json:"care_fee"`    // 护理费
    BedFee                    float64    `gorm:"type:decimal(12,2);default:0" json:"bed_fee"`     // 床位费
    OtherFee                  float64    `gorm:"type:decimal(12,2);default:0" json:"other_fee"`   // 其他费用
    MedicalInsurance          float64    `gorm:"type:decimal(12,2);default:0" json:"medical_insurance"` // 医保报销
    Subsidy                   float64    `gorm:"type:decimal(12,2);default:0" json:"subsidy"`     // 补贴减免

    // ----- 其他 -----
    Note                      string     `gorm:"size:1000" json:"note"`                           // 备注

    // ----- 状态与关联 -----
    Status                    string     `gorm:"size:16;index;not null;default:completed" json:"status"` // 状态（completed/draft等）
    CompletedAt               *time.Time `json:"completed_at"`                                          // 完成时间
    CarePlanID                *uint      `gorm:"index" json:"care_plan_id"`                             // 关联护理计划ID
    BillID                    *uint      `gorm:"index" json:"bill_id"`                                  // 关联账单ID
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
