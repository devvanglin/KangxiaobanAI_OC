package repository

import (
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// FamilyRepository 家属绑定。
type FamilyRepository struct{ db *gorm.DB }

func NewFamilyRepository(db *gorm.DB) *FamilyRepository { return &FamilyRepository{db: db} }

// BoundElderIDs 返回该家属账号可查看的长者 id 集合。
func (r *FamilyRepository) BoundElderIDs(userID uint) ([]uint, error) {
	var rows []model.FamilyElder
	if err := r.db.Where("user_id = ?", userID).Find(&rows).Error; err != nil {
		return nil, err
	}
	ids := make([]uint, 0, len(rows))
	for _, f := range rows {
		ids = append(ids, f.ElderID)
	}
	return ids, nil
}

// Bind 建立/幂等创建绑定。
func (r *FamilyRepository) Bind(userID, elderID uint) error {
	return r.db.FirstOrCreate(&model.FamilyElder{UserID: userID, ElderID: elderID},
		model.FamilyElder{UserID: userID, ElderID: elderID}).Error
}