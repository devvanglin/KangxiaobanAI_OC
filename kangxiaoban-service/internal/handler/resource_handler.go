package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// ResourceHandler 房间/床位。
type ResourceHandler struct{ svc *service.ResourceService }

func NewResourceHandler(svc *service.ResourceService) *ResourceHandler {
	return &ResourceHandler{svc: svc}
}

func (h *ResourceHandler) ListRooms(c *gin.Context) {
	page, size := parsePage(c)
	floor := parseInt(c, "floor", 0)
	items, total, err := h.svc.ListRooms(c.Query("building"), floor, page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询房间失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *ResourceHandler) ListBeds(c *gin.Context) {
	page, size := parsePage(c)
	roomID := uint(parseUint(c, "room_id"))
	items, total, err := h.svc.ListBeds(roomID, c.Query("status"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询床位失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}