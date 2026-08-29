package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// IotHandler 物联网设备与告警。
type IotHandler struct {
	svc    *iot.IotService
	family *service.FamilyService
}

func NewIotHandler(svc *iot.IotService, family *service.FamilyService) *IotHandler {
	return &IotHandler{svc: svc, family: family}
}

// ListDevices GET /api/v1/iot/devices
func (h *IotHandler) ListDevices(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListDevicesScoped(c.Request.Context(), page, size, boundElderIDs(c, h.family))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询设备失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// ListAlerts GET /api/v1/alerts?status=&level=
func (h *IotHandler) ListAlerts(c *gin.Context) {
	page, size := parsePage(c)
	bound := boundElderIDs(c, h.family)
	items, total, err := h.svc.ListAlertsScoped(c.Request.Context(), c.Query("status"), c.Query("level"), page, size, bound)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询告警失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// HandleAlert PATCH /api/v1/alerts/:id/handle?close=1|0
func (h *IotHandler) HandleAlert(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if a, err := h.svc.GetAlert(c.Request.Context(), uint(id)); err == nil && a.ElderID != nil && !requireElderAccess(c, h.family, *a.ElderID) {
		return
	}
	closeIt := c.Query("close") == "1"
	by := "admin" // M3：处置人后续接当前用户
	if err := h.svc.HandleAlert(c.Request.Context(), uint(id), by, closeIt); err != nil {
		Fail(c, http.StatusNotFound, 404, "告警不存在")
		return
	}
	OK(c, gin.H{"id": id, "closed": closeIt})
}

// ListAlertActions GET /api/v1/alerts/:id/actions
func (h *IotHandler) ListAlertActions(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if a, err := h.svc.GetAlert(c.Request.Context(), uint(id)); err == nil && a.ElderID != nil && !requireElderAccess(c, h.family, *a.ElderID) {
		return
	}
	page, size := parsePage(c)
	items, total, err := h.svc.ListAlertActions(c.Request.Context(), uint(id), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询告警处置记录失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

type alertActionReq struct {
	Action string `json:"action" binding:"required"`
	Note   string `json:"note"`
}

// CreateAlertAction POST /api/v1/alerts/:id/actions
func (h *IotHandler) CreateAlertAction(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if a, err := h.svc.GetAlert(c.Request.Context(), uint(id)); err == nil && a.ElderID != nil && !requireElderAccess(c, h.family, *a.ElderID) {
		return
	}
	var req alertActionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, 400, "参数错误")
		return
	}
	switch req.Action {
	case "acknowledge", "assign", "note", "escalate", "resolve", "close":
	default:
		Fail(c, 400, 400, "不支持的处置动作")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	var uid uint
	if cl != nil {
		uid = cl.UserID
	}
	if err := h.svc.RecordAlertAction(c.Request.Context(), uint(id), uid, req.Action, req.Note); err != nil {
		Fail(c, 500, 500, "记录告警处置失败")
		return
	}
	OK(c, gin.H{"alert_id": id, "action": req.Action})
}

type ingestReq struct {
	DeviceID string                 `json:"device_id" binding:"required"`
	Product  string                 `json:"product"`
	Payload  map[string]interface{} `json:"payload" binding:"required"`
}

// Ingest POST /api/v1/iot/ingest —— 测试/模拟产线数据，走同一归一化+规则引擎。
func (h *IotHandler) Ingest(c *gin.Context) {
	var req ingestReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误: 需 device_id 与 payload")
		return
	}
	if err := h.svc.IngestContext(c.Request.Context(), req.DeviceID, req.Product, req.Payload); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "数据处理失败")
		return
	}
	OK(c, gin.H{"ingested": true, "device_id": req.DeviceID})
}
