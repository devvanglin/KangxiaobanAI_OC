package model

import "strings"

// 登录工作台基准权限集。角色的权限完全由其工作台决定：
// 管理工作台仅供系统内置管理员角色使用；自定义角色只能选择
// 护工/医师工作台，服务端在创建、更新与启动时把角色权限
// 强制同步到对应基准集，客户端提交的权限清单不再生效。
func WorkspacePermissionCodes(workspace string) []string {
	switch workspace {
	case "admin":
		return []string{
			"dash:read", "elder:read", "elder:write", "task:read", "task:write",
			"care:review", "health:read", "health:write", "alert:read", "alert:handle",
			"admission:read", "admission:write", "plan:manage", "admin:all"}
	case "doctor":
		return []string{
			"dash:read", "elder:read", "health:read", "health:write", "task:read", "care:review",
			"alert:read", "alert:handle", "admission:read", "admission:write", "plan:manage"}
	default:
		return []string{
			"dash:read", "elder:read", "health:read", "health:write",
			"task:read", "task:write", "alert:read"}
	}
}

// NormalizeWorkspace 归一化自定义角色的登录工作台；
// 管理工作台不可分配，未知取值回退到护工工作台。
func NormalizeWorkspace(value string) string {
	trimmed := strings.TrimSpace(value)
	switch trimmed {
	case "doctor", "caregiver":
		return trimmed
	}
	return "caregiver"
}

// WorkspaceDisplayName 返回工作台的界面名称。
func WorkspaceDisplayName(workspace string) string {
	switch workspace {
	case "admin":
		return "管理工作台"
	case "doctor":
		return "医师工作台"
	case "caregiver":
		return "护工工作台"
	}
	return "护工工作台"
}
