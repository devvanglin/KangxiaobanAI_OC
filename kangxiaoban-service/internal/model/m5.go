package model

// MedicineStock 药物库存（出入库、近效期）。
type MedicineStock struct {
	Base
	MedicineName string `gorm:"size:128;index" json:"medicine_name"`
	Spec         string `gorm:"size:64" json:"spec"`
	Batch        string `gorm:"size:64" json:"batch"`
	Qty          int    `gorm:"default:0" json:"qty"`
	ExpireDate   string `gorm:"size:10" json:"expire_date"` // YYYY-MM-DD
	Storage      string `gorm:"size:64" json:"storage"`     // 阴凉/常温/冷藏
}

// DiningOrder 餐饮订餐。餐次 breakfast/lunch/dinner/snack；状态 ordered/served/cancelled。
type DiningOrder struct {
	Base
	ElderID     uint    `gorm:"index;not null" json:"elder_id"`
	MealTime    string  `gorm:"size:8" json:"meal_time"`
	Items       string  `gorm:"size:255" json:"items"`
	Qty         int     `json:"qty"`
	UnitPrice   float64 `json:"unit_price"`
	TotalAmount float64 `json:"total_amount"`
	Status      string  `gorm:"size:16;default:ordered" json:"status"`
}