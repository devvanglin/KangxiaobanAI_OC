package service

import (
	"context"
	"errors"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// CareService 提供“评估 -> 计划 -> 执行 -> 复核”的护理业务链路。
type CareService struct{ repo *repository.CareRepository }

var (
	ErrCarePlanMismatch = errors.New("care plan item does not belong to elder")
	ErrCareNotAssigned  = errors.New("care plan item is assigned to another caregiver")
)

func NewCareService(repo *repository.CareRepository) *CareService { return &CareService{repo: repo} }

func (s *CareService) ListAssessments(ctx context.Context, elderID uint, page, size int, allowed []uint) ([]model.Assessment, int64, error) {
	return s.repo.ListAssessments(ctx, elderID, page, size, allowed)
}
func (s *CareService) CreateAssessment(ctx context.Context, v *model.Assessment) error {
	if v.AssessedAt.IsZero() {
		v.AssessedAt = time.Now()
	}
	return s.repo.CreateAssessment(ctx, v)
}
func (s *CareService) ListPlans(ctx context.Context, elderID uint, page, size int, allowed []uint) ([]model.CarePlan, int64, error) {
	return s.repo.ListPlans(ctx, elderID, page, size, allowed)
}
func (s *CareService) CreatePlan(ctx context.Context, v *model.CarePlan) error {
	if v.Status == "" {
		v.Status = "draft"
	}
	return s.repo.CreatePlan(ctx, v)
}
func (s *CareService) AddPlanItem(ctx context.Context, planID uint, v *model.CarePlanItem) error {
	p, err := s.repo.GetPlan(ctx, planID)
	if err != nil {
		return err
	}
	if p.Status == "completed" {
		return errors.New("completed plan cannot be changed")
	}
	v.CarePlanID = planID
	return s.repo.CreatePlanItem(ctx, v)
}
func (s *CareService) GetPlan(ctx context.Context, id uint) (*model.CarePlan, error) {
	return s.repo.GetPlan(ctx, id)
}
func (s *CareService) ListExecutions(ctx context.Context, elderID, itemID uint, page, size int, allowed []uint) ([]model.CareExecution, int64, error) {
	return s.repo.ListExecutions(ctx, elderID, itemID, page, size, allowed)
}
func (s *CareService) CreateExecution(ctx context.Context, v *model.CareExecution) error {
	item, err := s.repo.GetPlanItem(ctx, v.PlanItemID)
	if err != nil {
		return err
	}
	plan, err := s.repo.GetPlan(ctx, item.CarePlanID)
	if err != nil {
		return err
	}
	if !item.Active || plan.Status != "active" || plan.ElderID != v.ElderID {
		return ErrCarePlanMismatch
	}
	if item.AssigneeID != nil && *item.AssigneeID != v.ExecutorID {
		return ErrCareNotAssigned
	}
	if v.ExecutedAt.IsZero() {
		v.ExecutedAt = time.Now()
	}
	// Workflow and review fields are server-owned even when this service is
	// called outside the HTTP handler.
	v.Base = model.Base{}
	v.Status = "completed"
	v.ReviewedBy = 0
	v.ReviewedAt = nil
	v.Result = truncateRunes(v.Result, 1024)
	v.Abnormal = truncateRunes(v.Abnormal, 1024)
	return s.repo.CreateExecution(ctx, v)
}
func (s *CareService) ReviewExecution(ctx context.Context, id uint, reviewer uint, status, note string) error {
	v, err := s.repo.GetExecution(ctx, id)
	if err != nil {
		return err
	}
	switch status {
	case "reviewed", "abnormal", "completed", "skipped":
	default:
		return errors.New("invalid execution status")
	}
	v.Status = status
	v.ReviewedBy = reviewer
	now := time.Now()
	v.ReviewedAt = &now
	if note != "" {
		v.Result = note
	}
	return s.repo.SaveExecution(ctx, v)
}
func (s *CareService) GetExecution(ctx context.Context, id uint) (*model.CareExecution, error) {
	return s.repo.GetExecution(ctx, id)
}
