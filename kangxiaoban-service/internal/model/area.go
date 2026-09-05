package model

// AreaType is a spatial node in the institution. Rooms may contain beds;
// corridors, stairs and common areas may contain devices but never beds.
type AreaType string

const (
	AreaTypeFloor    AreaType = "floor"
	AreaTypeRoom     AreaType = "room"
	AreaTypeCorridor AreaType = "corridor"
	AreaTypeStair    AreaType = "stair"
	AreaTypeCommon   AreaType = "common"
	AreaTypeOther    AreaType = "other"
)

type Area struct {
	Base
	ParentID    *uint    `gorm:"index" json:"parent_id"`
	Type        AreaType `gorm:"size:16;index;not null" json:"type"`
	Code        string   `gorm:"size:64;uniqueIndex:uk_areas_tenant_code;not null" json:"code"`
	Name        string   `gorm:"size:128;not null" json:"name"`
	Building    string   `gorm:"size:32;index" json:"building"`
	FloorNo     int      `gorm:"index" json:"floor_no"`
	Status      string   `gorm:"size:16;default:active;index" json:"status"`
	SortOrder   int      `gorm:"default:0" json:"sort_order"`
	Description string   `gorm:"size:500" json:"description"`
	// Floor-plan geometry in grid cells. Zero size marks an area that has
	// not been placed on its floor map yet.
	PosX  float64 `gorm:"default:0" json:"pos_x"`
	PosY  float64 `gorm:"default:0" json:"pos_y"`
	SizeW float64 `gorm:"default:0" json:"size_w"`
	SizeH float64 `gorm:"default:0" json:"size_h"`
}

type CarePackageTemplate struct {
	Base
	Code                string            `gorm:"size:64;uniqueIndex:uk_care_package_tenant_code;not null" json:"code"`
	Name                string            `gorm:"size:128;not null" json:"name"`
	Description         string            `gorm:"size:1024" json:"description"`
	ApplicableCareLevel *int8             `json:"applicable_care_level"`
	MonthlyPrice        float64           `gorm:"type:decimal(12,2);default:0" json:"monthly_price"`
	Currency            string            `gorm:"size:3;default:CNY" json:"currency"`
	Status              string            `gorm:"size:16;default:draft;index" json:"status"`
	Version             int               `gorm:"default:1" json:"version"`
	Items               []CarePackageItem `gorm:"foreignKey:TemplateID;constraint:OnDelete:CASCADE" json:"items,omitempty"`
}

type CarePackageItem struct {
	Base
	TemplateID   uint   `gorm:"index;not null" json:"template_id"`
	Title        string `gorm:"size:128;not null" json:"title"`
	Kind         string `gorm:"size:32" json:"kind"`
	Frequency    string `gorm:"size:64" json:"frequency"`
	Instructions string `gorm:"size:1024" json:"instructions"`
	RiskLevel    string `gorm:"size:16" json:"risk_level"`
	AssigneeRole string `gorm:"size:32" json:"assignee_role"`
	SortOrder    int    `gorm:"default:0" json:"sort_order"`
	Enabled      bool   `gorm:"default:true" json:"enabled"`
}

type ElderCarePackageSubscription struct {
	Base
	ElderID         uint    `gorm:"index;not null" json:"elder_id"`
	TemplateID      uint    `gorm:"index;not null" json:"template_id"`
	CarePlanID      *uint   `gorm:"index" json:"care_plan_id"`
	TemplateName    string  `gorm:"size:128" json:"template_name"`
	TemplateVersion int     `gorm:"default:1" json:"template_version"`
	StartDate       string  `gorm:"size:10;not null" json:"start_date"`
	EndDate         string  `gorm:"size:10" json:"end_date"`
	Status          string  `gorm:"size:16;default:active;index" json:"status"`
	MonthlyPrice    float64 `gorm:"type:decimal(12,2);default:0" json:"monthly_price"`
	Currency        string  `gorm:"size:3;default:CNY" json:"currency"`
	AssignedBy      uint    `gorm:"index" json:"assigned_by"`
}
