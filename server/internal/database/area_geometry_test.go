package database

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestAreaGeometryRoundTrip(t *testing.T) {
	dsn := fmt.Sprintf("file:area_geometry_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))

	floor := &model.Area{Type: model.AreaTypeFloor, Code: "geo-floor-1", Name: "地理测试 1 楼", Building: "GEO", FloorNo: 1, Status: "active"}
	if err := db.WithContext(ctx).Create(floor).Error; err != nil {
		t.Fatal(err)
	}
	room := &model.Area{ParentID: &floor.ID, Type: model.AreaTypeRoom, Code: "geo-room-101", Name: "101", Building: "GEO", FloorNo: 1, Status: "active", PosX: 2, PosY: 3, SizeW: 4, SizeH: 3}
	if err := db.WithContext(ctx).Create(room).Error; err != nil {
		t.Fatal(err)
	}

	var loaded model.Area
	if err := db.WithContext(ctx).Where("code = ?", "geo-room-101").First(&loaded).Error; err != nil {
		t.Fatal(err)
	}
	if loaded.PosX != 2 || loaded.PosY != 3 || loaded.SizeW != 4 || loaded.SizeH != 3 {
		t.Fatalf("geometry not persisted: got (%.1f,%.1f,%.1f,%.1f)", loaded.PosX, loaded.PosY, loaded.SizeW, loaded.SizeH)
	}

	if err := db.WithContext(ctx).Model(&loaded).Updates(map[string]interface{}{"pos_x": 5.5, "pos_y": 1.5, "size_w": 2, "size_h": 2}).Error; err != nil {
		t.Fatal(err)
	}
	var reloaded model.Area
	if err := db.WithContext(ctx).First(&reloaded, loaded.ID).Error; err != nil {
		t.Fatal(err)
	}
	if reloaded.PosX != 5.5 || reloaded.PosY != 1.5 || reloaded.SizeW != 2 || reloaded.SizeH != 2 {
		t.Fatalf("geometry update not persisted: got (%.1f,%.1f,%.1f,%.1f)", reloaded.PosX, reloaded.PosY, reloaded.SizeW, reloaded.SizeH)
	}

	// A fresh area without geometry must stay unplaced (zero size).
	unplaced := &model.Area{ParentID: &floor.ID, Type: model.AreaTypeCorridor, Code: "geo-corridor-1", Name: "北走廊", Building: "GEO", FloorNo: 1, Status: "active"}
	if err := db.WithContext(ctx).Create(unplaced).Error; err != nil {
		t.Fatal(err)
	}
	var loadedCorridor model.Area
	if err := db.WithContext(ctx).Where("code = ?", "geo-corridor-1").First(&loadedCorridor).Error; err != nil {
		t.Fatal(err)
	}
	if loadedCorridor.SizeW != 0 || loadedCorridor.SizeH != 0 {
		t.Fatalf("fresh area must be unplaced: got %.1fx%.1f", loadedCorridor.SizeW, loadedCorridor.SizeH)
	}
}
