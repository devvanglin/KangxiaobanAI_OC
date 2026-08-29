package service

import (
	"errors"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// CareService 提供“评估 -> 计划 -> 执行 -> 复核”的护理业务链路。
type CareService struct{ repo *repository.CareRepository }

func NewCareService(repo *repository.CareRepository) *CareService { return &CareService{repo: repo} }

func (s *CareService) ListAssessments(elderID uint, page, size int, allowed []uint) ([]model.Assessment, int64, error) {
	return s.repo.ListAssessments(elderID, page, size, allowed)
}
func (s *CareService) CreateAssessment(v *model.Assessment) error {
	if v.AssessedAt.IsZero() {
		v.AssessedAt = time.Now()
	}
	return s.repo.CreateAssessment(v)
}
func (s *CareService) ListPlans(elderID uint, page, size int, allowed []uint) ([]model.CarePlan, int64, error) {
	return s.repo.ListPlans(elderID, page, size, allowed)
}
func (s *CareService) CreatePlan(v *model.CarePlan) error {
	if v.Status == "" {
		v.Status = "draft"
	}
	return s.repo.CreatePlan(v)
}
func (s *CareService) AddPlanItem(planID uint, v *model.CarePlanItem) error {
	p, err := s.repo.GetPlan(planID)
	if err != nil {
		return err
	}
	if p.Status == "completed" {
		return errors.New("completed plan cannot be changed")
	}
	v.CarePlanID = planID
	return s.repo.CreatePlanItem(v)
}
func (s *CareService) GetPlan(id uint) (*model.CarePlan, error) { return s.repo.GetPlan(id) }
func (s *CareService) ListExecutions(elderID, itemID uint, page, size int, allowed []uint) ([]model.CareExecution, int64, error) {
	return s.repo.ListExecutions(elderID, itemID, page, size, allowed)
}
func (s *CareService) CreateExecution(v *model.CareExecution) error {
	if v.ExecutedAt.IsZero() {
		v.ExecutedAt = time.Now()
	}
	if v.Status == "" {
		v.Status = "completed"
	}
	return s.repo.CreateExecution(v)
}
func (s *CareService) ReviewExecution(id uint, reviewer uint, status, note string) error {
	v, err := s.repo.GetExecution(id)
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
	return s.repo.SaveExecution(v)
}
func (s *CareService) GetExecution(id uint) (*model.CareExecution, error) {
	return s.repo.GetExecution(id)
}
