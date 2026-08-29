package repository

import (
	"context"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// CareRepository 评估、护理计划和执行记录数据访问。
type CareRepository struct{ db *gorm.DB }

func NewCareRepository(db *gorm.DB) *CareRepository { return &CareRepository{db: db} }

func (r *CareRepository) ListAssessments(ctx context.Context, elderID uint, page, size int, allowed []uint) ([]model.Assessment, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Assessment{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if allowed != nil {
		if len(allowed) == 0 {
			q = q.Where("1 = 0")
		} else {
			q = q.Where("elder_id IN ?", allowed)
		}
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.Assessment
	err := q.Order("assessed_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) CreateAssessment(ctx context.Context, v *model.Assessment) error {
	return r.db.WithContext(ctx).Create(v).Error
}

func (r *CareRepository) ListPlans(ctx context.Context, elderID uint, page, size int, allowed []uint) ([]model.CarePlan, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.CarePlan{}).Preload("Items")
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if allowed != nil {
		if len(allowed) == 0 {
			q = q.Where("1 = 0")
		} else {
			q = q.Where("elder_id IN ?", allowed)
		}
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.CarePlan
	err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) GetPlan(ctx context.Context, id uint) (*model.CarePlan, error) {
	var p model.CarePlan
	err := r.db.WithContext(ctx).Preload("Items").First(&p, id).Error
	return &p, err
}

func (r *CareRepository) CreatePlan(ctx context.Context, v *model.CarePlan) error {
	return r.db.WithContext(ctx).Create(v).Error
}
func (r *CareRepository) CreatePlanItem(ctx context.Context, v *model.CarePlanItem) error {
	return r.db.WithContext(ctx).Create(v).Error
}

func (r *CareRepository) GetPlanItem(ctx context.Context, id uint) (*model.CarePlanItem, error) {
	var item model.CarePlanItem
	err := r.db.WithContext(ctx).First(&item, id).Error
	return &item, err
}

func (r *CareRepository) ListExecutions(ctx context.Context, elderID, itemID uint, page, size int, allowed []uint) ([]model.CareExecution, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.CareExecution{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if itemID > 0 {
		q = q.Where("plan_item_id = ?", itemID)
	}
	if allowed != nil {
		if len(allowed) == 0 {
			q = q.Where("1 = 0")
		} else {
			q = q.Where("elder_id IN ?", allowed)
		}
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.CareExecution
	err := q.Order("executed_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) GetExecution(ctx context.Context, id uint) (*model.CareExecution, error) {
	var v model.CareExecution
	err := r.db.WithContext(ctx).First(&v, id).Error
	return &v, err
}

func (r *CareRepository) CreateExecution(ctx context.Context, v *model.CareExecution) error {
	return r.db.WithContext(ctx).Create(v).Error
}
func (r *CareRepository) SaveExecution(ctx context.Context, v *model.CareExecution) error {
	return r.db.WithContext(ctx).Save(v).Error
}
