package service

import (
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
	"time"
)

type NotificationService struct {
	repo *repository.NotificationRepository
}

func NewNotificationService(repo *repository.NotificationRepository) *NotificationService {
	return &NotificationService{repo: repo}
}
func (s *NotificationService) List(userID uint, roles []string, unread bool, page, size int) ([]model.Notification, int64, error) {
	return s.repo.List(userID, roles, unread, page, size)
}
func (s *NotificationService) MarkRead(id, userID uint, roles []string) error {
	return s.repo.MarkRead(id, userID, roles)
}
func (s *NotificationService) CreateRoleNotification(role, typ, title, content, severity string) error {
	now := time.Now()
	return s.repo.Create(&model.Notification{Role: role, Channel: "in_app", Type: typ, Title: title, Content: content, Severity: severity, SentAt: &now})
}
