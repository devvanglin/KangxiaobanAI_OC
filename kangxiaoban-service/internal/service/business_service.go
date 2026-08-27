package service

import (
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// ElderService 长者档案。
type ElderService struct{ repo *repository.ElderRepository }

func NewElderService(repo *repository.ElderRepository) *ElderService {
	return &ElderService{repo: repo}
}

func (s *ElderService) List(keyword string, status, careLevel, page, size int) ([]model.Elder, int64, error) {
	return s.repo.List(keyword, status, careLevel, page, size)
}
func (s *ElderService) Get(id uint) (*model.Elder, error) { return s.repo.Get(id) }
func (s *ElderService) Create(e *model.Elder) error       { return s.repo.Create(e) }
func (s *ElderService) Update(e *model.Elder) error       { return s.repo.Update(e) }
func (s *ElderService) Delete(id uint) error              { return s.repo.Delete(id) }

// ResourceService 房间/床位。
type ResourceService struct{ repo *repository.ResourceRepository }

func NewResourceService(repo *repository.ResourceRepository) *ResourceService {
	return &ResourceService{repo: repo}
}

func (s *ResourceService) ListRooms(building string, floor, page, size int) ([]model.Room, int64, error) {
	return s.repo.ListRooms(building, floor, page, size)
}
func (s *ResourceService) ListBeds(roomID uint, status string, page, size int) ([]model.Bed, int64, error) {
	return s.repo.ListBeds(roomID, status, page, size)
}

// TaskService 护理任务。
type TaskService struct{ repo *repository.TaskRepository }

func NewTaskService(repo *repository.TaskRepository) *TaskService {
	return &TaskService{repo: repo}
}

func (s *TaskService) List(elderID uint, status string, page, size int) ([]model.CareTask, int64, error) {
	return s.repo.List(elderID, status, page, size)
}
func (s *TaskService) Create(t *model.CareTask) error { return s.repo.Create(t) }
func (s *TaskService) SetStatus(id uint, status string) error {
	t, err := s.repo.Get(id)
	if err != nil {
		return err
	}
	t.Status = status
	return s.repo.Update(t)
}

// HealthService 健康体征；录入时按阈值自动判定异常。
type HealthService struct{ repo *repository.HealthRepository }

func NewHealthService(repo *repository.HealthRepository) *HealthService {
	return &HealthService{repo: repo}
}

func (s *HealthService) ListByElder(elderID uint, page, size int) ([]model.HealthRecord, int64, error) {
	return s.repo.ListByElder(elderID, page, size)
}

// Create 录入体征，自动化异常标记（参考 nursing_home 触发器阈值）。
func (s *HealthService) Create(hr *model.HealthRecord) error {
	if hr.RecordTime.IsZero() {
		hr.RecordTime = time.Now()
	}
	if hr.Source == "" {
		hr.Source = "manual"
	}
	hr.IsAbnormal = abnormal(hr)
	return s.repo.Create(hr)
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