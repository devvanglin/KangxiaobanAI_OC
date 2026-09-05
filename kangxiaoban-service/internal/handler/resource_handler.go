package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
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
	RoomID uint   `json:"room_id"`
	AreaID uint   `json:"area_id"`
	BedNo  string `json:"bed_no" binding:"required"`
	Status string `json:"status"`
}

// CreateBed creates one of the maximum two bed slots in a room. The room is
// addressed either by the legacy room_id or by a floor-plan area_id, whose
// historical room record is provisioned on demand. Admission and resident
// APIs keep using the room_id compatibility field.
func (h *ResourceHandler) CreateBed(c *gin.Context) {
	var req bedCreateReq
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.BedNo) == "" {
		Fail(c, 400, 400, "bed_no 必填，room_id 或 area_id 必填")
		return
	}
	var areaID *uint
	if req.AreaID > 0 {
		area := req.AreaID
		areaID = &area
	}
	roomID := req.RoomID
	if roomID == 0 {
		if areaID == nil {
			Fail(c, 400, 400, "room_id 或 area_id 必填")
			return
		}
		room, err := h.svc.EnsureRoomForArea(c.Request.Context(), *areaID)
		if err != nil {
			Fail(c, 404, 404, "区域不存在或不是房间")
			return
		}
		roomID = room.ID
	}
	status := strings.TrimSpace(req.Status)
	if status == "" {
		status = "free"
	}
	bed := &model.Bed{RoomID: roomID, AreaID: areaID, BedNo: strings.TrimSpace(req.BedNo), Status: status}
	if err := h.svc.CreateBedInRoom(c.Request.Context(), bed); err != nil {
		switch {
		case errors.Is(err, gorm.ErrRecordNotFound):
			Fail(c, 404, 404, "房间不存在")
		case errors.Is(err, service.ErrBedNumberExists):
			Fail(c, 409, 409, "床位编号已存在")
		case errors.Is(err, service.ErrBedLimitReached):
			Fail(c, 409, 409, "一个房间最多配置两张床位")
		default:
			Fail(c, 500, 500, "床位创建失败")
		}
		return
	}
	OK(c, bed)
}

// DeleteBed removes a bed and releases any resident assignment on it, so the
// room bed-count setting can shrink freely.
func (h *ResourceHandler) DeleteBed(c *gin.Context) {
	id64, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		Fail(c, 400, 400, "床位 ID 无效")
		return
	}
	if err := h.svc.DeleteBed(c.Request.Context(), uint(id64)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, 404, 404, "床位不存在")
			return
		}
		Fail(c, 500, 500, "床位删除失败")
		return
	}
	OK(c, gin.H{"id": uint(id64)})
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
