package iot

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/ws"
)

func TestBatteryFromValues(t *testing.T) {
	tests := []struct {
		name   string
		values map[string]interface{}
		want   *int
	}{
		{name: "battery", values: map[string]interface{}{"battery": 83.6}, want: batteryPointer(84)},
		{name: "alias", values: map[string]interface{}{"batteryLevel": "72"}, want: batteryPointer(72)},
		{name: "upper clamp", values: map[string]interface{}{"batteryPercent": 120}, want: batteryPointer(100)},
		{name: "lower clamp", values: map[string]interface{}{"battery": -5}, want: batteryPointer(0)},
		{name: "missing", values: map[string]interface{}{}, want: nil},
		{name: "invalid", values: map[string]interface{}{"battery": "unknown"}, want: nil},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := batteryFromValues(test.values)
			if test.want == nil {
				if got != nil {
					t.Fatalf("battery = %d, want nil", *got)
				}
				return
			}
			if got == nil || *got != *test.want {
				t.Fatalf("battery = %v, want %d", got, *test.want)
			}
		})
	}
}

func batteryPointer(value int) *int { return &value }

func TestIotEvaluationUsesDatabaseThreshold(t *testing.T) {
	dsn := fmt.Sprintf("file:iot_threshold_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := database.RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.HealthThreshold{}, &model.Alert{}, &model.Elder{}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "default", Name: "测试机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	warningMax := 100.0
	criticalMax := 130.0
	threshold := model.HealthThreshold{
		Metric: "heart_rate", DisplayName: "心率", Unit: "bpm", WarningMax: &warningMax, CriticalMax: &criticalMax, Enabled: true,
	}
	if err := db.Create(&threshold).Error; err != nil {
		t.Fatal(err)
	}

	service := NewIotService(db, ws.NewHub())
	service.evaluate(db, model.IotDevice{DeviceID: "threshold-device-1"}, map[string]interface{}{"heartRateValue": 110}, time.Now())
	var count int64
	if err := db.Model(&model.Alert{}).Where("type = ?", "heart_abnormal").Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("alert count = %d, want 1", count)
	}

	if err := db.Model(&threshold).Updates(map[string]interface{}{"warning_max": 120.0, "critical_max": 140.0}).Error; err != nil {
		t.Fatal(err)
	}
	service.evaluate(db, model.IotDevice{DeviceID: "threshold-device-2"}, map[string]interface{}{"heartRateValue": 110}, time.Now())
	if err := db.Model(&model.Alert{}).Where("type = ?", "heart_abnormal").Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("adjusted database threshold still emitted alert: count=%d", count)
	}
}

func TestIotEvaluationUsesDatabaseCooldownPolicy(t *testing.T) {
	dsn := fmt.Sprintf("file:iot_policy_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := database.RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.OperationPolicy{}, &model.HealthThreshold{}, &model.Alert{}, &model.Elder{}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "default", Name: "测试机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	policy := model.OperationPolicy{
		OccupancyWarningPercent: 95, DeviceOnlineWarningPercent: 95,
		AlertCooldownSeconds: 1, DeviceOfflineSeconds: 60, AlertEscalationSeconds: 60,
	}
	if err := db.Create(&policy).Error; err != nil {
		t.Fatal(err)
	}

	service := NewIotService(db, ws.NewHub())
	now := time.Now()
	device := model.IotDevice{DeviceID: "policy-device"}
	values := map[string]interface{}{"fallStatus": 1}
	service.evaluate(db, device, values, now)
	service.evaluate(db, device, values, now.Add(2*time.Second))

	var count int64
	if err := db.Model(&model.Alert{}).Where("type = ?", "fall").Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 2 {
		t.Fatalf("alert count = %d, want 2 from one-second database cooldown", count)
	}
}

func TestListDevicesHidesDisabledSeedRows(t *testing.T) {
	dsn := fmt.Sprintf("file:iot_list_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := database.RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.IotDevice{}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "default", Name: "测试机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&[]model.IotDevice{
		{DeviceID: "disabled-seed", DeviceType: "millimeter_wave", Protocol: "MQTT", DiscoveryStatus: "disabled"},
		{DeviceID: "real-camera", DeviceType: "camera", Protocol: "RTSP", DiscoveryStatus: "claimed"},
	}).Error; err != nil {
		t.Fatal(err)
	}

	service := NewIotService(db, ws.NewHub())
	devices, total, err := service.ListDevices(context.Background(), 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(devices) != 1 || devices[0].DeviceID != "real-camera" {
		t.Fatalf("list = %+v, total = %d; disabled device should be hidden", devices, total)
	}
}
