package repository

import (
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// SupplyRepository 药物库存 + 餐饮订餐。
type SupplyRepository struct{ db *gorm.DB }

func NewSupplyRepository(db *gorm.DB) *SupplyRepository { return &SupplyRepository{db: db} }

func (r *SupplyRepository) ListStock(keyword string, page, size int) ([]model.MedicineStock, int64, error) {
	q := r.db.Model(&model.MedicineStock{})
	if keyword != "" {
		q = q.Where("medicine_name LIKE ? OR spec LIKE ?", "%"+keyword+"%", "%"+keyword+"%")
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.MedicineStock
	err := q.Order("expire_date asc, id").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *SupplyRepository) CreateStock(s *model.MedicineStock) error { return r.db.Create(s).Error }

func (r *SupplyRepository) AdjustStock(id uint, delta int) error {
	return r.db.Model(&model.MedicineStock{}).Where("id = ?", id).UpdateColumn("qty", gorm.Expr("qty + ?", delta)).Error
}

func (r *SupplyRepository) ListDining(elderID uint, mealTime string, page, size int) ([]model.DiningOrder, int64, error) {
	q := r.db.Model(&model.DiningOrder{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if mealTime != "" {
		q = q.Where("meal_time = ?", mealTime)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.DiningOrder
	err := q.Order("created_at desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *SupplyRepository) CreateDining(d *model.DiningOrder) error { return r.db.Create(d).Error }