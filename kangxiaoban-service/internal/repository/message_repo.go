package repository

import (
	"time"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

type MessageRepository struct{ db *gorm.DB }

func NewMessageRepository(db *gorm.DB) *MessageRepository { return &MessageRepository{db: db} }

func (r *MessageRepository) List(userID, peerID uint, elderID *uint, page, size int) ([]model.Message, int64, error) {
	q := r.db.Model(&model.Message{}).Where("(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)", userID, peerID, peerID, userID)
	if elderID != nil {
		q = q.Where("elder_id = ?", *elderID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Message
	err := q.Order("sent_at asc, id asc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (r *MessageRepository) Create(m *model.Message) error { return r.db.Create(m).Error }

func (r *MessageRepository) MarkRead(userID, messageID uint) error {
	now := time.Now()
	result := r.db.Model(&model.Message{}).Where("id = ? AND receiver_id = ?", messageID, userID).Update("read_at", &now)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *MessageRepository) SeedCount() (int64, error) {
	var n int64
	err := r.db.Model(&model.Message{}).Count(&n).Error
	return n, err
}
