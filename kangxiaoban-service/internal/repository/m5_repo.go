package repository

import (
	"context"

	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// SupplyRepository 药物库存 + 餐饮订餐。
type SupplyRepository struct{ db *gorm.DB }

func NewSupplyRepository(db *gorm.DB) *SupplyRepository { return &SupplyRepository{db: db} }

func (r *SupplyRepository) ListStock(ctx context.Context, keyword string, page, size int) ([]model.MedicineStock, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.MedicineStock{})
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

func (r *SupplyRepository) CreateStock(ctx context.Context, s *model.MedicineStock) error {
	return r.db.WithContext(ctx).Create(s).Error
}

func (r *SupplyRepository) AdjustStock(ctx context.Context, id uint, delta int) error {
	result := r.db.WithContext(ctx).Model(&model.MedicineStock{}).Where("id = ?", id).UpdateColumn("qty", gorm.Expr("qty + ?", delta))
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *SupplyRepository) ListDining(ctx context.Context, elderID uint, mealTime string, page, size int) ([]model.DiningOrder, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.DiningOrder{})
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

func (r *SupplyRepository) CreateDining(ctx context.Context, d *model.DiningOrder) error {
	return r.db.WithContext(ctx).Create(d).Error
}
