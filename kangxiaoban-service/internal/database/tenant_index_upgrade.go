package database

import (
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// ensureTenantScopedIdentityIndexes upgrades the historical global username
// and role-code indexes without deleting any rows. This keeps custom roles and
// same-named users isolated per institution.
func ensureTenantScopedIdentityIndexes(db *gorm.DB) error {
	if db.Dialector.Name() == "sqlite" {
		if err := db.Exec("DROP INDEX IF EXISTS idx_roles_code").Error; err != nil { return err }
		if err := db.Exec("DROP INDEX IF EXISTS idx_users_username").Error; err != nil { return err }
		if err := db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_roles_tenant_code ON roles(tenant_id, code) WHERE deleted_at IS NULL").Error; err != nil {
			return err
		}
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_users_tenant_username ON users(tenant_id, username) WHERE deleted_at IS NULL").Error
	}
	if db.Migrator().HasIndex(&model.Role{}, "idx_roles_code") {
		if err := db.Migrator().DropIndex(&model.Role{}, "idx_roles_code"); err != nil { return err }
	}
	if db.Migrator().HasIndex(&model.User{}, "idx_users_username") {
		if err := db.Migrator().DropIndex(&model.User{}, "idx_users_username"); err != nil { return err }
	}
	if !db.Migrator().HasIndex(&model.Role{}, "uk_roles_tenant_code") {
		if err := db.Exec("CREATE UNIQUE INDEX uk_roles_tenant_code ON roles(tenant_id, code, deleted_at)").Error; err != nil { return err }
	}
	if !db.Migrator().HasIndex(&model.User{}, "uk_users_tenant_username") {
		return db.Exec("CREATE UNIQUE INDEX uk_users_tenant_username ON users(tenant_id, username, deleted_at)").Error
	}
	return nil
}
