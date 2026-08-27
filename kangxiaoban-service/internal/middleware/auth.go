package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/auth"
	"kangxiaoban-service/internal/repository"
)

type ctxKey string

// ClaimsKey context 中存放已解析身份的键。
const ClaimsKey ctxKey = "claims"

// JWTAuth 校验 Authorization: Bearer <token>，并把身份写入上下文。
func JWTAuth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "msg": "未登录或缺少令牌"})
			return
		}
		claims, err := auth.ParseToken(strings.TrimPrefix(header, "Bearer "), secret)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "msg": "令牌无效或已过期"})
			return
		}
		c.Set(string(ClaimsKey), claims)
		c.Next()
	}
}

// RequirePermission 基于角色加载权限并校验；required 为 "*" 时放行（超级权限）。
func RequirePermission(repo *repository.UserRepository, required string) gin.HandlerFunc {
	return func(c *gin.Context) {
		claims, ok := c.Get(string(ClaimsKey))
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "msg": "未登录"})
			return
		}
		cl := claims.(*auth.Claims)

		perms, err := repo.PermissionsByRoleCodes(cl.Roles)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"code": 500, "msg": "权限校验失败"})
			return
		}
		if hasPerm(perms, required) {
			c.Next()
			return
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"code": 403, "msg": "无权限执行该操作"})
	}
}

func hasPerm(perms []string, required string) bool {
	for _, p := range perms {
		if p == "*" || p == required {
			return true
		}
	}
	return false
}

// ClaimsFrom 从上下文取身份。
func ClaimsFrom(c *gin.Context) (*auth.Claims, bool) {
	v, ok := c.Get(string(ClaimsKey))
	if !ok {
		return nil, false
	}
	cl, ok := v.(*auth.Claims)
	return cl, ok
}