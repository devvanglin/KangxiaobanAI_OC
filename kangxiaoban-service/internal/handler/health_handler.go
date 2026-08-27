package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// HealthHandler 健康体征。
type HealthHandler struct{ svc *service.HealthService }

func NewHealthHandler(svc *service.HealthService) *HealthHandler {
	return &HealthHandler{svc: svc}
}

// ListByElder GET /api/v1/elders/:id/health-records
func (h *HealthHandler) ListByElder(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	page, size := parsePage(c)
	items, total, err := h.svc.ListByElder(uint(id), page, size)
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
	if err := h.svc.Create(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "录入体征失败")
		return
	}
	OK(c, req)
}