package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// HealthHandler 健康体征。
type HealthHandler struct {
	svc    *service.HealthService
	hub    *ws.Hub
	family *service.FamilyService
}

func NewHealthHandler(svc *service.HealthService, hub *ws.Hub, family *service.FamilyService) *HealthHandler {
	return &HealthHandler{svc: svc, hub: hub, family: family}
}

// ListByElder GET /api/v1/elders/:id/health-records
func (h *HealthHandler) ListByElder(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if bound := boundElderIDs(c, h.family); bound != nil && !contains(uint(id), bound) {
		Fail(c, http.StatusForbidden, 403, "无权限查看该长者体征")
		return
	}
	page, size := parsePage(c)
	items, total, err := h.svc.ListByElder(c.Request.Context(), uint(id), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询体征失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// Create POST /api/v1/health-records
func (h *HealthHandler) Create(c *gin.Context) {
	var req model.HealthRecord
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if req.ElderID == 0 {
		Fail(c, http.StatusBadRequest, 400, "elder_id 必填")
		return
	}
	if !requireElderAccess(c, h.family, req.ElderID) {
		return
	}
	req.Base = model.Base{}
	if err := h.svc.Create(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "录入体征失败")
		return
	}
	// 实时广播体征（前端据此刷新曲线/告警）
	event := "vital.record"
	if req.IsAbnormal {
		event = "vital.abnormal"
	}
	tenantID := uint(1)
	if cl, ok := middleware.ClaimsFrom(c); ok && cl.TenantID > 0 {
		tenantID = cl.TenantID
	}
	h.hub.SendToTenant(tenantID, event, req)
	OK(c, req)
}
