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

// 回归：角色种子只允许按 code 查找已有角色。模拟老库升级场景——
// AutoMigrate 补出 workspace_code/is_system 列后存量行是迁移默认值，
// 若把工作台字段并入 FirstOrCreate 查找条件会查空并触发角色码唯一冲突。
func TestSeedRepairsLegacyRoleWorkspaceFields(t *testing.T) {
	dsn := fmt.Sprintf("file:workspace_seed_%d?mode=memory&cache=shared", time.Now().UnixNano())
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

	// 退化成老库升级后的形态：工作台字段全部是迁移默认值。
	if err := db.WithContext(ctx).Model(&model.Role{}).Where("1 = 1").
		Updates(map[string]interface{}{"workspace_code": "caregiver", "is_system": false}).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatalf("second seed on legacy-shaped roles must not fail: %v", err)
	}

	var roles []model.Role
	if err := db.WithContext(ctx).Preload("Permissions").Order("code asc").Find(&roles).Error; err != nil {
		t.Fatal(err)
	}
	want := map[string]struct {
		workspace string
		isSystem  bool
		perms     int
	}{
		"admin":     {"admin", true, len(model.WorkspacePermissionCodes("admin"))},
		"doctor":    {"doctor", false, len(model.WorkspacePermissionCodes("doctor"))},
		"caregiver": {"caregiver", false, len(model.WorkspacePermissionCodes("caregiver"))},
	}
	if len(roles) != len(want) {
		t.Fatalf("expected %d roles, got %d", len(want), len(roles))
	}
	for _, role := range roles {
		expected := want[role.Code]
		if role.WorkspaceCode != expected.workspace || role.IsSystem != expected.isSystem {
			t.Fatalf("role %s: got workspace=%s is_system=%v, want %s/%v",
				role.Code, role.WorkspaceCode, role.IsSystem, expected.workspace, expected.isSystem)
		}
		if len(role.Permissions) != expected.perms {
			t.Fatalf("role %s: got %d permissions, want %d", role.Code, len(role.Permissions), expected.perms)
		}
	}
}
