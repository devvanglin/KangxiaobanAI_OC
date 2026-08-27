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
	var u model.User
	err := r.db.
		Preload("Roles", func(db *gorm.DB) *gorm.DB {
			return db.Preload("Permissions")
		}).
		Where("username = ?", username).
		First(&u).Error
	if err != nil {
		return nil, err
	}
	return &u, nil
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