package database

import (
	"context"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/operationpolicy"
)

// seedOperationPolicies creates only missing tenant rows. Institution-specific
// values are never overwritten on restart.
func seedOperationPolicies(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		defaults := operationpolicy.Default()
		policy := defaults
		if err := db.WithContext(ctx).Where("tenant_id = ?", tenant.ID).
			FirstOrCreate(&policy).Error; err != nil {
			return err
		}
		if len(policy.MedicationTimePeriods) == 0 {
			policy.MedicationTimePeriods = defaults.MedicationTimePeriods
			if err := db.WithContext(ctx).Model(&policy).
				Update("medication_time_periods", policy.MedicationTimePeriods).Error; err != nil {
				return err
			}
		}
	}
	return nil
}
