package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// AdmissionHandler exposes the persisted A/B/C admission assessment workflow.
type AdmissionHandler struct{ svc *service.AdmissionService }

func NewAdmissionHandler(svc *service.AdmissionService) *AdmissionHandler {
	return &AdmissionHandler{svc: svc}
}

func (h *AdmissionHandler) CurrentTemplate(c *gin.Context) {
	bundle, err := h.svc.TemplateBundle(c.Request.Context())
	if err != nil {
		h.fail(c, err, "查询入住评估模板失败")
		return
	}
	OK(c, bundle)
}

func (h *AdmissionHandler) ScreeningTemplates(c *gin.Context) {
	templates, err := h.svc.ScreeningTemplates(c.Request.Context())
	if err != nil {
		h.fail(c, err, "查询入住筛查模板失败")
		return
	}
	OK(c, templates)
}

func (h *AdmissionHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.List(c.Request.Context(), admissionActor(c), c.Query("status"), c.Query("mine") == "true", page, size)
	if err != nil {
		h.fail(c, err, "查询入住评估失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *AdmissionHandler) Create(c *gin.Context) {
	var req service.AdmissionDraftInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	created, err := h.svc.Create(c.Request.Context(), admissionActor(c), req)
	if err != nil {
		h.fail(c, err, "创建入住评估草稿失败")
		return
	}
	OK(c, created)
}

func (h *AdmissionHandler) Get(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	item, err := h.svc.Get(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.fail(c, err, "查询入住评估失败")
		return
	}
	OK(c, item)
}

func (h *AdmissionHandler) Update(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req service.AdmissionDraftInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	updated, err := h.svc.Update(c.Request.Context(), admissionActor(c), id, req)
	if err != nil {
		h.fail(c, err, "保存入住评估草稿失败")
		return
	}
	OK(c, updated)
}

func (h *AdmissionHandler) Preview(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req struct {
		Answers []service.AdmissionAnswerInput `json:"answers"`
	}
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&req); err != nil {
			Fail(c, http.StatusBadRequest, 400, "请求格式错误")
			return
		}
	}
	preview, err := h.svc.Preview(c.Request.Context(), admissionActor(c), id, req.Answers)
	if err != nil {
		h.fail(c, err, "预览评估结果失败")
		return
	}
	OK(c, preview)
}

func (h *AdmissionHandler) Submit(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	result, err := h.svc.Submit(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.fail(c, err, "提交入住评估失败")
		return
	}
	OK(c, result)
}

func (h *AdmissionHandler) ListScreenings(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	items, err := h.svc.ListScreenings(c.Request.Context(), id)
	if err != nil {
		h.fail(c, err, "查询入住筛查记录失败")
		return
	}
	OK(c, items)
}

func (h *AdmissionHandler) SaveScreening(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req service.AdmissionScreeningInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	result, err := h.svc.SaveScreening(c.Request.Context(), admissionActor(c), id, c.Param("template_code"), req)
	if err != nil {
		h.fail(c, err, "保存入住筛查失败")
		return
	}
	OK(c, result)
}

func admissionActor(c *gin.Context) service.AdmissionActor {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		return service.AdmissionActor{}
	}
	return service.AdmissionActor{UserID: claims.UserID, IsAdmin: hasRole(claims.Roles, "admin")}
}

func admissionID(c *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		Fail(c, http.StatusBadRequest, 400, "入住评估 ID 无效")
		return 0, false
	}
	return uint(id), true
}

func (h *AdmissionHandler) fail(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrAdmissionNotFound):
		Fail(c, http.StatusNotFound, 404, "入住评估不存在")
	case errors.Is(err, service.ErrAdmissionForbidden):
		Fail(c, http.StatusForbidden, 403, "无权限操作该入住评估")
	case errors.Is(err, service.ErrAdmissionInvalidState):
		Fail(c, http.StatusConflict, 409, "入住评估当前状态不允许该操作")
	case errors.Is(err, service.ErrAdmissionBedConflict):
		Fail(c, http.StatusConflict, 409, "目标床位不存在或已被占用")
	case errors.Is(err, service.ErrAdmissionElderConflict):
		Fail(c, http.StatusConflict, 409, "长者已入住或身份信息与现有档案冲突")
	case errors.Is(err, service.ErrAdmissionIncomplete), errors.Is(err, service.ErrAdmissionValidation):
		Fail(c, http.StatusBadRequest, 400, err.Error())
	default:
		Fail(c, http.StatusInternalServerError, 500, fallback)
	}
}
