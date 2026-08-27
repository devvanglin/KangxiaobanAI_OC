package middleware

import (
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
		go func() {
			_ = auditRepo.Create(&model.AuditLog{
				UserID: cl.UserID,
				Method: c.Request.Method,
				Path:   c.Request.URL.Path,
				IP:     c.ClientIP(),
			})
		}()
	}
}