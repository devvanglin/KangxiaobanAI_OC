package database

import (
	"context"
	"fmt"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

var defaultBillingRates = []model.BillingRate{
	{Kind: model.BillingRateKindBed, CareLevel: 0, DisplayName: "标准床位费", Amount: 1500, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindMeal, CareLevel: 0, DisplayName: "标准餐费", Amount: 900, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindNursing, CareLevel: 1, DisplayName: "一级护理费", Amount: 1200, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindNursing, CareLevel: 2, DisplayName: "二级护理费", Amount: 1800, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindNursing, CareLevel: 3, DisplayName: "三级护理费", Amount: 2400, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindNursing, CareLevel: 4, DisplayName: "四级护理费", Amount: 3000, Currency: "CNY", Unit: "month", Enabled: true},
	{Kind: model.BillingRateKindNursing, CareLevel: 5, DisplayName: "五级护理费", Amount: 3600, Currency: "CNY", Unit: "month", Enabled: true},
}

// ensureBillingRateConstraint prevents ambiguous current rates while retaining
// soft-deleted history. SQLite uses a partial index; MySQL uses an equivalent
// nullable generated key because it has no partial unique indexes.
func ensureBillingRateConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID  uint
		Kind      string
		CareLevel int8
		Count     int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, kind, care_level, COUNT(*) AS count FROM billing_rates WHERE deleted_at IS NULL GROUP BY tenant_id, kind, care_level HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active billing rate in tenant %d: %s/%d", duplicates[0].TenantID, duplicates[0].Kind, duplicates[0].CareLevel)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_billing_rates_tenant_kind_level ON billing_rates(tenant_id, kind, care_level) WHERE deleted_at IS NULL").Error
	case "mysql":
		if !db.Migrator().HasColumn(&model.BillingRate{}, "active_rate_key") {
			if err := db.Exec("ALTER TABLE billing_rates ADD COLUMN active_rate_key VARCHAR(32) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN CONCAT(kind, ':', care_level) ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.BillingRate{}, "uk_billing_rates_tenant_kind_level") {
			return db.Exec("CREATE UNIQUE INDEX uk_billing_rates_tenant_kind_level ON billing_rates(tenant_id, active_rate_key)").Error
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}

// seedBillingRates supplies only missing tenant defaults. Existing configured
// amounts and enabled state are deliberately preserved across restarts.
func seedBillingRates(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		tenantDB := db.WithContext(ctx)
		for _, defaultRate := range defaultBillingRates {
			var rate model.BillingRate
			query := tenantDB.Where("kind = ? AND care_level = ?", defaultRate.Kind, defaultRate.CareLevel)
			if err := query.Attrs(defaultRate).FirstOrCreate(&rate).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func loadMonthlyBillingRates(db *gorm.DB, careLevel int8) (bed, nursing, meal float64, err error) {
	var rates []model.BillingRate
	if err = db.Where("enabled = ?", true).Find(&rates).Error; err != nil {
		return 0, 0, 0, err
	}
	foundBed, foundNursing, foundMeal := false, false, false
	for _, rate := range rates {
		switch {
		case rate.Kind == model.BillingRateKindBed && rate.CareLevel == 0:
			bed, foundBed = rate.Amount, true
		case rate.Kind == model.BillingRateKindMeal && rate.CareLevel == 0:
			meal, foundMeal = rate.Amount, true
		case rate.Kind == model.BillingRateKindNursing && rate.CareLevel == careLevel:
			nursing, foundNursing = rate.Amount, true
		}
	}
	if !foundBed || !foundNursing || !foundMeal {
		return 0, 0, 0, fmt.Errorf("incomplete billing rates for care level %d", careLevel)
	}
	if bed < 0 || nursing < 0 || meal < 0 {
		return 0, 0, 0, fmt.Errorf("negative billing rate for care level %d", careLevel)
	}
	return bed, nursing, meal, nil
}
