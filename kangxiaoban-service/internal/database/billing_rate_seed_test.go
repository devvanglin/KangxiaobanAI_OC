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

func TestBillingRateSeedIsIdempotentAndPreservesTenantValues(t *testing.T) {
	dsn := fmt.Sprintf("file:billing_rate_seed_%d?mode=memory&cache=shared", time.Now().UnixNano())
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
	ctx1 := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	var initial int64
	if err := db.WithContext(ctx1).Model(&model.BillingRate{}).Count(&initial).Error; err != nil {
		t.Fatal(err)
	}
	if initial != 7 {
		t.Fatalf("default billing rate count = %d, want 7", initial)
	}
	if err := db.WithContext(ctx1).Model(&model.BillingRate{}).
		Where("kind = ? AND care_level = 0", model.BillingRateKindBed).
		Update("amount", 1888).Error; err != nil {
		t.Fatal(err)
	}
	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}
	var bed model.BillingRate
	if err := db.WithContext(ctx1).Where("kind = ? AND care_level = 0", model.BillingRateKindBed).First(&bed).Error; err != nil {
		t.Fatal(err)
	}
	if bed.Amount != 1888 {
		t.Fatalf("configured bed amount overwritten: got %.2f", bed.Amount)
	}
	var after int64
	if err := db.WithContext(ctx1).Model(&model.BillingRate{}).Count(&after).Error; err != nil {
		t.Fatal(err)
	}
	if after != initial {
		t.Fatalf("idempotent seed count = %d, want %d", after, initial)
	}
	if err := seedBusinessData(db); err != nil {
		t.Fatal(err)
	}
	var bill model.Bill
	if err := db.WithContext(ctx1).Order("id").First(&bill).Error; err != nil {
		t.Fatal(err)
	}
	if bill.BedFee != 1888 {
		t.Fatalf("bootstrap bill ignored configured bed rate: got %.2f", bill.BedFee)
	}
	duplicate := model.BillingRate{Kind: model.BillingRateKindBed, DisplayName: "duplicate", Amount: 1, Currency: "CNY", Unit: "month", Enabled: true}
	if err := db.WithContext(ctx1).Create(&duplicate).Error; err == nil {
		t.Fatal("expected duplicate tenant billing rate to fail")
	}
}
