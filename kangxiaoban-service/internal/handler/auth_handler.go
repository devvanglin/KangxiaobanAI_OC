package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

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
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// Login POST /api/v1/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	token, user, err := h.svc.Login(req.Username, req.Password)
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
	Fail(c, http.StatusNotImplemented, 501, "M0 暂不实现 /me 详情，后续里程碑补齐")
}