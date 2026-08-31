package handler

import (
	"net/http"
	"strconv"

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
	if status := c.Query("status"); status == "0" || status == "1" {
		query = query.Where("status = ?", status)
	}
	var total int64
	if err := query.Count(&total).Error; err != nil { Fail(c, http.StatusInternalServerError, 500, "查询角色失败"); return }
	var roles []model.Role
	if err := query.Order("display_order asc, id asc").Offset((page-1)*size).Limit(size).Find(&roles).Error; err != nil { Fail(c, http.StatusInternalServerError, 500, "查询角色失败"); return }
	OK(c, gin.H{"list": roles, "page": page, "size": size, "total": total})
}

type roleInput struct {
	Name string `json:"name" binding:"required"`
	Code string `json:"code" binding:"required"`
	DisplayOrder int8 `json:"display_order"`
	Status int8 `json:"status"`
	Remark string `json:"remark"`
	PermissionIDs []uint `json:"permission_ids"`
}

func (h *RoleHandler) Create(c *gin.Context) {
	var input roleInput
	if err := c.ShouldBindJSON(&input); err != nil { Fail(c, http.StatusBadRequest, 400, "角色名称和权限字符必填"); return }
	role := model.Role{Name: input.Name, Code: input.Code, DisplayOrder: input.DisplayOrder, Status: normalizedRoleStatus(input.Status), Remark: input.Remark}
	if err := h.db.WithContext(c.Request.Context()).Create(&role).Error; err != nil { Fail(c, http.StatusConflict, 409, "角色字符已存在或创建失败"); return }
	if err := h.replacePermissions(c, &role, input.PermissionIDs); err != nil { Fail(c, 500, 500, "角色权限保存失败"); return }
	OK(c, role)
}

func (h *RoleHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input roleInput
	if err := c.ShouldBindJSON(&input); err != nil { Fail(c, 400, 400, "角色名称和权限字符必填"); return }
	var role model.Role
	db := h.db.WithContext(c.Request.Context())
	if err := db.First(&role, uint(id)).Error; err != nil { Fail(c, 404, 404, "角色不存在"); return }
	if err := db.Model(&role).Updates(map[string]interface{}{"name": input.Name, "code": input.Code, "display_order": input.DisplayOrder, "status": normalizedRoleStatus(input.Status), "remark": input.Remark}).Error; err != nil { Fail(c, 409, 409, "角色更新失败"); return }
	role.Name, role.Code, role.DisplayOrder, role.Status, role.Remark = input.Name, input.Code, input.DisplayOrder, normalizedRoleStatus(input.Status), input.Remark
	if err := h.replacePermissions(c, &role, input.PermissionIDs); err != nil { Fail(c, 500, 500, "角色权限保存失败"); return }
	OK(c, role)
}

func (h *RoleHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.db.WithContext(c.Request.Context()).Delete(&model.Role{}, uint(id)).Error; err != nil { Fail(c, 500, 500, "删除角色失败"); return }
	OK(c, gin.H{"deleted": true})
}

func (h *RoleHandler) SetStatus(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input struct{ Status int8 `json:"status"` }
	if err := c.ShouldBindJSON(&input); err != nil { Fail(c, 400, 400, "状态参数错误"); return }
	status := normalizedRoleStatus(input.Status)
	if err := h.db.WithContext(c.Request.Context()).Model(&model.Role{}).Where("id = ?", uint(id)).Update("status", status).Error; err != nil { Fail(c, 500, 500, "状态更新失败"); return }
	OK(c, gin.H{"status": status})
}

func (h *RoleHandler) replacePermissions(c *gin.Context, role *model.Role, ids []uint) error {
	var permissions []model.Permission
	if len(ids) > 0 {
		if err := h.db.WithContext(c.Request.Context()).Where("id IN ?", ids).Find(&permissions).Error; err != nil { return err }
	}
	return h.db.WithContext(c.Request.Context()).Model(role).Association("Permissions").Replace(permissions)
}

func normalizedRoleStatus(value int8) int8 { if value != 0 && value != 1 { return 1 }; return value }
