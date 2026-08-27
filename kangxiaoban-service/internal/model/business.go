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
	ElderID  uint       `gorm:"index;not null" json:"elder_id"`
	Title    string     `gorm:"size:128;not null" json:"title"`
	Kind     string     `gorm:"size:32" json:"kind"` // feeding/bath/medication/turnover/rehab...
	Assignee string     `gorm:"size:64" json:"assignee"`
	DueAt    *time.Time `json:"due_at"`
	Status   string     `gorm:"size:16;default:todo" json:"status"`
	Remark   string     `gorm:"size:500" json:"remark"`
}

// HealthRecord 健康体征记录。source manual 手录 / iot 设备。
type HealthRecord struct {
	Base
	ElderID     uint     `gorm:"index;not null" json:"elder_id"`
	Temperature *float64 `json:"temperature"`
	Systolic    *int     `json:"systolic"`
	Diastolic   *int     `json:"diastolic"`
	HeartRate   *int     `json:"heart_rate"`
	Spo2        *float64 `json:"spo2"`
	Source      string   `gorm:"size:16;default:manual" json:"source"`
	RecordTime  time.Time `json:"record_time"`
	IsAbnormal  bool     `gorm:"default:false" json:"is_abnormal"`
}