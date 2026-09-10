package handler

import (
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

type RoleHandler struct{ db *gorm.DB }

func NewRoleHandler(db *gorm.DB) *RoleHandler { return &RoleHandler{db: db} }

func (h *RoleHandler) ListPermissions(c *gin.Context) {
	var permissions []model.Permission
	if err := h.db.WithContext(c.Request.Context()).Order("id asc").Find(&permissions).Error; err != nil {
		Fail(c, 500, 500, "查询权限目录失败")
		return
	}
	OK(c, gin.H{"list": permissions})
}

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
	if err := query.Count(&total).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询角色失败")
		return
	}
	var roles []model.Role
	if err := query.Order("display_order asc, id asc").Offset((page - 1) * size).Limit(size).Find(&roles).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询角色失败")
		return
	}
	OK(c, gin.H{"list": roles, "page": page, "size": size, "total": total})
}

type roleInput struct {
	Name          string `json:"name" binding:"required"`
	Code          string `json:"code" binding:"required"`
	DisplayOrder  int8   `json:"display_order"`
	Status        int8   `json:"status"`
	Remark        string `json:"remark"`
	WorkspaceCode string `json:"workspace_code"`
}

func (h *RoleHandler) Create(c *gin.Context) {
	var input roleInput
	if err := c.ShouldBindJSON(&input); err != nil {
		Fail(c, http.StatusBadRequest, 400, "角色名称和权限字符必填")
		return
	}
	input.Code = strings.TrimSpace(input.Code)
	if !isValidRoleCode(input.Code) {
		Fail(c, http.StatusBadRequest, 400, "权限字符需以小写字母开头，长度 2-32，仅可包含字母、数字、下划线和短横线")
		return
	}
	if input.Code == "admin" || strings.TrimSpace(input.WorkspaceCode) == "admin" {
		Fail(c, http.StatusForbidden, 403, "管理工作台仅供系统管理员角色使用")
		return
	}
	workspace := model.NormalizeWorkspace(input.WorkspaceCode)
	role := model.Role{Name: input.Name, Code: input.Code, DisplayOrder: input.DisplayOrder, Status: normalizedRoleStatus(input.Status), Remark: input.Remark, WorkspaceCode: workspace}
	if err := h.db.WithContext(c.Request.Context()).Create(&role).Error; err != nil {
		Fail(c, http.StatusConflict, 409, "角色字符已存在或创建失败")
		return
	}
	if err := h.applyWorkspacePermissions(c, &role); err != nil {
		_ = h.db.WithContext(c.Request.Context()).Delete(&model.Role{}, role.ID)
		Fail(c, 500, 500, "角色权限保存失败")
		return
	}
	if err := h.db.WithContext(c.Request.Context()).Preload("Permissions").First(&role, role.ID).Error; err != nil {
		Fail(c, 500, 500, "角色创建失败")
		return
	}
	OK(c, role)
}

func (h *RoleHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input roleInput
	if err := c.ShouldBindJSON(&input); err != nil {
		Fail(c, 400, 400, "角色名称和权限字符必填")
		return
	}
	var role model.Role
	db := h.db.WithContext(c.Request.Context())
	if err := db.First(&role, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "角色不存在")
		return
	}
	if role.IsSystem {
		Fail(c, http.StatusForbidden, 403, "系统角色不可修改")
		return
	}
	input.Code = strings.TrimSpace(input.Code)
	if !isValidRoleCode(input.Code) {
		Fail(c, http.StatusBadRequest, 400, "权限字符需以小写字母开头，长度 2-32，仅可包含字母、数字、下划线和短横线")
		return
	}
	if input.Code == "admin" || strings.TrimSpace(input.WorkspaceCode) == "admin" {
		Fail(c, http.StatusForbidden, 403, "管理工作台仅供系统管理员角色使用")
		return
	}
	workspace := model.NormalizeWorkspace(input.WorkspaceCode)
	if err := db.Model(&role).Updates(map[string]interface{}{"name": input.Name, "code": input.Code, "display_order": input.DisplayOrder, "status": normalizedRoleStatus(input.Status), "remark": input.Remark, "workspace_code": workspace}).Error; err != nil {
		Fail(c, 409, 409, "角色更新失败")
		return
	}
	role.Name, role.Code, role.DisplayOrder, role.Status, role.Remark, role.WorkspaceCode = input.Name, input.Code, input.DisplayOrder, normalizedRoleStatus(input.Status), input.Remark, workspace
	if err := h.applyWorkspacePermissions(c, &role); err != nil {
		Fail(c, 500, 500, "角色权限保存失败")
		return
	}
	if err := db.Preload("Permissions").First(&role, role.ID).Error; err != nil {
		Fail(c, 500, 500, "角色更新失败")
		return
	}
	OK(c, role)
}

func (h *RoleHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var role model.Role
	if err := h.db.WithContext(c.Request.Context()).First(&role, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "角色不存在")
		return
	}
	if role.IsSystem {
		Fail(c, http.StatusForbidden, 403, "系统角色不可删除")
		return
	}
	var assigned int64
	if err := h.db.WithContext(c.Request.Context()).Table("sys_user_role").Where("role_id = ?", role.ID).Count(&assigned).Error; err != nil {
		Fail(c, 500, 500, "角色使用情况检查失败")
		return
	}
	if assigned > 0 {
		Fail(c, http.StatusConflict, 409, "该角色仍分配给用户，请先在用户管理中移除分配")
		return
	}
	if err := h.db.WithContext(c.Request.Context()).Delete(&model.Role{}, uint(id)).Error; err != nil {
		Fail(c, 500, 500, "删除角色失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

func (h *RoleHandler) SetStatus(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input struct {
		Status int8 `json:"status"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		Fail(c, 400, 400, "状态参数错误")
		return
	}
	var role model.Role
	if err := h.db.WithContext(c.Request.Context()).First(&role, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "角色不存在")
		return
	}
	if role.IsSystem {
		Fail(c, http.StatusForbidden, 403, "系统角色不可停用")
		return
	}
	status := normalizedRoleStatus(input.Status)
	if err := h.db.WithContext(c.Request.Context()).Model(&model.Role{}).Where("id = ?", uint(id)).Update("status", status).Error; err != nil {
		Fail(c, 500, 500, "状态更新失败")
		return
	}
	OK(c, gin.H{"status": status})
}

// applyWorkspacePermissions 用登录工作台的基准权限集替换角色权限。
// 角色的能力由工作台唯一决定，客户端提交的权限清单不参与授权。
func (h *RoleHandler) applyWorkspacePermissions(c *gin.Context, role *model.Role) error {
	var permissions []model.Permission
	if err := h.db.WithContext(c.Request.Context()).Where("code IN ?", model.WorkspacePermissionCodes(role.WorkspaceCode)).Find(&permissions).Error; err != nil {
		return err
	}
	return h.db.WithContext(c.Request.Context()).Model(role).Association("Permissions").Replace(permissions)
}

func normalizedRoleStatus(value int8) int8 {
	if value != 0 && value != 1 {
		return 1
	}
	return value
}

var roleCodePattern = regexp.MustCompile(`^[a-z][a-z0-9_-]{1,31}$`)

func isValidRoleCode(code string) bool { return roleCodePattern.MatchString(strings.TrimSpace(code)) }
