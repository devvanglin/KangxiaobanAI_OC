package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// ElderHandler 长者档案。
type ElderHandler struct {
	svc *service.ElderService
}

func NewElderHandler(svc *service.ElderService) *ElderHandler {
	return &ElderHandler{svc: svc}
}

func (h *ElderHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	status := parseInt(c, "status", 0)
	careLevel := parseInt(c, "care_level", 0)
	items, total, err := h.svc.List(c.Request.Context(), c.Query("keyword"), status, careLevel, page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询长者失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *ElderHandler) Get(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	e, err := h.svc.Get(c.Request.Context(), uint(id))
	if err != nil {
		Fail(c, http.StatusNotFound, 404, "长者不存在")
		return
	}
	OK(c, e)
}

func (h *ElderHandler) Create(c *gin.Context) {
	var req model.Elder
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if req.Name == "" {
		Fail(c, http.StatusBadRequest, 400, "姓名不能为空")
		return
	}
	if err := h.svc.Create(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建长者失败")
		return
	}
	OK(c, req)
}

func (h *ElderHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req model.Elder
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	req.ID = uint(id)
	if err := h.svc.Update(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "更新长者失败")
		return
	}
	OK(c, req)
}

func (h *ElderHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.svc.Delete(c.Request.Context(), uint(id)); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "删除长者失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}

func hasRole(codes []string, want string) bool {
	for _, c := range codes {
		if c == want {
			return true
		}
	}
	return false
}
