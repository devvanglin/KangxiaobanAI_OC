package operationpolicy

import (
	"fmt"
	"sort"
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
		MedicationTimePeriods: []model.MedicationTimePeriod{
			{Code: "morning", Label: "早晨", StartTime: "06:00", EndTime: "10:00", SortOrder: 1},
			{Code: "noon", Label: "中午", StartTime: "10:00", EndTime: "14:00", SortOrder: 2},
			{Code: "evening", Label: "晚上", StartTime: "14:00", EndTime: "22:00", SortOrder: 3},
			{Code: "night", Label: "夜间", StartTime: "22:00", EndTime: "06:00", SortOrder: 4},
		},
	}
}

func Load(db *gorm.DB) (model.OperationPolicy, error) {
	var policy model.OperationPolicy
	if err := db.First(&policy).Error; err != nil {
		return model.OperationPolicy{}, err
	}
	if len(policy.MedicationTimePeriods) == 0 {
		policy.MedicationTimePeriods = Default().MedicationTimePeriods
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
	if len(policy.MedicationTimePeriods) == 0 {
		return fmt.Errorf("operation policy medication time periods are required")
	}
	periods := append([]model.MedicationTimePeriod(nil), policy.MedicationTimePeriods...)
	sort.Slice(periods, func(i, j int) bool { return periods[i].SortOrder < periods[j].SortOrder })
	seen := make(map[string]bool, len(periods))
	for _, period := range periods {
		if period.Code == "" || period.Label == "" || seen[period.Code] {
			return fmt.Errorf("invalid medication time period %q", period.Code)
		}
		if _, err := time.Parse("15:04", period.StartTime); err != nil {
			return fmt.Errorf("invalid medication period start time %q", period.StartTime)
		}
		if _, err := time.Parse("15:04", period.EndTime); err != nil {
			return fmt.Errorf("invalid medication period end time %q", period.EndTime)
		}
		seen[period.Code] = true
	}
	return nil
}

func Seconds(value int) time.Duration {
	return time.Duration(value) * time.Second
}
