package middleware

import (
	"context"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestRequestTimeoutReturnsGatewayTimeout(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestTimeout(5 * time.Millisecond))
	r.GET("/slow", func(c *gin.Context) {
		<-c.Request.Context().Done()
	})

	req := httptest.NewRequest("GET", "/slow", nil)
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)
	if resp.Code != 504 {
		t.Fatalf("status = %d, want 504", resp.Code)
	}
	if resp.Body.Len() == 0 {
		t.Fatal("timeout response body is empty")
	}
}

func TestRequestTimeoutLeavesWebSocketLifetimeUnbounded(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestTimeout(1 * time.Millisecond))
	done := make(chan struct{})
	r.GET("/api/v1/ws", func(c *gin.Context) {
		select {
		case <-time.After(10 * time.Millisecond):
			close(done)
		case <-c.Request.Context().Done():
		}
	})

	req := httptest.NewRequest("GET", "/api/v1/ws", nil)
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)
	select {
	case <-done:
	case <-time.After(100 * time.Millisecond):
		t.Fatal("WebSocket request context was unexpectedly bounded")
	}
	if req.Context().Err() == context.DeadlineExceeded {
		t.Fatal("original request context was changed")
	}
}
