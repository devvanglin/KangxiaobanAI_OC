package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
)

// IotHandler 物联网设备与告警。
type IotHandler struct {
	svc *iot.IotService
}

type deviceCreateReq struct {
	DeviceID   string `json:"device_id" binding:"required"`
	Product    string `json:"product" binding:"required"`
	DeviceType string `json:"device_type"`
	Building   string `json:"building"`
	Room       string `json:"room"`
	Bed        string `json:"bed"`
	AreaID     *uint  `json:"area_id"`
	StreamURL  string `json:"stream_url"`
}

func (h *IotHandler) CreateDevice(c *gin.Context) {
	var req deviceCreateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, 400, "设备编号和设备类型必填")
		return
	}
	protocol := "MQTT"
	deviceType := strings.TrimSpace(req.DeviceType)
	if deviceType == "camera" {
		protocol = "RTSP"
	}
	if deviceType == "" {
		if req.StreamURL != "" {
			deviceType = "camera"
		} else {
			deviceType = "millimeter_wave"
		}
	}
	streamURL := strings.TrimSpace(req.StreamURL)
	if deviceType == "camera" && streamURL == "" {
		Fail(c, 400, 400, "摄像头必须提供 RTSP 地址")
		return
	}
	device := &model.IotDevice{DeviceID: strings.TrimSpace(req.DeviceID), Product: req.Product, DeviceType: deviceType, Building: req.Building, Room: req.Room, Bed: req.Bed, AreaID: req.AreaID, Protocol: protocol, StreamURL: streamURL, StreamStatus: "unknown", Online: 0, DiscoveryStatus: "claimed"}
	if err := h.svc.CreateDevice(c.Request.Context(), device); err != nil {
		Fail(c, 409, 409, "设备编号已存在或创建失败")
		return
	}
	OK(c, device)
}

func (h *IotHandler) DeleteDevice(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.svc.DeleteDevice(c.Request.Context(), uint(id)); err != nil {
		Fail(c, 500, 500, "删除设备失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

func NewIotHandler(svc *iot.IotService) *IotHandler {
	return &IotHandler{svc: svc}
}

// ListDevices GET /api/v1/iot/devices
func (h *IotHandler) ListDevices(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListDevices(c.Request.Context(), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询设备失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *IotHandler) UpdateDevice(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req struct {
		DeviceType      string `json:"device_type"`
		AreaID          *uint  `json:"area_id"`
		Building        string `json:"building"`
		Room            string `json:"room"`
		Bed             string `json:"bed"`
		ElderID         *uint  `json:"elder_id"`
		StreamURL       string `json:"stream_url"`
		DiscoveryStatus string `json:"discovery_status"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, 400, "参数错误")
		return
	}
	updates := map[string]interface{}{"area_id": req.AreaID, "building": strings.TrimSpace(req.Building), "room": strings.TrimSpace(req.Room), "bed": strings.TrimSpace(req.Bed), "elder_id": req.ElderID}
	if deviceType := strings.TrimSpace(req.DeviceType); deviceType != "" {
		if deviceType != "camera" && deviceType != "millimeter_wave" && deviceType != "other" {
			Fail(c, 400, 400, "不支持的设备类型")
			return
		}
		updates["device_type"] = deviceType
		if deviceType == "camera" {
			updates["protocol"] = "RTSP"
		} else {
			updates["protocol"] = "MQTT"
			updates["stream_url"] = ""
			updates["stream_status"] = "unknown"
		}
	}
	if streamURL := strings.TrimSpace(req.StreamURL); streamURL != "" {
		updates["stream_url"] = streamURL
		updates["protocol"] = "RTSP"
		updates["device_type"] = "camera"
		updates["stream_status"] = "unknown"
	}
	if value := strings.TrimSpace(req.DiscoveryStatus); value != "" {
		updates["discovery_status"] = value
	}
	if err := h.svc.UpdateDevice(c.Request.Context(), uint(id), updates); err != nil {
		Fail(c, 404, 404, "设备不存在或更新失败")
		return
	}
	OK(c, gin.H{"id": id, "updated": true})
}

func (h *IotHandler) ListSignals(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	device, err := h.svc.GetDevice(c.Request.Context(), uint(id))
	if err != nil {
		Fail(c, 404, 404, "设备不存在")
		return
	}
	items, err := h.svc.ListSignals(c.Request.Context(), device.DeviceID, parseInt(c, "limit", 100))
	if err != nil {
		Fail(c, 500, 500, "查询设备信号失败")
		return
	}
	OK(c, gin.H{"list": items})
}

func (h *IotHandler) Probe(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	device, err := h.svc.GetDevice(c.Request.Context(), uint(id))
	if err != nil {
		Fail(c, 404, 404, "设备不存在")
		return
	}
	if device.StreamURL == "" {
		Fail(c, 400, 400, "设备没有 RTSP 地址")
		return
	}
	if err := h.svc.ProbeStream(c.Request.Context(), device.StreamURL); err != nil {
		_ = h.svc.UpdateDevice(c.Request.Context(), uint(id), map[string]interface{}{"stream_status": "offline"})
		Fail(c, 503, 503, "RTSP 流不可达")
		return
	}
	_ = h.svc.UpdateDevice(c.Request.Context(), uint(id), map[string]interface{}{"stream_status": "online"})
	OK(c, gin.H{"id": id, "stream_status": "online"})
}

// ListAlerts GET /api/v1/alerts?status=&level=
func (h *IotHandler) ListAlerts(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListAlerts(c.Request.Context(), c.Query("status"), c.Query("level"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询告警失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// HandleAlert PATCH /api/v1/alerts/:id/handle?close=1|0
func (h *IotHandler) HandleAlert(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	closeIt := c.Query("close") == "1"
	by := "unknown"
	if claims, ok := middleware.ClaimsFrom(c); ok {
		by = claims.Username
	}
	if err := h.svc.HandleAlert(c.Request.Context(), uint(id), by, closeIt); err != nil {
		Fail(c, http.StatusNotFound, 404, "告警不存在")
		return
	}
	OK(c, gin.H{"id": id, "closed": closeIt})
}

// ListAlertActions GET /api/v1/alerts/:id/actions
func (h *IotHandler) ListAlertActions(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
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
