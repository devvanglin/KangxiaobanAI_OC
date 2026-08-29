package database

import (
	"context"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"kangxiaoban-service/internal/model"
)

// TenantContextKey 是请求上下文中的机构租户键。未设置时使用默认租户 1。
func tenantFromContext(ctx context.Context) uint {
	if ctx != nil {
		if v, ok := ctx.Value(model.TenantContextKey).(uint); ok && v > 0 {
			return v
		}
	}
	return 1
}

// RegisterTenantScope 为所有带 tenant_id 的模型注册统一 GORM 隔离规则。
// 这样 Repository 无需逐个复制 Where 条件，且每个请求使用自己的 context。
func RegisterTenantScope(db *gorm.DB) error {
	query := func(tx *gorm.DB) {
		if tx.Statement.Schema == nil || tx.Statement.Schema.Table == "tenants" || tx.Statement.Schema.Table == "roles" || tx.Statement.Schema.Table == "permissions" || tx.Statement.Schema.LookUpField("TenantID") == nil {
			return
		}
		tx.Statement.AddClause(clause.Where{Exprs: []clause.Expression{clause.Eq{Column: clause.Column{Name: "tenant_id"}, Value: tenantFromContext(tx.Statement.Context)}}})
	}
	create := func(tx *gorm.DB) {
		if tx.Statement.Schema == nil || tx.Statement.Schema.Table == "tenants" || tx.Statement.Schema.Table == "roles" || tx.Statement.Schema.Table == "permissions" {
			return
		}
		if tx.Statement.Schema.LookUpField("TenantID") == nil {
			return
		}
		tx.Statement.SetColumn("TenantID", tenantFromContext(tx.Statement.Context))
	}
	if err := db.Callback().Query().Before("gorm:query").Register("kangxiaoban:tenant_query", query); err != nil {
		return err
	}
	if err := db.Callback().Create().Before("gorm:create").Register("kangxiaoban:tenant_create", create); err != nil {
		return err
	}
	if err := db.Callback().Update().Before("gorm:update").Register("kangxiaoban:tenant_update", query); err != nil {
		return err
	}
	if err := db.Callback().Delete().Before("gorm:delete").Register("kangxiaoban:tenant_delete", query); err != nil {
		return err
	}
	return nil
}
