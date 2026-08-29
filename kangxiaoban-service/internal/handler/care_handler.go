package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// CareHandler 护理评估、计划、执行与复核。
type CareHandler struct {
	svc    *service.CareService
	family *service.FamilyService
}

func NewCareHandler(svc *service.CareService, family *service.FamilyService) *CareHandler {
	return &CareHandler{svc: svc, family: family}
}

func (h *CareHandler) allowed(c *gin.Context) []uint { return boundElderIDs(c, h.family) }

func (h *CareHandler) ListAssessments(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListAssessments(uint(parseUint(c, "elder_id")), page, size, h.allowed(c))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询评估失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *CareHandler) CreateAssessment(c *gin.Context) {
	var req model.Assessment
	if err := c.ShouldBindJSON(&req); err != nil || req.ElderID == 0 || req.AssessmentType == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: elder_id 与 assessment_type 必填")
		return
	}
	if allowed := h.allowed(c); allowed != nil && !contains(req.ElderID, allowed) {
		Fail(c, 403, 403, "无权限操作该长者")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	if cl != nil {
		req.AssessorID = cl.UserID
	}
	if err := h.svc.CreateAssessment(&req); err != nil {
		Fail(c, 500, 500, "创建评估失败")
		return
	}
	OK(c, req)
}

func (h *CareHandler) ListPlans(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListPlans(uint(parseUint(c, "elder_id")), page, size, h.allowed(c))
	if err != nil {
		Fail(c, 500, 500, "查询护理计划失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *CareHandler) CreatePlan(c *gin.Context) {
	var req model.CarePlan
	if err := c.ShouldBindJSON(&req); err != nil || req.ElderID == 0 || req.Name == "" {
		Fail(c, 400, 400, "参数错误: elder_id 与 name 必填")
		return
	}
	if allowed := h.allowed(c); allowed != nil && !contains(req.ElderID, allowed) {
		Fail(c, 403, 403, "无权限操作该长者")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	if cl != nil {
		req.CreatedBy = cl.UserID
	}
	if err := h.svc.CreatePlan(&req); err != nil {
		Fail(c, 500, 500, "创建护理计划失败")
		return
	}
	OK(c, req)
}

func (h *CareHandler) AddPlanItem(c *gin.Context) {
	planID, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req model.CarePlanItem
	if err := c.ShouldBindJSON(&req); err != nil || req.Title == "" {
		Fail(c, 400, 400, "参数错误: title 必填")
		return
	}
	if p, err := h.svc.GetPlan(uint(planID)); err == nil {
		if !requireElderAccess(c, h.family, p.ElderID) {
			return
		}
	} else {
		Fail(c, 404, 404, "护理计划不存在")
		return
	}
	if err := h.svc.AddPlanItem(uint(planID), &req); err != nil {
		Fail(c, 404, 404, "护理计划不存在或不可修改")
		return
	}
	OK(c, req)
}

func (h *CareHandler) ListExecutions(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListExecutions(uint(parseUint(c, "elder_id")), uint(parseUint(c, "plan_item_id")), page, size, h.allowed(c))
	if err != nil {
		Fail(c, 500, 500, "查询执行记录失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *CareHandler) CreateExecution(c *gin.Context) {
	var req model.CareExecution
	if err := c.ShouldBindJSON(&req); err != nil || req.PlanItemID == 0 || req.ElderID == 0 {
		Fail(c, 400, 400, "参数错误: plan_item_id 与 elder_id 必填")
		return
	}
	if allowed := h.allowed(c); allowed != nil && !contains(req.ElderID, allowed) {
		Fail(c, 403, 403, "无权限操作该长者")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	if cl != nil {
		req.ExecutorID = cl.UserID
		req.Executor = cl.Username
	}
	if err := h.svc.CreateExecution(&req); err != nil {
		Fail(c, 500, 500, "创建执行记录失败")
		return
	}
	OK(c, req)
}

type reviewExecutionReq struct {
	Status string `json:"status" binding:"required"`
	Note   string `json:"note"`
}

func (h *CareHandler) ReviewExecution(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req reviewExecutionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, 400, "参数错误")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	var uid uint
	if cl != nil {
		uid = cl.UserID
	}
	if v, err := h.svc.GetExecution(uint(id)); err == nil {
		if !requireElderAccess(c, h.family, v.ElderID) {
			return
		}
	} else {
		Fail(c, 404, 404, "执行记录不存在")
		return
	}
	if err := h.svc.ReviewExecution(uint(id), uid, req.Status, req.Note); err != nil {
		Fail(c, 404, 404, "执行记录不存在或状态无效")
		return
	}
	OK(c, gin.H{"id": id, "status": req.Status})
}
