package model

// FamilyElder 家属账号↔长者 绑定（家属仅可查看绑定的长者）。
type FamilyElder struct {
	Base
	UserID  uint   `gorm:"uniqueIndex:uk_fam_user_elder;not null" json:"user_id"`
	ElderID uint   `gorm:"uniqueIndex:uk_fam_user_elder;not null" json:"elder_id"`
	User    *User  `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Elder   *Elder `gorm:"foreignKey:ElderID" json:"elder,omitempty"`
}
