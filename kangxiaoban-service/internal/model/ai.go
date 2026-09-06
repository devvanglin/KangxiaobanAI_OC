package model

import "time"

// AIPromptSuggestion is a tenant-owned starter prompt shown by the AI client.
// Institutions can edit or disable rows without rebuilding any client.
type AIPromptSuggestion struct {
	Base
	RoleScope  string `gorm:"size:16;default:all;index" json:"role_scope"`
	Code       string `gorm:"size:64;index;not null" json:"code"`
	GroupIndex int    `gorm:"index;not null" json:"group_index"`
	Title      string `gorm:"size:255;not null" json:"title"`
	Prompt     string `gorm:"size:1024;not null" json:"prompt"`
	SortOrder  int    `gorm:"index;not null" json:"sort_order"`
	Enabled    bool   `gorm:"default:true;index" json:"enabled"`
}

func (AIPromptSuggestion) TableName() string { return "ai_prompt_suggestions" }

// AIModelConfig is tenant-owned configuration for one role's AI gateway.
// API keys are deliberately never serialized.
type AIModelConfig struct {
	Base
	RoleScope          string  `gorm:"size:16;index;not null" json:"role_scope"`
	Name               string  `gorm:"size:128;not null" json:"name"`
	Provider           string  `gorm:"size:16;not null" json:"provider"`
	BaseURL            string  `gorm:"size:512" json:"base_url"`
	Model              string  `gorm:"size:128;not null" json:"model"`
	APIKeyEncrypted    string  `gorm:"size:2048" json:"-"`
	SystemPrompt       string  `gorm:"type:text" json:"system_prompt"`
	ContextWindow      int     `gorm:"default:8192" json:"context_window"`
	Temperature        float64 `gorm:"default:0.3" json:"temperature"`
	Enabled            bool    `gorm:"default:true;index" json:"enabled"`
	Allowed            bool    `gorm:"default:true" json:"allowed"`
	IsDefault          bool    `gorm:"default:false;index" json:"is_default"`
	RAGEnabled         bool    `gorm:"default:false" json:"rag_enabled"`
	RAGBaseURL         string  `gorm:"size:512" json:"rag_base_url"`
	RAGDatasetID       string  `gorm:"size:128" json:"rag_dataset_id"`
	RAGAPIKeyEncrypted string  `gorm:"size:2048" json:"-"`
}

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

// AIUsageLog is one immutable per-call AI gateway usage record. It powers the
// admin model page stat cards and never contains message content.
type AIUsageLog struct {
	Base
	UserID           uint   `gorm:"index;not null" json:"user_id"`
	RoleScope        string `gorm:"size:16;index" json:"role_scope"`
	ConfigID         uint   `gorm:"index" json:"config_id"`
	Provider         string `gorm:"size:16" json:"provider"`
	Model            string `gorm:"size:128" json:"model"`
	PromptTokens     int64  `gorm:"not null;default:0" json:"prompt_tokens"`
	CompletionTokens int64  `gorm:"not null;default:0" json:"completion_tokens"`
	TotalTokens      int64  `gorm:"not null;default:0;index" json:"total_tokens"`
	RAGUsed          bool   `gorm:"not null;index" json:"rag_used"`
	Success          bool   `gorm:"not null" json:"success"`
	DurationMS       int64  `gorm:"not null;default:0" json:"duration_ms"`
}

func (AIUsageLog) TableName() string { return "ai_usage_logs" }
