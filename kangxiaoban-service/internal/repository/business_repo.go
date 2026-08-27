package repository

import (
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// ElderRepository 长者数据访问。
type ElderRepository struct{ db *gorm.DB }

func NewElderRepository(db *gorm.DB) *ElderRepository { return &ElderRepository{db: db} }

func (r *ElderRepository) List(keyword string, status, careLevel int, page, size int) ([]model.Elder, int64, error) {
	q := r.db.Model(&model.Elder{})
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

func (r *ElderRepository) Get(id uint) (*model.Elder, error) {
	var e model.Elder
	err := r.db.Preload("Bed").First(&e, id).Error
	return &e, err
}

func (r *ElderRepository) Create(e *model.Elder) error { return r.db.Create(e).Error }
func (r *ElderRepository) Update(e *model.Elder) error { return r.db.Save(e).Error }
func (r *ElderRepository) Delete(id uint) error        { return r.db.Delete(&model.Elder{}, id).Error }

// ResourceRepository 房间 + 床位。
type ResourceRepository struct{ db *gorm.DB }

func NewResourceRepository(db *gorm.DB) *ResourceRepository { return &ResourceRepository{db: db} }

func (r *ResourceRepository) ListRooms(building string, floor int, page, size int) ([]model.Room, int64, error) {
	q := r.db.Model(&model.Room{})
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

func (r *ResourceRepository) ListBeds(roomID uint, status string, page, size int) ([]model.Bed, int64, error) {
	q := r.db.Model(&model.Bed{})
	if roomID > 0 {
		q = q.Where("room_id = ?", roomID)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Bed
	err := q.Preload("Room").Order("room_id, id").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *ResourceRepository) GetBed(id uint) (*model.Bed, error) {
	var b model.Bed
	err := r.db.Preload("Room").First(&b, id).Error
	return &b, err
}

// TaskRepository 护理任务。
type TaskRepository struct{ db *gorm.DB }

func NewTaskRepository(db *gorm.DB) *TaskRepository { return &TaskRepository{db: db} }

func (r *TaskRepository) List(elderID uint, status string, page, size int) ([]model.CareTask, int64, error) {
	q := r.db.Model(&model.CareTask{})
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
	var items []model.CareTask
	err := q.Order("created_at desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *TaskRepository) Get(id uint) (*model.CareTask, error) {
	var t model.CareTask
	err := r.db.First(&t, id).Error
	return &t, err
}

func (r *TaskRepository) Create(t *model.CareTask) error { return r.db.Create(t).Error }
func (r *TaskRepository) Update(t *model.CareTask) error { return r.db.Save(t).Error }

// HealthRepository 健康体征。
type HealthRepository struct{ db *gorm.DB }

func NewHealthRepository(db *gorm.DB) *HealthRepository { return &HealthRepository{db: db} }

func (r *HealthRepository) ListByElder(elderID uint, page, size int) ([]model.HealthRecord, int64, error) {
	var total int64
	if err := r.db.Model(&model.HealthRecord{}).Where("elder_id = ?", elderID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.HealthRecord
	err := r.db.Where("elder_id = ?", elderID).Order("record_time desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *HealthRepository) Create(hr *model.HealthRecord) error { return r.db.Create(hr).Error }