package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CORS 允许跨域访问（护士站大屏等 Web 端）。
// 演示阶段放开所有来源；生产应按域白名单收紧。
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		// The admission photo endpoint uses headers for the opaque pending
		// upload key and fixed document slot. Keep them explicit so a browser
		// client can pass the preflight before the authenticated upload.
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Upload-Key, X-Photo-Kind")
		c.Header("Access-Control-Max-Age", "86400")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
