package ws

import (
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait  = 10 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10
	maxMessage = 512
)

// readPump 处理连接关闭与 Pong，忽略客户端业务消息（M2 无上行协议）。
func (c *Client) readPump() {
	defer func() {
		c.Hub.Unregister(c)
		_ = c.Conn.Close()
	}()
	c.Conn.SetReadLimit(maxMessage)
	_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		return c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	})
	for {
		if _, _, err := c.Conn.ReadMessage(); err != nil {
			return
		}
	}
}

// writePump 向下行通道投递消息与心跳 Ping。
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.Conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.Send:
			c.writeMu.Lock()
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				c.writeMu.Unlock()
				return
			}
			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				c.writeMu.Unlock()
				return
			}
			_, _ = w.Write(msg)
			if err := w.Close(); err != nil {
				c.writeMu.Unlock()
				return
			}
			c.writeMu.Unlock()
		case <-ticker.C:
			c.writeMu.Lock()
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			_ = c.Conn.WriteMessage(websocket.PingMessage, nil)
			c.writeMu.Unlock()
		}
	}
}

// Start 启动两端泵。
func (c *Client) Start() {
	go c.writePump()
	go c.readPump()
}
