package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// TaskHandler 护理任务。
type TaskHandler struct {
	svc    *service.TaskService
	hub    *ws.Hub
	family *service.FamilyService
}

func NewTaskHandler(svc *service.TaskService, hub *ws.Hub, family *service.FamilyService) *TaskHandler {
	return &TaskHandler{svc: svc, hub: hub, family: family}
}

func (h *TaskHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	elderID := uint(parseUint(c, "elder_id"))
	allowed := boundElderIDs(c, h.family)
	if isFamilyUser(c) && elderID > 0 && !contains(elderID, allowed) {
		Fail(c, http.StatusForbidden, 403, "无权限访问该长者任务")
		return
	}
	if isFamilyUser(c) && elderID == 0 {
		// Repository 当前支持单 elder 过滤，逐个绑定长者合并由后续分页查询完善；
		// 至少避免家属在未指定 elder_id 时看到全院任务。
		if len(allowed) == 0 {
			OK(c, gin.H{"list": []model.CareTask{}, "page": page, "size": size, "total": 0})
			return
		}
		elderID = allowed[0]
	}
	items, total, err := h.svc.List(elderID, c.Query("status"), page, size)
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
	if !requireElderAccess(c, h.family, req.ElderID) {
		return
	}
	if err := h.svc.Create(&req); err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建任务失败")
		return
	}
	OK(c, req)
}

type setStatusReq struct {
	Status string `json:"status" binding:"required"`
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
	if err := h.svc.SetStatus(uint(id), req.Status); err != nil {
		Fail(c, http.StatusNotFound, 404, "任务不存在")
		return
	}
	// 实时广播任务状态变化
	if t, err := h.svc.Get(uint(id)); err == nil {
		h.hub.BroadcastEvent("task.updated", gin.H{"id": t.ID, "elder_id": t.ElderID, "title": t.Title, "status": t.Status})
	}
	OK(c, gin.H{"id": id, "status": req.Status})
}
