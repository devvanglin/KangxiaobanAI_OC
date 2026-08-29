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

func TestElderIdentityIsUniquePerTenant(t *testing.T) {
	dsn := fmt.Sprintf("file:elder_identity_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Tenant{}, &model.Elder{}); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "one", Name: "一号机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "two", Name: "二号机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}
	if err := ensureElderIdentityConstraint(db); err != nil {
		t.Fatal(err)
	}
	ctx1 := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	first := model.Elder{Name: "甲", IDCard: "ID-UNIQUE-1"}
	if err := db.WithContext(ctx1).Create(&first).Error; err != nil {
		t.Fatal(err)
	}
	duplicate := model.Elder{Name: "乙", IDCard: "ID-UNIQUE-1"}
	if err := db.WithContext(ctx1).Create(&duplicate).Error; err == nil {
		t.Fatal("expected duplicate active ID card in tenant 1 to fail")
	}
	otherTenant := model.Elder{Name: "丙", IDCard: "ID-UNIQUE-1"}
	if err := db.WithContext(ctx2).Create(&otherTenant).Error; err != nil {
		t.Fatalf("same ID card should be allowed in tenant 2: %v", err)
	}
}
