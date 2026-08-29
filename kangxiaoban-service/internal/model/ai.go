package model

import "time"

// AIPromptSuggestion is a tenant-owned starter prompt shown by the AI client.
// Institutions can edit or disable rows without rebuilding any client.
type AIPromptSuggestion struct {
	Base
	Code       string `gorm:"size:64;index;not null" json:"code"`
	GroupIndex int    `gorm:"index;not null" json:"group_index"`
	Title      string `gorm:"size:255;not null" json:"title"`
	Prompt     string `gorm:"size:1024;not null" json:"prompt"`
	SortOrder  int    `gorm:"index;not null" json:"sort_order"`
	Enabled    bool   `gorm:"default:true;index" json:"enabled"`
}

func (AIPromptSuggestion) TableName() string { return "ai_prompt_suggestions" }

// AIConversation is one authenticated user's isolated AI chat thread.
type AIConversation struct {
	Base
	UserID        uint        `gorm:"index:idx_ai_conversations_user_updated,priority:1;not null" json:"user_id"`
	Title         string      `gorm:"size:120;not null" json:"title"`
	IsDefault     bool        `gorm:"index" json:"is_default"`
	LastMessageAt *time.Time  `gorm:"index:idx_ai_conversations_user_updated,priority:2" json:"last_message_at"`
	Messages      []AIMessage `gorm:"foreignKey:ConversationID;constraint:OnDelete:CASCADE" json:"-"`
}

// AIMessage is one immutable user or assistant message in an AI conversation.
type AIMessage struct {
	Base
	ConversationID uint      `gorm:"index:idx_ai_messages_conversation_sent,priority:1;not null" json:"conversation_id"`
	UserID         uint      `gorm:"index;not null" json:"user_id"`
	Role           string    `gorm:"size:16;not null" json:"role"`
	Content        string    `gorm:"type:text;not null" json:"content"`
	Model          string    `gorm:"size:128" json:"model"`
	SentAt         time.Time `gorm:"index:idx_ai_messages_conversation_sent,priority:2;not null" json:"sent_at"`
}
