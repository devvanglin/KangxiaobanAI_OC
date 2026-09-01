package repository

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/model"
)

func TestResourceRepositoryListBedsExcludesMaintenanceRoomsForFreeStatus(t *testing.T) {
	dsn := fmt.Sprintf("file:resource_repo_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.Room{}, &model.Bed{}); err != nil {
		t.Fatal(err)
	}
	freeRoom := model.Room{Base: model.Base{TenantID: 1}, Building: "A", Floor: 1, RoomNo: "101", Type: "normal", Status: "free"}
	maintenanceRoom := model.Room{Base: model.Base{TenantID: 1}, Building: "A", Floor: 1, RoomNo: "102", Type: "normal", Status: "maintenance"}
	otherTenantRoom := model.Room{Base: model.Base{TenantID: 2}, Building: "B", Floor: 1, RoomNo: "201", Type: "normal", Status: "free"}
	if err := db.Create(&freeRoom).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&maintenanceRoom).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&otherTenantRoom).Error; err != nil {
		t.Fatal(err)
	}
	for _, bed := range []model.Bed{
		{Base: model.Base{TenantID: 1}, RoomID: freeRoom.ID, BedNo: "1", Status: "free"},
		{Base: model.Base{TenantID: 1}, RoomID: maintenanceRoom.ID, BedNo: "1", Status: "free"},
		{Base: model.Base{TenantID: 2}, RoomID: otherTenantRoom.ID, BedNo: "1", Status: "free"},
	} {
		if err := db.Create(&bed).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err := database.RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	repo := NewResourceRepository(db)
	items, total, err := repo.ListBeds(ctx, 0, "free", 1, 20)
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(items) != 1 {
		t.Fatalf("free beds = %d/%d, want one tenant-1 operational bed", total, len(items))
	}
	if items[0].RoomID != freeRoom.ID || items[0].Room == nil || items[0].Room.Status == "maintenance" {
		t.Fatalf("unexpected free bed result: %+v", items[0])
	}
}
