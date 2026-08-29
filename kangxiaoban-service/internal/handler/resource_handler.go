package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// ResourceHandler 房间/床位。
type ResourceHandler struct {
	svc    *service.ResourceService
	family *service.FamilyService
}

func NewResourceHandler(svc *service.ResourceService, family *service.FamilyService) *ResourceHandler {
	return &ResourceHandler{svc: svc, family: family}
}

func (h *ResourceHandler) ListRooms(c *gin.Context) {
	page, size := parsePage(c)
	floor := parseInt(c, "floor", 0)
	items, total, err := h.svc.ListRooms(c.Request.Context(), c.Query("building"), floor, page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询房间失败")
		return
	}
	if isFamilyUser(c) {
		allowed := boundElderIDs(c, h.family)
		filtered := items[:0]
		for _, room := range items {
			room.Beds = filterBeds(room.Beds, allowed)
			if len(room.Beds) > 0 {
				filtered = append(filtered, room)
			}
		}
		items = filtered
		total = int64(len(items))
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *ResourceHandler) ListBeds(c *gin.Context) {
	page, size := parsePage(c)
	roomID := uint(parseUint(c, "room_id"))
	items, total, err := h.svc.ListBeds(c.Request.Context(), roomID, c.Query("status"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询床位失败")
		return
	}
	if isFamilyUser(c) {
		allowed := boundElderIDs(c, h.family)
		items = filterBeds(items, allowed)
		total = int64(len(items))
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func filterBeds(items []model.Bed, allowed []uint) []model.Bed {
	out := make([]model.Bed, 0, len(items))
	for _, item := range items {
		if item.ElderID != nil && contains(*item.ElderID, allowed) {
			out = append(out, item)
		}
	}
	return out
}
