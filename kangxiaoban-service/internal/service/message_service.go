package service

import (
	"context"
	"errors"
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

type MessageService struct{ repo *repository.MessageRepository }

var ErrMessagePeerUnavailable = errors.New("message peer is unavailable in current tenant")

func NewMessageService(repo *repository.MessageRepository) *MessageService {
	return &MessageService{repo: repo}
}
func (s *MessageService) List(ctx context.Context, userID, peerID uint, elderID *uint, page, size int) ([]model.Message, int64, error) {
	if err := s.repo.RequireActiveUser(ctx, userID); err != nil {
		return nil, 0, ErrMessagePeerUnavailable
	}
	if err := s.repo.RequireActiveUser(ctx, peerID); err != nil {
		return nil, 0, ErrMessagePeerUnavailable
	}
	return s.repo.List(ctx, userID, peerID, elderID, page, size)
}
func (s *MessageService) Send(ctx context.Context, senderID, receiverID uint, elderID *uint, content, typ string) (*model.Message, error) {
	if err := s.repo.RequireActiveUser(ctx, senderID); err != nil {
		return nil, ErrMessagePeerUnavailable
	}
	if err := s.repo.RequireActiveUser(ctx, receiverID); err != nil {
		return nil, ErrMessagePeerUnavailable
	}
	m := &model.Message{SenderID: senderID, ReceiverID: receiverID, ElderID: elderID, Content: content, Type: typ, SentAt: time.Now()}
	if m.Type == "" {
		m.Type = "chat"
	}
	return m, s.repo.Create(ctx, m)
}
func (s *MessageService) MarkRead(ctx context.Context, userID, messageID uint) error {
	return s.repo.MarkRead(ctx, userID, messageID)
}
func (s *MessageService) SeedCount() (int64, error) { return s.repo.SeedCount() }
