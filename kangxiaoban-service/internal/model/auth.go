package model

import (
	"time"

	"gorm.io/gorm"
)

// Base 通用字段；GORM 同时兼容 SQLite 与 MySQL。
type Base struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// User 员工账号（护工/医师/管理员/其他）。
type User struct {
	Base
	Username     string `gorm:"size:64;uniqueIndex;not null" json:"username"`
	PasswordHash string `gorm:"size:255;not null" json:"-"`
	RealName     string `gorm:"size:64" json:"real_name"`
	Phone        string `gorm:"size:32" json:"phone"`
	Status       int8   `gorm:"default:1" json:"status"` // 1启用 0禁用
	Roles        []Role `gorm:"many2many:sys_user_role;joinForeignKey:UserID;joinReferences:RoleID" json:"roles,omitempty"`
}

// Role 角色（护工/医师/管理员…）。
type Role struct {
	Base
	Code        string       `gorm:"size:32;uniqueIndex;not null" json:"code"`
	Name        string       `gorm:"size:64;not null" json:"name"`
	Description string       `gorm:"size:255" json:"description"`
	Permissions []Permission `gorm:"many2many:sys_role_permission;joinForeignKey:RoleID;joinReferences:PermissionID" json:"permissions,omitempty"`
}

// Permission 权限码（如 elder:read / task:write）。
type Permission struct {
	Base
	Code string `gorm:"size:64;uniqueIndex;not null" json:"code"`
	Name string `gorm:"size:128" json:"name"`
}

// AuditLog 操作审计日志。
type AuditLog struct {
	Base
	UserID uint   `gorm:"index" json:"user_id"`
	Action string `gorm:"size:64" json:"action"`
	Module string `gorm:"size:64" json:"module"`
	Method string `gorm:"size:16" json:"method"`
	Path   string `gorm:"size:255" json:"path"`
	IP     string `gorm:"size:64" json:"ip"`
}

// AutoMigrate 同步认证相关表结构。
func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&User{}, &Role{}, &Permission{}, &AuditLog{})
}

// AutoMigrateAll 认证表 + 业务业务。
func AutoMigrateAll(db *gorm.DB) error {
	return db.AutoMigrate(&User{}, &Role{}, &Permission{}, &AuditLog{}, &Elder{}, &Room{}, &Bed{}, &CareTask{}, &HealthRecord{}, &IotDevice{}, &SignalRecord{}, &Alert{})
}