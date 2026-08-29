package handler

import (
	"github.com/gin-gonic/gin"
	"net/http"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// requireElderAccess 统一校验涉及 elder_id 的家属访问范围；机构员工不受家属绑定限制。
func requireElderAccess(c *gin.Context, fam *service.FamilyService, elderID uint) bool {
	if elderID == 0 || !isFamilyUser(c) {
		return true
	}
	ids := boundElderIDs(c, fam)
	if contains(elderID, ids) {
		return true
	}
	Fail(c, http.StatusForbidden, 403, "无权限访问该长者")
	return false
}

// isFamilyUser 当前请求是否为 family 角色。
func isFamilyUser(c *gin.Context) bool {
	cl, ok := middleware.ClaimsFrom(c)
	return ok && hasRole(cl.Roles, roleFamily)
}

// boundElderIDs 返回当前家属的可见长者集合；非家属返回 nil（表示不限）。
func boundElderIDs(c *gin.Context, fam *service.FamilyService) []uint {
	if !isFamilyUser(c) {
		return nil
	}
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		return []uint{}
	}
	ids, err := fam.BoundElderIDs(c.Request.Context(), cl.UserID)
	if err != nil {
		return []uint{}
	}
	return ids
}

// contains 判断 id 是否在集合内。
func contains(id uint, ids []uint) bool {
	for _, v := range ids {
		if v == id {
			return true
		}
	}
	return false
}
