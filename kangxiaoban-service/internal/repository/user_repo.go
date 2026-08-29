package repository

import (
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// UserRepository 用户数据访问。
type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

// FindByUsername 按用户名查询，预载角色与权限。
func (r *UserRepository) FindByUsername(username string) (*model.User, error) {
	return r.FindByUsernameInTenant(username, 1)
}

func (r *UserRepository) FindByUsernameInTenant(username string, tenantID uint) (*model.User, error) {
	var u model.User
	err := r.db.
		Preload("Roles", func(db *gorm.DB) *gorm.DB {
			return db.Preload("Permissions")
		}).
		Where("username = ? AND tenant_id = ?", username, tenantID).
		First(&u).Error
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) TenantByCode(code string) (*model.Tenant, error) {
	var t model.Tenant
	err := r.db.Where("code = ? AND status = 1", code).First(&t).Error
	return &t, err
}

// FindByID 按主键查询，预载角色与权限。
func (r *UserRepository) FindByID(id uint) (*model.User, error) {
	var u model.User
	err := r.db.
		Preload("Roles", func(db *gorm.DB) *gorm.DB {
			return db.Preload("Permissions")
		}).
		First(&u, id).Error
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// ListContacts 返回当前租户可用于护理沟通的正式账号，不包含密码哈希。
func (r *UserRepository) ListContacts(tenantID, excludeID uint) ([]model.User, error) {
	var users []model.User
	err := r.db.Preload("Roles").Where("tenant_id = ? AND id <> ? AND deleted_at IS NULL AND status = 1", tenantID, excludeID).Order("id asc").Find(&users).Error
	for i := range users {
		users[i].PasswordHash = ""
	}
	return users, err
}

// PermissionsByRoleCodes 汇总给定角色集合的权限码（去重）。
func (r *UserRepository) PermissionsByRoleCodes(codes []string) ([]string, error) {
	if len(codes) == 0 {
		return nil, nil
	}
	var perms []model.Permission
	err := r.db.
		Joins("JOIN sys_role_permission srp ON srp.permission_id = permissions.id").
		Joins("JOIN roles r ON r.id = srp.role_id").
		Where("r.code IN ?", codes).
		Find(&perms).Error
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(perms))
	seen := map[string]bool{}
	for _, p := range perms {
		if !seen[p.Code] {
			seen[p.Code] = true
			out = append(out, p.Code)
		}
	}
	return out, nil
}
