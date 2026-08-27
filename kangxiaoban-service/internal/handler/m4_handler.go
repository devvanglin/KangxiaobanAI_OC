package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// M4Handler 排班/交接班/费用/用药/审计。
type M4Handler struct {
	schedule  *service.ScheduleService
	finance   *service.FinanceService
	medication *service.MedicationService
	audit     *service.AuditService
}

func NewM4Handler(schedule *service.ScheduleService, finance *service.FinanceService,
	medication *service.MedicationService, audit *service.AuditService,
) *M4Handler {
	return &M4Handler{schedule: schedule, finance: finance, medication: medication, audit: audit}
}

// ---- 排班 ----
func (h *M4Handler) ListSchedules(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.schedule.ListSchedules(c.Query("date"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询排班失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *M4Handler) CreateSchedule(c *gin.Context) {
	var req model.Schedule
	if err := c.ShouldBindJSON(&req); err != nil || req.Staff == "" || req.WorkDate == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: staff 与 work_date 必填")
		return
	}
	if err := h.schedule.CreateSchedule(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建排班失败")
		return
	}
	OK(c, req)
}

// ---- 交接班 ----
func (h *M4Handler) ListHandovers(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.schedule.ListHandovers(c.Query("date"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询交接班失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *M4Handler) CreateHandover(c *gin.Context) {
	var req model.ShiftHandover
	if err := c.ShouldBindJSON(&req); err != nil || req.FromStaff == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: from_staff 必填")
		return
	}
	if err := h.schedule.CreateHandover(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建交接班失败")
		return
	}
	OK(c, req)
}

// ---- 费用 ----
func (h *M4Handler) ListBills(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.finance.ListBills(uint(parseUint(c, "elder_id")), c.Query("month"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询账单失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// GenerateBills POST /api/v1/bills/generate —— 为当前月份在院长者生成账单。
func (h *M4Handler) GenerateBills(c *gin.Context) {
	month := c.Query("month")
	created, err := h.finance.GenerateMonth(month)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "生成账单失败")
		return
	}
	OK(c, gin.H{"created": created})
}

type payReq struct {
	ElderID uint    `json:"elder_id" binding:"required"`
	Month   string  `json:"month" binding:"required"`
	Amount  float64 `json:"amount" binding:"required"`
	Reason  string  `json:"reason"`
}

// Pay POST /api/v1/bills/pay —— 缴费入账并更新账单状态。
func (h *M4Handler) Pay(c *gin.Context) {
	var req payReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if err := h.finance.Pay(req.ElderID, req.Month, req.Amount, req.Reason); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "缴费失败")
		return
	}
	OK(c, gin.H{"paid": req.Amount})
}

// Balance GET /api/v1/elders/:id/balance —— 预缴余额。
func (h *M4Handler) Balance(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	bal, err := h.finance.Balance(uint(id))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询余额失败")
		return
	}
	OK(c, gin.H{"elder_id": id, "balance": bal})
}

// ListFlows GET /api/v1/elders/:id/flows —— 资金流水。
func (h *M4Handler) ListFlows(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	page, size := parsePage(c)
	items, total, err := h.finance.ListFlows(uint(id), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询流水失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// ---- 用药 ----
func (h *M4Handler) ListMedications(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.medication.List(uint(parseUint(c, "elder_id")), c.Query("status"), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询用药失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *M4Handler) CreateMedication(c *gin.Context) {
	var req model.MedicationRecord
	if err := c.ShouldBindJSON(&req); err != nil || req.ElderID == 0 || req.MedicineName == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: elder_id 与 medicine_name 必填")
		return
	}
	if err := h.medication.Create(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建用药记录失败")
		return
	}
	OK(c, req)
}

type medStatusReq struct {
	Status string `json:"status" binding:"required"`
}

// MarkMedicationStatus PATCH /api/v1/medications/:id/status
func (h *M4Handler) MarkMedicationStatus(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req medStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	switch req.Status {
	case "taken", "refused", "missed":
	default:
		Fail(c, http.StatusBadRequest, 400, "status 仅支持 taken/refused/missed")
		return
	}
	if err := h.medication.MarkStatus(uint(id), req.Status); err != nil {
		Fail(c, http.StatusNotFound, 404, "记录不存在")
		return
	}
	OK(c, gin.H{"id": id, "status": req.Status})
}

// ---- 审计 ----
func (h *M4Handler) ListAudits(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.audit.List(page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询审计失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}