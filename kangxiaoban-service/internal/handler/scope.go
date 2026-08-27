package handler

import (
	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

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
	ids, err := fam.BoundElderIDs(cl.UserID)
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