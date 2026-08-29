package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// AuthHandler 登录 / 当前用户。
type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

type loginReq struct {
	Username   string `json:"username" binding:"required"`
	Password   string `json:"password" binding:"required"`
	TenantCode string `json:"tenant_code"`
}

// Login POST /api/v1/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	tenantID := uint(1)
	if req.TenantCode != "" {
		// 登录服务内部按租户查用户；租户不存在时按凭据错误处理，避免泄露机构信息。
		// TenantCode 解析由服务层仓储完成。
		if t, e := h.svc.TenantByCode(req.TenantCode); e == nil {
			tenantID = t.ID
		} else {
			Fail(c, http.StatusUnauthorized, 401, service.ErrInvalidCredentials.Error())
			return
		}
	}
	token, user, err := h.svc.LoginInTenant(c.Request.Context(), req.Username, req.Password, tenantID)
	if err != nil {
		code := http.StatusUnauthorized
		if err == service.ErrUserDisabled {
			code = http.StatusForbidden
		}
		Fail(c, code, code, err.Error())
		return
	}
	OK(c, gin.H{
		"token": token,
		"user":  user,
	})
}

// Me GET /api/v1/auth/me —— 从上下文身份回显（真实用户信息以 Login 返回为准，这里供前端核对 token）。
func (h *AuthHandler) Me(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	OK(c, gin.H{"user_id": claims.UserID, "username": claims.Username, "tenant_id": claims.TenantID, "roles": claims.Roles})
}
