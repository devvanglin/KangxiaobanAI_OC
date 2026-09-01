package database

import (
	"fmt"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// ensureAdmissionIntakeConstraint makes a non-empty client idempotency key
// unique within a tenant. Existing legacy rows with an empty key are left
// untouched for migration compatibility; new intake requests are required to
// provide a key. The database guard closes the race between concurrent calls.
func ensureAdmissionIntakeConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID       uint
		IdempotencyKey string
		Count          int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, idempotency_key, COUNT(*) AS count FROM admission_intakes WHERE idempotency_key <> '' AND deleted_at IS NULL GROUP BY tenant_id, idempotency_key HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active admission intake idempotency key in tenant %d: %s", duplicates[0].TenantID, duplicates[0].IdempotencyKey)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_admission_intakes_tenant_idempotency_key ON admission_intakes(tenant_id, idempotency_key) WHERE idempotency_key <> '' AND deleted_at IS NULL").Error
	case "mysql":
		// MySQL/MariaDB have no partial unique indexes. A nullable generated
		// value gives blank/deleted rows NULL (and therefore repeatable) while
		// enforcing non-empty active keys.
		if !db.Migrator().HasColumn(&model.AdmissionIntake{}, "active_idempotency_key") {
			if err := db.Exec("ALTER TABLE admission_intakes ADD COLUMN active_idempotency_key VARCHAR(128) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL AND idempotency_key <> '' THEN idempotency_key ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.AdmissionIntake{}, "uk_admission_intakes_tenant_idempotency_key") {
			if err := db.Exec("CREATE UNIQUE INDEX uk_admission_intakes_tenant_idempotency_key ON admission_intakes(tenant_id, active_idempotency_key)").Error; err != nil {
				return err
			}
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}
