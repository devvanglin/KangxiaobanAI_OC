package model

import "time"

// IotDevice 物联网设备（雷达/床垫/血压计等）。
type IotDevice struct {
	Base
	DeviceID string `gorm:"size:64;uniqueIndex;not null" json:"device_id"`
	Product  string `gorm:"size:32" json:"product"` // breath_radar / fall_radar / ...
	Building string `gorm:"size:16" json:"building"`
	Room     string `gorm:"size:16" json:"room"`
	Bed      string `gorm:"size:8" json:"bed"`
	ElderID  *uint  `json:"elder_id"`
	Online   int8   `gorm:"default:0" json:"online"` // 1在线 0离线
	LastSeen *time.Time `json:"last_seen"`
	Protocol string `gorm:"size:16;default:MQTT" json:"protocol"`
}

// SignalRecord 设备归一化体征/事件。
type SignalRecord struct {
	Base
	DeviceID string `gorm:"size:64;index" json:"device_id"`
	ElderID  *uint  `gorm:"index" json:"elder_id"`
	Type     string `gorm:"size:32;index" json:"type"`
	Value    string `gorm:"size:64" json:"value"`
	TS       time.Time `json:"ts"`
}

// Alert 告警。级别 emergency/important/info；状态 new/handling/handled/closed。
type Alert struct {
	Base
	ElderID   *uint  `gorm:"index" json:"elder_id"`
	DeviceID  string `gorm:"size:64;index" json:"device_id"`
	Type      string `gorm:"size:32" json:"type"`
	Level     string `gorm:"size:16" json:"level"`
	Content   string `gorm:"size:255" json:"content"`
	Status    string `gorm:"size:16;default:new" json:"status"`
	HandledBy string `gorm:"size:64" json:"handled_by"`
	CreateTime time.Time `json:"create_time"`
	CloseTime *time.Time `json:"close_time"`
}