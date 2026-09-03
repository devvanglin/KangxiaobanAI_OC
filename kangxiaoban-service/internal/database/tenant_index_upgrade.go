package database

import (
	"fmt"

	"gorm.io/gorm"
)

// ensureTenantScopedIdentityIndexes upgrades the historical global username
// and role-code indexes without deleting any rows. This keeps custom roles and
// same-named users isolated per institution.
func ensureTenantScopedIdentityIndexes(db *gorm.DB) error {
	statements := []string{
		"DROP INDEX IF EXISTS idx_roles_code",
		"DROP INDEX IF EXISTS idx_users_username",
	}
	for _, statement := range statements {
		if err := db.Exec(statement).Error; err != nil {
			return fmt.Errorf("%s: %w", statement, err)
		}
	}
	if db.Dialector.Name() == "sqlite" {
		if err := db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_roles_tenant_code ON roles(tenant_id, code) WHERE deleted_at IS NULL").Error; err != nil {
			return err
		}
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_users_tenant_username ON users(tenant_id, username) WHERE deleted_at IS NULL").Error
	}
	if err := db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_roles_tenant_code ON roles(tenant_id, code, deleted_at)").Error; err != nil {
		return err
	}
	return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_users_tenant_username ON users(tenant_id, username, deleted_at)").Error
}
