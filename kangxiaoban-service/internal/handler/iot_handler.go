package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/iot"
)

// IotHandler 物联网设备与告警。
type IotHandler struct {
	svc *iot.IotService
}

func NewIotHandler(svc *iot.IotService) *IotHandler {
	return &IotHandler{svc: svc}
}

// ListDevices GET /api/v1/iot/devices
func (h *IotHandler) ListDevices(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListDevices(page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询设备失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// ListAlerts GET /api/v1/alerts?status=&level=
func (h *IotHandler) ListAlerts(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListAlerts(c.Query("status"), c.Query("level"), page, size)
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
	by := "admin" // M3：处置人后续接当前用户
	if err := h.svc.HandleAlert(uint(id), by, closeIt); err != nil {
		Fail(c, http.StatusNotFound, 404, "告警不存在")
		return
	}
	OK(c, gin.H{"id": id, "closed": closeIt})
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
	if err := h.svc.Ingest(req.DeviceID, req.Product, req.Payload); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "数据处理失败")
		return
	}
	OK(c, gin.H{"ingested": true, "device_id": req.DeviceID})
}