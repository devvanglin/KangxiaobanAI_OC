package middleware

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestTimeout gives context-aware REST handlers a finite deadline so a
// stalled database or upstream dependency can release the native client's
// request. The WebSocket endpoint is deliberately excluded because its
// request lifetime is the lifetime of the upgraded connection rather than one
// response. Handlers must pass c.Request.Context() to their dependencies.
func RequestTimeout(timeout time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.URL.Path == "/api/v1/ws" || timeout <= 0 {
			c.Next()
			return
		}

		ctx, cancel := context.WithTimeout(c.Request.Context(), timeout)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Next()

		// Handlers normally propagate the context error through their repository
		// call and write a 5xx response. This fallback covers handlers that return
		// without writing after the deadline; never overwrite an existing body.
		if ctx.Err() == context.DeadlineExceeded && !c.Writer.Written() {
			c.AbortWithStatusJSON(http.StatusGatewayTimeout, gin.H{
				"code": http.StatusGatewayTimeout,
				"msg":  "请求处理超时，请稍后重试",
			})
		}
	}
}
