package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// SupplyHandler 药物库存 + 餐饮订餐。
type SupplyHandler struct{ svc *service.SupplyService }

func NewSupplyHandler(svc *service.SupplyService) *SupplyHandler { return &SupplyHandler{svc: svc} }

// ---- 药物库存 ----
func (h *SupplyHandler) ListStock(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListStock(c.Query("keyword"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询库存失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *SupplyHandler) CreateStock(c *gin.Context) {
	var req model.MedicineStock
	if err := c.ShouldBindJSON(&req); err != nil || req.MedicineName == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: medicine_name 必填")
		return
	}
	if err := h.svc.CreateStock(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建库存失败")
		return
	}
	OK(c, req)
}

type adjustReq struct {
	Delta int `json:"delta" binding:"required"`
}

// AdjustStock PATCH /api/v1/stocks/:id 〔delta>0 入库, <0 出库〕
func (h *SupplyHandler) AdjustStock(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req adjustReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if err := h.svc.AdjustStock(uint(id), req.Delta); err != nil {
		Fail(c, http.StatusNotFound, 404, "库存条目不存在")
		return
	}
	OK(c, gin.H{"id": id, "delta": req.Delta})
}

// ---- 餐饮 ----
func (h *SupplyHandler) ListDining(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListDining(uint(parseUint(c, "elder_id")), c.Query("meal_time"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询订餐失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *SupplyHandler) CreateDining(c *gin.Context) {
	var req model.DiningOrder
	if err := c.ShouldBindJSON(&req); err != nil || req.ElderID == 0 && req.Items == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: elder_id 与 items 必填")
		return
	}
	req.TotalAmount = float64(req.Qty) * req.UnitPrice
	if err := h.svc.CreateDining(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建订餐失败")
		return
	}
	OK(c, req)
}