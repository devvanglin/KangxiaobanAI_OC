package model

import "time"

// IotDevice 物联网设备（雷达/床垫/血压计等）。
type IotDevice struct {
	Base
	DeviceID        string     `gorm:"size:64;uniqueIndex;not null" json:"device_id"`
	Product         string     `gorm:"size:32" json:"product"`                         // breath_radar / fall_radar / ...
	DeviceType      string     `gorm:"size:24;default:other;index" json:"device_type"` // millimeter_wave/camera/other
	Building        string     `gorm:"size:16" json:"building"`
	Room            string     `gorm:"size:16" json:"room"`
	Bed             string     `gorm:"size:8" json:"bed"`
	AreaID          *uint      `gorm:"index" json:"area_id"`
	ElderID         *uint      `json:"elder_id"`
	Online          int8       `gorm:"default:0" json:"online"` // 1在线 0离线
	Battery         *int       `json:"battery"`
	LastSeen        *time.Time `json:"last_seen"`
	Protocol        string     `gorm:"size:16;default:MQTT" json:"protocol"`
	StreamURL       string     `gorm:"size:512" json:"stream_url,omitempty"`
	StreamStatus    string     `gorm:"size:16;default:unknown" json:"stream_status"`
	DiscoveryStatus string     `gorm:"size:16;default:claimed;index" json:"discovery_status"` // pending/claimed/disabled
}

// SignalRecord 设备归一化体征/事件。
type SignalRecord struct {
	Base
	DeviceID string    `gorm:"size:64;index" json:"device_id"`
	ElderID  *uint     `gorm:"index" json:"elder_id"`
	Type     string    `gorm:"size:32;index" json:"type"`
	Value    string    `gorm:"size:64" json:"value"`
	TS       time.Time `json:"ts"`
}

// Alert 告警。级别 emergency/important/info；状态 new/handling/handled/closed。
type Alert struct {
	Base
	ElderID    *uint      `gorm:"index" json:"elder_id"`
	DeviceID   string     `gorm:"size:64;index" json:"device_id"`
	Type       string     `gorm:"size:32" json:"type"`
	Level      string     `gorm:"size:16" json:"level"`
	Content    string     `gorm:"size:255" json:"content"`
	Status     string     `gorm:"size:16;default:new" json:"status"`
	HandledBy  string     `gorm:"size:64" json:"handled_by"`
	CreateTime time.Time  `json:"create_time"`
	CloseTime  *time.Time `json:"close_time"`
}

// AlertAction 告警处置时间线。
type AlertAction struct {
	Base
	AlertID uint   `gorm:"index;not null" json:"alert_id"`
	UserID  uint   `gorm:"index" json:"user_id"`
	Action  string `gorm:"size:32;not null" json:"action"` // acknowledge/assign/note/escalate/resolve/close
	Note    string `gorm:"size:2048" json:"note"`
}

// Notification 应用内通知记录；短信/Push/微信等由后续 Provider 消费。
type Notification struct {
	Base
	UserID   uint       `gorm:"index" json:"user_id"`
	Role     string     `gorm:"size:32;index" json:"role"`
	Channel  string     `gorm:"size:16;default:in_app" json:"channel"`
	Type     string     `gorm:"size:32" json:"type"`
	Title    string     `gorm:"size:128" json:"title"`
	Content  string     `gorm:"size:1024" json:"content"`
	Severity string     `gorm:"size:16" json:"severity"`
	ReadAt   *time.Time `json:"read_at"`
	SentAt   *time.Time `json:"sent_at"`
}
