package ws

import (
	"encoding/json"
	"sync"

	"github.com/gorilla/websocket"
)

// Hub 管理所有连接客户端并负责广播事件。
type Hub struct {
	clients    map[*Client]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
	mu         sync.RWMutex
}

// NewHub 创建 Hub。
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte, 256),
	}
}

// Run 协程循环：处理注册/注销/广播。
func (h *Hub) Run() {
	for {
		select {
		case c := <-h.register:
			h.mu.Lock()
			h.clients[c] = true
			h.mu.Unlock()
		case c := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[c]; ok {
				delete(h.clients, c)
				close(c.Send)
			}
			h.mu.Unlock()
		case msg := <-h.broadcast:
			h.mu.RLock()
			for c := range h.clients {
				select {
				case c.Send <- msg:
				default:
					// 发送缓冲区满则丢弃该慢客户端
				}
			}
			h.mu.RUnlock()
		}
	}
}

// Register 注册连接。
func (h *Hub) Register(c *Client) { h.register <- c }

// Unregister 注销连接。
func (h *Hub) Unregister(c *Client) { h.unregister <- c }

// BroadcastEvent 序列化并广播 {type, data} 事件。
func (h *Hub) BroadcastEvent(eventType string, data interface{}) {
	payload, _ := json.Marshal(map[string]interface{}{"type": eventType, "data": data})
	select {
	case h.broadcast <- payload:
	default:
		select {
		case <-h.broadcast: // 队列满则丢弃最旧，保证实时性
		default:
		}
		h.broadcast <- payload
	}
}

// SendToUser 向指定用户的所有在线连接发送事件。
func (h *Hub) SendToUser(userID uint, eventType string, data interface{}) {
	payload, _ := json.Marshal(map[string]interface{}{"type": eventType, "data": data})
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		if c.UserID != userID {
			continue
		}
		select {
		case c.Send <- payload:
		default:
		}
	}
}

// SendToRole sends an event only to clients with the role in the same tenant.
func (h *Hub) SendToRole(tenantID uint, role, eventType string, data interface{}) {
	payload, _ := json.Marshal(map[string]interface{}{"type": eventType, "data": data})
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		if c.TenantID != tenantID || !clientHasRole(c.Roles, role) {
			continue
		}
		select {
		case c.Send <- payload:
		default:
		}
	}
}

// SendToTenant sends an event to authenticated clients in one tenant only.
func (h *Hub) SendToTenant(tenantID uint, eventType string, data interface{}) {
	payload, _ := json.Marshal(map[string]interface{}{"type": eventType, "data": data})
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		if c.TenantID != tenantID {
			continue
		}
		select {
		case c.Send <- payload:
		default:
		}
	}
}

func clientHasRole(roles []string, role string) bool {
	for _, candidate := range roles {
		if candidate == role {
			return true
		}
	}
	return false
}

// Client 单个 WebSocket 连接。
type Client struct {
	Hub      *Hub
	Conn     *websocket.Conn
	Send     chan []byte
	UserID   uint
	TenantID uint
	Roles    []string

	writeMu sync.Mutex
}
