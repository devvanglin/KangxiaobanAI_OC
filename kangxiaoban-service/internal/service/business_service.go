package service

import (
	"context"
	"errors"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// ElderService 长者档案。
type ElderService struct{ repo *repository.ElderRepository }

func NewElderService(repo *repository.ElderRepository) *ElderService {
	return &ElderService{repo: repo}
}

func (s *ElderService) List(ctx context.Context, keyword string, status, careLevel, page, size int) ([]model.Elder, int64, error) {
	return s.repo.List(ctx, keyword, status, careLevel, page, size)
}
func (s *ElderService) ListScoped(ctx context.Context, keyword string, status, careLevel, page, size int, allowed []uint) ([]model.Elder, int64, error) {
	return s.repo.ListScoped(ctx, keyword, status, careLevel, page, size, allowed)
}
func (s *ElderService) Get(ctx context.Context, id uint) (*model.Elder, error) {
	return s.repo.Get(ctx, id)
}
func (s *ElderService) Create(ctx context.Context, e *model.Elder) error {
	return s.repo.Create(ctx, e)
}
func (s *ElderService) Update(ctx context.Context, e *model.Elder) error {
	return s.repo.Update(ctx, e)
}
func (s *ElderService) Delete(ctx context.Context, id uint) error {
	return s.repo.Delete(ctx, id)
}

// ResourceService 房间/床位。
type ResourceService struct {
	repo *repository.ResourceRepository
}

func NewResourceService(repo *repository.ResourceRepository) *ResourceService {
	return &ResourceService{repo: repo}
}

func (s *ResourceService) ListRooms(ctx context.Context, building string, floor, page, size int) ([]model.Room, int64, error) {
	return s.repo.ListRooms(ctx, building, floor, page, size)
}
func (s *ResourceService) ListBeds(ctx context.Context, roomID uint, status string, page, size int) ([]model.Bed, int64, error) {
	return s.repo.ListBeds(ctx, roomID, status, page, size)
}

// TaskService 护理任务。
type TaskService struct{ repo *repository.TaskRepository }

var ErrTaskNotAssigned = errors.New("care task is assigned to another caregiver")

func NewTaskService(repo *repository.TaskRepository) *TaskService {
	return &TaskService{repo: repo}
}

func (s *TaskService) List(ctx context.Context, elderID uint, status string, assigneeID uint, page, size int) ([]model.CareTask, int64, error) {
	return s.repo.List(ctx, elderID, status, assigneeID, page, size)
}
func (s *TaskService) Get(ctx context.Context, id uint) (*model.CareTask, error) {
	return s.repo.Get(ctx, id)
}
func (s *TaskService) Create(ctx context.Context, t *model.CareTask) error {
	return s.repo.Create(ctx, t)
}
func (s *TaskService) SetStatus(ctx context.Context, id uint, status string, executorID uint, executor, result string) error {
	t, err := s.repo.Get(ctx, id)
	if err != nil {
		return err
	}
	if t.AssigneeID != nil && *t.AssigneeID != executorID {
		return ErrTaskNotAssigned
	}
	if t.Status == status {
		return nil
	}
	valid := t.Status == "todo" && status == "doing" || t.Status == "doing" && status == "done"
	if !valid {
		return repository.ErrTaskStateConflict
	}
	if result == "" && status == "done" {
		result = "任务已按护理计划完成"
	}
	return s.repo.SetStatus(ctx, id, t.Status, status, executorID, executor, truncateRunes(result, 1024))
}

// HealthService 健康体征；录入时按阈值自动判定异常。
type HealthService struct{ repo *repository.HealthRepository }

func NewHealthService(repo *repository.HealthRepository) *HealthService {
	return &HealthService{repo: repo}
}

func (s *HealthService) ListByElder(ctx context.Context, elderID uint, page, size int) ([]model.HealthRecord, int64, error) {
	return s.repo.ListByElder(ctx, elderID, page, size)
}

// Create 录入体征，自动化异常标记（参考 nursing_home 触发器阈值）。
func (s *HealthService) Create(ctx context.Context, hr *model.HealthRecord) error {
	if hr.RecordTime.IsZero() {
		hr.RecordTime = time.Now()
	}
	if hr.Source == "" {
		hr.Source = "manual"
	}
	hr.IsAbnormal = abnormal(hr)
	return s.repo.Create(ctx, hr)
}

func abnormal(hr *model.HealthRecord) bool {
	if hr.Temperature != nil && (*hr.Temperature < 36.0 || *hr.Temperature > 37.3) {
		return true
	}
	if hr.Systolic != nil && (*hr.Systolic < 90 || *hr.Systolic > 140) {
		return true
	}
	if hr.Diastolic != nil && (*hr.Diastolic < 60 || *hr.Diastolic > 90) {
		return true
	}
	if hr.HeartRate != nil && (*hr.HeartRate < 60 || *hr.HeartRate > 100) {
		return true
	}
	if hr.Spo2 != nil && *hr.Spo2 < 90 {
		return true
	}
	return false
}
