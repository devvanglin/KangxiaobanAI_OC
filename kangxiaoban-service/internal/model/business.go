package model

import "time"

// ElderContact 长者紧急/家属联系人（随 elder.emergency_contact 以 JSON 序列化存储）。
type ElderContact struct {
	Name        string `json:"name"`
	Relation    string `json:"relation"`
	Phone       string `json:"phone"`
	IsEmergency bool   `json:"is_emergency"`
}

// Elder 长者档案。状态: 1登记 2入住 3退住。
type Elder struct {
	Base
	Name              string         `gorm:"size:50;not null" json:"name"`
	IDCard            string         `gorm:"size:28" json:"id_card"`
	Gender            string         `gorm:"size:4" json:"gender"` // M 男 / F 女
	BirthDate         string         `gorm:"size:10" json:"birth_date"`
	ContactPhone      string         `gorm:"size:32" json:"contact_phone"`
	CareLevel         int8           `gorm:"default:1" json:"care_level"` // 1-5 照护等级
	Status            int8           `gorm:"default:1" json:"status"`
	BedID             *uint          `gorm:"default:null" json:"bed_id"`
	EmergencyContacts []ElderContact `gorm:"serializer:json" json:"emergency_contacts"`
	Image             string         `gorm:"size:255" json:"image"`
	Remark            string         `gorm:"size:500" json:"remark"`
	Bed               *Bed           `json:"bed,omitempty"`
}

// Room 房间（隶属楼栋/楼层）。
type Room struct {
	Base
	Building string `gorm:"size:16;index" json:"building"`
	Floor    int    `json:"floor"`
	RoomNo   string `gorm:"size:16" json:"room_no"`
	Type     string `gorm:"size:16;default:normal" json:"type"` // normal 普通 / nursing 照护 / special 特护
	Status   string `gorm:"size:16;default:free" json:"status"` // free/occupied/maintenance
	Beds     []Bed  `json:"beds,omitempty"`
}

// Bed 床位。状态 free/occupied/maintenance。
type Bed struct {
	Base
	RoomID  uint   `gorm:"index" json:"room_id"`
	BedNo   string `gorm:"size:8" json:"bed_no"`
	Status  string `gorm:"size:16;default:free" json:"status"`
	ElderID *uint  `json:"elder_id"`
	Room    *Room  `json:"room,omitempty"`
}

// CareTask 护理任务。状态 todo/doing/done。
type CareTask struct {
	Base
	ElderID    uint       `gorm:"index;not null" json:"elder_id"`
	PlanItemID *uint      `gorm:"index" json:"plan_item_id,omitempty"`
	Title      string     `gorm:"size:128;not null" json:"title"`
	Kind       string     `gorm:"size:32" json:"kind"` // feeding/bath/medication/turnover/rehab...
	AssigneeID *uint      `gorm:"index" json:"assignee_id,omitempty"`
	Assignee   string     `gorm:"size:64" json:"assignee"`
	DueAt      *time.Time `json:"due_at"`
	Status     string     `gorm:"size:16;default:todo" json:"status"`
	Remark     string     `gorm:"size:500" json:"remark"`
}

// HealthRecord 健康体征记录。source manual 手录 / iot 设备。
type HealthRecord struct {
	Base
	ElderID     uint      `gorm:"index;not null" json:"elder_id"`
	Temperature *float64  `json:"temperature"`
	Systolic    *int      `json:"systolic"`
	Diastolic   *int      `json:"diastolic"`
	HeartRate   *int      `json:"heart_rate"`
	Spo2        *float64  `json:"spo2"`
	Source      string    `gorm:"size:16;default:manual" json:"source"`
	RecordTime  time.Time `json:"record_time"`
	IsAbnormal  bool      `gorm:"default:false" json:"is_abnormal"`
}

// Assessment 长者照护/风险评估。评估结果用于生成护理计划，不等同于临床诊断。
type Assessment struct {
	Base
	ElderID        uint      `gorm:"index;not null" json:"elder_id"`
	AssessorID     uint      `gorm:"index" json:"assessor_id"`
	AssessmentType string    `gorm:"size:32;not null" json:"assessment_type"` // adl/fall/cognition/nutrition
	Score          *float64  `json:"score"`
	RiskLevel      string    `gorm:"size:16" json:"risk_level"`
	Notes          string    `gorm:"size:1024" json:"notes"`
	AssessedAt     time.Time `json:"assessed_at"`
}

// CarePlan 护理计划主表。
type CarePlan struct {
	Base
	ElderID   uint           `gorm:"index;not null" json:"elder_id"`
	Name      string         `gorm:"size:128;not null" json:"name"`
	Status    string         `gorm:"size:16;default:active" json:"status"` // draft/active/paused/completed
	StartDate string         `gorm:"size:10" json:"start_date"`
	EndDate   string         `gorm:"size:10" json:"end_date"`
	CreatedBy uint           `gorm:"index" json:"created_by"`
	Items     []CarePlanItem `json:"items,omitempty"`
}

// CarePlanItem 护理计划中的周期性项目。
type CarePlanItem struct {
	Base
	CarePlanID   uint       `gorm:"index;not null" json:"care_plan_id"`
	Title        string     `gorm:"size:128;not null" json:"title"`
	Kind         string     `gorm:"size:32" json:"kind"`
	Frequency    string     `gorm:"size:64" json:"frequency"`
	DueAt        *time.Time `json:"due_at"`
	AssigneeID   *uint      `gorm:"index" json:"assignee_id,omitempty"`
	Assignee     string     `gorm:"size:64" json:"assignee"`
	RiskLevel    string     `gorm:"size:16" json:"risk_level"`
	Instructions string     `gorm:"size:1024" json:"instructions"`
	Active       bool       `gorm:"default:true" json:"active"`
}

// CareExecution 护理项目实际执行记录，用于复核与质控。
type CareExecution struct {
	Base
	PlanItemID uint       `gorm:"index;not null" json:"plan_item_id"`
	ElderID    uint       `gorm:"index;not null" json:"elder_id"`
	ExecutorID uint       `gorm:"index" json:"executor_id"`
	Executor   string     `gorm:"size:64" json:"executor"`
	Status     string     `gorm:"size:16;default:completed" json:"status"` // completed/skipped/abnormal/reviewed
	ExecutedAt time.Time  `json:"executed_at"`
	Result     string     `gorm:"size:1024" json:"result"`
	Abnormal   string     `gorm:"size:1024" json:"abnormal"`
	ReviewedBy uint       `gorm:"index" json:"reviewed_by"`
	ReviewedAt *time.Time `json:"reviewed_at"`
}

// Incident 事故/异常事件记录，承接告警后的人工处置。
type Incident struct {
	Base
	ElderID     *uint      `gorm:"index" json:"elder_id"`
	AlertID     *uint      `gorm:"index" json:"alert_id"`
	Type        string     `gorm:"size:32;not null" json:"type"`
	Level       string     `gorm:"size:16" json:"level"`
	Status      string     `gorm:"size:16;default:open" json:"status"` // open/handling/resolved/closed
	OwnerID     uint       `gorm:"index" json:"owner_id"`
	Description string     `gorm:"size:2048" json:"description"`
	Resolution  string     `gorm:"size:2048" json:"resolution"`
	OccurredAt  time.Time  `json:"occurred_at"`
	ResolvedAt  *time.Time `json:"resolved_at"`
}
