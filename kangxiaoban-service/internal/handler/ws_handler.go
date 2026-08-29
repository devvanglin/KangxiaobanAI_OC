package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"kangxiaoban-service/internal/auth"
	"kangxiaoban-service/internal/ws"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// M2 开发/Native 客户端：允许跨域；生产应按 Origin 白名单收紧。
	CheckOrigin: func(r *http.Request) bool { return true },
}

// WSHandler WebSocket 实时推送入口。
type WSHandler struct {
	hub    *ws.Hub
	secret string
}

func NewWSHandler(hub *ws.Hub, secret string) *WSHandler {
	return &WSHandler{hub: hub, secret: secret}
}

// Serve WS：认证 token 后建立长连接。
// 连接方式：ws://host/api/v1/ws?token=<jwt>  （本机开发 http://）
func (h *WSHandler) Serve(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		token = strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
	}
	claims, err := auth.ParseToken(token, h.secret)
	if err != nil {
		Fail(c, http.StatusUnauthorized, 401, "令牌无效")
		return
	}
	if claims.TenantID == 0 {
		claims.TenantID = 1
	}
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	client := &ws.Client{
		Hub:      h.hub,
		Conn:     conn,
		Send:     make(chan []byte, 32),
		UserID:   claims.UserID,
		TenantID: claims.TenantID,
		Roles:    claims.Roles,
	}
	h.hub.Register(client)
	client.Start()
}
