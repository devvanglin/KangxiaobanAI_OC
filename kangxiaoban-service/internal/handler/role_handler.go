package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

type RoleHandler struct { db *gorm.DB }

func NewRoleHandler(db *gorm.DB) *RoleHandler { return &RoleHandler{db: db} }

// List GET /api/v1/roles returns tenant-independent RBAC definitions for administrators.
func (h *RoleHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	query := h.db.WithContext(c.Request.Context()).Model(&model.Role{}).Preload("Permissions")
	if keyword := c.Query("keyword"); keyword != "" {
		query = query.Where("name LIKE ? OR code LIKE ?", "%"+keyword+"%", "%"+keyword+"%")
	}
	var total int64
	if err := query.Count(&total).Error; err != nil { Fail(c, http.StatusInternalServerError, 500, "查询角色失败"); return }
	var roles []model.Role
	if err := query.Order("id asc").Offset((page-1)*size).Limit(size).Find(&roles).Error; err != nil { Fail(c, http.StatusInternalServerError, 500, "查询角色失败"); return }
	OK(c, gin.H{"list": roles, "page": page, "size": size, "total": total})
}
