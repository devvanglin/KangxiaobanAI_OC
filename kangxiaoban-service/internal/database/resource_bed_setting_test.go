package database

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
)

func setupBedSettingDB(t *testing.T) (*gorm.DB, *service.ResourceService, context.Context) {
	t.Helper()
	dsn := fmt.Sprintf("file:bed_setting_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	svc := service.NewResourceService(repository.NewResourceRepository(db))
	return db, svc, ctx
}

func TestEnsureRoomForAreaProvisionsLegacyRoom(t *testing.T) {
	db, svc, ctx := setupBedSettingDB(t)

	floor := &model.Area{Type: model.AreaTypeFloor, Code: "bed-floor-2", Name: "床测 2 楼", Building: "BED", FloorNo: 2, Status: "active"}
	if err := db.WithContext(ctx).Create(floor).Error; err != nil {
		t.Fatal(err)
	}
	roomArea := &model.Area{ParentID: &floor.ID, Type: model.AreaTypeRoom, Code: "bed-room-201", Name: "201", Building: "BED", FloorNo: 2, Status: "active"}
	if err := db.WithContext(ctx).Create(roomArea).Error; err != nil {
		t.Fatal(err)
	}

	room, err := svc.EnsureRoomForArea(ctx, roomArea.ID)
	if err != nil {
		t.Fatal(err)
	}
	if room.Building != "BED" || room.Floor != 2 || room.RoomNo != "201" {
		t.Fatalf("provisioned room key mismatch: %+v", room)
	}

	again, err := svc.EnsureRoomForArea(ctx, roomArea.ID)
	if err != nil {
		t.Fatal(err)
	}
	if again.ID != room.ID {
		t.Fatalf("second call must reuse the same room: %d vs %d", again.ID, room.ID)
	}

	if _, err := svc.EnsureRoomForArea(ctx, floor.ID); !errors.Is(err, service.ErrAreaNotRoom) {
		t.Fatalf("floor area must be rejected: %v", err)
	}
}

func TestCreateBedInRoomEnforcesLimitAndNumbers(t *testing.T) {
	db, svc, ctx := setupBedSettingDB(t)

	room := &model.Room{Building: "BED", Floor: 3, RoomNo: "301"}
	if err := db.WithContext(ctx).Create(room).Error; err != nil {
		t.Fatal(err)
	}
	bed1 := &model.Bed{RoomID: room.ID, BedNo: "1", Status: "free"}
	if err := svc.CreateBedInRoom(ctx, bed1); err != nil {
		t.Fatal(err)
	}
	if bed1.ID == 0 {
		t.Fatal("bed id not persisted")
	}

	dup := &model.Bed{RoomID: room.ID, BedNo: "1", Status: "free"}
	if err := svc.CreateBedInRoom(ctx, dup); !errors.Is(err, service.ErrBedNumberExists) {
		t.Fatalf("duplicate number must be rejected: %v", err)
	}

	bed2 := &model.Bed{RoomID: room.ID, BedNo: "2", Status: "free"}
	if err := svc.CreateBedInRoom(ctx, bed2); err != nil {
		t.Fatal(err)
	}
	third := &model.Bed{RoomID: room.ID, BedNo: "3", Status: "free"}
	if err := svc.CreateBedInRoom(ctx, third); !errors.Is(err, service.ErrBedLimitReached) {
		t.Fatalf("third bed must be rejected: %v", err)
	}
}

func TestDeleteBedGuardsOccupancy(t *testing.T) {
	db, svc, ctx := setupBedSettingDB(t)

	room := &model.Room{Building: "BED", Floor: 4, RoomNo: "401"}
	if err := db.WithContext(ctx).Create(room).Error; err != nil {
		t.Fatal(err)
	}
	free := &model.Bed{RoomID: room.ID, BedNo: "2", Status: "free"}
	if err := svc.CreateBedInRoom(ctx, free); err != nil {
		t.Fatal(err)
	}
	occupied := &model.Bed{RoomID: room.ID, BedNo: "1", Status: "occupied", ElderID: &[]uint{7}[0]}
	if err := svc.CreateBedInRoom(ctx, occupied); err != nil {
		t.Fatal(err)
	}

	if err := svc.DeleteBed(ctx, free.ID); err != nil {
		t.Fatalf("free bed must be removable: %v", err)
	}
	if err := svc.DeleteBed(ctx, occupied.ID); !errors.Is(err, service.ErrBedNotRemovable) {
		t.Fatalf("occupied bed must be protected: %v", err)
	}
	if err := svc.DeleteBed(ctx, free.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("deleted bed must not be found again: %v", err)
	}
}
