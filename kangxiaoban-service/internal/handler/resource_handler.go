package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/model"

	"kangxiaoban-service/internal/service"
)

// ResourceHandler 房间/床位。
type ResourceHandler struct {
	svc *service.ResourceService
}

func NewResourceHandler(svc *service.ResourceService) *ResourceHandler {
	return &ResourceHandler{svc: svc}
}

type bedCreateReq struct {
	RoomID uint   `json:"room_id" binding:"required"`
	BedNo  string `json:"bed_no" binding:"required"`
	Status string `json:"status"`
}

// CreateBed creates one of the maximum two bed slots in a room. Existing
// admission and resident APIs continue to use the room_id compatibility field.
func (h *ResourceHandler) CreateBed(c *gin.Context) {
	var req bedCreateReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.BedNo) == "" {
		Fail(c, 400, 400, "room_id 与 bed_no 必填")
		return
	}
	// The resource service owns the repository; the handler only validates the
	// request and delegates persistence through the service boundary.
	// Room existence and the two-bed limit are checked by the repository query
	// before creating the row.
	db := h.svc
	var room model.Room
	rooms, _, err := db.ListRooms(c.Request.Context(), "", 0, 1, 200)
	if err != nil {
		Fail(c, 500, 500, "查询房间失败")
		return
	}
	for _, item := range rooms {
		if item.ID == req.RoomID {
			room = item
			break
		}
	}
	if room.ID == 0 {
		Fail(c, 404, 404, "房间不存在")
		return
	}
	status := strings.TrimSpace(req.Status)
	if status == "" {
		status = "free"
	}
	bed := &model.Bed{RoomID: req.RoomID, BedNo: strings.TrimSpace(req.BedNo), Status: status}
	for _, item := range room.Beds {
		if item.ID != 0 {
			if item.BedNo == bed.BedNo {
				Fail(c, 409, 409, "床位编号已存在")
				return
			}
		}
	}
	if len(room.Beds) >= 2 {
		Fail(c, 409, 409, "一个房间最多配置两张床位")
		return
	}
	if err := db.CreateBed(c.Request.Context(), bed); err != nil {
		Fail(c, 409, 409, "床位编号已存在或创建失败")
		return
	}
	OK(c, bed)
}

func (h *ResourceHandler) ListRooms(c *gin.Context) {
	page, size := parsePage(c)
	floor := parseInt(c, "floor", 0)
	items, total, err := h.svc.ListRooms(c.Request.Context(), c.Query("building"), floor, page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询房间失败")
		return
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
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}
