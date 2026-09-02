package database

import (
	"fmt"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// ensureAdmissionPhotoConstraint permits at most one active pending image for
// a tenant/user/form/slot tuple.  The application replaces a pending image
// when a user selects a new one, but the database guard is still required for
// two concurrent uploads (or two server processes) that both observe an empty
// slot before inserting.
//
// Attached photos (intake_id != 0) are deliberately excluded: they are
// immutable historical records and their reuse is rejected by the service.
// Soft-deleted pending rows are also excluded so a replacement can be created
// after the old row is tombstoned.
func ensureAdmissionPhotoConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID   uint
		UploadedBy uint
		UploadKey  string
		Kind       string
		Count      int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, uploaded_by, upload_key, kind, COUNT(*) AS count FROM admission_intake_photos WHERE intake_id = 0 AND deleted_at IS NULL GROUP BY tenant_id, uploaded_by, upload_key, kind HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active pending admission photo in tenant %d for user %d, key %s, kind %s", duplicates[0].TenantID, duplicates[0].UploadedBy, duplicates[0].UploadKey, duplicates[0].Kind)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_admission_photos_pending_slot ON admission_intake_photos(tenant_id, uploaded_by, upload_key, kind) WHERE intake_id = 0 AND deleted_at IS NULL").Error
	case "mysql":
		// MySQL/MariaDB do not support partial indexes. A nullable generated
		// key gives attached and soft-deleted rows NULL while enforcing the
		// pending tuple for active rows.
		if !db.Migrator().HasColumn(&model.AdmissionIntakePhoto{}, "active_pending_key") {
			if err := db.Exec("ALTER TABLE admission_intake_photos ADD COLUMN active_pending_key VARCHAR(192) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL AND intake_id = 0 THEN CONCAT(uploaded_by, ':', upload_key, ':', kind) ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.AdmissionIntakePhoto{}, "uk_admission_photos_pending_slot") {
			return db.Exec("CREATE UNIQUE INDEX uk_admission_photos_pending_slot ON admission_intake_photos(tenant_id, active_pending_key)").Error
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}
