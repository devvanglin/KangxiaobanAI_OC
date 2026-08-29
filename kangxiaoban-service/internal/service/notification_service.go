package service

import (
	"context"
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
func (s *NotificationService) List(ctx context.Context, userID uint, roles []string, unread bool, page, size int) ([]model.Notification, int64, error) {
	return s.repo.List(ctx, userID, roles, unread, page, size)
}
func (s *NotificationService) MarkRead(ctx context.Context, id, userID uint, roles []string) error {
	return s.repo.MarkRead(ctx, id, userID, roles)
}
func (s *NotificationService) CreateRoleNotification(role, typ, title, content, severity string) error {
	return s.CreateRoleNotificationContext(context.Background(), 1, role, typ, title, content, severity)
}

// CreateRoleNotificationContext writes a notification under the caller's
// tenant. The explicit tenant value protects background IoT callbacks from
// falling back to the default tenant.
func (s *NotificationService) CreateRoleNotificationContext(ctx context.Context, tenantID uint, role, typ, title, content, severity string) error {
	if tenantID > 0 {
		ctx = context.WithValue(ctx, model.TenantContextKey, tenantID)
	}
	now := time.Now()
	return s.repo.CreateContext(ctx, &model.Notification{Role: role, Channel: "in_app", Type: typ, Title: title, Content: content, Severity: severity, SentAt: &now})
}
