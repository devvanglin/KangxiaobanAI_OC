package repository

import (
	"context"
	"errors"
	"kangxiaoban-service/internal/model"
	"strings"
	"time"

	"gorm.io/gorm"
)

// ElderRepository 长者数据访问。
type ElderRepository struct{ db *gorm.DB }

func NewElderRepository(db *gorm.DB) *ElderRepository { return &ElderRepository{db: db} }

func (r *ElderRepository) List(ctx context.Context, keyword string, status, careLevel int, page, size int) ([]model.Elder, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Elder{})
	if keyword != "" {
		q = q.Where("(name LIKE ? OR id_card LIKE ? OR contact_phone LIKE ?)", "%"+keyword+"%", "%"+keyword+"%", "%"+keyword+"%")
	}
	if status > 0 {
		q = q.Where("status = ?", status)
	}
	if careLevel > 0 {
		q = q.Where("care_level = ?", careLevel)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Elder
	err := q.Preload("Bed").Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ElderRepository) Get(ctx context.Context, id uint) (*model.Elder, error) {
	var e model.Elder
	err := r.db.WithContext(ctx).Preload("Bed").First(&e, id).Error
	return &e, err
}

func (r *ElderRepository) Create(ctx context.Context, e *model.Elder) error {
	return r.db.WithContext(ctx).Create(e).Error
}
func (r *ElderRepository) Update(ctx context.Context, e *model.Elder) error {
	// Never let a request body move an elder between tenants or overwrite
	// lifecycle timestamps. Update only the editable domain columns.
	if v, ok := ctx.Value(model.TenantContextKey).(uint); ok && v > 0 {
		e.TenantID = v
	}
	return r.db.WithContext(ctx).Model(&model.Elder{}).Where("id = ?", e.ID).Select(
		"Name", "IDCard", "Gender", "BirthDate", "ContactPhone", "CareLevel", "Status", "BedID", "EmergencyContacts", "Allergies", "Image", "Remark",
	).Updates(e).Error
}
func (r *ElderRepository) Delete(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&model.Elder{}, id).Error
}

// ResourceRepository 房间 + 床位。
type ResourceRepository struct{ db *gorm.DB }

func NewResourceRepository(db *gorm.DB) *ResourceRepository { return &ResourceRepository{db: db} }

func (r *ResourceRepository) ListRooms(ctx context.Context, building string, floor int, page, size int) ([]model.Room, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Room{})
	if building != "" {
		q = q.Where("building = ?", building)
	}
	if floor > 0 {
		q = q.Where("floor = ?", floor)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Room
	err := q.Preload("Beds").Order("building, floor, room_no").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ResourceRepository) ListBeds(ctx context.Context, roomID uint, status string, page, size int) ([]model.Bed, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.Bed{})
	if roomID > 0 {
		q = q.Where("room_id = ?", roomID)
	}
	if status != "" {
		q = q.Where("status = ?", status)
		// A free bed in a maintenance room is not actually assignable. Keep it
		// out of the availability list so the admission form does not present a
		// choice that can only fail after submission. Use a tenant-scoped
		// subquery instead of a join: both tables carry tenant_id and a join
		// would make the shared tenant callback's unqualified predicate
		// ambiguous on SQLite/MySQL.
		if strings.EqualFold(strings.TrimSpace(status), "free") {
			maintenanceRooms := r.db.WithContext(ctx).Model(&model.Room{}).
				Select("id").Where("LOWER(COALESCE(status, '')) = ?", "maintenance")
			q = q.Where("room_id NOT IN (?)", maintenanceRooms)
		}
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Bed
	err := q.Preload("Room").Order("room_id, id").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ResourceRepository) GetBed(ctx context.Context, id uint) (*model.Bed, error) {
	var b model.Bed
	err := r.db.WithContext(ctx).Preload("Room").First(&b, id).Error
	return &b, err
}

func (r *ResourceRepository) CreateBed(ctx context.Context, bed *model.Bed) error {
	return r.db.WithContext(ctx).Create(bed).Error
}

func (r *ResourceRepository) DeleteBed(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&model.Bed{}, id).Error
}

// UnassignEldersFromBed clears the resident assignment of a bed that is about
// to be removed, so no profile keeps pointing at a deleted bed.
func (r *ResourceRepository) UnassignEldersFromBed(ctx context.Context, bedID uint) error {
	return r.db.WithContext(ctx).Model(&model.Elder{}).Where("bed_id = ?", bedID).
		Update("bed_id", nil).Error
}

func (r *ResourceRepository) FindArea(ctx context.Context, id uint) (*model.Area, error) {
	var area model.Area
	if err := r.db.WithContext(ctx).First(&area, id).Error; err != nil {
		return nil, err
	}
	return &area, nil
}

