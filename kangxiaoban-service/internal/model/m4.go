package model

import "time"

// Schedule 排班。班次 morning/evening/night。
type Schedule struct {
	Base
	Staff     string `gorm:"size:64;index" json:"staff"`
	WorkDate  string `gorm:"size:10;index" json:"work_date"` // YYYY-MM-DD
	Shift     string `gorm:"size:16" json:"shift"`
	RoomScope string `gorm:"size:128" json:"room_scope"`
}

// ShiftHandover 交接班。
type ShiftHandover struct {
	Base
	FromStaff string `gorm:"size:64" json:"from_staff"`
	ToStaff   string `gorm:"size:64" json:"to_staff"`
	WorkDate  string `gorm:"size:10" json:"work_date"`
	Summary   string `gorm:"size:1024" json:"summary"`
	Issues    string `gorm:"size:1024" json:"issues"`
}

// Bill 月度账单。状态 unpaid/partial/paid。
type Bill struct {
	Base
	ElderID    uint    `gorm:"index;not null" json:"elder_id"`
	BillMonth  string  `gorm:"size:10;index" json:"bill_month"` // YYYY-MM
	BedFee     float64 `json:"bed_fee"`
	NursingFee float64 `json:"nursing_fee"`
	MealFee    float64 `json:"meal_fee"`
	OtherFee   float64 `json:"other_fee"`
	Amount     float64 `json:"amount"`
	Paid       float64 `gorm:"default:0" json:"paid"`
	Status     string  `gorm:"size:16;default:unpaid" json:"status"`
}

// FundFlow 资金流水。方向 in 预缴/out 抵扣。
type FundFlow struct {
	Base
	ElderID       uint    `gorm:"index" json:"elder_id"`
	Direction     string  `gorm:"size:8" json:"direction"` // in / out
	RelatedMonth  string  `gorm:"size:10" json:"related_month"`
	Reason        string  `gorm:"size:128" json:"reason"`
	Amount        float64 `json:"amount"`
}

// MedicationRecord 用药记录。状态 pending/taken/refused/missed。
type MedicationRecord struct {
	Base
	ElderID      uint       `gorm:"index;not null" json:"elder_id"`
	MedicineName string     `gorm:"size:128" json:"medicine_name"`
	Dosage       string     `gorm:"size:64" json:"dosage"`
	Frequency    string     `gorm:"size:64;default:按医嘱" json:"frequency"`
	Route        string     `gorm:"size:32;default:口服" json:"route"`
	PlanTime     *time.Time `json:"plan_time"`
	TakenTime    *time.Time `json:"taken_time"`
	TodayTotal   int        `gorm:"default:1" json:"today_total"`
	TodayDone    int        `gorm:"default:0" json:"today_done"`
	Status       string     `gorm:"size:16;default:pending" json:"status"`
}