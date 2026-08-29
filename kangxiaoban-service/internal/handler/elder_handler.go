package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

const roleFamily = "family"

// ElderHandler 长者档案。
type ElderHandler struct {
	svc    *service.ElderService
	family *service.FamilyService
}

func NewElderHandler(svc *service.ElderService, family *service.FamilyService) *ElderHandler {
	return &ElderHandler{svc: svc, family: family}
}

// allowedElders 家属角色 -> 其绑定集合；其他角色 -> 空(不限)。
func (h *ElderHandler) allowedElders(c *gin.Context) []uint {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok || !hasRole(cl.Roles, roleFamily) {
		return nil
	}
	ids, err := h.family.BoundElderIDs(c.Request.Context(), cl.UserID)
	if err != nil {
		return []uint{}
	}
	return ids
}

// canView 家属角色只能查看绑定长者；其他角色放行。
func (h *ElderHandler) canView(c *gin.Context, id uint) bool {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok || !hasRole(cl.Roles, roleFamily) {
		return true
	}
	ids, err := h.family.BoundElderIDs(c.Request.Context(), cl.UserID)
	if err != nil {
		return false
	}
	for _, eid := range ids {
		if eid == id {
			return true
		}
	}
	return false
}

func (h *ElderHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	status := parseInt(c, "status", 0)
	careLevel := parseInt(c, "care_level", 0)
	allowed := h.allowedElders(c)
	items, total, err := h.svc.ListScoped(c.Request.Context(), c.Query("keyword"), status, careLevel, page, size, allowed)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询长者失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *ElderHandler) Get(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if !h.canView(c, uint(id)) {
		Fail(c, http.StatusForbidden, 403, "无权限查看该长者")
		return
	}
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
	req.Base = model.Base{}
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
	req.Base.TenantID = 0
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
