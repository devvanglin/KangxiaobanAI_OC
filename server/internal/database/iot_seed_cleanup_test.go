package database

import (
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

func TestRemoveLegacySeedIotDataDisablesOnlyFixedDemoDevices(t *testing.T) {
	dsn := fmt.Sprintf("file:iot_seed_cleanup_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.Elder{}, &model.IotDevice{}, &model.SignalRecord{}, &model.Alert{}, &model.AlertAction{}, &model.HealthRecord{}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "default", Name: "默认机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	legacy := model.IotDevice{DeviceID: "E438192584AA", Product: "fall_radar", Protocol: "MQTT", Online: 1}
	real := model.IotDevice{DeviceID: "real-radar-1", Product: "fall_radar", Protocol: "MQTT", Online: 1}
	if err := db.Create(&[]model.IotDevice{legacy, real}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Alert{DeviceID: legacy.DeviceID, Type: "fall", Level: "emergency", Content: "demo"}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.HealthRecord{ElderID: 1, Source: "iot", RecordTime: time.Now()}).Error; err != nil {
		t.Fatal(err)
	}
	if err := removeLegacySeedIotData(db); err != nil {
		t.Fatal(err)
	}
	var got model.IotDevice
	if err := db.Where("device_id = ?", legacy.DeviceID).First(&got).Error; err != nil {
		t.Fatal(err)
	}
	if got.DiscoveryStatus != "disabled" || got.Online != 0 || got.ElderID != nil {
		t.Fatalf("legacy device was not disabled: %+v", got)
	}
	var realCount int64
	if err := db.Model(&model.IotDevice{}).Where("device_id = ?", real.DeviceID).Count(&realCount).Error; err != nil {
		t.Fatal(err)
	}
	if realCount != 1 {
		t.Fatalf("real device was changed or removed: %d", realCount)
	}
	var alertCount int64
	if err := db.Model(&model.Alert{}).Where("device_id = ?", legacy.DeviceID).Count(&alertCount).Error; err != nil {
		t.Fatal(err)
	}
	if alertCount != 0 {
		t.Fatalf("legacy alerts remain: %d", alertCount)
	}
	var healthCount int64
	if err := db.Model(&model.HealthRecord{}).Where("source = ?", "iot").Count(&healthCount).Error; err != nil {
		t.Fatal(err)
	}
	if healthCount != 0 {
		t.Fatalf("bootstrap IoT health remains: %d", healthCount)
	}
}
