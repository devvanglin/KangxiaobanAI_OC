package database

import (
	"context"
	"errors"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func seedHealthThresholds(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		tenantDB := db.WithContext(ctx)
		for _, seed := range defaultHealthThresholds() {
			var existing model.HealthThreshold
			err := tenantDB.Where("metric = ?", seed.Metric).First(&existing).Error
			if err == nil {
				continue
			}
			if !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
			if err := tenantDB.Create(&seed).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func defaultHealthThresholds() []model.HealthThreshold {
	return []model.HealthThreshold{
		{Metric: "temperature", DisplayName: "体温", Unit: "℃", WarningMin: thresholdValue(36), WarningMax: thresholdValue(37.3), CriticalMin: thresholdValue(35), CriticalMax: thresholdValue(39), Enabled: true, SortOrder: 1},
		{Metric: "systolic", DisplayName: "收缩压", Unit: "mmHg", WarningMin: thresholdValue(90), WarningMax: thresholdValue(140), CriticalMin: thresholdValue(80), CriticalMax: thresholdValue(180), Enabled: true, SortOrder: 2},
		{Metric: "diastolic", DisplayName: "舒张压", Unit: "mmHg", WarningMin: thresholdValue(60), WarningMax: thresholdValue(90), CriticalMin: thresholdValue(50), CriticalMax: thresholdValue(120), Enabled: true, SortOrder: 3},
		{Metric: "heart_rate", DisplayName: "心率", Unit: "bpm", WarningMin: thresholdValue(60), WarningMax: thresholdValue(100), CriticalMin: thresholdValue(45), CriticalMax: thresholdValue(130), Enabled: true, SortOrder: 4},
		{Metric: "spo2", DisplayName: "血氧", Unit: "%", WarningMin: thresholdValue(95), CriticalMin: thresholdValue(90), Enabled: true, SortOrder: 5},
		{Metric: "respiratory_rate", DisplayName: "呼吸频率", Unit: "次/分", WarningMin: thresholdValue(12), WarningMax: thresholdValue(20), CriticalMin: thresholdValue(8), CriticalMax: thresholdValue(30), Enabled: true, SortOrder: 6},
		// Step totals depend on the observation window. The row keeps the metric server-owned
		// while deliberately applying no risk boundary until an institution configures one.
		{Metric: "steps", DisplayName: "步数", Unit: "步", Enabled: true, SortOrder: 7},
		{Metric: "sleep_hours", DisplayName: "睡眠时长", Unit: "小时", WarningMin: thresholdValue(5), WarningMax: thresholdValue(9), CriticalMin: thresholdValue(3), CriticalMax: thresholdValue(12), Enabled: true, SortOrder: 8},
	}
}

func thresholdValue(value float64) *float64 { return &value }
