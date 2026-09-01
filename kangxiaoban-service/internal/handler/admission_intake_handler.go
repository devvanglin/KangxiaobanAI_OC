package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// CreateIntake handles the operational, one-page admission form.  It is
// deliberately separate from the A/B/C assessment endpoints: submitting this
// form creates the resident/bed/care-plan operational records but never
// pretends that the 26-item ability assessment was completed.
func (h *AdmissionHandler) CreateIntake(c *gin.Context) {
	var req service.AdmissionIntakeInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	result, err := h.svc.CreateIntake(c.Request.Context(), admissionActor(c), req)
	if err != nil {
		h.fail(c, err, "办理入住失败")
		return
	}
	OK(c, result)
}

// GetIntake returns one completed operational intake and its linked records.
func (h *AdmissionHandler) GetIntake(c *gin.Context) {
	id, ok := intakeID(c)
	if !ok {
		return
	}
	result, err := h.svc.GetIntake(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.fail(c, err, "查询入住办理记录失败")
		return
	}
	OK(c, result)
}

// ListIntakes lists operational intake orders.  The response shape follows
// the existing paginated API used by the admission assessment screen.
func (h *AdmissionHandler) ListIntakes(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.ListIntakes(c.Request.Context(), admissionActor(c), c.Query("status"), c.Query("mine") == "true", page, size)
	if err != nil {
		h.fail(c, err, "查询入住办理记录失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func intakeID(c *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		Fail(c, http.StatusBadRequest, 400, "入住办理 ID 无效")
		return 0, false
	}
	return uint(id), true
}
