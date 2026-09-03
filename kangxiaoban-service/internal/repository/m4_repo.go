package repository

import (
	"context"

	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// ScheduleRepository 排班 + 交接班。
type ScheduleRepository struct{ db *gorm.DB }

func NewScheduleRepository(db *gorm.DB) *ScheduleRepository { return &ScheduleRepository{db: db} }

func (r *ScheduleRepository) ListSchedules(ctx context.Context, date string, page, size int) ([]model.Schedule, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Schedule{})
	if date != "" {
		q = q.Where("work_date = ?", date)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Schedule
	err := q.Order("work_date, shift, id").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ScheduleRepository) CreateSchedule(ctx context.Context, s *model.Schedule) error {
	return r.db.WithContext(ctx).Create(s).Error
}

func (r *ScheduleRepository) ListHandovers(ctx context.Context, date string, page, size int) ([]model.ShiftHandover, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.ShiftHandover{})
	if date != "" {
		q = q.Where("work_date = ?", date)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.ShiftHandover
	err := q.Order("created_at desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ScheduleRepository) CreateHandover(ctx context.Context, h *model.ShiftHandover) error {
	return r.db.WithContext(ctx).Create(h).Error
}

// FinanceRepository 费用账单 + 资金流水。
type FinanceRepository struct{ db *gorm.DB }

func NewFinanceRepository(db *gorm.DB) *FinanceRepository { return &FinanceRepository{db: db} }

func (r *FinanceRepository) ListBills(ctx context.Context, elderID uint, month string, page, size int) ([]model.Bill, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Bill{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if month != "" {
		q = q.Where("bill_month = ?", month)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Bill
	err := q.Order("bill_month desc, id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *FinanceRepository) GetBill(ctx context.Context, id uint) (*model.Bill, error) {
	var b model.Bill
	err := r.db.WithContext(ctx).First(&b, id).Error
	return &b, err
}

func (r *FinanceRepository) Save(ctx context.Context, b *model.Bill) error {
	return r.db.WithContext(ctx).Save(b).Error
}

func (r *FinanceRepository) ListFlows(ctx context.Context, elderID uint, page, size int) ([]model.FundFlow, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.FundFlow{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.FundFlow
	err := q.Order("created_at desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *FinanceRepository) CreateFlow(ctx context.Context, f *model.FundFlow) error {
	return r.db.WithContext(ctx).Create(f).Error
}

// MedicationRepository 用药记录。
type MedicationRepository struct{ db *gorm.DB }

func NewMedicationRepository(db *gorm.DB) *MedicationRepository { return &MedicationRepository{db: db} }

func (r *MedicationRepository) List(ctx context.Context, elderID uint, status string, page, size int) ([]model.MedicationRecord, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.MedicationRecord{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.MedicationRecord
	err := q.Order("plan_time desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *MedicationRepository) Create(ctx context.Context, m *model.MedicationRecord) error {
	return r.db.WithContext(ctx).Create(m).Error
}
func (r *MedicationRepository) Get(ctx context.Context, id uint) (*model.MedicationRecord, error) {
	var m model.MedicationRecord
	err := r.db.WithContext(ctx).First(&m, id).Error
	return &m, err
}
func (r *MedicationRepository) Save(ctx context.Context, m *model.MedicationRecord) error {
	return r.db.WithContext(ctx).Save(m).Error
}

// AuditRepository 审计日志。
type AuditRepository struct{ db *gorm.DB }

func NewAuditRepository(db *gorm.DB) *AuditRepository { return &AuditRepository{db: db} }

func (r *AuditRepository) List(ctx context.Context, page, size int) ([]model.AuditLog, int64, error) {
	db := r.db.WithContext(ctx)
	var total int64
	if err := db.Model(&model.AuditLog{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.AuditLog
	err := db.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *AuditRepository) CreateContext(ctx context.Context, a *model.AuditLog) error {
	return r.db.WithContext(ctx).Create(a).Error
}

func (r *AuditRepository) Create(a *model.AuditLog) error {
	return r.CreateContext(context.Background(), a)
}
