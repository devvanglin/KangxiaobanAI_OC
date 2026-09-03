package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// TaskHandler 护理任务。
type TaskHandler struct {
	svc *service.TaskService
	hub *ws.Hub
}

func NewTaskHandler(svc *service.TaskService, hub *ws.Hub) *TaskHandler {
	return &TaskHandler{svc: svc, hub: hub}
}

func (h *TaskHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	elderID := uint(parseUint(c, "elder_id"))
	cl, _ := middleware.ClaimsFrom(c)
	var assigneeID uint
	if cl != nil && hasRole(cl.Roles, "caregiver") {
		assigneeID = cl.UserID
	}
	items, total, err := h.svc.List(c.Request.Context(), elderID, c.Query("status"), assigneeID, page, size)
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询任务失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *TaskHandler) Create(c *gin.Context) {
	var req model.CareTask
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if req.ElderID == 0 || req.Title == "" {
		Fail(c, http.StatusBadRequest, 400, "elder_id 与 title 必填")
		return
	}
	req.Base = model.Base{}
	req.Status = "todo"
	if cl, ok := middleware.ClaimsFrom(c); ok && hasRole(cl.Roles, "caregiver") {
		req.AssigneeID = &cl.UserID
		req.Assignee = cl.Username
	}
	if err := h.svc.Create(c.Request.Context(), &req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建任务失败")
		return
	}
	OK(c, req)
}

type setStatusReq struct {
	Status string `json:"status" binding:"required"`
	Result string `json:"result"`
}

func (h *TaskHandler) SetStatus(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var req setStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	switch req.Status {
	case "todo", "doing", "done":
	default:
		Fail(c, http.StatusBadRequest, 400, "status 仅支持 todo/doing/done")
		return
	}
	cl, _ := middleware.ClaimsFrom(c)
	var executorID uint
	executor := ""
	if cl != nil {
		executorID = cl.UserID
		executor = cl.Username
	}
	if err := h.svc.SetStatus(c.Request.Context(), uint(id), req.Status, executorID, executor, req.Result); err != nil {
		if errors.Is(err, service.ErrTaskNotAssigned) {
			Fail(c, http.StatusForbidden, 403, "任务已分配给其他护理员")
			return
		}
		if errors.Is(err, repository.ErrTaskStateConflict) {
			Fail(c, http.StatusConflict, 409, "任务状态已变化，请刷新后重试")
			return
		}
		Fail(c, http.StatusNotFound, 404, "任务不存在")
		return
	}
	// 实时广播任务状态变化
	if t, err := h.svc.Get(c.Request.Context(), uint(id)); err == nil {
		tenantID := uint(1)
		if cl != nil && cl.TenantID > 0 {
			tenantID = cl.TenantID
		}
		h.hub.SendToTenant(tenantID, "task.updated", gin.H{"id": t.ID, "elder_id": t.ElderID, "title": t.Title, "status": t.Status})
	}
	OK(c, gin.H{"id": id, "status": req.Status})
}
