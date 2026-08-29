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
		policy := operationpolicy.Default()
		if err := db.WithContext(ctx).Where("tenant_id = ?", tenant.ID).
			FirstOrCreate(&policy).Error; err != nil {
			return err
		}
	}
	return nil
}
