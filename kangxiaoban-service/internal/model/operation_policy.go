package model

import "time"

// OperationPolicy stores tenant-owned operational and IoT alert thresholds.
// One row is kept per tenant so every client and background worker uses the
// same configured values.
type OperationPolicy struct {
	ID                         uint      `gorm:"primarykey" json:"id"`
	TenantID                   uint      `gorm:"uniqueIndex;not null" json:"tenant_id"`
	CreatedAt                  time.Time `json:"created_at"`
	UpdatedAt                  time.Time `json:"updated_at"`
	OccupancyWarningPercent    float64   `gorm:"not null" json:"occupancy_warning_percent"`
	DeviceOnlineWarningPercent float64   `gorm:"not null" json:"device_online_warning_percent"`
	AlertCooldownSeconds       int       `gorm:"not null" json:"alert_cooldown_seconds"`
	DeviceOfflineSeconds       int       `gorm:"not null" json:"device_offline_seconds"`
	AlertEscalationSeconds     int       `gorm:"not null" json:"alert_escalation_seconds"`
}
