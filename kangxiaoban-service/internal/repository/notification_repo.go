package repository

import (
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
	"time"
)

type NotificationRepository struct{ db *gorm.DB }

func NewNotificationRepository(db *gorm.DB) *NotificationRepository {
	return &NotificationRepository{db: db}
}

func (r *NotificationRepository) List(userID uint, roles []string, unreadOnly bool, page, size int) ([]model.Notification, int64, error) {
	q := r.db.Model(&model.Notification{}).Where("user_id = ? OR role IN ?", userID, roles)
	if unreadOnly {
		q = q.Where("read_at IS NULL")
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.Notification
	err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
}
func (r *NotificationRepository) MarkRead(id, userID uint, roles []string) error {
	now := time.Now()
	return r.db.Model(&model.Notification{}).Where("id = ? AND (user_id = ? OR role IN ?)", id, userID, roles).Update("read_at", &now).Error
}
func (r *NotificationRepository) Create(n *model.Notification) error { return r.db.Create(n).Error }
