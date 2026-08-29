package service

import (
	"context"
	"testing"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

func TestFinanceGenerateMonthUsesTenantBillingRates(t *testing.T) {
	_, db, _, ctx1 := newAdmissionTestService(t)
	tenant2 := model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "billing-two", Name: "费率二号机构", Status: 1}
	if err := db.Create(&tenant2).Error; err != nil {
		t.Fatal(err)
	}
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))

	rateRepo := repository.NewBillingRateRepository(db)
	defaults, err := rateRepo.ListEnabled(ctx1)
	if err != nil {
		t.Fatal(err)
	}
	for _, rate := range defaults {
		rate.Base = model.Base{}
		switch rate.Kind {
		case model.BillingRateKindBed:
			rate.Amount = 2100
		case model.BillingRateKindMeal:
			rate.Amount = 1100
		case model.BillingRateKindNursing:
			rate.Amount = float64(rate.CareLevel) * 1000
		}
		if err := db.WithContext(ctx2).Create(&rate).Error; err != nil {
			t.Fatal(err)
		}
	}
	elder := model.Elder{Name: "二号机构计费长者", IDCard: "BILLING-TENANT-2", CareLevel: 3, Status: 2}
	if err := db.WithContext(ctx2).Create(&elder).Error; err != nil {
		t.Fatal(err)
	}

	finance := NewFinanceService(db, repository.NewFinanceRepository(db), repository.NewElderRepository(db))
	created, err := finance.GenerateMonth(ctx2, "2099-01")
	if err != nil {
		t.Fatal(err)
	}
	if created != 1 {
		t.Fatalf("tenant 2 generated bills = %d, want 1", created)
	}
	var bill model.Bill
	if err := db.WithContext(ctx2).Where("elder_id = ? AND bill_month = ?", elder.ID, "2099-01").First(&bill).Error; err != nil {
		t.Fatal(err)
	}
	if bill.BedFee != 2100 || bill.NursingFee != 3000 || bill.MealFee != 1100 || bill.Amount != 6200 {
		t.Fatalf("tenant 2 bill used wrong rates: %+v", bill)
	}
	var leaked int64
	if err := db.WithContext(ctx1).Model(&model.Bill{}).Where("id = ?", bill.ID).Count(&leaked).Error; err != nil {
		t.Fatal(err)
	}
	if leaked != 0 {
		t.Fatal("tenant 2 bill leaked into tenant 1")
	}

	created, err = finance.GenerateMonth(ctx1, "2099-01")
	if err != nil {
		t.Fatal(err)
	}
	if created == 0 {
		t.Fatal("tenant 1 default billing generation created no bills")
	}
	var tenant1Bill model.Bill
	if err := db.WithContext(ctx1).Where("bill_month = ?", "2099-01").Order("id").First(&tenant1Bill).Error; err != nil {
		t.Fatal(err)
	}
	if tenant1Bill.BedFee != 1500 || tenant1Bill.MealFee != 900 {
		t.Fatalf("tenant 1 rates contaminated by tenant 2: %+v", tenant1Bill)
	}
	if err := db.WithContext(ctx1).Model(&model.BillingRate{}).
		Where("kind = ? AND care_level = ?", model.BillingRateKindNursing, 2).
		Update("enabled", false).Error; err != nil {
		t.Fatal(err)
	}
	created, err = finance.GenerateMonth(ctx1, "2099-01")
	if err != nil || created != 0 {
		t.Fatalf("idempotent existing month depends on current rates: created=%d err=%v", created, err)
	}
	created, err = finance.GenerateMonth(ctx1, "2099-02")
	if err == nil || created != 0 {
		t.Fatalf("incomplete tenant rates generated partial bills: created=%d err=%v", created, err)
	}
	var partial int64
	if err := db.WithContext(ctx1).Model(&model.Bill{}).Where("bill_month = ?", "2099-02").Count(&partial).Error; err != nil {
		t.Fatal(err)
	}
	if partial != 0 {
		t.Fatalf("incomplete rates persisted %d partial bills", partial)
	}
}
