package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/healthrisk"
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
func (s *ElderService) Get(ctx context.Context, id uint) (*model.Elder, error) {
	return s.repo.Get(ctx, id)
}
func (s *ElderService) Create(ctx context.Context, e *model.Elder) error {
	if e.Allergies == nil {
		e.Allergies = []string{}
	}
	return s.repo.Create(ctx, e)
}
func (s *ElderService) Update(ctx context.Context, e *model.Elder) error {
	// Older clients do not send allergies. Preserve the stored array unless the
	// caller explicitly sends an array (including an empty array to clear it).
	if e.Allergies == nil {
		current, err := s.repo.Get(ctx, e.ID)
		if err != nil {
			return err
		}
		e.Allergies = current.Allergies
	}
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
func (s *ResourceService) CreateBed(ctx context.Context, bed *model.Bed) error {
	return s.repo.CreateBed(ctx, bed)
}

// 床位设置的业务规则错误，由 handler 映射为具体状态码。
var (
	ErrAreaNotRoom     = errors.New("area is not a room")
	ErrRoomNotFound    = errors.New("room not found")
	ErrBedNumberExists = errors.New("bed number already exists")
	ErrBedLimitReached = errors.New("room already has two beds")
	ErrBedNotRemovable = errors.New("bed is occupied or unavailable")
)

// EnsureRoomForArea returns the historical room matching a floor-plan room
// area, provisioning the record on demand so rooms drawn on the map can hold
// beds without a legacy room row.
func (s *ResourceService) EnsureRoomForArea(ctx context.Context, areaID uint) (*model.Room, error) {
	area, err := s.repo.FindArea(ctx, areaID)
	if err != nil {
		return nil, err
	}
	if area.Type != model.AreaTypeRoom {
		return nil, ErrAreaNotRoom
	}
	room, err := s.repo.FindRoomByKey(ctx, area.Building, area.FloorNo, area.Name)
	if err == nil {
		return room, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	room = &model.Room{Building: area.Building, Floor: area.FloorNo, RoomNo: area.Name}
	if err := s.repo.CreateRoom(ctx, room); err != nil {
		return nil, err
	}
	return room, nil
}

// CreateBedInRoom validates duplicate numbers and the two-bed room limit
// before insert.
func (s *ResourceService) CreateBedInRoom(ctx context.Context, bed *model.Bed) error {
	room, err := s.repo.FindRoomByID(ctx, bed.RoomID)
	if err != nil {
		return err
	}
	for _, item := range room.Beds {
		if item.BedNo == bed.BedNo {
			return ErrBedNumberExists
		}
	}
	if len(room.Beds) >= 2 {
		return ErrBedLimitReached
	}
	return s.repo.CreateBed(ctx, bed)
}

// DeleteBed removes a bed that no resident occupies.
func (s *ResourceService) DeleteBed(ctx context.Context, id uint) error {
	bed, err := s.repo.GetBed(ctx, id)
	if err != nil {
		return err
	}
	if bed.ElderID != nil || !strings.EqualFold(strings.TrimSpace(bed.Status), "free") {
		return ErrBedNotRemovable
	}
	return s.repo.DeleteBed(ctx, id)
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
	t.Category = normalizeTaskCategory(t.Category, t.Kind)
	t.Priority = normalizeTaskPriority(t.Priority, "")
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

// Create records vitals and derives the aggregate risk from tenant-owned database thresholds.
func (s *HealthService) Create(ctx context.Context, hr *model.HealthRecord) error {
	if hr.RecordTime.IsZero() {
		hr.RecordTime = time.Now()
	}
	if hr.Source == "" {
		hr.Source = "manual"
	}
	thresholds, err := s.repo.ListThresholds(ctx)
	if err != nil {
		return err
	}
	level, summary, err := healthrisk.Evaluate(hr, thresholds)
	if err != nil {
		return err
	}
	hr.RiskLevel = level
	hr.RiskSummary = summary
	hr.IsAbnormal = level != "normal"
	return s.repo.Create(ctx, hr)
}

func normalizeTaskCategory(category, kind string) string {
	switch category {
	case "todo", "medication", "record", "report":
		return category
	}
	switch kind {
	case "medication":
		return "medication"
	case "health", "vital", "assessment":
		return "record"
	case "report":
		return "report"
	default:
		return "todo"
	}
}

func normalizeTaskPriority(priority, riskLevel string) string {
	switch priority {
	case "normal", "warning", "danger":
		return priority
	}
	switch riskLevel {
	case "critical", "high", "danger":
		return "danger"
	case "medium", "warning":
		return "warning"
	default:
		return "normal"
	}
}
