package model

const (
	BillingRateKindBed     = "bed"
	BillingRateKindMeal    = "meal"
	BillingRateKindNursing = "nursing"
)

// BillingRate is the tenant-owned monthly charge configuration. Bills copy
// these values when they are generated so later rate changes do not rewrite
// historical charges. CareLevel is 0 for flat fees and 1-5 for nursing fees.
type BillingRate struct {
	Base
	Kind        string  `gorm:"size:16;not null;index" json:"kind"`
	CareLevel   int8    `gorm:"not null;default:0;index" json:"care_level"`
	DisplayName string  `gorm:"size:64;not null" json:"display_name"`
	Amount      float64 `gorm:"type:decimal(12,2);not null" json:"amount"`
	Currency    string  `gorm:"size:3;not null;default:CNY" json:"currency"`
	Unit        string  `gorm:"size:16;not null;default:month" json:"unit"`
	Enabled     bool    `gorm:"not null;default:true;index" json:"enabled"`
}
