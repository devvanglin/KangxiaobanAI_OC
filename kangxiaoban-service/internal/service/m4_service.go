package service

import (
	"context"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// ScheduleService 排班 + 交接班。
type ScheduleService struct {
	repo *repository.ScheduleRepository
}

func NewScheduleService(repo *repository.ScheduleRepository) *ScheduleService {
	return &ScheduleService{repo: repo}
}

func (s *ScheduleService) ListSchedules(ctx context.Context, date string, page, size int) ([]model.Schedule, int64, error) {
	return s.repo.ListSchedules(ctx, date, page, size)
}
func (s *ScheduleService) CreateSchedule(ctx context.Context, sch *model.Schedule) error {
	return s.repo.CreateSchedule(ctx, sch)
}
func (s *ScheduleService) ListHandovers(ctx context.Context, date string, page, size int) ([]model.ShiftHandover, int64, error) {
	return s.repo.ListHandovers(ctx, date, page, size)
}
func (s *ScheduleService) CreateHandover(ctx context.Context, h *model.ShiftHandover) error {
	return s.repo.CreateHandover(ctx, h)
}

// feeTable 简易费率：床位费/餐饮费按常量，护理费按照护等级。
var feeTable = map[int]float64{1: 1200, 2: 1800, 3: 2400, 4: 3000, 5: 3600}

// FinanceService 费用账单与资金。
type FinanceService struct {
	db    *gorm.DB
	repo  *repository.FinanceRepository
	elder *repository.ElderRepository
}

func NewFinanceService(db *gorm.DB, repo *repository.FinanceRepository, elder *repository.ElderRepository) *FinanceService {
	return &FinanceService{db: db, repo: repo, elder: elder}
}

func (s *FinanceService) ListBills(ctx context.Context, elderID uint, month string, page, size int) ([]model.Bill, int64, error) {
	return s.repo.ListBills(ctx, elderID, month, page, size)
}

// ListBillsScoped 账单列表（家属按绑定集合过滤）。
func (s *FinanceService) ListBillsScoped(ctx context.Context, elderID uint, month string, page, size int, allowed []uint) ([]model.Bill, int64, error) {
	return s.repo.ListBillsScoped(ctx, elderID, month, page, size, allowed)
}

func (s *FinanceService) ListFlows(ctx context.Context, elderID uint, page, size int) ([]model.FundFlow, int64, error) {
	return s.repo.ListFlows(ctx, elderID, page, size)
}

// GenerateMonth 为当月所有在院长者生成账单（已存在则跳过），返回生成条数。
func (s *FinanceService) GenerateMonth(ctx context.Context, month string) (int, error) {
	if month == "" {
		month = time.Now().Format("2006-01")
	}
	var elders []model.Elder
	db := s.db.WithContext(ctx)
	if err := db.Where("status = 2").Find(&elders).Error; err != nil {
		return 0, err
	}
	count := 0
	for _, e := range elders {
		var n int64
		if err := db.Model(&model.Bill{}).Where("elder_id = ? AND bill_month = ?", e.ID, month).Count(&n).Error; err != nil {
			return count, err
		}
		if n > 0 {
			continue
		}
		nursing := feeTable[int(e.CareLevel)]
		bill := model.Bill{
			ElderID:    e.ID,
			BillMonth:  month,
			BedFee:     1500,
			NursingFee: nursing,
			MealFee:    900,
			Amount:     1500 + nursing + 900,
			Status:     "unpaid",
		}
		if err := db.Create(&bill).Error; err != nil {
			return count, err
		}
		count++
	}
	return count, nil
}

// Pay 缴费：入资金流水并更新账单已缴/状态。
func (s *FinanceService) Pay(ctx context.Context, elderID uint, month string, amount float64, reason string) error {
	if reason == "" {
		reason = "缴费"
	}
	flow := model.FundFlow{ElderID: elderID, Direction: "in", RelatedMonth: month, Reason: reason, Amount: amount}
	if err := s.repo.CreateFlow(ctx, &flow); err != nil {
		return err
	}
	var bills []model.Bill
	db := s.db.WithContext(ctx)
	if err := db.Where("elder_id = ? AND bill_month = ?", elderID, month).Find(&bills).Error; err != nil {
		return err
	}
	for _, b := range bills {
		b.Paid += amount
		if b.Paid >= b.Amount {
			b.Status = "paid"
		} else if b.Paid > 0 {
			b.Status = "partial"
		}
		if err := s.repo.Save(ctx, &b); err != nil {
			return err
		}
	}
	return nil
}

// Balance 余客（预缴in - 抵扣out）。
func (s *FinanceService) Balance(ctx context.Context, elderID uint) (float64, error) {
	db := s.db.WithContext(ctx)
	var in, out float64
	if err := db.Model(&model.FundFlow{}).Where("elder_id = ? AND direction = 'in'", elderID).Select("COALESCE(SUM(amount),0)").Scan(&in).Error; err != nil {
		return 0, err
	}
	if err := db.Model(&model.FundFlow{}).Where("elder_id = ? AND direction = 'out'", elderID).Select("COALESCE(SUM(amount),0)").Scan(&out).Error; err != nil {
		return 0, err
	}
	return in - out, nil
}

// MedicationService 用药记录。
type MedicationService struct {
	repo *repository.MedicationRepository
}

func NewMedicationService(repo *repository.MedicationRepository) *MedicationService {
	return &MedicationService{repo: repo}
}

func (s *MedicationService) List(ctx context.Context, elderID uint, status string, page, size int) ([]model.MedicationRecord, int64, error) {
	return s.repo.List(ctx, elderID, status, page, size)
}
func (s *MedicationService) Create(ctx context.Context, m *model.MedicationRecord) error {
	return s.repo.Create(ctx, m)
}
func (s *MedicationService) Get(ctx context.Context, id uint) (*model.MedicationRecord, error) {
	return s.repo.Get(ctx, id)
}

// MarkTaken 标记已服药。status: taken/refused/missed。
func (s *MedicationService) MarkStatus(ctx context.Context, id uint, status string) error {
	m, err := s.repo.Get(ctx, id)
	if err != nil {
		return err
	}
	m.Status = status
	if status == "taken" {
		now := time.Now()
		m.TakenTime = &now
	}
	return s.repo.Save(ctx, m)
}

// AuditService 审计日志。
type AuditService struct{ repo *repository.AuditRepository }

func NewAuditService(repo *repository.AuditRepository) *AuditService {
	return &AuditService{repo: repo}
}

func (s *AuditService) List(ctx context.Context, page, size int) ([]model.AuditLog, int64, error) {
	return s.repo.List(ctx, page, size)
}
func (s *AuditService) Record(ctx context.Context, a *model.AuditLog) error {
	return s.repo.CreateContext(ctx, a)
}
