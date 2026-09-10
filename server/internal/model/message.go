package model

import "time"

// Message 用户间消息。消息同时关联发送者、接收者和长者，保证护理沟通可追溯。
type Message struct {
	Base
	SenderID   uint       `gorm:"index;not null" json:"sender_id"`
	ReceiverID uint       `gorm:"index;not null" json:"receiver_id"`
	ElderID    *uint      `gorm:"index" json:"elder_id"`
	Content    string     `gorm:"size:2048;not null" json:"content"`
	Type       string     `gorm:"size:32;default:chat" json:"type"`
	SentAt     time.Time  `json:"sent_at"`
	ReadAt     *time.Time `json:"read_at"`
}
