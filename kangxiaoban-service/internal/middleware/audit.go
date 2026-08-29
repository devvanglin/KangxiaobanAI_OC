package middleware

import (
	"context"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// Audit 写操作审计：非 GET 请求在执行后异步记录 audit_log。
func Audit(auditRepo *repository.AuditRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
		if c.Request.Method == "GET" {
			return
		}
		cl, _ := ClaimsFrom(c)
		if cl == nil {
			return
		}
		// Gin's request context is canceled as soon as the response is returned.
		// Detach the asynchronous write while preserving the authenticated tenant.
		auditCtx := context.WithoutCancel(c.Request.Context())
		auditCtx = context.WithValue(auditCtx, model.TenantContextKey, cl.TenantID)
		userID := cl.UserID
		method := c.Request.Method
		path := c.Request.URL.Path
		ip := c.ClientIP()
		go func() {
			_ = auditRepo.CreateContext(auditCtx, &model.AuditLog{
				UserID: userID,
				Method: method,
				Path:   path,
				IP:     ip,
			})
		}()
	}
}
