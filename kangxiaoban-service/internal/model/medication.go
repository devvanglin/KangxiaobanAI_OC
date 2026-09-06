package model

// Medication 管理端维护的机构药物目录（药品台账），区别于按批次的药物库存台账。
type Medication struct {
	Base
	Name          string `gorm:"size:128;not null;index" json:"name"`
	Category      string `gorm:"size:32;default:西药" json:"category"`    // 西药/中药/保健品
	Specification string `gorm:"size:64" json:"specification"`           // 例: 100mg×30片
	Manufacturer  string `gorm:"size:128" json:"manufacturer"`
	UsageMethod   string `gorm:"size:32;default:口服" json:"usage_method"` // 口服/注射/外用/雾化
	Stock         int    `gorm:"default:0" json:"stock"`
	Unit          string `gorm:"size:16;default:盒" json:"unit"`
	Status        string `gorm:"size:16;default:in_use;index" json:"status"` // in_use/discontinued
	Note          string `gorm:"size:512" json:"note"`
}
