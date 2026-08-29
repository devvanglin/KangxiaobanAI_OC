package repository

import (
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// CareRepository 评估、护理计划和执行记录数据访问。
type CareRepository struct{ db *gorm.DB }

func NewCareRepository(db *gorm.DB) *CareRepository { return &CareRepository{db: db} }

func (r *CareRepository) ListAssessments(elderID uint, page, size int, allowed []uint) ([]model.Assessment, int64, error) {
	q := r.db.Model(&model.Assessment{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if len(allowed) > 0 {
		q = q.Where("elder_id IN ?", allowed)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.Assessment
	err := q.Order("assessed_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) CreateAssessment(v *model.Assessment) error { return r.db.Create(v).Error }

func (r *CareRepository) ListPlans(elderID uint, page, size int, allowed []uint) ([]model.CarePlan, int64, error) {
	q := r.db.Model(&model.CarePlan{}).Preload("Items")
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if len(allowed) > 0 {
		q = q.Where("elder_id IN ?", allowed)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.CarePlan
	err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) GetPlan(id uint) (*model.CarePlan, error) {
	var p model.CarePlan
	err := r.db.Preload("Items").First(&p, id).Error
	return &p, err
}

func (r *CareRepository) CreatePlan(v *model.CarePlan) error         { return r.db.Create(v).Error }
func (r *CareRepository) CreatePlanItem(v *model.CarePlanItem) error { return r.db.Create(v).Error }

func (r *CareRepository) ListExecutions(elderID, itemID uint, page, size int, allowed []uint) ([]model.CareExecution, int64, error) {
	q := r.db.Model(&model.CareExecution{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if itemID > 0 {
		q = q.Where("plan_item_id = ?", itemID)
	}
	if len(allowed) > 0 {
		q = q.Where("elder_id IN ?", allowed)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.CareExecution
	err := q.Order("executed_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}

func (r *CareRepository) GetExecution(id uint) (*model.CareExecution, error) {
	var v model.CareExecution
	err := r.db.First(&v, id).Error
	return &v, err
}

func (r *CareRepository) CreateExecution(v *model.CareExecution) error { return r.db.Create(v).Error }
func (r *CareRepository) SaveExecution(v *model.CareExecution) error   { return r.db.Save(v).Error }
