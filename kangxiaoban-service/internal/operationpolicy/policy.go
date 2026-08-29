package operationpolicy

import (
	"fmt"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

const (
	defaultPercent = 95
	defaultSeconds = 60
)

func Default() model.OperationPolicy {
	return model.OperationPolicy{
		OccupancyWarningPercent:    defaultPercent,
		DeviceOnlineWarningPercent: defaultPercent,
		AlertCooldownSeconds:       defaultSeconds,
		DeviceOfflineSeconds:       defaultSeconds,
		AlertEscalationSeconds:     defaultSeconds,
	}
}

func Load(db *gorm.DB) (model.OperationPolicy, error) {
	var policy model.OperationPolicy
	if err := db.First(&policy).Error; err != nil {
		return model.OperationPolicy{}, err
	}
	if err := Validate(policy); err != nil {
		return model.OperationPolicy{}, err
	}
	return policy, nil
}

func LoadOrDefault(db *gorm.DB) model.OperationPolicy {
	policy, err := Load(db)
	if err != nil {
		return Default()
	}
	return policy
}

func Validate(policy model.OperationPolicy) error {
	if policy.OccupancyWarningPercent <= 0 || policy.OccupancyWarningPercent > 100 {
		return fmt.Errorf("invalid occupancy warning percent %.2f", policy.OccupancyWarningPercent)
	}
	if policy.DeviceOnlineWarningPercent <= 0 || policy.DeviceOnlineWarningPercent > 100 {
		return fmt.Errorf("invalid device online warning percent %.2f", policy.DeviceOnlineWarningPercent)
	}
	if policy.AlertCooldownSeconds <= 0 || policy.DeviceOfflineSeconds <= 0 || policy.AlertEscalationSeconds <= 0 {
		return fmt.Errorf("operation policy durations must be positive")
	}
	return nil
}

func Seconds(value int) time.Duration {
	return time.Duration(value) * time.Second
}
