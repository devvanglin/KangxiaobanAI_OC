package database

import (
	"context"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// defaultMedications 演示用机构药物目录种子；仅空目录的租户写入一次。
var defaultMedications = []model.Medication{
	{Name: "阿司匹林肠溶片", Category: "西药", Specification: "100mg×30片", Manufacturer: "拜耳医药保健", UsageMethod: "口服", Stock: 120, Unit: "盒", Status: "in_use", Note: "抑制血小板聚集，须遵医嘱使用"},
	{Name: "硝苯地平缓释片", Category: "西药", Specification: "20mg×30片", Manufacturer: "扬子江药业", UsageMethod: "口服", Stock: 80, Unit: "盒", Status: "in_use", Note: "用于高血压的日常管理，注意监测血压"},
	{Name: "复方丹参滴丸", Category: "中药", Specification: "27mg×180丸", Manufacturer: "天士力医药", UsageMethod: "口服", Stock: 45, Unit: "盒", Status: "in_use", Note: "活血化瘀，气滞血瘀型胸痹适用"},
}

// seedMedications 为每个已存在租户注入演示药物目录，幂等：按名称+规格判重。
func seedMedications(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		tenantDB := db.WithContext(ctx)
		for _, med := range defaultMedications {
			var item model.Medication
			if err := tenantDB.Where("name = ? AND specification = ?", med.Name, med.Specification).FirstOrCreate(&item).Error; err != nil {
				return err
			}
		}
	}
	return nil
}
