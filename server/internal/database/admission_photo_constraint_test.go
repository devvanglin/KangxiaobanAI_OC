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

func TestAdmissionPhotoPendingSlotIsUniquePerTenantAndUser(t *testing.T) {
	dsn := fmt.Sprintf("file:admission_photo_constraint_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.AdmissionIntakePhoto{}); err != nil {
		t.Fatal(err)
	}
	for _, tenant := range []model.Tenant{
		{Base: model.Base{ID: 1, TenantID: 1}, Code: "photo-one", Name: "照片一号机构", Status: 1},
		{Base: model.Base{ID: 2, TenantID: 2}, Code: "photo-two", Name: "照片二号机构", Status: 1},
	} {
		if err := db.Create(&tenant).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err := ensureAdmissionPhotoConstraint(db); err != nil {
		t.Fatal(err)
	}

	ctx1 := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	photo := func(key, kind, storage string) model.AdmissionIntakePhoto {
		return model.AdmissionIntakePhoto{Kind: kind, StorageKey: storage, ContentType: "image/jpeg", Size: 1, SHA256: storage, UploadedBy: 7, UploadKey: key}
	}
	first := photo("form-1", "portrait", "tenant-1/first.jpg")
	if err := db.WithContext(ctx1).Create(&first).Error; err != nil {
		t.Fatal(err)
	}
	duplicate := photo("form-1", "portrait", "tenant-1/second.jpg")
	if err := db.WithContext(ctx1).Create(&duplicate).Error; err == nil {
		t.Fatal("expected duplicate active pending slot to fail")
	}
	// The same form key can have independent document slots.
	otherKind := photo("form-1", "id_front", "tenant-1/front.jpg")
	if err := db.WithContext(ctx1).Create(&otherKind).Error; err != nil {
		t.Fatalf("different kind should be allowed: %v", err)
	}
	// Tenant isolation is part of the key.
	otherTenant := photo("form-1", "portrait", "tenant-2/portrait.jpg")
	if err := db.WithContext(ctx2).Create(&otherTenant).Error; err != nil {
		t.Fatalf("same slot in another tenant should be allowed: %v", err)
	}
	// A replacement tombstones the old row, after which the slot is reusable.
	if err := db.WithContext(ctx1).Delete(&first).Error; err != nil {
		t.Fatal(err)
	}
	replacement := photo("form-1", "portrait", "tenant-1/replacement.jpg")
	if err := db.WithContext(ctx1).Create(&replacement).Error; err != nil {
		t.Fatalf("soft-deleted slot should be reusable: %v", err)
	}
}
