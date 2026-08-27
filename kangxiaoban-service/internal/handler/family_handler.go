package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// FamilyManageHandler 家属账号管理（管理员）。
type FamilyManageHandler struct {
	family *service.FamilyService
}

func NewFamilyManageHandler(family *service.FamilyService) *FamilyManageHandler {
	return &FamilyManageHandler{family: family}
}

type createMemberReq struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	RealName string `json:"real_name"`
	Phone    string `json:"phone"`
	ElderIDs []uint `json:"elder_ids"`
}

// CreateMember POST /api/v1/families —— 建家属账号并绑定长者。
func (h *FamilyManageHandler) CreateMember(c *gin.Context) {
	var req createMemberReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误: username/password 必填")
		return
	}
	u, err := h.family.CreateMember(req.Username, req.Password, req.RealName, req.Phone, req.ElderIDs)
	if err != nil {
		Fail(c, http.StatusConflict, 409, err.Error())
		return
	}
	OK(c, u)
}

// ListBindings GET /api/v1/families?elder_id=
func (h *FamilyManageHandler) ListBindings(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.family.ListBindings(uint(parseUint(c, "elder_id")), page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询绑定失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

// Unbind DELETE /api/v1/families?user_id=&elder_id=
func (h *FamilyManageHandler) Unbind(c *gin.Context) {
	uid := uint(parseUint(c, "user_id"))
	eid := uint(parseUint(c, "elder_id"))
	if uid == 0 || eid == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误: user_id 与 elder_id 必填")
		return
	}
	if err := h.family.Unbind(uid, eid); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "解绑失败")
		return
	}
	OK(c, gin.H{"unbound": true})
}