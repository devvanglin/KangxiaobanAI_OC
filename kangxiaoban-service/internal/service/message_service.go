package service

import (
	"time"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

type MessageService struct{ repo *repository.MessageRepository }

func NewMessageService(repo *repository.MessageRepository) *MessageService {
	return &MessageService{repo: repo}
}
func (s *MessageService) List(userID, peerID uint, elderID *uint, page, size int) ([]model.Message, int64, error) {
	return s.repo.List(userID, peerID, elderID, page, size)
}
func (s *MessageService) Send(senderID, receiverID uint, elderID *uint, content, typ string) (*model.Message, error) {
	m := &model.Message{SenderID: senderID, ReceiverID: receiverID, ElderID: elderID, Content: content, Type: typ, SentAt: time.Now()}
	if m.Type == "" {
		m.Type = "chat"
	}
	return m, s.repo.Create(m)
}
func (s *MessageService) MarkRead(userID, messageID uint) error {
	return s.repo.MarkRead(userID, messageID)
}
func (s *MessageService) SeedCount() (int64, error) { return s.repo.SeedCount() }
