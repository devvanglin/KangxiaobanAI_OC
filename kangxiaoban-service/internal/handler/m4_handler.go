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
	schedule   *service.ScheduleService
	finance    *service.FinanceService
	medication *service.MedicationService
	audit      *service.AuditService
	family     *service.FamilyService
}

func NewM4Handler(schedule *service.ScheduleService, finance *service.FinanceService,
	medication *service.MedicationService, audit *service.AuditService,
	family *service.FamilyService,
) *M4Handler {
	return &M4Handler{schedule: schedule, finance: finance, medication: medication, audit: audit, family: family}
}

// ---- 排班 ----
func (h *M4Handler) ListSchedules(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.schedule.ListSchedules(c.Request.Context(), c.Query("date"), page, size)
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
	req.Base = model.Base{}
	if err := h.schedule.CreateSchedule(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建排班失败")
		return
	}
	OK(c, req)
}

// ---- 交接班 ----
func (h *M4Handler) ListHandovers(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.schedule.ListHandovers(c.Request.Context(), c.Query("date"), page, size)
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
	req.Base = model.Base{}
	if err := h.schedule.CreateHandover(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建交接班失败")
		return
	}
	OK(c, req)
}

// ---- 费用 ----
func (h *M4Handler) ListBills(c *gin.Context) {
	page, size := parsePage(c)
	bound := boundElderIDs(c, h.family)
	items, total, err := h.finance.ListBillsScoped(c.Request.Context(), uint(parseUint(c, "elder_id")), c.Query("month"), page, size, bound)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询账单失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// GenerateBills POST /api/v1/bills/generate —— 为当前月份在院长者生成账单。
func (h *M4Handler) GenerateBills(c *gin.Context) {
	month := c.Query("month")
	created, err := h.finance.GenerateMonth(c.Request.Context(), month)
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
	if err := h.finance.Pay(c.Request.Context(), req.ElderID, req.Month, req.Amount, req.Reason); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "缴费失败")
		return
	}
	OK(c, gin.H{"paid": req.Amount})
}

// Balance GET /api/v1/elders/:id/balance —— 预缴余额。
func (h *M4Handler) Balance(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if bound := boundElderIDs(c, h.family); bound != nil && !contains(uint(id), bound) {
		Fail(c, http.StatusForbidden, 403, "无权限查看该长者余额")
		return
	}
	bal, err := h.finance.Balance(c.Request.Context(), uint(id))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询余额失败")
		return
	}
	OK(c, gin.H{"elder_id": id, "balance": bal})
}

// ListFlows GET /api/v1/elders/:id/flows —— 资金流水。
func (h *M4Handler) ListFlows(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if bound := boundElderIDs(c, h.family); bound != nil && !contains(uint(id), bound) {
		Fail(c, http.StatusForbidden, 403, "无权限查看该长者流水")
		return
	}
	page, size := parsePage(c)
	items, total, err := h.finance.ListFlows(c.Request.Context(), uint(id), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询流水失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// ---- 用药 ----
func (h *M4Handler) ListMedications(c *gin.Context) {
	page, size := parsePage(c)
	requested := uint(parseUint(c, "elder_id"))
	if bound := boundElderIDs(c, h.family); bound != nil {
		// 家属不允许通过任意 elder_id 探测其他长者；未指定时只返回绑定集合中的记录。
		if requested > 0 && !contains(requested, bound) {
			Fail(c, http.StatusForbidden, 403, "无权限查看该长者用药")
			return
		}
		if requested == 0 {
			// 当前 Repository 只支持单 elder_id 过滤；家属端逐个查询绑定长者，避免返回越权数据。
			if len(bound) == 0 {
				OK(c, gin.H{"list": []model.MedicationRecord{}, "page": page, "size": size, "total": 0})
				return
			}
			requested = bound[0]
		}
	}
	items, total, err := h.medication.List(c.Request.Context(), requested, c.Query("status"), page, size)
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
	if !requireElderAccess(c, h.family, req.ElderID) {
		return
	}
	req.Base = model.Base{}
	if err := h.medication.Create(c.Request.Context(), &req); err != nil {
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
	if m, err := h.medication.Get(c.Request.Context(), uint(id)); err == nil {
		if !requireElderAccess(c, h.family, m.ElderID) {
			return
		}
	}
	if err := h.medication.MarkStatus(c.Request.Context(), uint(id), req.Status); err != nil {
		Fail(c, http.StatusNotFound, 404, "记录不存在")
		return
	}
	OK(c, gin.H{"id": id, "status": req.Status})
}

// ---- 审计 ----
func (h *M4Handler) ListAudits(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.audit.List(c.Request.Context(), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询审计失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}
