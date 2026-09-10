package middleware

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// agentExchangeTimeout bounds one full agent exchange. The agent may run
// several model turns plus tool calls, which is far slower than one REST
// request; the value stays generous because on-prem models are slow and the
// client UI owns its own spinner.
// 480s：工作模式 AI 的沙箱工具首次创建隔离容器（含 egress 边车）在
// 低配宿主上可能耗时 3-5 分钟，放宽到 8 分钟以保证端到端可用。
const agentExchangeTimeout = 660 * time.Second

// isAgentExchangePath reports whether the request is one AI agent exchange.
func isAgentExchangePath(path string) bool {
	if path == "/api/v1/ai/chat" {
		return true
	}
	return strings.HasPrefix(path, "/api/v1/ai/conversations/") && strings.HasSuffix(path, "/messages")
}

// RequestTimeout gives context-aware REST handlers a finite deadline so a
// stalled database or upstream dependency can release the native client's
// request. The WebSocket endpoint is deliberately excluded because its
// request lifetime is the lifetime of the upgraded connection rather than one
// response. AI agent exchanges get the longer agentExchangeTimeout instead.
// Handlers must pass c.Request.Context() to their dependencies.
func RequestTimeout(timeout time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if timeout <= 0 {
			c.Next()
			return
		}
		if c.Request.URL.Path == "/api/v1/ws" ||
			(strings.HasPrefix(c.Request.URL.Path, "/api/v1/assessment-agent/sessions/") && strings.HasSuffix(c.Request.URL.Path, "/ws")) {
			c.Next()
			return
		}
		effective := timeout
		if isAgentExchangePath(c.Request.URL.Path) {
			effective = agentExchangeTimeout
		}

		ctx, cancel := context.WithTimeout(c.Request.Context(), effective)
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
