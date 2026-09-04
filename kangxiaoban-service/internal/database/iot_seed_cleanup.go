package database

import (
	"context"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

var legacySeedDeviceIDs = []string{"E438192584AA", "E438192584F5", "E438192587C3"}

// removeLegacySeedIotData removes only the fixed demo radar records that were
// created by the historical business seed. Real MQTT-discovered devices and
// administrator-created devices are untouched. The rows are soft-deleted so
// audit/history remains recoverable, while a future frame with the same ID can
// be reactivated by the ingest path.
func removeLegacySeedIotData(db *gorm.DB) error {
	migrationDB := db.WithContext(withoutTenantScope(context.Background()))
	return migrationDB.Transaction(func(tx *gorm.DB) error {
		var deviceIDs []uint
		if err := tx.Model(&model.IotDevice{}).Where("device_id IN ?", legacySeedDeviceIDs).Pluck("id", &deviceIDs).Error; err != nil {
			return err
		}
		if len(deviceIDs) > 0 {
			if err := tx.Where("device_id IN ?", legacySeedDeviceIDs).Delete(&model.SignalRecord{}).Error; err != nil {
				return err
			}
			var alertIDs []uint
			if err := tx.Model(&model.Alert{}).Where("device_id IN ?", legacySeedDeviceIDs).Pluck("id", &alertIDs).Error; err != nil {
				return err
			}
			if len(alertIDs) > 0 {
				if err := tx.Where("alert_id IN ?", alertIDs).Delete(&model.AlertAction{}).Error; err != nil {
					return err
				}
			}
			if err := tx.Where("device_id IN ?", legacySeedDeviceIDs).Delete(&model.Alert{}).Error; err != nil {
				return err
			}
			if err := tx.Model(&model.IotDevice{}).Where("device_id IN ?", legacySeedDeviceIDs).Updates(map[string]interface{}{
				"device_type":      "millimeter_wave",
				"online":           0,
				"elder_id":         nil,
				"area_id":          nil,
				"building":         "",
				"room":             "",
				"bed":              "",
				"battery":          nil,
				"last_seen":        nil,
				"discovery_status": "disabled",
			}).Error; err != nil {
				return err
			}
		}

		// The old business seed also inserted one synthetic source=iot health
		// snapshot. Remove it only when no active millimeter-wave device remains;
		// real MQTT-projected health history is retained while a real radar exists.
		var activeRadarCount int64
		if err := tx.Model(&model.IotDevice{}).Where("device_type = ? AND protocol = ? AND (discovery_status <> ? OR discovery_status IS NULL)", "millimeter_wave", "MQTT", "disabled").Count(&activeRadarCount).Error; err != nil {
			return err
		}
		if activeRadarCount == 0 {
			if err := tx.Where("source = ?", "iot").Delete(&model.HealthRecord{}).Error; err != nil {
				return err
			}
		}
		return nil
	})
}
