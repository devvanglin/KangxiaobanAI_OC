package handler

import (
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

type UserHandler struct{ db *gorm.DB }

func NewUserHandler(db *gorm.DB) *UserHandler { return &UserHandler{db: db} }

func (h *UserHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	query := h.db.WithContext(c.Request.Context()).Model(&model.User{}).Preload("Roles")
	if keyword := strings.TrimSpace(c.Query("keyword")); keyword != "" {
		like := "%" + keyword + "%"
		query = query.Where("username LIKE ? OR real_name LIKE ? OR phone LIKE ?", like, like, like)
	}
	if status := c.Query("status"); status == "0" || status == "1" {
		query = query.Where("status = ?", status)
	}
	var total int64
	if err := query.Count(&total).Error; err != nil {
		Fail(c, 500, 500, "查询用户失败")
		return
	}
	var users []model.User
	if err := query.Order("id asc").Offset((page - 1) * size).Limit(size).Find(&users).Error; err != nil {
		Fail(c, 500, 500, "查询用户失败")
		return
	}
	for i := range users {
		users[i].PasswordHash = ""
	}
	OK(c, gin.H{"list": users, "page": page, "size": size, "total": total})
}

type userInput struct {
	Username  string   `json:"username" binding:"required"`
	Password  string   `json:"password"`
	RealName  string   `json:"real_name"`
	Phone     string   `json:"phone"`
	RoleCode  string   `json:"role_code"`
	RoleCodes []string `json:"role_codes"`
}

func (h *UserHandler) Create(c *gin.Context) {
	var input userInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Password) == "" {
		Fail(c, 400, 400, "用户名、密码和角色必填")
		return
	}
	roleCodes := normalizeRoleCodes(input.RoleCodes, input.RoleCode)
	if len(roleCodes) == 0 {
		Fail(c, 400, 400, "至少绑定一个角色")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		Fail(c, 500, 500, "密码处理失败")
		return
	}
	db := h.db.WithContext(c.Request.Context())
	var roles []model.Role
	if err := db.Where("code IN ? AND status = 1", roleCodes).Find(&roles).Error; err != nil || len(roles) != len(roleCodes) {
		Fail(c, 400, 400, "角色不存在或已停用")
		return
	}
	user := model.User{Username: strings.TrimSpace(input.Username), PasswordHash: string(hash), RealName: input.RealName, Phone: input.Phone, Status: 1}
	if err := db.Create(&user).Error; err != nil {
		Fail(c, 409, 409, "用户名已存在")
		return
	}
	if err := db.Model(&user).Association("Roles").Replace(roles); err != nil {
		Fail(c, 500, 500, "角色绑定失败")
		return
	}
	user.PasswordHash = ""
	user.Roles = roles
	OK(c, user)
}

// UpdateRoles replaces all active roles for one user. The caller must be an
// administrator; tenant scoping is supplied by the request context.
func (h *UserHandler) UpdateRoles(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req struct {
		RoleCodes []string `json:"role_codes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || len(req.RoleCodes) == 0 {
		Fail(c, 400, 400, "至少绑定一个角色")
		return
	}
	roleCodes := normalizeRoleCodes(req.RoleCodes, "")
	var roles []model.Role
	db := h.db.WithContext(c.Request.Context())
	if err := db.Where("code IN ? AND status = 1", roleCodes).Find(&roles).Error; err != nil || len(roles) != len(roleCodes) {
		Fail(c, 400, 400, "角色不存在或已停用")
		return
	}
	var user model.User
	if err := db.First(&user, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "用户不存在")
		return
	}
	if err := db.Model(&user).Association("Roles").Replace(roles); err != nil {
		Fail(c, 500, 500, "角色绑定失败")
		return
	}
	user.PasswordHash = ""
	user.Roles = roles
	OK(c, user)
}

func (h *UserHandler) SetStatus(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input struct {
		Status int8 `json:"status"`
	}
	if err := c.ShouldBindJSON(&input); err != nil || (input.Status != 0 && input.Status != 1) {
		Fail(c, 400, 400, "状态参数错误")
		return
	}
	if err := h.db.WithContext(c.Request.Context()).Model(&model.User{}).Where("id = ?", uint(id)).Update("status", input.Status).Error; err != nil {
		Fail(c, 500, 500, "状态更新失败")
		return
	}
	OK(c, gin.H{"status": input.Status})
}

func normalizeRoleCodes(codes []string, fallback string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(codes)+1)
	for _, value := range append(codes, fallback) {
		value = strings.TrimSpace(value)
		if value != "" && !seen[value] {
			seen[value] = true
			out = append(out, value)
		}
	}
	return out
}
