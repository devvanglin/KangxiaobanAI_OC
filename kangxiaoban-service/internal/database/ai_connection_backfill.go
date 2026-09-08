package database

import (
	"context"
	"errors"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// ensureAIConnections promotes the legacy per-role http configs into the
// unified tenant connection, so existing deployments keep their endpoint and
// keys after the model page stops editing per-role connections.
func ensureAIConnections(db *gorm.DB) error {
	// Startup-wide repair: bypass the tenant callback so every tenant is seen.
	ctx := withoutTenantScope(context.Background())
	tenants := []model.Tenant{}
	if err := db.WithContext(ctx).Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		var connectionCount int64
		if err := db.WithContext(ctx).Model(&model.AIConnection{}).Where("tenant_id = ?", tenant.ID).
			Count(&connectionCount).Error; err != nil {
			return err
		}
		if connectionCount > 0 {
			continue
		}
		var config model.AIModelConfig
		err := db.WithContext(ctx).Where("tenant_id = ? AND provider = ? AND base_url <> ''", tenant.ID, "http").
			Order("is_default DESC, id ASC").First(&config).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			continue
		}
		if err != nil {
			return err
		}
		createCtx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		connection := model.AIConnection{
			Provider: "http", BaseURL: config.BaseURL, APIKeyEncrypted: config.APIKeyEncrypted,
			RAGEnabled: config.RAGEnabled, RAGBaseURL: config.RAGBaseURL,
			RAGDatasetID: config.RAGDatasetID, RAGAPIKeyEncrypted: config.RAGAPIKeyEncrypted,
			Enabled: true,
		}
		if err := db.WithContext(createCtx).Create(&connection).Error; err != nil {
			return err
		}
	}
	return nil
}