func (r *ResourceRepository) FindRoomByID(ctx context.Context, id uint) (*model.Room, error) {
	var room model.Room
	if err := r.db.WithContext(ctx).Preload("Beds").First(&room, id).Error; err != nil {
		return nil, err
	}
	return &room, nil
}

// FindRoomByKey resolves the historical room matching a floor-plan room area
// through the same building/floor/room_no key the clients use.
func (r *ResourceRepository) FindRoomByKey(ctx context.Context, building string, floor int, roomNo string) (*model.Room, error) {
	var room model.Room
	if err := r.db.WithContext(ctx).Preload("Beds").
		Where("building = ? AND floor = ? AND room_no = ?", building, floor, roomNo).
		First(&room).Error; err != nil {
		return nil, err
	}
	return &room, nil
}

func (r *ResourceRepository) CreateRoom(ctx context.Context, room *model.Room) error {
	return r.db.WithContext(ctx).Create(room).Error
}

// TaskRepository 护理任务。
type TaskRepository struct{ db *gorm.DB }

func NewTaskRepository(db *gorm.DB) *TaskRepository { return &TaskRepository{db: db} }

func (r *TaskRepository) List(ctx context.Context, elderID uint, status string, assigneeID uint, page, size int) ([]model.CareTask, int64, error) {
	q := r.db.WithContext(ctx).Model(&model.CareTask{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if assigneeID > 0 {
		q = q.Where("assignee_id = ? OR assignee_id IS NULL", assigneeID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.CareTask
	err := q.Preload("PlanItem").Order("created_at desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *TaskRepository) Get(ctx context.Context, id uint) (*model.CareTask, error) {
	var t model.CareTask
	err := r.db.WithContext(ctx).Preload("PlanItem").First(&t, id).Error
	return &t, err
}

func (r *TaskRepository) Create(ctx context.Context, t *model.CareTask) error {
	return r.db.WithContext(ctx).Create(t).Error
}
func (r *TaskRepository) Update(t *model.CareTask) error { return r.db.Save(t).Error }

var ErrTaskStateConflict = errors.New("care task state conflict")

// SetStatus updates the task and writes the linked plan execution in one transaction.
func (r *TaskRepository) SetStatus(ctx context.Context, id uint, fromStatus, toStatus string, executorID uint, executor, result string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var task model.CareTask
		if err := tx.First(&task, id).Error; err != nil {
			return err
		}
		if toStatus == "done" && task.PlanItemID != nil {
			var item model.CarePlanItem
			if err := tx.First(&item, *task.PlanItemID).Error; err != nil {
				return err
			}
			var plan model.CarePlan
			if err := tx.First(&plan, item.CarePlanID).Error; err != nil {
				return err
			}
			if !item.Active || plan.Status != "active" || plan.ElderID != task.ElderID {
				return ErrTaskStateConflict
			}
		}
		updates := map[string]interface{}{"status": toStatus}
		if task.AssigneeID == nil && executorID > 0 {
			updates["assignee_id"] = executorID
			updates["assignee"] = executor
		}
		updated := tx.Model(&model.CareTask{}).Where("id = ? AND status = ?", id, fromStatus).Updates(updates)
		if updated.Error != nil {
			return updated.Error
		}
		if updated.RowsAffected != 1 {
			return ErrTaskStateConflict
		}
		if toStatus != "done" || task.PlanItemID == nil {
			return nil
		}
		executorName := strings.TrimSpace(task.Assignee)
		if executorName == "" {
			executorName = executor
		}
		execution := model.CareExecution{
			PlanItemID: *task.PlanItemID, ElderID: task.ElderID, ExecutorID: executorID,
			Executor: executorName, Status: "completed", ExecutedAt: time.Now(), Result: result,
		}
		return tx.Create(&execution).Error
	})
}

// HealthRepository 健康体征。
type HealthRepository struct{ db *gorm.DB }

func NewHealthRepository(db *gorm.DB) *HealthRepository { return &HealthRepository{db: db} }

func (r *HealthRepository) ListByElder(ctx context.Context, elderID uint, page, size int) ([]model.HealthRecord, int64, error) {
	db := r.db.WithContext(ctx)
	var total int64
	if err := db.Model(&model.HealthRecord{}).Where("elder_id = ?", elderID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.HealthRecord
	err := db.Where("elder_id = ?", elderID).Order("record_time desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *HealthRepository) Create(ctx context.Context, hr *model.HealthRecord) error {
	return r.db.WithContext(ctx).Create(hr).Error
}

func (r *HealthRepository) ListThresholds(ctx context.Context) ([]model.HealthThreshold, error) {
	var thresholds []model.HealthThreshold
	err := r.db.WithContext(ctx).Order("sort_order, id").Find(&thresholds).Error
	return thresholds, err
}
